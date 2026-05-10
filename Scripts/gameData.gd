# GameData.gd — Autoload Singleton
# Añadilo en Project > Project Settings > Autoload como "GameData"
extends Node

var player_data: Array[Dictionary] = []
var enemy_data: Array[Dictionary] = []
var _initialized := false

func ensure_defaults() -> void:
	if _initialized:
		if player_data.size() > 0 and not player_data[0].has("hit_chance_base"):
			_initialized = false
	if _initialized:
		return
	_initialized = true

	player_data = [
		{
			"name": "Scout",
			"max_hp": 80.0, "speed": 1.4, "damage": 15.0, "atb_max": 100.0,
			"cadence": 4, "max_ammo": 16,
			"hit_chance_base": 0.80, "hit_chance_penalty": 0.02,
			"qte_speed_x": 0.45, "qte_speed_y": 0.35, "left_handed": false,
			"elipse_h": 0.0, "elipse_k": 0.05, "elipse_r": 0.06, "elipse_a": 1.2, "elipse_b": 0.8,
		},
		{
			"name": "Sniper",
			"max_hp": 70.0, "speed": 0.8, "damage": 55.0, "atb_max": 100.0,
			"cadence": 1, "max_ammo": 5,
			"hit_chance_base": 0.90, "hit_chance_penalty": 0.01,
			"qte_speed_x": 0.3, "qte_speed_y": 0.2, "left_handed": false,
			"elipse_h": 0.0, "elipse_k": 0.02, "elipse_r": 0.03, "elipse_a": 1.0, "elipse_b": 1.0,
		},
		{
			"name": "Gunner",
			"max_hp": 120.0, "speed": 1.0, "damage": 20.0, "atb_max": 100.0,
			"cadence": 6, "max_ammo": 30,
			"hit_chance_base": 0.75, "hit_chance_penalty": 0.03,
			"qte_speed_x": 0.55, "qte_speed_y": 0.45, "left_handed": false,
			"elipse_h": 0.0, "elipse_k": 0.08, "elipse_r": 0.10, "elipse_a": 1.5, "elipse_b": 0.7,
		},
		{
			"name": "Medic",
			"max_hp": 90.0, "speed": 1.1, "damage": 10.0, "atb_max": 100.0,
			"cadence": 2, "max_ammo": 10,
			"hit_chance_base": 0.80, "hit_chance_penalty": 0.02,
			"qte_speed_x": 0.45, "qte_speed_y": 0.35, "left_handed": false,
			"elipse_h": 0.0, "elipse_k": 0.05, "elipse_r": 0.06, "elipse_a": 1.2, "elipse_b": 0.8,
		},
	]

	enemy_data = [
		{ "name": "Grunt",  "max_hp": 60.0,  "speed": 1.0, "damage": 12.0, "atb_max": 100.0, "sprite_path": "" },
		{ "name": "Brute",  "max_hp": 200.0, "speed": 0.6, "damage": 35.0, "atb_max": 100.0, "sprite_path": "" },
		{ "name": "Dasher", "max_hp": 40.0,  "speed": 2.0, "damage": 8.0,  "atb_max": 100.0, "sprite_path": "" },
		{ "name": "Tank",   "max_hp": 350.0, "speed": 0.4, "damage": 50.0, "atb_max": 100.0, "sprite_path": "" },
	]

func build_players() -> Array:
	var PlayerCharacterScript = load("res://Scripts/playercharacter.gd")
	var result: Array = []
	for d in player_data:
		var p = PlayerCharacterScript.new()
		p.character_name      = d["name"]
		p.max_hp              = d["max_hp"]
		p.speed               = d["speed"]
		p.damage              = d["damage"]
		p.atb_max             = d["atb_max"]
		p.cadence             = d["cadence"]
		p.max_ammo            = d["max_ammo"]
		p.hit_chance_base     = d.get("hit_chance_base", 0.80)
		p.hit_chance_penalty  = d.get("hit_chance_penalty", 0.02)
		p.qte_speed_x         = d.get("qte_speed_x", 0.4)
		p.qte_speed_y         = d.get("qte_speed_y", 0.3)
		p.left_handed         = d.get("left_handed", false)
		p.elipse_h            = d.get("elipse_h", 0.0)
		p.elipse_k            = d.get("elipse_k", 0.05)
		p.elipse_r            = d.get("elipse_r", 0.08)
		p.elipse_a            = d.get("elipse_a", 1.2)
		p.elipse_b            = d.get("elipse_b", 0.8)
		result.append(p)
	return result

func build_enemies() -> Array:
	var CharacterScript = load("res://Scripts/character.gd")
	var result: Array = []
	for d in enemy_data:
		var e = CharacterScript.new()
		e.character_name = d["name"]
		e.max_hp         = d["max_hp"]
		e.speed          = d["speed"]
		e.damage         = d["damage"]
		e.atb_max        = d["atb_max"]
		result.append(e)
	return result
