# GameData.gd — Autoload Singleton
extends Node

var player_data: Array[Dictionary] = []
var enemy_data: Array[Dictionary] = []
var _initialized := false

# Velocidad global del juego (multiplica el delta en CombatManager)
var game_speed: float = 1.0

func ensure_defaults() -> void:
	if _initialized:
		return
	_initialized = true

	# ── DEFAULTS DE JUGADORES ──
	# Cada jugador: stats base + cadence + ammo + qte + array de elipse_sets (uno por bala)
	player_data = [
		_make_player("Scout",  80.0, 1.4, 15.0, 100.0, 4, 16, 0.45, 0.35, false),
		_make_player("Sniper", 70.0, 0.8, 55.0, 100.0, 1, 5,  0.30, 0.20, false),
		_make_player("Gunner", 120.0, 1.0, 20.0, 100.0, 6, 30, 0.55, 0.45, false),
		_make_player("Medic",  90.0, 1.1, 10.0, 100.0, 2, 10, 0.45, 0.35, false),
	]

	enemy_data = [
		{ "name": "Grunt",  "max_hp": 60.0,  "speed": 1.0, "damage": 12.0, "atb_max": 100.0, "sprite_path": "" },
		{ "name": "Brute",  "max_hp": 200.0, "speed": 0.6, "damage": 35.0, "atb_max": 100.0, "sprite_path": "" },
		{ "name": "Dasher", "max_hp": 40.0,  "speed": 2.0, "damage": 8.0,  "atb_max": 100.0, "sprite_path": "" },
		{ "name": "Tank",   "max_hp": 350.0, "speed": 0.4, "damage": 50.0, "atb_max": 100.0, "sprite_path": "" },
	]

	# Cargar zonas guardadas (si existen) sobre los defaults
	load_enemy_zones()

func _make_player(name: String, hp: float, spd: float, dmg: float, atb: float,
		cad: int, ammo: int, qx: float, qy: float, left: bool) -> Dictionary:
	var sets = []
	# Genera `cad` sets de elipse con dispersión creciente.
	# Coordenadas en formato Desmos (-1..+1 para x/y, r en unidades Desmos).
	for i in cad:
		sets.append({
			"h": 0.0,                     # centro X (Desmos)
			"k": 0.0,                     # centro Y (Desmos)
			"r": 0.10 + i * 0.04,         # radio en unidades Desmos
			"a": 1.0 + i * 0.15,          # escala X
			"b": 1.0,                     # escala Y
		})
	return {
		"name": name,
		"max_hp": hp, "speed": spd, "damage": dmg, "atb_max": atb,
		"cadence": cad, "max_ammo": ammo,
		"qte_speed_x": qx, "qte_speed_y": qy,
		"left_handed": left,
		"elipse_sets": sets,
	}

func build_players() -> Array:
	var PlayerCharacterScript = load("res://Scripts/playercharacter.gd")
	var result: Array = []
	for d in player_data:
		var p = PlayerCharacterScript.new()
		p.character_name = d["name"]
		p.max_hp         = d["max_hp"]
		p.speed          = d["speed"]
		p.damage         = d["damage"]
		p.atb_max        = d["atb_max"]
		p.cadence        = d["cadence"]
		p.max_ammo       = d["max_ammo"]
		p.qte_speed_x    = d.get("qte_speed_x", 0.4)
		p.qte_speed_y    = d.get("qte_speed_y", 0.3)
		p.left_handed    = d.get("left_handed", false)
		# Sets de elipse: copiar profundo para que cada PlayerCharacter tenga los suyos
		var sets_copy = []
		for s in d.get("elipse_sets", []):
			sets_copy.append(s.duplicate(true))
		p.elipse_sets = sets_copy
		p.ensure_elipse_sets()
		p.current_ammo = p.max_ammo
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

# ──────────────────────────────────────────────
#  PERSISTENCIA (savefile)
# ──────────────────────────────────────────────
const SAVE_PATH = "user://hitbox_zones.save"

func save_enemy_zones() -> void:
	var payload = {}
	for i in enemy_data.size():
		var d = enemy_data[i]
		var entry = { "name": d.get("name", "") }
		if d.has("grid_cells"):
			entry["grid_cells"] = d["grid_cells"]
		if d.has("grid_zones"):
			entry["grid_zones"] = d["grid_zones"]
		payload[d.get("name", "enemy_%d" % i)] = entry

	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo abrir el savefile para escritura")
		return
	f.store_string(JSON.stringify(payload))
	f.close()

func load_enemy_zones() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text = f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Savefile corrupto")
		return

	for i in enemy_data.size():
		var name = enemy_data[i].get("name", "")
		if parsed.has(name):
			var saved = parsed[name]
			if saved.has("grid_cells"):
				enemy_data[i]["grid_cells"] = saved["grid_cells"]
			if saved.has("grid_zones"):
				enemy_data[i]["grid_zones"] = saved["grid_zones"]
