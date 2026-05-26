# hitboxEditor.gd
# Editor de zonas de daño con grilla.
# process_mode: Always
extends Control

signal close_requested

# ──────────────────────────────────────────────
#  Constantes
# ──────────────────────────────────────────────
const GRID_COLS = 10
const GRID_ROWS = 15
const SPRITE_DISPLAY_SIZE = Vector2(300.0, 450.0)

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
#  Exports (Vincular desde el Inspector)
# ──────────────────────────────────────────────
@export var enemy_tabs: TabBar
@export var btn_add_zone: Button
@export var btn_reset: Button
@export var btn_close: Button
@export var zone_list: VBoxContainer
@export var enemy_name_label: Label
@export var sprite_rect: TextureRect
@export var grid_container: GridContainer

# ──────────────────────────────────────────────
#  Estado
# ──────────────────────────────────────────────
var _current_enemy = 0
var _zones = []
var _selected_zone = 0
var _cells = []
var _cell_buttons = []

# ──────────────────────────────────────────────
#  READY
# ──────────────────────────────────────────────
func _ready() -> void:
	# Conexión de señales de los nodos del editor
	btn_close.pressed.connect(func(): emit_signal("close_requested"))
	btn_reset.pressed.connect(_reset_all)
	btn_add_zone.pressed.connect(_add_zone)
	enemy_tabs.tab_changed.connect(_on_tab_changed)
	if grid_container:
		grid_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_build_grid()
	hide()

func refresh() -> void:
	_build_enemy_tabs()
	if GameData.enemy_data.size() > 0:
		_load_enemy(0)

# ──────────────────────────────────────────────
#  GRILLA (Esto sí se genera por código porque depende de Constantes)
# ──────────────────────────────────────────────
func _build_grid() -> void:
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.free()
	_cell_buttons.clear()

	var cell_w = SPRITE_DISPLAY_SIZE.x / GRID_COLS
	var cell_h = SPRITE_DISPLAY_SIZE.y / GRID_ROWS

	for r in GRID_ROWS:
		for c in GRID_COLS:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(cell_w, cell_h)
			# Para que el botón llene la celda del GridContainer:
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			btn.flat = false
			btn.focus_mode = Control.FOCUS_NONE
			
			var idx = r * GRID_COLS + c
			btn.gui_input.connect(_on_cell_input.bind(idx))
			grid_container.add_child(btn)
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
	while enemy_tabs.tab_count > 0:
		enemy_tabs.remove_tab(0)
	for d in GameData.enemy_data:
		enemy_tabs.add_tab(d["name"])

func _on_tab_changed(idx: int) -> void:
	_save_current()
	_load_enemy(idx)

# ──────────────────────────────────────────────
#  CARGA / GUARDADO
# ──────────────────────────────────────────────
func _build_default_cells() -> Array:
	var cells = []
	for r in GRID_ROWS:
		for c in GRID_COLS:
			var zone_idx = -1
			if r <= 1:
				zone_idx = 0  # Cabeza
			elif r <= 7:
				zone_idx = 1  # Torso
			else:
				zone_idx = 2  # Piernas
			cells.append(zone_idx)
	return cells

func _load_enemy(idx: int) -> void:
	_current_enemy = idx
	var d = GameData.enemy_data[idx]
	enemy_name_label.text = "Editando: %s" % d["name"]

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
		_cells = _build_default_cells()
		_save_current()

	_selected_zone = 0

	var sprite_path = d.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var tex = load(sprite_path)
		if tex is Texture2D:
			sprite_rect.texture = tex
		else:
			sprite_rect.texture = null
	else:
		sprite_rect.texture = null

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
	GameData.save_enemy_zones()

# ──────────────────────────────────────────────
#  ZONAS
# ──────────────────────────────────────────────
func _reset_all() -> void:
	_zones = []
	for dz in DEFAULT_ZONES:
		_zones.append({ "name": dz["name"], "mult": dz["mult"], "color": dz["color"] })
	_cells = _build_default_cells()
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
#  PANEL LATERAL (Generación dinámica de items)
# ──────────────────────────────────────────────
func _refresh_zone_list() -> void:
	if zone_list == null:
		return
	for child in zone_list.get_children():
		zone_list.remove_child(child)
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
		# SOLUCIÓN: bind congela el valor de 'i'
		name_edit.text_changed.connect(_on_zone_name_changed.bind(i))
		row.add_child(name_edit)

		var btn_sel = Button.new()
		btn_sel.text = "Activa" if i == _selected_zone else "Usar"
		btn_sel.disabled = (i == _selected_zone)
		# SOLUCIÓN: bind congela el valor de 'i'
		btn_sel.pressed.connect(_on_zone_selected.bind(i))
		row.add_child(btn_sel)

		var btn_del = Button.new()
		btn_del.text = "X"
		btn_del.custom_minimum_size.x = 26
		# SOLUCIÓN: bind congela el valor de 'i'
		btn_del.pressed.connect(_on_zone_deleted.bind(i))
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
		# SOLUCIÓN: bind congela el valor de 'i'
		mult_spin.value_changed.connect(_on_zone_mult_changed.bind(i))
		mult_row.add_child(mult_spin)
		vbox.add_child(mult_row)

		var count = 0
		for v in _cells:
			if v == i:
				count += 1
		var count_lbl = Label.new()
		count_lbl.text = "Celdas: %d / %d" % [count, GRID_COLS * GRID_ROWS]
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(count_lbl)

		zone_list.add_child(panel)

# ──────────────────────────────────────────────
#  HELPERS PARA SEÑALES (Evitan el bug de lambdas en loops)
# ──────────────────────────────────────────────
func _on_zone_name_changed(text: String, idx: int) -> void:
	_zones[idx]["name"] = text
	_save_current()

func _on_zone_selected(idx: int) -> void:
	_selected_zone = idx
	_refresh_zone_list()

func _on_zone_deleted(idx: int) -> void:
	_remove_zone(idx)

func _on_zone_mult_changed(val: float, idx: int) -> void:
	_zones[idx]["mult"] = val
	_save_current()

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
