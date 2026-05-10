# CombatTracker.gd
extends Node

@export var combat_manager: Node
@export var combat_ui: Node

var player_stats: Dictionary = {}
var enemy_stats: Dictionary = {}
var turn_number: int = 0
var combat_start_time: float = 0.0
var _last_attacker: String = ""

func _ready() -> void:
	pass  # Señales se conectan desde CombatSetup via reset()

func reset() -> void:
	# Conectar señales si no están conectadas
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
			"shots_fired": 0, "bullets_spent": 0, "damage_dealt": 0.0,
			"reloads": 0, "damage_taken": 0.0, "hits_taken": 0, "death_turn": -1,
		}
	for e in combat_manager.enemy_chars:
		enemy_stats[e.get("character_name")] = { "damage_taken": 0.0, "killed_by": "" }

func record_attack(attacker_name: String, bullets: int, damage: float) -> void:
	if not player_stats.has(attacker_name):
		return
	player_stats[attacker_name]["shots_fired"]   += 1
	player_stats[attacker_name]["bullets_spent"] += bullets
	player_stats[attacker_name]["damage_dealt"]  += damage
	_last_attacker = attacker_name

func record_reload(attacker_name: String) -> void:
	if player_stats.has(attacker_name):
		player_stats[attacker_name]["reloads"] += 1

func record_enemy_damage(enemy_name: String, damage: float) -> void:
	if enemy_stats.has(enemy_name):
		enemy_stats[enemy_name]["damage_taken"] += damage

func _on_player_turn_started(_player_char) -> void:
	turn_number += 1

func _on_enemy_turn_resolved(_enemy, target, dmg: float) -> void:
	turn_number += 1
	var name = target.get("character_name")
	if player_stats.has(name):
		player_stats[name]["damage_taken"] += dmg
		player_stats[name]["hits_taken"]   += 1

func _on_character_died(character, is_player: bool) -> void:
	var name = character.get("character_name")
	if is_player:
		if player_stats.has(name):
			player_stats[name]["death_turn"] = turn_number
	else:
		if enemy_stats.has(name) and _last_attacker != "":
			enemy_stats[name]["killed_by"] = _last_attacker

func _on_combat_ended(player_won: bool) -> void:
	_write_summary(player_won)

func _write_summary(player_won: bool) -> void:
	var duration = (Time.get_ticks_msec() / 1000.0) - combat_start_time
	combat_ui._log("")
	combat_ui._log("[color=yellow]==============================[/color]")
	combat_ui._log("[color=%s]  %s  [/color]" % ["yellow" if player_won else "red",
		"VICTORIA" if player_won else "DERROTA"])
	combat_ui._log("[color=yellow]==============================[/color]")
	combat_ui._log("[color=gray]Duracion: %.1fs  |  Turnos: %d[/color]" % [duration, turn_number])
	combat_ui._log("")
	combat_ui._log("[color=cyan]-- JUGADORES --[/color]")
	for p in combat_manager.player_chars:
		var pname = p.get("character_name")
		var s: Dictionary = player_stats.get(pname, {})
		if s.is_empty():
			continue
		var status = "[color=green]Sobrevivio[/color]" if s["death_turn"] == -1 \
			else "[color=red]Murio (turno %d)[/color]" % s["death_turn"]
		combat_ui._log("[color=white]%s[/color]  -  %s" % [pname, status])
		combat_ui._log("  Disparos: [b]%d[/b]  Balas: [b]%d[/b]  Dano: [b]%.0f[/b]  Recargas: [b]%d[/b]" % [
			s["shots_fired"], s["bullets_spent"], s["damage_dealt"], s["reloads"]])
		combat_ui._log("  Recibido: [b]%.0f[/b] dmg en [b]%d[/b] golpes" % [
			s["damage_taken"], s["hits_taken"]])
	combat_ui._log("")
	combat_ui._log("[color=orange]-- ENEMIGOS --[/color]")
	for e in combat_manager.enemy_chars:
		var ename = e.get("character_name")
		var s: Dictionary = enemy_stats.get(ename, {})
		if s.is_empty():
			continue
		var killed = "[color=yellow]Sobrevivio[/color]" if s["killed_by"] == "" \
			else "[color=gray]Eliminado por %s[/color]" % s["killed_by"]
		combat_ui._log("[color=white]%s[/color]  -  %s  |  Dano recibido: [b]%.0f[/b]" % [
			ename, killed, s["damage_taken"]])
	combat_ui._log("[color=yellow]==============================[/color]")
