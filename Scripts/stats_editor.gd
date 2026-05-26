# StatsEditor.gd
# Editor en runtime de TODOS los stats de jugadores y enemigos.
# UI 100% generada por código.
# process_mode: Always
extends Control

signal close_requested
signal apply_and_restart
signal resume_combat

@export var btn_close: Button
@export var btn_apply: Button
@export var btn_reset: Button
@export var tab_container: TabContainer

const STAT_FIELDS_PLAYER = [
	{ "key": "max_hp",       "label": "HP máximo",       "min": 1,    "max": 9999, "step": 1.0 },
	{ "key": "speed",        "label": "Velocidad ATB",   "min": 0.1,  "max": 10.0, "step": 0.05 },
	{ "key": "damage",       "label": "Daño base",       "min": 0,    "max": 999,  "step": 0.5 },
	{ "key": "atb_max",      "label": "ATB máximo",      "min": 10,   "max": 999,  "step": 1.0 },
	{ "key": "cadence",      "label": "Cadencia",        "min": 1,    "max": 20,   "step": 1.0 },
	{ "key": "max_ammo",     "label": "Munición máx",    "min": 1,    "max": 999,  "step": 1.0 },
	{ "key": "qte_speed_x",  "label": "QTE velocidad X", "min": 0.05, "max": 5.0,  "step": 0.05 },
	{ "key": "qte_speed_y",  "label": "QTE velocidad Y", "min": 0.05, "max": 5.0,  "step": 0.05 },
]
const STAT_FIELDS_ENEMY = [
	{ "key": "max_hp",   "label": "HP máximo",     "min": 1,    "max": 9999, "step": 1.0 },
	{ "key": "speed",    "label": "Velocidad ATB", "min": 0.1,  "max": 10.0, "step": 0.05 },
	{ "key": "damage",   "label": "Daño",          "min": 0,    "max": 999,  "step": 0.5 },
	{ "key": "atb_max",  "label": "ATB máximo",    "min": 10,   "max": 999,  "step": 1.0 },
]
const ELIPSE_FIELDS = [
	{ "key": "h", "label": "h (centro X, Desmos)",  "min": -1.0, "max": 1.0, "step": 0.01 },
	{ "key": "k", "label": "k (centro Y, Desmos)",  "min": -1.0, "max": 1.0, "step": 0.01 },
	{ "key": "r", "label": "r (radio, Desmos)",     "min": 0.0,  "max": 2.0, "step": 0.01 },
	{ "key": "a", "label": "a (escala X)",          "min": 0.1,  "max": 5.0, "step": 0.05 },
	{ "key": "b", "label": "b (escala Y)",          "min": 0.1,  "max": 5.0, "step": 0.05 },
]

var _player_cards: Array = []
var _enemy_cards: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_close.pressed.connect(func():
		emit_signal("close_requested")
		emit_signal("resume_combat")
	)
	btn_apply.pressed.connect(func():
		_apply_changes()
		emit_signal("apply_and_restart")
	)
	btn_reset.pressed.connect(_reset_to_defaults)
	hide()

func refresh() -> void:
	_build_tabs()

# ──────────────────────────────────────────────
#  CONSTRUCCIÓN DE LA UI
# ──────────────────────────────────────────────
func _build_tabs() -> void:
	for child in tab_container.get_children():
		tab_container.remove_child(child)
		child.queue_free()
	_player_cards.clear()
	_enemy_cards.clear()
	var players_scroll = ScrollContainer.new()
	players_scroll.name = "Jugadores"
	var players_vbox = VBoxContainer.new()
	players_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_vbox.add_theme_constant_override("separation", 12)
	players_scroll.add_child(players_vbox)
	tab_container.add_child(players_scroll)
	for i in GameData.player_data.size():
		var card = _build_player_card(GameData.player_data[i])
		players_vbox.add_child(card["root"])
		_player_cards.append(card)
	var enemies_scroll = ScrollContainer.new()
	enemies_scroll.name = "Enemigos"
	var enemies_vbox = VBoxContainer.new()
	enemies_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemies_vbox.add_theme_constant_override("separation", 12)
	enemies_scroll.add_child(enemies_vbox)
	tab_container.add_child(enemies_scroll)
	for i in GameData.enemy_data.size():
		var card = _build_enemy_card(GameData.enemy_data[i])
		enemies_vbox.add_child(card["root"])
		_enemy_cards.append(card)

func _build_player_card(d: Dictionary) -> Dictionary:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var name_row = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = "Nombre"
	name_lbl.custom_minimum_size.x = 130
	name_row.add_child(name_lbl)
	var name_edit = LineEdit.new()
	name_edit.text = d.get("name", "")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	vbox.add_child(name_row)
	var fields = {}
	for f in STAT_FIELDS_PLAYER:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = f["label"]
		lbl.custom_minimum_size.x = 130
		row.add_child(lbl)
		var spin = SpinBox.new()
		spin.min_value = f["min"]
		spin.max_value = f["max"]
		spin.step = f["step"]
		spin.value = float(d.get(f["key"], 0))
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spin)
		vbox.add_child(row)
		fields[f["key"]] = spin
	var lh_row = HBoxContainer.new()
	var lh_lbl = Label.new()
	lh_lbl.text = "Zurdo"
	lh_lbl.custom_minimum_size.x = 130
	lh_row.add_child(lh_lbl)
	var lh_check = CheckBox.new()
	lh_check.button_pressed = bool(d.get("left_handed", false))
	lh_row.add_child(lh_check)
	vbox.add_child(lh_row)
	vbox.add_child(HSeparator.new())
	var sets_header = Label.new()
	sets_header.text = "Sets de elipse (uno por disparo)"
	sets_header.add_theme_font_size_override("font_size", 13)
	sets_header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(sets_header)
	var sets_container = VBoxContainer.new()
	sets_container.add_theme_constant_override("separation", 6)
	vbox.add_child(sets_container)
	var elipse_spins = []  
	_build_elipse_sets_ui(sets_container, d.get("elipse_sets", []), elipse_spins)
	return {
		"root": panel,
		"name_edit": name_edit,
		"fields": fields,
		"left_handed_check": lh_check,
		"elipse_spins": elipse_spins,
		"sets_container": sets_container,
		"cadence_spin": fields["cadence"],
	}

func _build_elipse_sets_ui(container: VBoxContainer, sets: Array, out_spins: Array) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()
	out_spins.clear()
	for i in sets.size():
		var set_data = sets[i]
		var set_panel = PanelContainer.new()
		var set_vbox = VBoxContainer.new()
		set_panel.add_child(set_vbox)
		var title = Label.new()
		title.text = "Disparo #%d" % (i + 1)
		title.add_theme_font_size_override("font_size", 11)
		set_vbox.add_child(title)
		var spins_dict = {}
		for f in ELIPSE_FIELDS:
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = f["label"]
			lbl.custom_minimum_size.x = 120
			lbl.add_theme_font_size_override("font_size", 10)
			row.add_child(lbl)
			var spin = SpinBox.new()
			spin.min_value = f["min"]
			spin.max_value = f["max"]
			spin.step = f["step"]
			spin.value = float(set_data.get(f["key"], 0))
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spin)
			set_vbox.add_child(row)
			spins_dict[f["key"]] = spin
		out_spins.append(spins_dict)
		container.add_child(set_panel)

func _build_enemy_card(d: Dictionary) -> Dictionary:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var name_row = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = "Nombre"
	name_lbl.custom_minimum_size.x = 130
	name_row.add_child(name_lbl)
	var name_edit = LineEdit.new()
	name_edit.text = d.get("name", "")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	vbox.add_child(name_row)
	var path_row = HBoxContainer.new()
	var path_lbl = Label.new()
	path_lbl.text = "Sprite"
	path_lbl.custom_minimum_size.x = 130
	path_row.add_child(path_lbl)
	var path_edit = LineEdit.new()
	path_edit.text = d.get("sprite_path", "")
	path_edit.placeholder_text = "res://Sprites/enemy.png"
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(path_edit)
	vbox.add_child(path_row)
	var fields = {}
	for f in STAT_FIELDS_ENEMY:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = f["label"]
		lbl.custom_minimum_size.x = 130
		row.add_child(lbl)
		var spin = SpinBox.new()
		spin.min_value = f["min"]
		spin.max_value = f["max"]
		spin.step = f["step"]
		spin.value = float(d.get(f["key"], 0))
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spin)
		vbox.add_child(row)
		fields[f["key"]] = spin
	return {
		"root": panel,
		"name_edit": name_edit,
		"sprite_path_edit": path_edit,
		"fields": fields,
	}

# ──────────────────────────────────────────────
#  APLICAR Y RESET
# ──────────────────────────────────────────────
func _apply_changes() -> void:
	# Jugadores
	for i in _player_cards.size():
		var card = _player_cards[i]
		var d = GameData.player_data[i]
		d["name"] = card["name_edit"].text
		for key in card["fields"]:
			var val = card["fields"][key].value
			if key in ["cadence", "max_ammo", "atb_max"]:
				d[key] = int(val)
			else:
				d[key] = val
		d["left_handed"] = card["left_handed_check"].button_pressed
		var new_cad = int(d["cadence"])
		var current_sets = d.get("elipse_sets", [])
		if current_sets.size() != new_cad:
			while current_sets.size() < new_cad:
				current_sets.append({
					"h": 0.0, "k": 0.0,
					"r": 0.10 + current_sets.size() * 0.04,
					"a": 1.0, "b": 1.0,
				})
			while current_sets.size() > new_cad:
				current_sets.pop_back()
			d["elipse_sets"] = current_sets
		for j in card["elipse_spins"].size():
			if j >= d["elipse_sets"].size():
				break
			var spins = card["elipse_spins"][j]
			for key in spins:
				d["elipse_sets"][j][key] = spins[key].value
	for i in _enemy_cards.size():
		var card = _enemy_cards[i]
		var d = GameData.enemy_data[i]
		d["name"] = card["name_edit"].text
		d["sprite_path"] = card["sprite_path_edit"].text.strip_edges()
		for key in card["fields"]:
			var val = card["fields"][key].value
			if key in ["atb_max"]:
				d[key] = int(val)
			else:
				d[key] = val
	refresh()

func _reset_to_defaults() -> void:
	GameData._initialized = false
	GameData.ensure_defaults()
	refresh()
