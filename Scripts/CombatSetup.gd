# CombatSetup.gd
extends Node

var _paused = false

@export var combat_manager: Node
@export var combat_ui: Control
@export var pause_menu: Node
@export var stats_editor: Node
@export var hitbox_editor: Node
@export var combat_tracker: Node
@export var qte_display: Node
@export var center_display: Control

func _ready() -> void:
	GameData.ensure_defaults()
	_validate_nodes()
	_connect_signals()
	
	if center_display:
		center_display.hide()
		center_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Agregar modales al grupo
	_add_to_center_display_group()
	
	pause_menu.hide()
	stats_editor.hide()
	hitbox_editor.hide()
	_start_combat()

func _add_to_center_display_group() -> void:
	var nodes_to_watch = [stats_editor, hitbox_editor, qte_display]
	for node in nodes_to_watch:
		if node:
			if not node.is_in_group("center_display"):
				node.add_to_group("center_display")
			if node.has_signal("visibility_changed"):
				if not node.visibility_changed.is_connected(_update_center_display):
					node.visibility_changed.connect(_update_center_display)

func _validate_nodes() -> void:
	assert(combat_manager != null, "Falta asignar combat_manager")
	assert(combat_ui != null, "Falta asignar combat_ui")
	assert(pause_menu != null, "Falta asignar pause_menu")
	assert(stats_editor != null, "Falta asignar stats_editor")
	assert(combat_tracker != null, "Falta asignar combat_tracker")
	assert(hitbox_editor != null, "Falta asignar hitbox_editor")

func _connect_signals() -> void:
	combat_ui.pause_requested.connect(_pause)
	pause_menu.resume_requested.connect(_on_resume)
	pause_menu.open_stats_editor_requested.connect(_on_open_stats_editor)
	pause_menu.open_hitbox_editor_requested.connect(_on_open_hitbox_editor)
	stats_editor.apply_and_restart.connect(_on_apply_and_restart)
	stats_editor.resume_combat.connect(_on_resume_from_editor)
	hitbox_editor.close_requested.connect(_on_close_hitbox_editor)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if stats_editor.visible:
			_on_resume_from_editor()
		elif hitbox_editor.visible:
			_on_close_hitbox_editor()
		elif _paused:
			_on_resume()
		else:
			_pause()

func _start_combat() -> void:
	var players = GameData.build_players()
	var enemies = GameData.build_enemies()
	combat_manager.setup(players, enemies)
	combat_tracker.reset()
	combat_ui.set_tracker(combat_tracker)
	combat_ui.reinitialize()
	combat_manager.start_combat()

func _pause() -> void:
	_paused = true
	get_tree().paused = true
	pause_menu.show()

func _on_resume() -> void:
	_paused = false
	pause_menu.hide()
	get_tree().paused = false

func _update_center_display() -> void:
	if center_display == null:
		return
	
	var any_modal_visible = false
	var nodes_in_group = get_tree().get_nodes_in_group("center_display")
	
	for node in nodes_in_group:
		if node is CanvasItem and node.visible:
			any_modal_visible = true
			break
	
	if any_modal_visible:
		if not center_display.visible:
			center_display.show()
		center_display.mouse_filter = Control.MOUSE_FILTER_STOP
		if not get_tree().paused:
			get_tree().paused = true
	else:
		if center_display.visible:
			center_display.hide()
		center_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if get_tree().paused and not _paused:
			get_tree().paused = false

func _on_open_stats_editor() -> void:
	pause_menu.hide()
	stats_editor.show()
	stats_editor.refresh()
	_update_center_display()

func _on_resume_from_editor() -> void:
	stats_editor.hide()
	pause_menu.show()
	_update_center_display()

func _on_apply_and_restart() -> void:
	stats_editor.hide()
	pause_menu.hide()
	get_tree().paused = false
	_paused = false
	_update_center_display()
	_start_combat()

func _on_open_hitbox_editor() -> void:
	pause_menu.hide()
	hitbox_editor.show()
	hitbox_editor.refresh()
	_update_center_display()

func _on_close_hitbox_editor() -> void:
	hitbox_editor.hide()
	pause_menu.show()
	_update_center_display()
