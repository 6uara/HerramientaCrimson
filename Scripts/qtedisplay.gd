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
			if _debug_overlay:
				_debug_overlay.queue_redraw()
			print("[QTEDisplay] Debug mode: ", _debug_mode)

var _debug_overlay: Control = null

func _ready() -> void:
	# Anchors se configuran desde el Inspector de la escena, no por código

	# Crear overlay encima del sprite para dibujar las zonas debug
	_debug_overlay = Control.new()
	_debug_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_overlay.size = get_viewport_rect().size
	add_child(_debug_overlay)
	move_child(_debug_overlay, 0)  # Detrás de todo
	_debug_overlay.draw.connect(_on_debug_overlay_draw)

	# Asegurar que el botón de confirmar quede al frente
	if confirm_button:
		move_child(confirm_button, get_child_count() - 1)
	# Mantener overlay del tamaño del viewport
	get_viewport().size_changed.connect(func():
		_debug_overlay.size = get_viewport_rect().size
		_debug_overlay.queue_redraw()
	)

	qte_controller.axis_changed.connect(_on_axis_changed)
	qte_controller.qte_completed.connect(_on_qte_completed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	hide()

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
	_elipse.setup(
		player.elipse_h, player.elipse_k,
		player.elipse_r, player.elipse_a, player.elipse_b
	)

	show()
	queue_redraw()
	if _debug_overlay:
		_debug_overlay.queue_redraw()
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
	qte_controller.register_input()

func _on_qte_completed(point: Vector2) -> void:
	_phase = "done"
	_line_h = point.x
	_line_v = point.y

	# Primer disparo — punto del QTE
	var first = _resolve_shot(point, _player)
	_resolved.append(first)

	# Configurar la elipse con los stats del jugador.
	# k = centro Y de la elipse, lo seteamos al Y del primer disparo
	_elipse.h = 0.0
	_elipse.k = point.y
	_elipse.r = _player.elipse_r
	_elipse.a = _player.elipse_a
	_elipse.b = _player.elipse_b

	# Disparos siguientes — cada uno usa el anterior como anchor en X (encadenado)
	var previous_point = point
	for i in range(1, _shots_pending):
		var ep: Vector2 = _elipse.next_point_from(previous_point)
		ep = ep.clamp(Vector2.ZERO, Vector2.ONE)
		_resolved.append(_resolve_shot(ep, _player))
		previous_point = ep

	queue_redraw()

	await get_tree().create_timer(1.4).timeout
	hide()
	emit_signal("attack_resolved", _resolved)

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

	var chance: float = clampf(
		player.get("hit_chance_base") - player.get("hit_chance_penalty") * player.get("bullets_spent_total"),
		0.0, 1.0
	)
	var hit_chance = randf() <= chance
	# El disparo solo cuenta si está dentro de la silueta Y pasa el roll de chance
	var hit = inside_silhouette and hit_chance
	var damage = _bullet_damage * mult if hit else 0.0

	return {
		"point":           point,
		"zone":            zone,
		"hit":             hit,
		"chance":          chance,
		"inside_silhouette": inside_silhouette,
		"damage":          damage,
		"mult":            mult,
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

	# El debug se dibuja en _debug_overlay (encima del sprite)

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
			else "FALLO (%.0f%%)" % (shot["chance"] * 100)
		draw_string(font, Vector2(px + 8, py + 4), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

	# Chance actual en la esquina
	if _player and _phase != "done":
		var chance_now = clampf(
			_player.hit_chance_base - _player.hit_chance_penalty * _player.bullets_spent_total,
			0.0, 1.0
		)
		draw_string(font, Vector2(s.position.x, s.position.y + s.size.y + 20),
			"Chance de impacto: %.0f%%" % (chance_now * 100),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW)


# ──────────────────────────────────────────────
#  Debug mode: dibujar grilla de zonas
# ──────────────────────────────────────────────
func _on_debug_overlay_draw() -> void:
	print("[overlay draw] debug=", _debug_mode, " enemy_data tiene grid_cells=", _current_enemy_data.has("grid_cells"))
	if not _debug_mode:
		return
	# Asegurar que el overlay tenga tamaño correcto antes de dibujar
	if _debug_overlay.size.x < 1:
		_debug_overlay.size = get_viewport_rect().size
	var enemy_data: Dictionary = _current_enemy_data
	if not enemy_data.has("grid_cells") or not enemy_data.has("grid_zones"):
		return
	var cells = enemy_data["grid_cells"]
	var zones = enemy_data["grid_zones"]
	if cells.is_empty() or zones.is_empty():
		return

	# Forzar recálculo del rect del sprite usando la posición real del TextureRect
	var s: Rect2
	if sprite_panel and sprite_panel.is_inside_tree() and _debug_overlay.is_inside_tree() and sprite_panel.size.x > 1:
		s = Rect2(sprite_panel.global_position - _debug_overlay.global_position, sprite_panel.size)
	elif sprite_node and sprite_node.is_inside_tree() and _debug_overlay.is_inside_tree() and sprite_node.size.x > 1:
		s = Rect2(sprite_node.global_position - _debug_overlay.global_position, sprite_node.size)
	else:
		s = _sprite_rect
	if s.size.x < 1 or s.size.y < 1:
		return  # rect aún no calculado

	var cols = 10
	var rows = 15
	var cell_w = s.size.x / cols
	var cell_h = s.size.y / rows

	# Dibujar TODAS las celdas (vacías incluidas) con borde para ver la grilla completa
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
				# Fill opaco-fuerte para ver bien la zona
				var fill_col = Color(z["cr"], z["cg"], z["cb"], 0.75)
				_debug_overlay.draw_rect(cell_rect, fill_col)
				# Borde blanco grueso
				_debug_overlay.draw_rect(cell_rect, Color.WHITE, false, 1.5)
			else:
				# Celda vacía: solo borde gris claro para ver la grilla
				_debug_overlay.draw_rect(cell_rect, Color(1, 1, 1, 0.25), false, 1.0)

	print("[overlay draw] dibujando ", cells.size(), " celdas, ", zones.size(), " zonas, sprite_rect=", s)
	# Etiquetas de zona — escribir el nombre en la primera celda asignada a cada zona
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
		_debug_overlay.draw_string(font, label_pos,
			"%s x%.1f" % [z["name"], z["mult"]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

	# Indicador de debug mode
	_debug_overlay.draw_string(font, Vector2(s.position.x, s.position.y - 10),
		"DEBUG MODE - F1 para ocultar",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.8, 0.2))
