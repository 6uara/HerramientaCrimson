# QTEDisplay.gd
# Control que dibuja el QTE sobre el sprite del enemigo.
# Adjuntarlo a un Control de pantalla completa (CanvasLayer recomendado).
# process_mode: Always
extends Control

const HitboxEditorScript = preload("res://Scripts/hitboxEditor.gd")

# ──────────────────────────────────────────────
#  Señales
# ──────────────────────────────────────────────
signal attack_resolved(shots: Array)  # [{point, damage, zone, hit}]

# ──────────────────────────────────────────────
#  Exports — asignar en Inspector
# ──────────────────────────────────────────────
@export var qte_controller: Node  # Asignar nodo con QTEController.gd
@export var confirm_button: Button
@export var sprite_panel: Control      # Panel que contiene el sprite (define posición/tamaño)
@export var sprite_node: TextureRect   # TextureRect con el sprite del enemigo (hijo del sprite_panel)

# ──────────────────────────────────────────────
#  Placeholder — se usa si no hay sprite real cargado
# ──────────────────────────────────────────────
const PLACEHOLDER_COLOR := Color(0.35, 0.35, 0.45)

# ──────────────────────────────────────────────
#  Zonas de daño (porcentajes verticales, iguales para todos)
# ──────────────────────────────────────────────
const ZONE_HEAD_END   := 0.20   # 0–20% = cabeza
const ZONE_TORSO_END  := 0.60   # 20–60% = torso
								 # 60–100% = piernas

const ZONE_MULTIPLIERS := {
	"Cabeza":  2.0,
	"Torso":   1.0,
	"Piernas": 0.6,
}

const COLOR_HEAD_TINT   := Color(1.0, 0.3, 0.3, 0.25)
const COLOR_TORSO_TINT  := Color(0.3, 0.6, 1.0, 0.25)
const COLOR_LEGS_TINT   := Color(0.3, 1.0, 0.4, 0.25)
const COLOR_LINE_V      := Color(1.0, 0.9, 0.2, 0.9)
const COLOR_LINE_H      := Color(0.2, 0.95, 1.0, 0.9)
const COLOR_HIT         := Color(1.0, 0.4, 0.1)
const COLOR_MISS        := Color(0.55, 0.55, 0.55)
const COLOR_BG          := Color(0.05, 0.05, 0.08, 0.92)
const SPRITE_DISPLAY_SIZE := Vector2(200.0, 350.0)
# ──────────────────────────────────────────────
#  Estado interno
# ──────────────────────────────────────────────
var _sprite_rect: Rect2          
var _line_v: float = 0.0         
var _line_h: float = 0.0
var _phase: String = "idle"      

var _shots_pending: int   = 0
var _bullet_damage: float = 0.0
var _player: Object = null
var _elipse: Object = null
var _resolved: Array = []        # shots ya calculados
var _shot_calc_data: Array = []  # datos verbose de cada disparo (u, v, q, w, rx, ry, n, m, h, k, r, a, b, point)
var _current_enemy_data: Dictionary = {}  # datos del enemigo objetivo actual
var _debug_mode: bool = false  # F1 toggle para ver zonas

# ──────────────────────────────────────────────
#  READY
# ──────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_debug_mode = not _debug_mode
			queue_redraw()
			if debug_overlay:
				debug_overlay.queue_redraw()
			print("[QTEDisplay] Debug mode: ", _debug_mode)

var debug_overlay: Control = null

func _ready() -> void:
	# Anchors se configuran desde el Inspector de la escena, no por código

	# Crear overlay para dibujar zonas debug.
	# Lo agregamos como hijo del sprite_panel (si existe) para que no tape el botón
	# Confirm ni la UI. Si no hay sprite_panel asignado, fallback al QTEDisplay.
	debug_overlay = Control.new()
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if sprite_panel:
		sprite_panel.add_child(debug_overlay)
	else:
		add_child(debug_overlay)
		move_child(debug_overlay, 0)
	debug_overlay.draw.connect(_on_debug_overlay_draw)

	# Asegurar que el botón de confirmar quede al frente.
	# Solo si es hijo directo del QTEDisplay (puede estar dentro de un Container).
	if confirm_button and confirm_button.get_parent() == self:
		move_child(confirm_button, get_child_count() - 1)

	qte_controller.axis_changed.connect(_on_axis_changed)
	qte_controller.qte_completed.connect(_on_qte_completed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.mouse_entered.connect(func(): print("[QTE] HOVER en confirm_button"))
	hide()

	# Diagnóstico de mouse_filter
	print("\n[QTE DIAG] confirm_button stack (de Confirm hasta el root):")
	var node = confirm_button
	while node:
		var info = "  " + str(node.name) + " (" + node.get_class() + ")"
		if node is Control:
			info += " filter=" + str(node.mouse_filter) + "(" + _filter_name(node.mouse_filter) + ")"
			info += " visible=" + str(node.visible)
			info += " disabled=" + str(node.disabled if "disabled" in node else "n/a")
		print(info)
		node = node.get_parent()

func _filter_name(f: int) -> String:
	match f:
		0: return "STOP"
		1: return "PASS"
		2: return "IGNORE"
	return "?"

# ──────────────────────────────────────────────
#  API pública
# ──────────────────────────────────────────────

# sprite_texture: la textura del enemigo actual (puede ser null → usa placeholder)
func _init_elipse() -> void:
	if _elipse == null:
		_elipse = load("res://Scripts/elipse_calculator.gd").new()

func set_enemy(enemy_data: Dictionary) -> void:
	_current_enemy_data = enemy_data

func start_qte(player: Object, bullets: int, sprite_texture: Texture2D = null) -> void:
	_player         = player
	_shots_pending  = bullets
	_bullet_damage  = player.damage
	_resolved.clear()
	_shot_calc_data.clear()
	_phase = "vertical"
	_line_v = 0.0
	_line_h = 1.0 if player.left_handed else 0.0

	# Cargar sprite o placeholder
	if sprite_texture != null:
		sprite_node.texture = sprite_texture
	else:
		sprite_node.texture = null   # _draw() dibuja el placeholder

	# Calcular rect del sprite centrado
	_update_sprite_rect()

	# Configurar elipse
	_init_elipse()
	# La elipse se configura por disparo en _on_qte_completed
	_elipse.setup(0.0, 0.0, 1.0, 1.0, 1.0)

	show()
	queue_redraw()
	if debug_overlay:
		debug_overlay.queue_redraw()
	# Resetear el botón Confirm para esta ronda
	if confirm_button:
		confirm_button.text = "Confirmar"
		confirm_button.disabled = false
		confirm_button.show()

	# Diag: estado del confirm_button cuando arranca QTE
	await get_tree().process_frame
	print("\n[QTE start_qte] confirm_button state:")
	print("  visible=", confirm_button.visible, " disabled=", confirm_button.disabled)
	print("  global_position=", confirm_button.global_position, " size=", confirm_button.size)
	print("  mouse_filter=", confirm_button.mouse_filter)
	print("  process_mode=", confirm_button.process_mode)
	print("  paused=", get_tree().paused)

	qte_controller.start(player)

func _update_sprite_rect() -> void:
	# Usar el sprite_panel como referencia de área del sprite — vos lo posicionás con anchors
	if sprite_panel and sprite_panel.is_inside_tree() and sprite_panel.size.x > 1:
		var local_pos = sprite_panel.global_position - global_position if is_inside_tree() else sprite_panel.position
		_sprite_rect = Rect2(local_pos, sprite_panel.size)
	elif sprite_node and sprite_node.is_inside_tree() and sprite_node.size.x > 1:
		var local_pos = sprite_node.global_position - global_position if is_inside_tree() else sprite_node.position
		_sprite_rect = Rect2(local_pos, sprite_node.size)
	else:
		var fallback = Vector2(200, 350)
		var vp = get_viewport_rect().size
		_sprite_rect = Rect2(vp / 2 - fallback / 2, fallback)

# ──────────────────────────────────────────────
#  PROCESO
# ──────────────────────────────────────────────
func _process(delta: float) -> void:
	if not visible or not qte_controller.is_active():
		return
	qte_controller.tick(delta)
	queue_redraw()

# ──────────────────────────────────────────────
#  SEÑALES DEL CONTROLLER
# ──────────────────────────────────────────────
func _on_axis_changed(axis: String, value: float) -> void:
	if axis == "vertical":
		_line_v = value
		_phase  = "vertical"
	else:
		_line_h = value
		_phase  = "horizontal"
	queue_redraw()

func _on_confirm_pressed() -> void:
	print("[QTE] _on_confirm_pressed disparado! phase=", _phase)
	# Si el QTE ya está resuelto, este botón funciona como "Continuar"
	if _phase == "done":
		hide()
		emit_signal("attack_resolved", _resolved)
		return
	# Si aún está en fase activa (vertical/horizontal), confirma el input del QTE
	qte_controller.register_input()

func _on_qte_completed(point: Vector2) -> void:
	_phase = "done"
	_line_h = point.x
	_line_v = point.y

	# Primer disparo — punto del QTE (manual, sin elipse)
	var first = _resolve_shot(point, _player)
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
	print("\n[Elipse Calc] === DISPARO #1 (manual, sin elipse) ===")
	print("  punto final: (n=%.4f, m=%.4f)" % [point.x, point.y])

	# Disparos siguientes — cada uno usa el set de elipse correspondiente a su índice
	var previous_point = point
	for i in range(1, _shots_pending):
		var shot_set: Dictionary = _player.call("get_elipse_set", i)

		# --- CORRECCIÓN MATEMÁTICA ---
		# Extraemos el offset relativo porque desmos_to_game convierte 0 en 0.5 absoluto.
		var offset_x = float(shot_set.get("h", 0.5)) - 0.5
		var offset_y = float(shot_set.get("k", 0.5)) - 0.5

		# La X se encadena al impacto previo sumando el offset.
		_elipse.h = previous_point.x + offset_x

		# Según la lógica del GDD para este retroceso, la Y mantiene como base el tiro inicial.
		_elipse.k = point.y + offset_y
		# -----------------------------

		_elipse.r = float(shot_set.get("r", 0.05))
		_elipse.a = float(shot_set.get("a", 1.0))
		_elipse.b = float(shot_set.get("b", 1.0))

		# Versión verbose: obtiene TODAS las variables intermedias del cálculo
		var calc: Dictionary = _elipse.next_point_from_verbose(previous_point)
		var ep: Vector2 = (calc["point"] as Vector2).clamp(Vector2.ZERO, Vector2.ONE)

		# Print detallado de las variables
		print("\n[Elipse Calc] === DISPARO #%d ===" % (i + 1))
		print("  Parametros de elipse: h=%.4f, k=%.4f, r=%.4f, a=%.4f, b=%.4f" % [
			calc["h"], calc["k"], calc["r"], calc["a"], calc["b"]
		])
		print("  Variables aleatorias: u=%.4f, v=%.4f" % [calc["u"], calc["v"]])
		print("  Variables de calculo: q=%.4f rad (%.2f°), w=%.4f" % [
			calc["q"], rad_to_deg(calc["q"]), calc["w"]
		])
		print("  Radios efectivos: rx=%.4f, ry=%.4f" % [calc["rx"], calc["ry"]])
		print("  Punto base (previo): (%.4f, %.4f)" % [previous_point.x, previous_point.y])
		print("  Punto final: n=%.4f, m=%.4f" % [calc["n"], calc["m"]])
		print("  Punto clampeado: (%.4f, %.4f)" % [ep.x, ep.y])

		# Guardar datos del cálculo para el debug overlay
		calc["point"] = ep
		calc["previous_point"] = previous_point
		_shot_calc_data.append(calc)

		_resolved.append(_resolve_shot(ep, _player))
		previous_point = ep

	queue_redraw()
	if debug_overlay:
		debug_overlay.queue_redraw()  # redibujar el overlay con los datos reales del cálculo
	print("[QTE] shots resolved, esperando boton Continuar...")

	# El QTE ya no se cierra automáticamente — espera al botón "Continuar"
	if confirm_button:
		confirm_button.text = "Continuar"
		confirm_button.disabled = false
		confirm_button.show()

# ──────────────────────────────────────────────
#  RESOLUCIÓN: zona + chance de impacto
# ──────────────────────────────────────────────
func _resolve_shot(point: Vector2, player: Object) -> Dictionary:
	var zone: String = "Torso"
	var mult: float = 1.0
	var inside_silhouette: bool = true
	var enemy_data: Dictionary = _current_enemy_data

	if enemy_data.has("grid_cells") and enemy_data.has("grid_zones") \
			and not enemy_data["grid_cells"].is_empty() and not enemy_data["grid_zones"].is_empty():
		var zone_result: Dictionary = HitboxEditorScript.get_zone_at(point, enemy_data)
		zone = zone_result.get("name", "Sin zona")
		mult = float(zone_result.get("mult", 0.0))
		# Si el lookup devuelve mult 0 o nombre "Sin zona", el disparo cayó fuera de la silueta
		if zone == "Sin zona" or (mult == 0.0 and zone_result.get("name", "") == "Sin zona"):
			inside_silhouette = false
	else:
		# Fallback: porcentajes verticales (todo cuenta como dentro)
		if point.y <= 0.20:
			zone = "Cabeza"; mult = 2.0
		elif point.y <= 0.60:
			zone = "Torso";  mult = 1.0
		else:
			zone = "Piernas"; mult = 0.6

	# El disparo solo cuenta si está dentro de la silueta
	var hit = inside_silhouette
	var damage = _bullet_damage * mult if hit else 0.0

	return {
		"point":             point,
		"zone":              zone,
		"hit":               hit,
		"inside_silhouette": inside_silhouette,
		"damage":            damage,
		"mult":              mult,
	}

func _get_zone_mult(_zone_name: String, _hitboxes: Array) -> float:
	return 1.0

# ──────────────────────────────────────────────
#  DIBUJADO
# ──────────────────────────────────────────────
func _draw() -> void:
	_update_sprite_rect()
	var s = _sprite_rect
	var font = ThemeDB.fallback_font

	# Fondo oscuro pantalla completa
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)

	# Instrucción
	var instruction = ""
	match _phase:
		"vertical":   instruction = "↕  Presioná CONFIRMAR para fijar la mira vertical"
		"horizontal": instruction = "↔  Presioná CONFIRMAR para fijar la mira horizontal"
		"done":       instruction = "Impactos resueltos"
	draw_string(font, Vector2(s.position.x, s.position.y - 28),
		instruction, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# Placeholder si no hay textura (el TextureRect dibuja la textura real si la tiene)
	if sprite_node.texture == null:
		draw_rect(s, PLACEHOLDER_COLOR)
		draw_string(font, s.position + Vector2(8, 20),
			"[sprite enemigo]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.7))

	# El debug se dibuja en debug_overlay (encima del sprite)

	# Borde del sprite
	draw_rect(s, Color.WHITE, false, 1.5)

	# Línea vertical (siempre visible una vez arranca)
	if _phase != "idle":
		var ly = s.position.y + _line_v * s.size.y
		draw_line(Vector2(s.position.x, ly), Vector2(s.position.x + s.size.x, ly),
			COLOR_LINE_V, 2.0)

	# Línea horizontal (visible desde fase horizontal)
	if _phase in ["horizontal", "done"]:
		var lx = s.position.x + _line_h * s.size.x
		draw_line(Vector2(lx, s.position.y), Vector2(lx, s.position.y + s.size.y),
			COLOR_LINE_H, 2.0)

	# Puntos de impacto
	for i in _resolved.size():
		var shot: Dictionary = _resolved[i]
		var pt: Vector2 = shot["point"]
		var px = s.position.x + pt.x * s.size.x
		var py = s.position.y + pt.y * s.size.y
		var col = COLOR_HIT if shot["hit"] else COLOR_MISS

		draw_circle(Vector2(px, py), 5.0, col)
		draw_circle(Vector2(px, py), 5.0, Color.WHITE, false, 1.5)

		var label = "%s  %.0f dmg" % [shot["zone"], shot["damage"]] if shot["hit"] \
			else "FALLO"
		draw_string(font, Vector2(px + 8, py + 4), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


# ──────────────────────────────────────────────
#  Debug mode: dibujar grilla de zonas
# ──────────────────────────────────────────────
func _on_debug_overlay_draw() -> void:
	if not _debug_mode:
		return

	# El debug_overlay ahora es hijo del sprite_panel, así que su área local
	# (0,0)-size coincide exactamente con el área del sprite.
	var s = Rect2(Vector2.ZERO, debug_overlay.size)
	if s.size.x < 1 or s.size.y < 1:
		return

	# 1. Dibujar Grilla PRIMERO (al fondo, semi-transparente)
	var enemy_data: Dictionary = _current_enemy_data
	var has_grid = enemy_data.has("grid_cells") and enemy_data.has("grid_zones")
	if not has_grid:
		# Sin grilla, igual dibujar elipses encima del sprite
		if _player != null:
			_draw_elipses_debug(s)
		return
	var cells = enemy_data["grid_cells"]
	var zones = enemy_data["grid_zones"]
	if cells.is_empty() or zones.is_empty():
		return

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
				var fill_col = Color(z["cr"], z["cg"], z["cb"], 0.25)
				debug_overlay.draw_rect(cell_rect, fill_col)
				debug_overlay.draw_rect(cell_rect, Color(1, 1, 1, 0.4), false, 1.0)
			else:
				debug_overlay.draw_rect(cell_rect, Color(1, 1, 1, 0.1), false, 1.0)

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
			"%s x%.1f" % [z["name"], z["mult"]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

	debug_overlay.draw_string(font, Vector2(s.position.x, s.position.y - 10),
		"DEBUG MODE - F1 para ocultar",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.8, 0.2))

	# 2. Dibujar Elipses ENCIMA de la grilla (al frente)
	if _player != null:
		_draw_elipses_debug(s)


# Dibuja el borde de cada elipse de los sets del jugador, con color distinto por disparo
func _draw_elipses_debug(sprite_rect: Rect2) -> void:
	var colors = [
		Color(1.0, 0.2, 0.2, 0.9),   # rojo
		Color(0.2, 1.0, 0.2, 0.9),   # verde
		Color(0.2, 0.5, 1.0, 0.9),   # azul
		Color(1.0, 0.9, 0.2, 0.9),   # amarillo
		Color(1.0, 0.4, 1.0, 0.9),   # magenta
		Color(0.4, 1.0, 1.0, 0.9),   # cian
	]
	var font = ThemeDB.fallback_font

	# Si hay datos de cálculo (después de un QTE resuelto), usar esos.
	if _shot_calc_data.size() > 0:
		_draw_elipses_from_calc_data(sprite_rect, colors, font)
		return

	# Fallback: mostrar elipses teóricas del jugador (antes del QTE)
	var cad = int(_player.get("cadence"))
	if cad <= 0:
		return
	for i in cad:
		var set_game: Dictionary = _player.call("get_elipse_set", i)
		var col: Color = colors[i % colors.size()]
		var h = float(set_game.get("h", 0.5))
		var k = float(set_game.get("k", 0.5))
		var r = float(set_game.get("r", 0.05))
		var a = float(set_game.get("a", 1.0))
		var b = float(set_game.get("b", 1.0))
		var center_px = sprite_rect.position + Vector2(h * sprite_rect.size.x, k * sprite_rect.size.y)
		var rx_px = r * sqrt(a) * sprite_rect.size.x
		var ry_px = r * sqrt(b) * sprite_rect.size.y
		_draw_ellipse_outline(center_px, rx_px, ry_px, col)
		_draw_center_cross(center_px, col)
		debug_overlay.draw_string(font, center_px + Vector2(6, -6),
			"#%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


# Dibuja las elipses con los datos REALES del cálculo (después del QTE)
# Muestra contorno, centro, punto de impacto y línea desde el centro al punto
func _draw_elipses_from_calc_data(sprite_rect: Rect2, colors: Array, font) -> void:
	for i in _shot_calc_data.size():
		var calc: Dictionary = _shot_calc_data[i]
		var col: Color = colors[i % colors.size()]

		var point_px = sprite_rect.position + Vector2(
			calc["point"].x * sprite_rect.size.x,
			calc["point"].y * sprite_rect.size.y
		)

		# Primer disparo (manual, sin elipse) → solo el punto
		if calc.get("manual", false):
			debug_overlay.draw_circle(point_px, 5.0, col)
			debug_overlay.draw_string(font, point_px + Vector2(8, -8),
				"#1 (manual)",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
			continue

		# Centro de la elipse en coords del juego: (h, k) que ya tiene los offsets aplicados
		var center_norm = Vector2(calc["h"], calc["k"])
		var center_px = sprite_rect.position + Vector2(
			center_norm.x * sprite_rect.size.x,
			center_norm.y * sprite_rect.size.y
		)
		var rx_px = calc["rx"] * sprite_rect.size.x
		var ry_px = calc["ry"] * sprite_rect.size.y

		_draw_ellipse_outline(center_px, rx_px, ry_px, col)
		_draw_center_cross(center_px, col)
		debug_overlay.draw_line(center_px, point_px, col, 1.5)
		debug_overlay.draw_circle(point_px, 5.0, col)

		debug_overlay.draw_string(font, center_px + Vector2(6, -6),
			"#%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		debug_overlay.draw_string(font, point_px + Vector2(8, 4),
			"(%.2f, %.2f)" % [calc["point"].x, calc["point"].y],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


# Helpers de dibujo
func _draw_ellipse_outline(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts = PackedVector2Array()
	var segments = 48
	for seg in segments + 1:
		var angle = 2.0 * PI * float(seg) / float(segments)
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	debug_overlay.draw_polyline(pts, col, 2.0, true)


func _draw_center_cross(center: Vector2, col: Color) -> void:
	debug_overlay.draw_line(
		center + Vector2(-4, 0), center + Vector2(4, 0),
		col, 1.5)
	debug_overlay.draw_line(
		center + Vector2(0, -4), center + Vector2(0, 4),
		col, 1.5)
