extends Node

const PlayerCharacterScript = preload("res://Scripts/playercharacter.gd")
const CharacterScript = preload("res://Scripts/character.gd")

# ──────────────────────────────────────────────
#  SEÑALES
# ──────────────────────────────────────────────
signal player_turn_started(player_char: PlayerCharacter)
signal enemy_turn_resolved(enemy: Character, target: PlayerCharacter, dmg: float)
signal character_died(character: Character, is_player: bool)
signal combat_ended(player_won: bool)
signal atb_updated()

# ──────────────────────────────────────────────
#  ESTADO
# ──────────────────────────────────────────────
enum CombatState { RUNNING, WAITING_PLAYER_ACTION, GAME_OVER }

var state: CombatState = CombatState.RUNNING
var player_chars: Array = []
var enemy_chars: Array = []
var active_player_char = null

# ──────────────────────────────────────────────
#  INICIALIZACIÓN
# ──────────────────────────────────────────────
func setup(players: Array, enemies: Array) -> void:
	# Limpiar estado completamente antes de reiniciar
	state = CombatState.RUNNING
	active_player_char = null
	player_chars = players
	enemy_chars = enemies
	for c in player_chars:
		c.reset()
	for c in enemy_chars:
		c.reset()

# ──────────────────────────────────────────────
#  LOOP PRINCIPAL
# ──────────────────────────────────────────────
func _process(delta: float) -> void:
	if state != CombatState.RUNNING:
		return

	# Tick enemigos primero
	for enemy in enemy_chars:
		if not enemy.get("is_alive"):
			continue
		if enemy.call("tick_atb", delta):
			_resolve_enemy_turn(enemy)
			if state == CombatState.GAME_OVER:
				return
			# Después de un turno enemigo, refrescar y seguir
			# (no retornar, puede que otro enemigo también esté listo)

	# Tick jugadores — si alguno llena el ATB, pausar y esperar input
	for player in player_chars:
		if not player.get("is_alive"):
			continue
		if player.call("tick_atb", delta):
			_start_player_turn(player)
			return  # Sale del _process hasta que el jugador actúe

	emit_signal("atb_updated")

# ──────────────────────────────────────────────
#  TURNO ENEMIGO
# ──────────────────────────────────────────────
func _resolve_enemy_turn(enemy) -> void:
	var alive_players = player_chars.filter(func(p): return p.get("is_alive"))
	if alive_players.is_empty():
		return

	var target: PlayerCharacter = alive_players[randi() % alive_players.size()]
	var dmg = enemy.get("damage")
	target.call("take_damage", dmg)
	enemy.call("consume_atb")

	emit_signal("enemy_turn_resolved", enemy, target, dmg)

	if not target.get("is_alive"):
		emit_signal("character_died", target, true)

	_check_combat_end()

# ──────────────────────────────────────────────
#  TURNO JUGADOR
# ──────────────────────────────────────────────
func _start_player_turn(player) -> void:
	active_player_char = player
	state = CombatState.WAITING_PLAYER_ACTION
	emit_signal("player_turn_started", player)

# Llamado desde CombatUI después de resolver la chance de impacto.
# El daño ya está calculado (puede ser 0 si todas las balas fallaron).
# La munición también ya fue consumida por PlayerCharacter.shoot().
func action_attack_with_damage(target_enemy, total_damage: float) -> void:
	if state != CombatState.WAITING_PLAYER_ACTION:
		return

	if total_damage > 0.0:
		target_enemy.call("take_damage", total_damage)

	active_player_char.call("consume_atb")

	if not target_enemy.get("is_alive"):
		emit_signal("character_died", target_enemy, false)

	_end_player_action()

func action_reload() -> void:
	if state != CombatState.WAITING_PLAYER_ACTION:
		return
	active_player_char.call("reload")
	active_player_char.call("consume_atb")
	_end_player_action()

func _end_player_action() -> void:
	active_player_char = null
	state = CombatState.RUNNING
	_check_combat_end()

# ──────────────────────────────────────────────
#  FIN DE COMBATE
# ──────────────────────────────────────────────
func _check_combat_end() -> void:
	var all_enemies_dead = enemy_chars.all(func(e): return not e.get("is_alive"))
	var all_players_dead = player_chars.all(func(p): return not p.get("is_alive"))

	if all_enemies_dead:
		state = CombatState.GAME_OVER
		emit_signal("combat_ended", true)
	elif all_players_dead:
		state = CombatState.GAME_OVER
		emit_signal("combat_ended", false)

# ──────────────────────────────────────────────
#  HELPERS
# ──────────────────────────────────────────────
func get_active_player():
	return active_player_char

# Helpers para que CombatUI no necesite castear active_player_char
func active_can_shoot(bullets: int) -> bool:
	if active_player_char == null:
		return false
	return active_player_char.call("can_shoot", bullets)

func active_consume_ammo(bullets: int) -> void:
	if active_player_char != null:
		active_player_char.call("consume_ammo", bullets)

func active_reload() -> void:
	if active_player_char != null:
		active_player_char.call("reload")

func active_get_name() -> String:
	if active_player_char == null:
		return ""
	return active_player_char.get("character_name")

func active_get_ammo() -> int:
	if active_player_char == null:
		return 0
	return active_player_char.get("current_ammo")

func active_get_max_ammo() -> int:
	if active_player_char == null:
		return 0
	return active_player_char.get("max_ammo")

func active_get_cadence() -> int:
	if active_player_char == null:
		return 0
	return active_player_char.get("cadence")

func active_get_hit_chance() -> float:
	if active_player_char == null:
		return 0.0
	return active_player_char.call("get_current_hit_chance")

func active_start_qte(qte_display: Node, bullets: int) -> void:
	if active_player_char != null:
		qte_display.call("start_qte", active_player_char, bullets)

func get_alive_enemies() -> Array:
	return enemy_chars.filter(func(e): return e.get("is_alive"))

func get_alive_players() -> Array:
	return player_chars.filter(func(p): return p.get("is_alive"))
