# CombatTracker.gd
# Nodo hijo de Combat (hermano de CombatManager y CombatUI).
# Se engancha a las señales del CombatManager y acumula estadísticas.
# Al terminar el combate escribe el resumen en el log de CombatUI.
extends Node

# ──────────────────────────────────────────────
#  Referencias
# ──────────────────────────────────────────────
@export var combat_manager: Node
@export var combat_ui: Node

# ──────────────────────────────────────────────
#  Datos acumulados
# ──────────────────────────────────────────────

# Por personaje jugador — clave: character_name
# {
#   "shots_fired":    int,
#   "bullets_spent":  int,
#   "damage_dealt":   float,
#   "reloads":        int,
#   "damage_taken":   float,
#   "hits_taken":     int,
#   "death_turn":     int,   # -1 si sobrevivió
# }
var player_stats: Dictionary = {}

# Por enemigo — clave: character_name
# {
#   "damage_taken":  float,
#   "killed_by":     String,  # nombre del jugador que dio el golpe final, "" si no murió
# }
var enemy_stats: Dictionary = {}

# Global
var turn_number: int    = 0
var combat_start_time: float = 0.0

# Último atacante por turno (para registrar kill)
var _last_attacker: String = ""

# ──────────────────────────────────────────────
#  INIT
# ──────────────────────────────────────────────
func _ready() -> void:
	pass  # señales se conectan en reset()

# Llamado desde CombatSetup al (re)iniciar el combate
func reset() -> void:
	if not combat_manager.player_turn_started.is_connected(_on_player_turn_started):
		combat_manager.player_turn_started.connect(_on_player_turn_started)
	if not combat_manager.enemy_turn_resolved.is_connected(_on_enemy_turn_resolved):
		combat_manager.enemy_turn_resolved.connect(_on_enemy_turn_resolved)
	if not combat_manager.character_died.is_connected(_on_character_died):
		combat_manager.character_died.connect(_on_character_died)
	if not combat_manager.combat_ended.is_connected(_on_combat_ended):
		combat_manager.combat_ended.connect(_on_combat_ended)
	player_stats.clear()
	enemy_stats.clear()
	turn_number       = 0
	combat_start_time = Time.get_ticks_msec() / 1000.0
	_last_attacker    = ""

	for p in combat_manager.player_chars:
		player_stats[p.get("character_name")] = {
			"shots_fired":   0,
			"bullets_spent": 0,
			"damage_dealt":  0.0,
			"reloads":       0,
			"damage_taken":  0.0,
			"hits_taken":    0,
			"death_turn":    -1,
		}

	for e in combat_manager.enemy_chars:
		enemy_stats[e.get("character_name")] = {
			"damage_taken": 0.0,
			"killed_by":    "",
		}

# ──────────────────────────────────────────────
#  REGISTRO DE ACCIONES
#  Estas funciones son llamadas externamente desde CombatUI
#  justo antes de delegar al CombatManager.
# ──────────────────────────────────────────────

func record_attack(attacker_name: String, bullets: int, damage: float) -> void:
	if not player_stats.has(attacker_name):
		return
	player_stats[attacker_name]["shots_fired"]   += 1
	player_stats[attacker_name]["bullets_spent"] += bullets
	player_stats[attacker_name]["damage_dealt"]  += damage
	_last_attacker = attacker_name

func record_reload(attacker_name: String) -> void:
	if not player_stats.has(attacker_name):
		return
	player_stats[attacker_name]["reloads"] += 1

func record_enemy_damage(enemy_name: String, damage: float) -> void:
	if not enemy_stats.has(enemy_name):
		return
	enemy_stats[enemy_name]["damage_taken"] += damage

# ──────────────────────────────────────────────
#  SEÑALES DEL COMBAT MANAGER
# ──────────────────────────────────────────────
func _on_player_turn_started(_player_char) -> void:
	turn_number += 1

func _on_enemy_turn_resolved(_enemy, target, dmg: float) -> void:
	turn_number += 1
	if not player_stats.has(target.get("character_name")):
		return
	player_stats[target.get("character_name")]["damage_taken"] += dmg
	player_stats[target.get("character_name")]["hits_taken"]   += 1

func _on_character_died(character, is_player: bool) -> void:
	if is_player:
		if player_stats.has(character.get("character_name")):
			player_stats[character.get("character_name")]["death_turn"] = turn_number
	else:
		if enemy_stats.has(character.get("character_name")) and _last_attacker != "":
			enemy_stats[character.get("character_name")]["killed_by"] = _last_attacker

func _on_combat_ended(player_won: bool) -> void:
	_write_summary(player_won)

# ──────────────────────────────────────────────
#  RESUMEN EN EL LOG
# ──────────────────────────────────────────────
func _write_summary(player_won: bool) -> void:
	var duration = (Time.get_ticks_msec() / 1000.0) - combat_start_time

	combat_ui._log("")
	combat_ui._log("[color=yellow]==============================[/color]")
	if player_won:
		combat_ui._log("[color=yellow]        VICTORIA[/color]")
	else:
		combat_ui._log("[color=red]        DERROTA[/color]")
	combat_ui._log("[color=yellow]==============================[/color]")
	combat_ui._log("[color=gray]Duración: %.1fs  |  Turnos: %d[/color]" % [duration, turn_number])
	combat_ui._log("")

	# ── Jugadores ──
	combat_ui._log("[color=cyan]-- JUGADORES --[/color]")
	for p in combat_manager.player_chars:
		var s: Dictionary = player_stats.get(p.get("character_name"), {})
		if s.is_empty():
			continue

		var status_str: String
		if s["death_turn"] == -1:
			status_str = "[color=green]Sobrevivió[/color]"
		else:
			status_str = "[color=red]Murió (turno %d)[/color]" % s["death_turn"]

		combat_ui._log("[color=white]%s[/color]  -  %s" % [p.get("character_name"), status_str])
		combat_ui._log(
			"  Disparos: [b]%d[/b]  Balas: [b]%d[/b]  Daño: [b]%.0f[/b]  Recargas: [b]%d[/b]" % [
				s["shots_fired"],
				s["bullets_spent"],
				s["damage_dealt"],
				s["reloads"],
			]
		)
		combat_ui._log(
			"  Recibido: [b]%.0f[/b] dmg en [b]%d[/b] golpes" % [
				s["damage_taken"],
				s["hits_taken"],
			]
		)

	combat_ui._log("")

	# ── Enemigos ──
	combat_ui._log("[color=orange]-- ENEMIGOS --[/color]")
	for e in combat_manager.enemy_chars:
		var s: Dictionary = enemy_stats.get(e.get("character_name"), {})
		if s.is_empty():
			continue

		var killed_str: String
		if s["killed_by"] == "":
			killed_str = "[color=yellow]Sobrevivió[/color]"
		else:
			killed_str = "[color=gray]Eliminado por %s[/color]" % s["killed_by"]

		combat_ui._log(
			"[color=white]%s[/color]  —  %s  |  Daño recibido: [b]%.0f[/b]" % [
				e.get("character_name"),
				killed_str,
				s["damage_taken"],
			]
		)

	combat_ui._log("[color=yellow]==============================[/color]")
