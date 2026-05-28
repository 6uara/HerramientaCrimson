# QTEDisplay.gd
extends Control

const HitboxEditorScript = preload("res://Scripts/hitboxEditor.gd")

signal attack_resolved(shots: Array)

# Franja horizontal útil — debe coincidir con QTEController.QTE_X_MIN/MAX.
# Franja horizontal útil — se CALCULA automáticamente desde el tamaño real de
# la textura del enemigo. El espacio es cuadrado (lado = alto del sprite), y el
# ancho real de la textura suele ser menor, dejando margen a los lados.
# extra_x_margin agrega un margen adicional configurable como respaldo.
@export var extra_x_margin: float = 0.0  # margen extra (0..0.4) sumado a cada lado

var _qte_x_min: float = 0.0
var _qte_x_max: float = 1.0

# Calcula la franja útil en X según el aspect ratio de la textura.
# Si la textura es 100x175 en un cuadrado de 175x175, el ancho ocupa 100/175 = 0.57
# del cuadrado, centrado → franja de 0.21 a 0.79 (más el margen extra).
func _compute_x_band() -> void:
	var tex_w: float = 0.0
	var tex_h: float = 0.0
	# 1. Intentar leer del sprite_node si tiene textura
	if sprite_node and sprite_node.texture:
		var ts: Vector2 = sprite_node.texture.get_size()
		tex_w = ts.x
		tex_h = ts.y
	# 2. Si no, intentar cargar la textura desde el sprite_path del enemigo
	elif _current_enemy_data.has("sprite_path"):
		var path: String = _current_enemy_data["sprite_path"]
		if path != "" and ResourceLoader.exists(path):
			var tex = load(path)
			if tex and tex is Texture2D:
				var ts2: Vector2 = tex.get_size()
				tex_w = ts2.x
				tex_h = ts2.y
	if tex_w <= 0.0 or tex_h <= 0.0:
		# Sin textura válida → usar todo el ancho con un pequeño margen
		_qte_x_min = 0.05 + extra_x_margin
		_qte_x_max = 0.95 - extra_x_margin
		return
	# El cuadrado tiene lado = dimensión mayor de la textura
	var square_side: float = max(tex_w, tex_h)
	# Fracción del cuadrado que ocupa el ancho real de la textura
	var width_frac: float = tex_w / square_side
	# Centrar esa franja: margen a cada lado = (1 - width_frac) / 2
	var side_margin: float = (1.0 - width_frac) / 2.0
	_qte_x_min = side_margin + extra_x_margin
	_qte_x_max = 1.0 - side_margin - extra_x_margin
	# Sanity: no invertir
	if _qte_x_min >= _qte_x_max:
		_qte_x_min = 0.1
		_qte_x_max = 0.9

@export var qte_controller: Node
@export var confirm_button: Button
@export var sprite_panel: Control
@export var sprite_node: TextureRect

const PLACEHOLDER_COLOR := Color(0.35, 0.35, 0.45)
const COLOR_LINE_V := Color(1.0, 0.9, 0.2, 0.9)
const COLOR_LINE_H := Color(0.2, 0.95, 1.0, 0.9)
const COLOR_HIT := Color(1.0, 0.4, 0.1)
const COLOR_MISS := Color(0.55, 0.55, 0.55)

var _sprite_rect: Rect2          
var _line_v: float = 0.0         
var _line_h: float = 0.0
var _phase: String = "idle"      

var _shots_pending: int = 0
var _bullet_damage: float = 0.0
var _player: Object = null
var _elipse: Object = null
var _resolved: Array = []
var _shot_calc_data: Array = []
var _current_enemy_data: Dictionary = {}
var _debug_mode: bool = false

var debug_overlay: Control = null

func _ready() -> void:
	add_to_group("center_display")
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	debug_overlay = Control.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(debug_overlay)
	debug_overlay.draw.connect(_on_debug_overlay_draw)
	
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	
	if qte_controller:
		qte_controller.axis_changed.connect(_on_axis_changed)
		qte_controller.qte_completed.connect(_on_qte_completed)
	
	hide()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_debug_mode = not _debug_mode
			queue_redraw()
			if debug_overlay:
				debug_overlay.queue_redraw()

func _init_elipse() -> void:
	if _elipse == null:
		_elipse = load("res://Scripts/elipse_calculator.gd").new()

func set_enemy(enemy_data: Dictionary) -> void:
	_current_enemy_data = enemy_data

func start_qte(player: Object, bullets: int, _sprite_texture: Texture2D = null) -> void:
	print("[QTEDisplay] start_qte - player: ", player.character_name, " bullets: ", bullets)
	
	_player = player
	_shots_pending = bullets
	_bullet_damage = player.damage
	_resolved.clear()
	_shot_calc_data.clear()
	_phase = "vertical"
	_line_v = 0.5
	_line_h = 1.0 if player.left_handed else 0.0

	if sprite_node:
		sprite_node.texture = null

	_update_sprite_rect()
	_init_elipse()
	_elipse.setup(0.0, 0.0, 1.0, 1.0, 1.0)

	# Calcular la franja útil en X según el tamaño de la textura del enemigo
	_compute_x_band()

	show()
	queue_redraw()
	
	if confirm_button:
		confirm_button.text = "Confirmar"
		confirm_button.disabled = false
		confirm_button.show()
	
	if qte_controller:
		# Pasar los límites de X calculados al controller para que el input manual
		# rebote dentro de la franja útil
		if qte_controller.has_method("set_x_band"):
			qte_controller.set_x_band(_qte_x_min, _qte_x_max)
		qte_controller.start(player)

func _update_sprite_rect() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	if sprite_panel and sprite_panel.is_inside_tree() and sprite_panel.size.x > 1:
		var local_pos = sprite_panel.global_position - global_position if is_inside_tree() else sprite_panel.position
		_sprite_rect = Rect2(local_pos, sprite_panel.size)
	elif sprite_node and sprite_node.is_inside_tree() and sprite_node.size.x > 1:
		var local_pos = sprite_node.global_position - global_position if is_inside_tree() else sprite_node.position
		_sprite_rect = Rect2(local_pos, sprite_node.size)
	else:
		var desired_width = min(300.0, viewport_size.x * 0.35)
		var desired_height = desired_width * 1.75
		var fallback = Vector2(desired_width, desired_height)
		_sprite_rect = Rect2(viewport_size / 2 - fallback / 2, fallback)


# ──────────────────────────────────────────────
#  CONVERSIÓN ESPACIO NORMALIZADO ↔ PÍXELES
# ──────────────────────────────────────────────
# El espacio de juego es CUADRADO normalizado (0..1 en ambos ejes), igual que el
# Desmos del GD (-1..+1). Para que sea independiente del aspect ratio del sprite
# y de la resolución, usamos el LADO MAYOR del sprite como referencia única para
# ambos ejes. El cuadrado se centra en X y se alinea con la altura del sprite (Y).
#
# Esto garantiza:
#  - a=b siempre da círculo (en cálculo Y en dibujo)
#  - el punto de impacto siempre cae dentro de su elipse (misma escala)
#  - cambiar resolución/sprite no distorsiona la forma

# Devuelve la escala única (píxeles por unidad normalizada) y el origen del cuadrado
func _get_square_mapping(sprite_rect: Rect2) -> Dictionary:
	# Lado mayor como referencia (llena el eje largo, recorta el corto)
	var ref = max(sprite_rect.size.x, sprite_rect.size.y)
	# Centrar el cuadrado dentro del sprite_rect
	var offset_x = sprite_rect.position.x + (sprite_rect.size.x - ref) / 2.0
	var offset_y = sprite_rect.position.y + (sprite_rect.size.y - ref) / 2.0
	return { "scale": ref, "origin": Vector2(offset_x, offset_y) }

# Convierte un punto normalizado (0..1) a píxeles usando el mapeo cuadrado
func _norm_to_px(norm_pt: Vector2, sprite_rect: Rect2) -> Vector2:
	var m = _get_square_mapping(sprite_rect)
	return m["origin"] + norm_pt * m["scale"]

# Convierte un radio/escala normalizado a píxeles (escala única)
func _norm_len_to_px(norm_len: float, sprite_rect: Rect2) -> float:
	var m = _get_square_mapping(sprite_rect)
	return norm_len * m["scale"]

func _process(delta: float) -> void:
	if not visible:
		return
	
	if qte_controller and qte_controller.is_active():
		qte_controller.tick(delta)
		queue_redraw()

func _on_axis_changed(axis: String, value: float) -> void:
	if axis == "vertical":
		_line_v = value
		_phase = "vertical"
	else:
		_line_h = value
		_phase = "horizontal"
	queue_redraw()

func _on_confirm_pressed() -> void:
	if _phase == "done":
		hide()
		emit_signal("attack_resolved", _resolved)
		return
	
	if qte_controller:
		qte_controller.register_input()

func _on_qte_completed(point: Vector2) -> void:
	print("[QTEDisplay] qte_completed - point: ", point)
	_phase = "done"
	_line_h = point.x
	_line_v = point.y

	var first = _resolve_shot(point)
	_resolved.append(first)
	_shot_calc_data.append({
		"u": -1.0, "v": -1.0, "q": -1.0, "w": -1.0,
		"rx": 0.0, "ry": 0.0,
		"n": point.x, "m": point.y,
		"h": 0.0, "k": 0.0, "r": 0.0, "a": 0.0, "b": 0.0,
		"point": point,
		"previous_point": Vector2.ZERO,
		"manual": true,
	})

	var previous_point = point
	for i in range(1, _shots_pending):
		var shot_set: Dictionary = _player.call("get_elipse_set", i)
		var offset_x = float(shot_set.get("h", 0.5)) - 0.5
		var offset_y = float(shot_set.get("k", 0.5)) - 0.5
		_elipse.h = previous_point.x + offset_x
		_elipse.k = point.y + offset_y
		_elipse.r = float(shot_set.get("r", 0.05))
		_elipse.a = float(shot_set.get("a", 1.0))
		_elipse.b = float(shot_set.get("b", 1.0))
		var calc: Dictionary = _elipse.next_point_from_verbose(previous_point)
		var ep: Vector2 = (calc["point"] as Vector2)
		# Clampear: Y usa todo el alto (0..1), X se limita a la franja útil del sprite
		# para que ningún disparo caiga fuera del personaje a los lados.
		ep.x = clamp(ep.x, _qte_x_min, _qte_x_max)
		ep.y = clamp(ep.y, 0.0, 1.0)

		calc["point"] = ep
		calc["previous_point"] = previous_point
		_shot_calc_data.append(calc)

		_resolved.append(_resolve_shot(ep))
		previous_point = ep

	queue_redraw()
	if debug_overlay:
		debug_overlay.queue_redraw()
	
	if confirm_button:
		confirm_button.text = "Continuar"
		confirm_button.disabled = false
		confirm_button.show()

func _resolve_shot(point: Vector2, _player_unused = null) -> Dictionary:
	var zone: String = "Torso"
	var mult: float = 1.0
	var inside_silhouette: bool = true
	var enemy_data: Dictionary = _current_enemy_data

	if enemy_data.has("grid_cells") and enemy_data.has("grid_zones") \
			and not enemy_data["grid_cells"].is_empty() and not enemy_data["grid_zones"].is_empty():
		var zone_result: Dictionary = HitboxEditorScript.get_zone_at(point, enemy_data)
		zone = zone_result.get("name", "Sin zona")
		mult = float(zone_result.get("mult", 0.0))
		if zone == "Sin zona" or (mult == 0.0 and zone_result.get("name", "") == "Sin zona"):
			inside_silhouette = false
	else:
		if point.y <= 0.20:
			zone = "Cabeza"
			mult = 2.0
		elif point.y <= 0.60:
			zone = "Torso"
			mult = 1.0
		else:
			zone = "Piernas"
			mult = 0.6
	
	var hit = inside_silhouette
	var damage = _bullet_damage * mult if hit else 0.0

	return {
		"point": point,
		"zone": zone,
		"hit": hit,
		"inside_silhouette": inside_silhouette,
		"damage": damage,
		"mult": mult,
	}

func _draw() -> void:
	_update_sprite_rect()
	var s = _sprite_rect
	var font = ThemeDB.fallback_font

	var instruction = ""
	match _phase:
		"vertical":   instruction = "↕  Presioná CONFIRMAR para fijar la mira vertical"
		"horizontal": instruction = "↔  Presioná CONFIRMAR para fijar la mira horizontal"
		"done":       instruction = "Impactos resueltos"
	
	draw_string(font, Vector2(s.position.x, s.position.y - 28),
		instruction, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	
	if sprite_node and sprite_node.texture == null:
		draw_rect(s, PLACEHOLDER_COLOR)
		draw_string(font, s.position + Vector2(8, 20),
			"[sprite enemigo]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.7))
	
	draw_rect(s, Color.WHITE, false, 1.5)
	
	if _phase == "vertical" or _phase == "done":
		var ly = s.position.y + _line_v * s.size.y
		draw_line(Vector2(s.position.x, ly), Vector2(s.position.x + s.size.x, ly),
			COLOR_LINE_V, 2.0)
	
	if _phase == "horizontal" or _phase == "done":
		var lx = s.position.x + _line_h * s.size.x
		draw_line(Vector2(lx, s.position.y), Vector2(lx, s.position.y + s.size.y),
			COLOR_LINE_H, 2.0)
	
	for i in _resolved.size():
		var shot: Dictionary = _resolved[i]
		var pt: Vector2 = shot["point"]
		# Usar la misma conversión cuadrada que el overlay para que los puntos
		# coincidan exactamente con las elipses dibujadas
		var pos_px = _norm_to_px(pt, s)
		var col = COLOR_HIT if shot["hit"] else COLOR_MISS
		var radius = max(4.0, _norm_len_to_px(0.02, s))

		draw_circle(pos_px, radius, col)
		draw_circle(pos_px, radius, Color.WHITE, false, 1.5)

		var label = "%s  %.0f dmg" % [shot["zone"], shot["damage"]] if shot["hit"] else "FALLO"
		var font_size = max(10, int(s.size.x * 0.035))
		draw_string(font, pos_px + Vector2(8, 4), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _on_debug_overlay_draw() -> void:
	if not _debug_mode:
		return
	
	_update_sprite_rect()
	
	debug_overlay.draw_rect(Rect2(Vector2.ZERO, debug_overlay.size), Color(0.2, 0.1, 0.3, 0.3))
	
	var s = _sprite_rect
	if s.size.x <= 0 or s.size.y <= 0:
		return
	
	debug_overlay.draw_rect(s, Color(1.0, 0.5, 0.0, 0.5), false, 2.0)
	
	var enemy_data: Dictionary = _current_enemy_data
	var has_grid = enemy_data.has("grid_cells") and enemy_data.has("grid_zones")
	
	if has_grid:
		var cells = enemy_data["grid_cells"]
		var zones = enemy_data["grid_zones"]
		if not cells.is_empty() and not zones.is_empty():
			var cols = 10
			var rows = 15
			var cell_w = s.size.x / cols
			var cell_h = s.size.y / rows
			
			for r in rows:
				for c in cols:
					var i = r * cols + c
					var cell_rect = Rect2(
						s.position + Vector2(c * cell_w, r * cell_h),
						Vector2(cell_w, cell_h)
					)
					var zone_idx = int(cells[i]) if i < cells.size() else -1
					if zone_idx >= 0 and zone_idx < zones.size():
						var z = zones[zone_idx]
						var fill_col = Color(z.get("cr", 0.5), z.get("cg", 0.5), z.get("cb", 0.5), 0.35)
						debug_overlay.draw_rect(cell_rect, fill_col)
						debug_overlay.draw_rect(cell_rect, Color(1, 1, 1, 0.5), false, 1.0)
					else:
						debug_overlay.draw_rect(cell_rect, Color(1, 1, 1, 0.08), false, 0.5)
			
			var font = ThemeDB.fallback_font
			var zone_labeled = {}
			for i in cells.size():
				var zone_idx = int(cells[i])
				if zone_idx < 0 or zone_idx >= zones.size():
					continue
				if zone_labeled.has(zone_idx):
					continue
				zone_labeled[zone_idx] = true
				var r = i / cols
				var c = i % cols
				var z = zones[zone_idx]
				var label_pos = s.position + Vector2(c * cell_w + 2, r * cell_h + 12)
				debug_overlay.draw_string(font, label_pos,
					"%s x%.1f" % [z.get("name", "?"), z.get("mult", 1.0)],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	
	if _player != null and _shot_calc_data.size() > 0:
		_draw_elipses_debug(s)
	
	var font = ThemeDB.fallback_font
	debug_overlay.draw_string(font, Vector2(10, 20),
		"DEBUG MODE ACTIVADO - F1 para ocultar",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW)

func _draw_ellipse_outline(center: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	
	var pts = PackedVector2Array()
	var segments = 48
	
	for seg in segments + 1:
		var angle = 2.0 * PI * float(seg) / float(segments)
		var x = center.x + cos(angle) * rx
		var y = center.y + sin(angle) * ry
		pts.append(Vector2(x, y))
	
	debug_overlay.draw_polyline(pts, col, 2.0, true)

func _draw_center_cross(center: Vector2, col: Color) -> void:
	var cross_size = 6.0
	debug_overlay.draw_line(
		center + Vector2(-cross_size, 0), center + Vector2(cross_size, 0),
		col, 1.5)
	debug_overlay.draw_line(
		center + Vector2(0, -cross_size), center + Vector2(0, cross_size),
		col, 1.5)

func _draw_elipses_debug(sprite_rect: Rect2) -> void:
	var colors = [
		Color(1.0, 0.2, 0.2, 0.9),
		Color(0.2, 1.0, 0.2, 0.9),
		Color(0.2, 0.5, 1.0, 0.9),
		Color(1.0, 0.9, 0.2, 0.9),
		Color(1.0, 0.4, 1.0, 0.9),
		Color(0.4, 1.0, 1.0, 0.9),
	]
	var font = ThemeDB.fallback_font
	
	for i in _shot_calc_data.size():
		var calc: Dictionary = _shot_calc_data[i]
		var col: Color = colors[i % colors.size()]

		var point_px = _norm_to_px(calc["point"], sprite_rect)
		
		if calc.get("manual", false):
			debug_overlay.draw_circle(point_px, 5.0, col)
			debug_overlay.draw_string(font, point_px + Vector2(8, -8),
				"#1 (manual)",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
			continue
		
		var center_norm = Vector2(calc.get("h", 0.5), calc.get("k", 0.5))
		var center_px = _norm_to_px(center_norm, sprite_rect)
		# Misma escala única para rx y ry → consistente con el punto, e independiente
		# del aspect ratio. a=b siempre da círculo y el punto cae dentro.
		var rx_px = _norm_len_to_px(calc.get("rx", 0.05), sprite_rect)
		var ry_px = _norm_len_to_px(calc.get("ry", 0.05), sprite_rect)
		
		_draw_ellipse_outline(center_px, rx_px, ry_px, col)
		_draw_center_cross(center_px, col)
		
		debug_overlay.draw_line(center_px, point_px, col, 1.5)
		debug_overlay.draw_circle(point_px, 5.0, col)
		
		debug_overlay.draw_string(font, center_px + Vector2(6, -6),
			"#%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
