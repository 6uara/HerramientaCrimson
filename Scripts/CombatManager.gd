extends Node

const PlayerCharacterScript = preload("res://Scripts/playercharacter.gd")
const CharacterScript = preload("res://Scripts/character.gd")

# ──────────────────────────────────────────────
#  SEÑALES
# ──────────────────────────────────────────────
signal player_ready_changed(player_char, is_ready)
signal action_queued(action_data)        # data: { actor, kind, target, ... }
signal action_started(action_data)
signal action_resolved(action_data)
signal character_died(character, is_player)
signal combat_started
signal combat_ended(player_won: bool)
signal state_changed(new_state)

# ──────────────────────────────────────────────
#  CONFIGURACIÓN
# ──────────────────────────────────────────────
const ENEMY_ACTION_DURATION = 1.2  # segundos que tarda la animación de ataque enemigo

enum State { RUNNING, PLAYER_MENU, ACTION_PLAYING }

# ──────────────────────────────────────────────
#  ESTADO
# ──────────────────────────────────────────────
var player_chars: Array = []
var enemy_chars: Array = []

var combat_active: bool = false
var state: State = State.RUNNING

var _action_queue: Array = []
var _current_action = null
var _action_timer: float = 0.0

var active_player_char = null
var _player_ready_state: Dictionary = {}

# ──────────────────────────────────────────────
#  SETUP
# ──────────────────────────────────────────────
func setup(players: Array, enemies: Array) -> void:
	player_chars = players
	enemy_chars = enemies
	for p in player_chars:
		p.call("reset")
		_player_ready_state[p] = false
	for e in enemy_chars:
		e.call("reset")

func start_combat() -> void:
	combat_active = true
	state = State.RUNNING
	_action_queue.clear()
	_current_action = null
	emit_signal("combat_started")
	emit_signal("state_changed", state)

# ──────────────────────────────────────────────
#  PROCESO PRINCIPAL
# ──────────────────────────────────────────────
func _process(delta: float) -> void:
	if not combat_active:
		return

	var scaled_delta = delta * GameData.game_speed

	if state == State.RUNNING:
		_tick_atb(scaled_delta)
		_try_start_next_action()
	elif state == State.ACTION_PLAYING:
		_tick_current_action(scaled_delta)

func _tick_atb(delta: float) -> void:
	for p in player_chars:
		if not p.get("is_alive"):
			continue
		p.call("tick_atb", delta)
		var is_ready = p.get("atb") >= p.get("atb_max")
		if is_ready != _player_ready_state.get(p, false):
			_player_ready_state[p] = is_ready
			emit_signal("player_ready_changed", p, is_ready)

	for e in enemy_chars:
		if not e.get("is_alive"):
			continue
		if _is_actor_in_queue_or_acting(e):
			continue
		e.call("tick_atb", delta)
		if e.get("atb") >= e.get("atb_max"):
			var action = {
				"actor": e,
				"kind": "enemy_attack",
				"target": null,
			}
			_action_queue.append(action)
			emit_signal("action_queued", action)

func _try_start_next_action() -> void:
	if _current_action != null or _action_queue.is_empty():
		return
	while not _action_queue.is_empty():
		var next = _action_queue[0]
		if not next["actor"].get("is_alive"):
			_action_queue.pop_front()
			continue
		break
	if _action_queue.is_empty():
		return
	_current_action = _action_queue.pop_front()
	_start_action(_current_action)

func _start_action(action: Dictionary) -> void:
	state = State.ACTION_PLAYING
	emit_signal("state_changed", state)

	if action["kind"] == "enemy_attack":
		var alive_players = get_alive_players()
		if alive_players.is_empty():
			_finish_current_action()
			return
		action["target"] = alive_players[randi() % alive_players.size()]
		action["damage"] = float(action["actor"].get("damage"))
		_action_timer = ENEMY_ACTION_DURATION
		emit_signal("action_started", action)

	elif action["kind"] == "player_turn":
		active_player_char = action["actor"]
		_action_timer = 0.0
		emit_signal("action_started", action)

	elif action["kind"] == "player_attack":
		active_player_char = action["actor"]
		_action_timer = 0.0

func _tick_current_action(delta: float) -> void:
	if _current_action == null:
		return
	if _current_action["kind"] != "enemy_attack":
		return
	_action_timer -= delta
	if _action_timer <= 0.0:
		_resolve_enemy_attack()

func _resolve_enemy_attack() -> void:
	if _current_action == null:
		return
	var enemy = _current_action["actor"]
	var target = _current_action["target"]
	var dmg = _current_action.get("damage", float(enemy.get("damage")))

	if not enemy.get("is_alive"):
		_finish_current_action()
		return

	if target == null or not target.get("is_alive"):
		var alive_players = get_alive_players()
		if alive_players.is_empty():
			_finish_current_action()
			return
		target = alive_players[randi() % alive_players.size()]
		_current_action["target"] = target

	target.call("take_damage", dmg)
	if not target.get("is_alive"):
		emit_signal("character_died", target, true)

	enemy.call("consume_atb")
	emit_signal("action_resolved", _current_action)
	_finish_current_action()

func _finish_current_action() -> void:
	print("[DEBUG CM] _finish_current_action ejecutado. Limpiando accion...")
	_current_action = null
	state = State.RUNNING
	emit_signal("state_changed", state)
	print("[DEBUG CM] Estado vuelto a RUNNING. Revisando fin de combate...")
	_check_combat_end()

# ──────────────────────────────────────────────
#  API PARA JUGADOR (llamada por CombatUI)
# ──────────────────────────────────────────────
func queue_player_turn(player) -> bool:
	if not is_player_ready(player):
		return false
	if _is_actor_in_queue_or_acting(player):
		return false
	var action = {
		"actor": player,
		"kind": "player_turn",
		"target": null,
	}
	_action_queue.append(action)
	emit_signal("action_queued", action)
	return true

func confirm_player_attack(target, bullets: int) -> void:
	print("[CM] confirm_player_attack llamado. _current_action: ", _current_action, " active: ", active_player_char)
	if _current_action == null or _current_action.get("kind") != "player_turn":
		print("[CM] confirm_player_attack ABORT — no hay current_action de tipo player_turn")
		return
	if active_player_char == null:
		print("[CM] confirm_player_attack ABORT — no hay active_player_char")
		return
	_current_action["kind"] = "player_attack"
	_current_action["target"] = target
	_current_action["bullets"] = bullets
	print("[CM] confirm_player_attack OK — emitiendo action_started con player_attack")
	emit_signal("action_started", _current_action)

func confirm_player_reload() -> void:
	if _current_action == null or _current_action.get("kind") != "player_turn":
		return
	if active_player_char == null:
		return
	active_player_char.call("reload")
	emit_signal("action_resolved", _current_action)
	active_player_char = null
	_finish_current_action()

func resolve_player_attack(damage_total: float) -> void:
	print("[DEBUG CM] resolve_player_attack INICIO. _current_action: ", _current_action)
	if _current_action == null or _current_action["kind"] != "player_attack":
		print("[DEBUG CM] ERROR: resolve_player_attack abortado (current_action es null o incorrecto)")
		return
		
	var attacker = _current_action["actor"]
	var target = _current_action["target"]

	if target != null and target.get("is_alive"):
		print("[DEBUG CM] Aplicando ", damage_total, " de daño a ", target.get("character_name"))
		target.call("take_damage", damage_total)
		if not target.get("is_alive"):
			print("[DEBUG CM] Target murio.")
			emit_signal("character_died", target, false)
			_remove_actor_from_queue(target)

	attacker.call("consume_atb")
	_player_ready_state[attacker] = false
	emit_signal("player_ready_changed", attacker, false)
	
	print("[DEBUG CM] Emitiendo action_resolved y limpiando turno activo.")
	emit_signal("action_resolved", _current_action)
	active_player_char = null
	
	_finish_current_action()

# ──────────────────────────────────────────────
#  HELPERS
# ──────────────────────────────────────────────
func is_player_ready(player) -> bool:
	if player == null or not player.get("is_alive"):
		return false
	return player.get("atb") >= player.get("atb_max")

func get_ready_players() -> Array:
	var result = []
	for p in player_chars:
		if is_player_ready(p):
			result.append(p)
	return result

func get_alive_enemies() -> Array:
	return enemy_chars.filter(func(e): return e.get("is_alive"))

func get_alive_players() -> Array:
	return player_chars.filter(func(p): return p.get("is_alive"))

func get_active_player():
	return active_player_char

func _is_actor_in_queue_or_acting(actor) -> bool:
	if _current_action != null and _current_action["actor"] == actor:
		return true
	for a in _action_queue:
		if a["actor"] == actor:
			return true
	return false

func _remove_actor_from_queue(actor) -> void:
	var filtered = []
	for a in _action_queue:
		if a["actor"] != actor:
			filtered.append(a)
	_action_queue = filtered

func _check_combat_end() -> void:
	var alive_players = get_alive_players().size()
	var alive_enemies = get_alive_enemies().size()
	if alive_players == 0:
		combat_active = false
		emit_signal("combat_ended", false)
	elif alive_enemies == 0:
		combat_active = false
		emit_signal("combat_ended", true)

# ──────────────────────────────────────────────
#  HELPERS PARA CombatUI / QTEDisplay
# ──────────────────────────────────────────────
func active_can_shoot(bullets: int) -> bool:
	if active_player_char == null:
		return false
	return active_player_char.call("can_shoot", bullets)

func active_consume_ammo(bullets: int) -> void:
	if active_player_char != null:
		active_player_char.call("consume_ammo", bullets)

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

func active_start_qte(qte_display: Node, bullets: int) -> void:
	if active_player_char != null:
		qte_display.call("start_qte", active_player_char, bullets)
