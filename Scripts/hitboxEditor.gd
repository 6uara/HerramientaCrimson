# hitboxEditor.gd
# Editor de zonas de daño usando grilla de celdas seleccionables.
# process_mode: Always
extends Control

signal close_requested

# ──────────────────────────────────────────────
#  Exports
# ──────────────────────────────────────────────
@export var btn_close: Button
@export var btn_reset: Button
@export var btn_add_zone: Button
@export var enemy_tab_bar: TabBar
@export var zone_list_container: VBoxContainer
@export var sprite_display: TextureRect
var grid_container: GridContainer  # generado en _ready, no del Inspector

# ──────────────────────────────────────────────
#  Constantes
# ──────────────────────────────────────────────
const GRID_COLS = 10
const GRID_ROWS = 15
const SPRITE_DISPLAY_SIZE = Vector2(300.0, 450.0)

const DEFAULT_ZONES = [
	{ "name": "Cabeza",  "mult": 2.0, "color": Color(1.0, 0.25, 0.25, 0.65) },
	{ "name": "Torso",   "mult": 1.0, "color": Color(0.25, 0.55, 1.0, 0.65) },
	{ "name": "Piernas", "mult": 0.6, "color": Color(0.25, 0.9, 0.35, 0.65) },
]
const ZONE_COLORS_AVAILABLE = [
	Color(1.0, 0.25, 0.25, 0.65),
	Color(0.25, 0.55, 1.0, 0.65),
	Color(0.25, 0.9, 0.35, 0.65),
	Color(1.0, 0.8, 0.1, 0.65),
	Color(0.8, 0.25, 1.0, 0.65),
	Color(1.0, 0.5, 0.1, 0.65),
]

# ──────────────────────────────────────────────
#  Estado
# ──────────────────────────────────────────────
var _current_enemy = 0
var _zones = []  # [{ name, mult, color }]
var _selected_zone = 0

# Asignación celda → índice de zona (-1 = vacío)
# cells[row * GRID_COLS + col]
var _cells = []

# Botones de la grilla
var _cell_buttons = []

# ──────────────────────────────────────────────
#  READY
# ──────────────────────────────────────────────
func _draw() -> void:
	# Fondo opaco que tapa el combate detrás
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.06, 0.06, 0.09, 1.0))

const PANEL_WIDTH = 280

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_close.pressed.connect(func(): emit_signal("close_requested"))
	btn_reset.pressed.connect(_reset_all)
	btn_add_zone.pressed.connect(_add_zone)
	enemy_tab_bar.tab_changed.connect(_on_tab_changed)

	# Forzar el panel lateral a la izquierda con ancho fijo
	var vp = get_viewport_rect().size
	var parent_panel = zone_list_container.get_parent()
	if parent_panel is Control:
		parent_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		parent_panel.position = Vector2.ZERO
		parent_panel.size = Vector2(PANEL_WIDTH, vp.y)
		# Si tiene un padre VBox, también limitarle el ancho
		var gp = parent_panel.get_parent()
		if gp is Control and gp != self:
			gp.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			gp.position = Vector2.ZERO
			gp.size = Vector2(PANEL_WIDTH, vp.y)

	# Posicionar el GridContainer a la derecha, lejos del panel
	var grid_x = PANEL_WIDTH + (vp.x - PANEL_WIDTH - SPRITE_DISPLAY_SIZE.x) / 2
	var pos = Vector2(grid_x, vp.y * 0.5 - SPRITE_DISPLAY_SIZE.y / 2)

	if sprite_display:
		sprite_display.position = pos
		sprite_display.size = SPRITE_DISPLAY_SIZE
		sprite_display.mouse_filter = Control.MOUSE_FILTER_IGNORE

	grid_container = GridContainer.new()
	grid_container.position = pos
	grid_container.size = SPRITE_DISPLAY_SIZE
	grid_container.add_theme_constant_override("h_separation", 1)
	grid_container.add_theme_constant_override("v_separation", 1)
	add_child(grid_container)

	# Configurar la grilla
	grid_container.columns = GRID_COLS
	grid_container.add_theme_constant_override("h_separation", 1)
	grid_container.add_theme_constant_override("v_separation", 1)
	_build_grid()

	hide()

func refresh() -> void:
	_build_enemy_tabs()
	_load_enemy(0)

# ──────────────────────────────────────────────
#  GRILLA
# ──────────────────────────────────────────────
func _build_grid() -> void:
	# Limpiar celdas previas
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
			btn.flat = true
			btn.focus_mode = Control.FOCUS_NONE
			# Capturar índice de la celda
			var idx = r * GRID_COLS + c
			btn.gui_input.connect(_on_cell_input.bind(idx))
			grid_container.add_child(btn)
			_cell_buttons.append(btn)

	# Inicializar celdas vacías si todavía no se cargaron (para que sean visibles)
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
			# Celdas vacías: fondo gris semi-transparente para que se VEAN
			sb.bg_color = Color(0.5, 0.5, 0.5, 0.25)
			sb.border_color = Color(1, 1, 1, 0.35)
			sb_hover.bg_color = Color(0.7, 0.7, 0.7, 0.4)
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
			# Asignar zona activa a esta celda
			if _selected_zone >= 0 and _selected_zone < _zones.size():
				_cells[cell_idx] = _selected_zone
				_refresh_grid_visual()
				_save_current()
				_refresh_zone_list()  # actualiza contadores
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Borrar celda
			_cells[cell_idx] = -1
			_refresh_grid_visual()
			_save_current()
			_refresh_zone_list()
	elif event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_LEFT:
		# Drag para pintar varias celdas seguidas
		if _selected_zone >= 0 and _selected_zone < _zones.size():
			_cells[cell_idx] = _selected_zone
			_refresh_grid_visual()

# ──────────────────────────────────────────────
#  TABS DE ENEMIGOS
# ──────────────────────────────────────────────
func _build_enemy_tabs() -> void:
	while enemy_tab_bar.tab_count > 0:
		enemy_tab_bar.remove_tab(0)
	for d in GameData.enemy_data:
		enemy_tab_bar.add_tab(d["name"])

func _on_tab_changed(idx: int) -> void:
	_save_current()
	_load_enemy(idx)

# ──────────────────────────────────────────────
#  CARGA / GUARDADO
# ──────────────────────────────────────────────
func _load_enemy(idx: int) -> void:
	_current_enemy = idx
	var d = GameData.enemy_data[idx]

	# Cargar zonas
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

	# Cargar celdas
	_cells = []
	if d.has("grid_cells") and d["grid_cells"].size() == GRID_COLS * GRID_ROWS:
		for v in d["grid_cells"]:
			_cells.append(int(v))
	else:
		for i in GRID_COLS * GRID_ROWS:
			_cells.append(-1)

	_selected_zone = 0

	# Cargar sprite
	var sprite_path = d.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var tex = load(sprite_path)
		if tex is Texture2D:
			sprite_display.texture = tex
	else:
		sprite_display.texture = null

	_refresh_grid_visual()
	_refresh_zone_list()

func _save_current() -> void:
	var d = GameData.enemy_data[_current_enemy]
	# Guardar zonas
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
#  GESTIÓN DE ZONAS
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
	# Limpiar celdas asignadas a esta zona
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
#  PANEL LATERAL — LISTA DE ZONAS
# ──────────────────────────────────────────────
func _refresh_zone_list() -> void:
	if zone_list_container == null:
		return
	for child in zone_list_container.get_children():
		zone_list_container.remove_child(child)
		child.free()

	for i in _zones.size():
		var z = _zones[i]
		var panel = PanelContainer.new()
		var vbox = VBoxContainer.new()
		panel.add_child(vbox)

		# Fila 1: swatch + nombre + botón seleccionar + botón eliminar
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

		# Fila 2: multiplicador
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

		# Fila 3: contador de celdas
		var count = 0
		for v in _cells:
			if v == zi:
				count += 1
		var count_lbl = Label.new()
		count_lbl.text = "Celdas: %d / %d" % [count, GRID_COLS * GRID_ROWS]
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(count_lbl)

		zone_list_container.add_child(panel)

# ──────────────────────────────────────────────
#  Lookup de zona para el QTE
# ──────────────────────────────────────────────
# point: Vector2 normalizado (0-1)
# enemy_data: dict con grid_cells y grid_zones
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
