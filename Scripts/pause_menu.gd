# PauseMenu.gd
extends PanelContainer

signal resume_requested
signal open_stats_editor_requested
signal open_hitbox_editor_requested

@export var btn_resume: Button     
@export var btn_stats: Button       
@export var btn_hitboxes: Button    
@export var btn_restart: Button     

func _ready() -> void:
	btn_resume.pressed.connect(func(): emit_signal("resume_requested"))
	btn_stats.pressed.connect(func(): emit_signal("open_stats_editor_requested"))
	btn_hitboxes.pressed.connect(func(): emit_signal("open_hitbox_editor_requested"))
	btn_restart.pressed.connect(_on_restart)
	hide()

func _on_restart() -> void:
	# Reinicia el combate sin cambiar stats
	get_tree().reload_current_scene()

# Nodo estructura sugerida para PauseMenu:
# PauseMenu (PanelContainer)   ← este script
#   └── VBox (VBoxContainer)
#         ├── Label ["PAUSA"]
#         ├── BtnResume   (Button) ["Continuar"]
#         ├── BtnStats    (Button) ["Editar Stats"]
#         ├── BtnHitboxes (Button) ["Editar Hitboxes"]
#         └── BtnRestart  (Button) ["Reiniciar Combate"]
