# PauseMenu.gd
# Panel de pausa que aparece sobre el combate.
# Adjuntalo a un nodo PanelContainer dentro de CombatUI (o como hijo directo de Combat).
extends PanelContainer

signal resume_requested
signal open_stats_editor_requested
signal open_hitbox_editor_requested

# Asignar desde el Inspector arrastrando los botones
@export var btn_resume: Button
@export var btn_stats: Button
@export var btn_hitboxes: Button
@export var btn_restart: Button

# Slider opcional para controlar la velocidad del juego
@export var speed_slider: HSlider  # opcional — si lo asignás, controla GameData.game_speed
@export var speed_label: Label     # opcional — muestra el valor actual

func _ready() -> void:
	assert(btn_resume != null,    "Falta asignar btn_resume en el Inspector")
	assert(btn_stats != null,     "Falta asignar btn_stats en el Inspector")
	assert(btn_hitboxes != null,  "Falta asignar btn_hitboxes en el Inspector")
	assert(btn_restart != null,   "Falta asignar btn_restart en el Inspector")

	btn_resume.pressed.connect(func(): emit_signal("resume_requested"))
	btn_stats.pressed.connect(func(): emit_signal("open_stats_editor_requested"))
	btn_hitboxes.pressed.connect(func(): emit_signal("open_hitbox_editor_requested"))
	btn_restart.pressed.connect(_on_restart)

	# Si hay slider de velocidad, configurarlo
	if speed_slider:
		speed_slider.min_value = 0.25
		speed_slider.max_value = 4.0
		speed_slider.step = 0.25
		speed_slider.value = GameData.game_speed
		speed_slider.value_changed.connect(_on_speed_changed)
		_on_speed_changed(GameData.game_speed)

	hide()

func _on_speed_changed(value: float) -> void:
	GameData.game_speed = value
	if speed_label:
		speed_label.text = "Velocidad: %.2fx" % value

func _on_restart() -> void:
	# Reinicia el combate sin cambiar stats
	get_tree().reload_current_scene()
