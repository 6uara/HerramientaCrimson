# StatsEditor.gd
extends Control

# ──────────────────────────────────────────────
#  Definición de campos por tipo de personaje
# ──────────────────────────────────────────────
const PLAYER_FIELDS = [
	{ "key": "max_hp",   "label": "HP Máx",      "min": 1.0,  "max": 9999.0, "step": 1.0,  "is_int": false },
	{ "key": "speed",    "label": "Velocidad",    "min": 0.1,  "max": 10.0,   "step": 0.05, "is_int": false },
	{ "key": "damage",   "label": "Daño/Bala",    "min": 1.0,  "max": 9999.0, "step": 1.0,  "is_int": false },
	{ "key": "atb_max",  "label": "ATB Máx",      "min": 10.0, "max": 500.0,  "step": 5.0,  "is_int": false },
	{ "key": "cadence",           "label": "Cadencia",        "min": 1.0,  "max": 20.0,  "step": 1.0,   "is_int": true  },
	{ "key": "max_ammo",          "label": "Munición Máx",    "min": 1.0,  "max": 999.0, "step": 1.0,   "is_int": true  },
	{ "key": "hit_chance_base",   "label": "Chance base (%)", "min": 0.0,  "max": 100.0, "step": 1.0,   "is_int": false },
	{ "key": "hit_chance_penalty","label": "Penalidad/bala (%)", "min": 0.0, "max": 100.0, "step": 1.0, "is_int": false },
]

const ENEMY_FIELDS = [
	{ "key": "max_hp",  "label": "HP Máx",    "min": 1.0,  "max": 9999.0, "step": 1.0,  "is_int": false },
	{ "key": "speed",   "label": "Velocidad", "min": 0.1,  "max": 10.0,   "step": 0.05, "is_int": false },
	{ "key": "damage",  "label": "Daño",      "min": 1.0,  "max": 9999.0, "step": 1.0,  "is_int": false },
	{ "key": "atb_max", "label": "ATB Máx",   "min": 10.0, "max": 500.0,  "step": 5.0,  "is_int": false },
]

# ──────────────────────────────────────────────
#  Señales
# ──────────────────────────────────────────────
signal apply_and_restart   
signal resume_combat        

# ──────────────────────────────────────────────
#  Referencias a nodos 
# ──────────────────────────────────────────────
@export var tab_container: TabContainer 
@export var btn_apply: Button       
@export var btn_cancel: Button      
@export var btn_reset: Button         
@export var status_label: Label      

var _widgets: Dictionary = { "players": [], "enemies": [] }

# ──────────────────────────────────────────────
#  INICIALIZACIÓN
# ──────────────────────────────────────────────
func _ready() -> void:
	GameData.ensure_defaults()
	_build_tabs()

	btn_apply.pressed.connect(_on_apply)
	btn_cancel.pressed.connect(_on_cancel)
	btn_reset.pressed.connect(_on_reset_defaults)

	status_label.text = ""

# ──────────────────────────────────────────────
#  CONSTRUCCIÓN DINÁMICA DE TABS Y CAMPOS
# ──────────────────────────────────────────────
func _build_tabs() -> void:
	for child in tab_container.get_children():
		tab_container.remove_child(child)
		child.free()

	_widgets["players"].clear()
	_widgets["enemies"].clear()

	# Tab de Jugadores
	var players_tab = _build_group_tab(
		GameData.player_data,
		PLAYER_FIELDS,
		_widgets["players"],
		true
	)
	tab_container.add_child(players_tab)
	players_tab.name = "Jugadores"

	# Tab de Enemigos
	var enemies_tab = _build_group_tab(
		GameData.enemy_data,
		ENEMY_FIELDS,
		_widgets["enemies"],
		false
	)
	tab_container.add_child(enemies_tab)
	enemies_tab.name = "Enemigos"

func _build_group_tab(
		data_array: Array,
		fields: Array,
		widget_array: Array,
		is_player: bool
) -> ScrollContainer:

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)
	scroll.add_child(hbox)

	for i in data_array.size():
		var char_data: Dictionary = data_array[i]
		var card_data: Dictionary = { "index": i, "is_player": is_player, "fields": {} }

		# Panel tarjeta
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(200, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(panel)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		panel.add_child(vbox)

		# Header con nombre editable
		var header = Label.new()
		header.text = "── %s ──" % char_data["name"]
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		vbox.add_child(header)

		var name_hbox = HBoxContainer.new()
		var name_lbl = Label.new()
		name_lbl.text = "Nombre"
		name_lbl.custom_minimum_size.x = 90
		name_hbox.add_child(name_lbl)
		var name_edit = LineEdit.new()
		name_edit.text = char_data["name"]
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_hbox.add_child(name_edit)
		vbox.add_child(name_hbox)
		card_data["name_edit"] = name_edit

		# Separador
		vbox.add_child(HSeparator.new())

		# Campos numéricos
		for field in fields:
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = field["label"]
			lbl.custom_minimum_size.x = 90
			row.add_child(lbl)

			var spin = SpinBox.new()
			spin.min_value = field["min"]
			spin.max_value = field["max"]
			spin.step      = field["step"]
			# Usar .get() con fallback para evitar crash si la key no existe en el dict
			var raw_val = char_data.get(field["key"], field["min"])
			if field["key"] in ["hit_chance_base", "hit_chance_penalty"]:
				# hit_chance se guarda en 0-1 pero el editor lo muestra en 0-100
				spin.value = raw_val * 100.0
			else:
				spin.value = raw_val
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if field["is_int"]:
				spin.step = 1.0
			row.add_child(spin)

			card_data["fields"][field["key"]] = spin
			vbox.add_child(row)

		widget_array.append(card_data)

	return scroll

# ──────────────────────────────────────────────
#  ACCIONES DE BOTONES
# ──────────────────────────────────────────────
func _on_apply() -> void:
	_read_widgets_into_gamedata()
	status_label.text = "✓ Valores guardados. Reiniciando combate..."
	status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	# Pequeña pausa visual antes de emitir
	await get_tree().create_timer(0.4).timeout
	emit_signal("apply_and_restart")

func _on_cancel() -> void:
	emit_signal("resume_combat")

func _on_reset_defaults() -> void:
	# Fuerza reinicializar los defaults y reconstruye los widgets
	GameData._initialized = false
	GameData.ensure_defaults()
	_build_tabs()
	status_label.text = "Valores restaurados a los defaults."
	status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))

# ──────────────────────────────────────────────
#  LEER WIDGETS Y ESCRIBIR EN GameData
# ──────────────────────────────────────────────
func _read_widgets_into_gamedata() -> void:
	for card_data in _widgets["players"]:
		var i: int = card_data["index"]
		GameData.player_data[i]["name"] = card_data["name_edit"].text
		for key in card_data["fields"]:
			var spin: SpinBox = card_data["fields"][key]
			if key in ["cadence", "max_ammo"]:
				GameData.player_data[i][key] = int(spin.value)
			elif key in ["hit_chance_base", "hit_chance_penalty"]:
				# Editor muestra 0-100, GameData guarda 0.0-1.0
				GameData.player_data[i][key] = spin.value / 100.0
			else:
				GameData.player_data[i][key] = spin.value

	for card_data in _widgets["enemies"]:
		var i: int = card_data["index"]
		GameData.enemy_data[i]["name"] = card_data["name_edit"].text
		for key in card_data["fields"]:
			var spin: SpinBox = card_data["fields"][key]
			GameData.enemy_data[i][key] = spin.value
