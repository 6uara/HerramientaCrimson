# CombatSetup.gd
# Nodo raíz de Combat.tscn — process_mode: Always
extends Node

var _paused = false

# Referencias — asignar desde el Inspector arrastrando los nodos
@export var combat_manager: Node
@export var combat_ui: Control
@export var pause_menu: Node
@export var stats_editor: Node
@export var hitbox_editor: Node
@export var combat_tracker: Node
@export var qte_display: Node
@export var center_display: Control  # contenedor de modales — se oculta cuando no hay ninguno abierto

func _ready() -> void:
	GameData.ensure_defaults()
	_validate_nodes()
	_connect_signals()
	pause_menu.hide()
	stats_editor.hide()
	_update_center_display_visibility()
	hitbox_editor.hide()
	_update_center_display_visibility()
	_start_combat()

# ──────────────────────────────────────────────
#  Resolución segura de nodos
# ──────────────────────────────────────────────
func _process(_delta: float) -> void:
	_update_center_display_visibility()


func _validate_nodes() -> void:
	# Verificar que todos los exports estén asignados desde el Inspector
	assert(combat_manager != null, "Falta asignar combat_manager en el Inspector")
	assert(combat_ui != null,      "Falta asignar combat_ui en el Inspector")
	assert(pause_menu != null,     "Falta asignar pause_menu en el Inspector")
	assert(stats_editor != null,   "Falta asignar stats_editor en el Inspector")
	assert(combat_tracker != null, "Falta asignar combat_tracker en el Inspector")
	assert(hitbox_editor != null,  "Falta asignar hitbox_editor en el Inspector")

	# Verificar que los scripts estén asignados correctamente
	assert(combat_manager.has_method("setup"),
		"CombatManager no tiene CombatManager.gd asignado")
	assert(pause_menu.has_signal("resume_requested"),
		"PauseMenu no tiene PauseMenu.gd asignado")
	assert(stats_editor.has_signal("apply_and_restart"),
		"StatsEditor no tiene StatsEditor.gd asignado")
	assert(combat_tracker.has_method("reset"),
		"CombatTracker no tiene CombatTracker.gd asignado")
	assert(hitbox_editor.has_signal("close_requested"),
		"HitboxEditor no tiene HitboxEditor.gd asignado")

# ──────────────────────────────────────────────
#  Conexión de señales
# ──────────────────────────────────────────────
func _connect_signals() -> void:
	combat_ui.pause_requested.connect(_pause)
	pause_menu.resume_requested.connect(_on_resume)
	pause_menu.open_stats_editor_requested.connect(_on_open_stats_editor)
	pause_menu.open_hitbox_editor_requested.connect(_on_open_hitbox_editor)
	stats_editor.apply_and_restart.connect(_on_apply_and_restart)
	stats_editor.resume_combat.connect(_on_resume_from_editor)
	hitbox_editor.close_requested.connect(_on_close_hitbox_editor)

# ──────────────────────────────────────────────
#  INPUT — ESC
# ──────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if stats_editor.visible:
			_on_resume_from_editor()
		elif _paused:
			_on_resume()
		else:
			_pause()

# ──────────────────────────────────────────────
#  Combate
# ──────────────────────────────────────────────
func _start_combat() -> void:
	var players = GameData.build_players()
	var enemies = GameData.build_enemies()
	combat_manager.setup(players, enemies)
	combat_tracker.reset()
	combat_ui.set_tracker(combat_tracker)
	combat_ui.reinitialize()
	combat_manager.start_combat()  # arranca el tick del ATB

# ──────────────────────────────────────────────
#  Pausa
# ──────────────────────────────────────────────
func _pause() -> void:
	_paused = true
	get_tree().paused = true
	pause_menu.show()

func _on_resume() -> void:
	_paused = false
	pause_menu.hide()
	get_tree().paused = false

# ──────────────────────────────────────────────
#  Editor de stats
# ──────────────────────────────────────────────
func _on_open_stats_editor() -> void:
	pause_menu.hide()
	stats_editor.show()
	_update_center_display_visibility()  # pausa automática al detectar editor visible
	stats_editor._build_tabs()

func _on_resume_from_editor() -> void:
	stats_editor.hide()
	_update_center_display_visibility()
	pause_menu.show()

func _on_apply_and_restart() -> void:
	stats_editor.hide()
	_update_center_display_visibility()
	pause_menu.hide()
	get_tree().paused = false
	_paused = false
	_start_combat()

func _on_open_hitbox_editor() -> void:
	pause_menu.hide()
	hitbox_editor.show()
	_update_center_display_visibility()  # pausa automática al detectar editor visible
	hitbox_editor.refresh()

func _on_close_hitbox_editor() -> void:
	hitbox_editor.hide()
	_update_center_display_visibility()
	pause_menu.show()

# ──────────────────────────────────────────────
#  PROCESS MODE — recordatorio
#  Combat        → Always
#  PauseMenu     → Always
#  StatsEditor   → Always
#  HitboxEditor  → Always
#  CombatManager, CombatUI → Pausable (default)
# ──────────────────────────────────────────────
# ──────────────────────────────────────────────
#  CenterDisplay — se oculta cuando no hay modales abiertos
# ──────────────────────────────────────────────
var _last_pause_debug: bool = false
func _update_center_display_visibility() -> void:
	# Si hay algún modal del CenterDisplay visible:
	#  - El CenterDisplay bloquea clicks de la UI debajo
	#  - El juego se pausa automáticamente
	# Si no hay ninguno:
	#  - El CenterDisplay deja pasar clicks
	#  - El juego corre normalmente
	if center_display == null:
		return
	var any_modal_active = false
	if stats_editor != null and stats_editor.visible:
		any_modal_active = true
	if hitbox_editor != null and hitbox_editor.visible:
		any_modal_active = true
	if qte_display != null and qte_display.visible:
		any_modal_active = true

	center_display.visible = true  # SIEMPRE visible
	if any_modal_active != _last_pause_debug:
		print("[Pause debug] modal activo: ", any_modal_active,
			"  paused: ", get_tree().paused,
			"  stats_editor.process_mode: ", stats_editor.process_mode if stats_editor else "null",
			"  hitbox_editor.process_mode: ", hitbox_editor.process_mode if hitbox_editor else "null",
			"  center_display.process_mode: ", center_display.process_mode if center_display else "null")
		_last_pause_debug = any_modal_active

	if any_modal_active != _last_pause_debug or any_modal_active:
		pass  # debug arriba
	if any_modal_active:
		center_display.mouse_filter = Control.MOUSE_FILTER_PASS
		# Deshabilitar input de la UI principal para que no tape al modal del CenterDisplay
		if combat_ui:
			combat_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not get_tree().paused:
			print("[Pause] PAUSANDO (modal visible)")
			get_tree().paused = true
	else:
		center_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Restaurar input de la UI principal cuando se cierra el modal
		if combat_ui:
			combat_ui.mouse_filter = Control.MOUSE_FILTER_PASS
		if get_tree().paused and not _paused:
			print("[Pause] DESPAUSANDO (no hay modal y no pause_menu)")
			get_tree().paused = false
