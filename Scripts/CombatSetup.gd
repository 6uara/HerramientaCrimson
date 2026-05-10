# CombatSetup.gd
# Nodo raíz de Combat.tscn — process_mode: Always
extends Node

var _paused := false


@export var combat_manager: Node
@export var combat_ui: Control
@export var pause_menu: Node
@export var stats_editor: Node
@export var hitbox_editor: Node
@export var combat_tracker: Node

func _ready() -> void:
	GameData.ensure_defaults()
	_connect_signals()
	pause_menu.hide()
	stats_editor.hide()
	hitbox_editor.hide()
	_start_combat()

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
	stats_editor._build_tabs()

func _on_resume_from_editor() -> void:
	stats_editor.hide()
	pause_menu.show()

func _on_apply_and_restart() -> void:
	stats_editor.hide()
	pause_menu.hide()
	get_tree().paused = false
	_paused = false
	_start_combat()

func _on_open_hitbox_editor() -> void:
	pause_menu.hide()
	hitbox_editor.show()
	hitbox_editor.refresh()

func _on_close_hitbox_editor() -> void:
	hitbox_editor.hide()
	pause_menu.show()

# ──────────────────────────────────────────────
#  PROCESS MODE — recordatorio
#  Combat        → Always
#  PauseMenu     → Always
#  StatsEditor   → Always
#  HitboxEditor  → Always
#  CombatManager, CombatUI → Pausable (default)
# ──────────────────────────────────────────────
