# hitboxEditor.gd
# Editor de zonas de daño con grilla. UI 100% generada por código.
# process_mode: Always
extends Control

signal close_requested

# ──────────────────────────────────────────────
#  Constantes
# ──────────────────────────────────────────────
const GRID_COLS = 10
const GRID_ROWS = 15
const SPRITE_DISPLAY_SIZE = Vector2(300.0, 450.0)
const PANEL_WIDTH = 300

const DEFAULT_ZONES = [
	{ "name": "Cabeza",  "mult": 2.0, "color": Color(1.0, 0.25, 0.25, 0.7) },
	{ "name": "Torso",   "mult": 1.0, "color": Color(0.25, 0.55, 1.0, 0.7) },
	{ "name": "Piernas", "mult": 0.6, "color": Color(0.25, 0.9, 0.35, 0.7) },
]
const ZONE_COLORS_AVAILABLE = [
	Color(1.0, 0.25, 0.25, 0.7),
	Color(0.25, 0.55, 1.0, 0.7),
	Color(0.25, 0.9, 0.35, 0.7),
	Color(1.0, 0.8, 0.1, 0.7),
	Color(0.8, 0.25, 1.0, 0.7),
	Color(1.0, 0.5, 0.1, 0.7),
]

# ──────────────────────────────────────────────
#  Estado
# ──────────────────────────────────────────────
var _current_enemy = 0
var _zones = []
var _selected_zone = 0
var _cells = []
var _cell_buttons = []

# Nodos UI generados por código
var _enemy_tabs: TabBar
var _zone_list: VBoxContainer
var _btn_close_back: Button  # se conserva del @export para compat
var _grid_container: GridContainer
var _sprite_rect: TextureRect
var _enemy_name_label: Label

# ──────────────────────────────────────────────
#  READY
# ──────────────────────────────────────────────
func _draw() -> void:
	# Fondo opaco para tapar el combate
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.06, 0.06, 0.09, 1.0))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	hide()

func refresh() -> void:
	_build_enemy_tabs()
	if GameData.enemy_data.size() > 0:
		_load_enemy(0)

# ──────────────────────────────────────────────
#  CONSTRUCCIÓN COMPLETA DE LA UI
# ──────────────────────────────────────────────
func _build_ui() -> void:
	var vp = get_viewport_rect().size

	# ──── PANEL IZQUIERDO ────
	var left_panel = PanelContainer.new()
	left_panel.position = Vector2.ZERO
	left_panel.size = Vector2(PANEL_WIDTH, vp.y)
	add_child(left_panel)

	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	# Título
	var title = Label.new()
	title.text = "Editor de Hitboxes"
	title.add_theme_font_size_override("font_size", 18)
	left_vbox.add_child(title)

	# Tabs de enemigos
	_enemy_tabs = TabBar.new()
	_enemy_tabs.tab_changed.connect(_on_tab_changed)
	left_vbox.add_child(_enemy_tabs)

	# Botones acción
	var btn_row = HBoxContainer.new()
	var btn_add = Button.new()
	btn_add.text = "+ Zona"
	btn_add.pressed.connect(_add_zone)
	btn_row.add_child(btn_add)

	var btn_reset = Button.new()
	btn_reset.text = "Reset"
	btn_reset.pressed.connect(_reset_all)
	btn_row.add_child(btn_reset)

	var btn_close = Button.new()
	btn_close.text = "Cerrar"
	btn_close.pressed.connect(func(): emit_signal("close_requested"))
	btn_row.add_child(btn_close)
	left_vbox.add_child(btn_row)

	# Separador
	left_vbox.add_child(HSeparator.new())

	# Lista de zonas (scroll)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	_zone_list = VBoxContainer.new()
	_zone_list.add_theme_constant_override("separation", 6)
	_zone_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_zone_list)

	# ──── ÁREA DERECHA: SPRITE + GRILLA ────
	var right_x = PANEL_WIDTH + (vp.x - PANEL_WIDTH - SPRITE_DISPLAY_SIZE.x) / 2
	var right_y = vp.y * 0.5 - SPRITE_DISPLAY_SIZE.y / 2

	# Label arriba con nombre del enemigo
	_enemy_name_label = Label.new()
	_enemy_name_label.position = Vector2(right_x, right_y - 40)
	_enemy_name_label.size = Vector2(SPRITE_DISPLAY_SIZE.x, 20)
	_enemy_name_label.text = ""
	_enemy_name_label.add_theme_font_size_override("font_size", 16)
	add_child(_enemy_name_label)

	var help = Label.new()
	help.position = Vector2(right_x, right_y - 18)
	help.size = Vector2(SPRITE_DISPLAY_SIZE.x, 16)
	help.text = "Click izq: pintar  |  Click der: borrar  |  Drag para pintar varias"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(help)

	# TextureRect del sprite (debajo de la grilla)
	_sprite_rect = TextureRect.new()
	_sprite_rect.position = Vector2(right_x, right_y)
	_sprite_rect.size = SPRITE_DISPLAY_SIZE
	_sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite_rect)

	# Fondo gris debajo del sprite para ver donde está
	var bg_rect = ColorRect.new()
	bg_rect.position = Vector2(right_x, right_y)
	bg_rect.size = SPRITE_DISPLAY_SIZE
	bg_rect.color = Color(0.20, 0.20, 0.25, 1.0)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)
	move_child(bg_rect, _sprite_rect.get_index())  # bg detrás del sprite

	# Grilla de celdas (encima del sprite)
	_grid_container = GridContainer.new()
	_grid_container.position = Vector2(right_x, right_y)
	_grid_container.size = SPRITE_DISPLAY_SIZE
	_grid_container.columns = GRID_COLS
	_grid_container.add_theme_constant_override("h_separation", 1)
	_grid_container.add_theme_constant_override("v_separation", 1)
	add_child(_grid_container)

	_build_grid()

# ──────────────────────────────────────────────
#  GRILLA
# ──────────────────────────────────────────────
func _build_grid() -> void:
	for child in _grid_container.get_children():
		_grid_container.remove_child(child)
		child.free()
	_cell_buttons.clear()

	var cell_w = SPRITE_DISPLAY_SIZE.x / GRID_COLS
	var cell_h = SPRITE_DISPLAY_SIZE.y / GRID_ROWS

	for r in GRID_ROWS:
		for c in GRID_COLS:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(cell_w, cell_h)
			btn.flat = false
			btn.focus_mode = Control.FOCUS_NONE
			var idx = r * GRID_COLS + c
			btn.gui_input.connect(_on_cell_input.bind(idx))
			_grid_container.add_child(btn)
			_cell_buttons.append(btn)

	if _cells.is_empty():
		for i in GRID_COLS * GRID_ROWS:
			_cells.append(-1)
	_refresh_grid_visual()

func _refresh_grid_visual() -> void:
	for i in min(_cells.size(), _cell_buttons.size()):
		var zone_idx = _cells[i]
		var btn = _cell_buttons[i]
		var sb = StyleBoxFlat.new()
		var sb_hover = StyleBoxFlat.new()
		if zone_idx >= 0 and zone_idx < _zones.size():
			sb.bg_color = _zones[zone_idx]["color"]
			sb.border_color = Color(1, 1, 1, 0.5)
			sb_hover.bg_color = _zones[zone_idx]["color"].lightened(0.2)
			sb_hover.border_color = Color.WHITE
		else:
			sb.bg_color = Color(0.5, 0.5, 0.5, 0.30)
			sb.border_color = Color(1, 1, 1, 0.35)
			sb_hover.bg_color = Color(0.7, 0.7, 0.7, 0.5)
			sb_hover.border_color = Color.WHITE
		for s in [sb, sb_hover]:
			s.border_width_left = 1
			s.border_width_top = 1
			s.border_width_right = 1
			s.border_width_bottom = 1
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("focus", sb)
		btn.add_theme_stylebox_override("disabled", sb)

# ──────────────────────────────────────────────
#  INPUT EN CELDAS
# ──────────────────────────────────────────────
func _on_cell_input(event: InputEvent, cell_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _selected_zone >= 0 and _selected_zone < _zones.size():
				_cells[cell_idx] = _selected_zone
				_refresh_grid_visual()
				_save_current()
				_refresh_zone_list()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cells[cell_idx] = -1
			_refresh_grid_visual()
			_save_current()
			_refresh_zone_list()
	elif event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_LEFT:
		if _selected_zone >= 0 and _selected_zone < _zones.size():
			_cells[cell_idx] = _selected_zone
			_refresh_grid_visual()

# ──────────────────────────────────────────────
#  TABS DE ENEMIGOS
# ──────────────────────────────────────────────
func _build_enemy_tabs() -> void:
	while _enemy_tabs.tab_count > 0:
		_enemy_tabs.remove_tab(0)
	for d in GameData.enemy_data:
		_enemy_tabs.add_tab(d["name"])

func _on_tab_changed(idx: int) -> void:
	_save_current()
	_load_enemy(idx)

# ──────────────────────────────────────────────
#  CARGA / GUARDADO
# ──────────────────────────────────────────────
func _load_enemy(idx: int) -> void:
	_current_enemy = idx
	var d = GameData.enemy_data[idx]
	_enemy_name_label.text = "Editando: %s" % d["name"]

	if d.has("grid_zones") and not d["grid_zones"].is_empty():
		_zones = []
		for z in d["grid_zones"]:
			_zones.append({
				"name":  z["name"],
				"mult":  z["mult"],
				"color": Color(z["cr"], z["cg"], z["cb"], z["ca"]),
			})
	else:
		_zones = []
		for dz in DEFAULT_ZONES:
			_zones.append({ "name": dz["name"], "mult": dz["mult"], "color": dz["color"] })

	_cells = []
	if d.has("grid_cells") and d["grid_cells"].size() == GRID_COLS * GRID_ROWS:
		for v in d["grid_cells"]:
			_cells.append(int(v))
	else:
		for i in GRID_COLS * GRID_ROWS:
			_cells.append(-1)

	_selected_zone = 0

	var sprite_path = d.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var tex = load(sprite_path)
		if tex is Texture2D:
			_sprite_rect.texture = tex
		else:
			_sprite_rect.texture = null
	else:
		_sprite_rect.texture = null

	_refresh_grid_visual()
	_refresh_zone_list()

func _save_current() -> void:
	var d = GameData.enemy_data[_current_enemy]
	var zones_out = []
	for z in _zones:
		var c = z["color"]
		zones_out.append({
			"name": z["name"], "mult": z["mult"],
			"cr": c.r, "cg": c.g, "cb": c.b, "ca": c.a,
		})
	d["grid_zones"] = zones_out
	d["grid_cells"] = _cells.duplicate()

# ──────────────────────────────────────────────
#  ZONAS
# ──────────────────────────────────────────────
func _reset_all() -> void:
	_zones = []
	for dz in DEFAULT_ZONES:
		_zones.append({ "name": dz["name"], "mult": dz["mult"], "color": dz["color"] })
	_cells = []
	for i in GRID_COLS * GRID_ROWS:
		_cells.append(-1)
	_selected_zone = 0
	_refresh_grid_visual()
	_refresh_zone_list()
	_save_current()

func _add_zone() -> void:
	var idx = _zones.size()
	_zones.append({
		"name":  "Zona %d" % (idx + 1),
		"mult":  1.0,
		"color": ZONE_COLORS_AVAILABLE[idx % ZONE_COLORS_AVAILABLE.size()],
	})
	_selected_zone = idx
	_refresh_zone_list()

func _remove_zone(idx: int) -> void:
	for i in _cells.size():
		if _cells[i] == idx:
			_cells[i] = -1
		elif _cells[i] > idx:
			_cells[i] -= 1
	_zones.remove_at(idx)
	_selected_zone = clamp(_selected_zone, 0, max(0, _zones.size() - 1))
	_refresh_grid_visual()
	_refresh_zone_list()
	_save_current()

# ──────────────────────────────────────────────
#  PANEL LATERAL
# ──────────────────────────────────────────────
func _refresh_zone_list() -> void:
	if _zone_list == null:
		return
	for child in _zone_list.get_children():
		_zone_list.remove_child(child)
		child.free()

	for i in _zones.size():
		var z = _zones[i]
		var panel = PanelContainer.new()
		var vbox = VBoxContainer.new()
		panel.add_child(vbox)

		var row = HBoxContainer.new()
		var swatch = ColorRect.new()
		swatch.color = z["color"]
		swatch.custom_minimum_size = Vector2(20, 20)
		row.add_child(swatch)

		var name_edit = LineEdit.new()
		name_edit.text = z["name"]
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var zi = i
		name_edit.text_changed.connect(func(t): _zones[zi]["name"] = t; _save_current())
		row.add_child(name_edit)

		var btn_sel = Button.new()
		btn_sel.text = "Activa" if i == _selected_zone else "Usar"
		btn_sel.disabled = (i == _selected_zone)
		btn_sel.pressed.connect(func():
			_selected_zone = zi
			call_deferred("_refresh_zone_list")
		)
		row.add_child(btn_sel)

		var btn_del = Button.new()
		btn_del.text = "X"
		btn_del.custom_minimum_size.x = 26
		btn_del.pressed.connect(func(): call_deferred("_remove_zone", zi))
		row.add_child(btn_del)
		vbox.add_child(row)

		var mult_row = HBoxContainer.new()
		var mult_lbl = Label.new()
		mult_lbl.text = "Mult x"
		mult_row.add_child(mult_lbl)
		var mult_spin = SpinBox.new()
		mult_spin.min_value = 0.0
		mult_spin.max_value = 10.0
		mult_spin.step = 0.1
		mult_spin.value = z["mult"]
		mult_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mult_spin.value_changed.connect(func(v): _zones[zi]["mult"] = v; _save_current())
		mult_row.add_child(mult_spin)
		vbox.add_child(mult_row)

		var count = 0
		for v in _cells:
			if v == zi:
				count += 1
		var count_lbl = Label.new()
		count_lbl.text = "Celdas: %d / %d" % [count, GRID_COLS * GRID_ROWS]
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(count_lbl)

		_zone_list.add_child(panel)

# ──────────────────────────────────────────────
#  Lookup para QTE
# ──────────────────────────────────────────────
static func get_zone_at(point: Vector2, enemy_data: Dictionary) -> Dictionary:
	if not enemy_data.has("grid_cells") or not enemy_data.has("grid_zones"):
		return { "name": "Torso", "mult": 1.0 }
	var cells = enemy_data["grid_cells"]
	var zones = enemy_data["grid_zones"]
	var col = int(point.x * GRID_COLS)
	var row = int(point.y * GRID_ROWS)
	col = clamp(col, 0, GRID_COLS - 1)
	row = clamp(row, 0, GRID_ROWS - 1)
	var idx = row * GRID_COLS + col
	if idx < 0 or idx >= cells.size():
		return { "name": "Torso", "mult": 1.0 }
	var zone_idx = int(cells[idx])
	if zone_idx < 0 or zone_idx >= zones.size():
		return { "name": "Sin zona", "mult": 0.0 }
	var z = zones[zone_idx]
	return { "name": z["name"], "mult": z["mult"] }
