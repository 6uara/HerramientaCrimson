# QTEController.gd
# Maneja la lógica pura del QTE: recorrido de ejes, timing, resultado.
# No dibuja nada — eso es responsabilidad de QTEDisplay.
class_name QTEController
extends Node

# ──────────────────────────────────────────────
#  Señales
# ──────────────────────────────────────────────
signal axis_changed(axis: String, value: float)   # "vertical" o "horizontal", 0.0-1.0
signal qte_completed(point: Vector2)               # Punto final normalizado (0-1, 0-1)

# ──────────────────────────────────────────────
#  Estado interno
# ──────────────────────────────────────────────
enum QTEPhase { IDLE, VERTICAL, HORIZONTAL, DONE }
var phase: QTEPhase = QTEPhase.IDLE

var _value_vertical:   float = 0.0   # 0.0 = arriba, 1.0 = abajo
var _value_horizontal: float = 0.0   # 0.0 = izquierda, 1.0 = derecha

var _speed_v:  float = 0.0
var _speed_h:  float = 0.0
var _left_handed: bool = false

# ──────────────────────────────────────────────
#  Arrancar el QTE con los datos del jugador
# ──────────────────────────────────────────────
func start(player: Object) -> void:
	phase = QTEPhase.VERTICAL
	_left_handed = player.left_handed

	# La vida faltante en % multiplica la velocidad
	# Ej: 10% vida actual → 90% vida faltante → velocidad * 1.9
	var hp_missing_pct: float = 1.0 - (float(player.current_hp) / float(player.max_hp))
	var speed_multiplier: float = 1.0 + hp_missing_pct

	_speed_v = player.qte_speed_y * speed_multiplier
	_speed_h = player.qte_speed_x * speed_multiplier

	# Posición inicial según mano hábil
	_value_vertical   = 0.0   # Siempre empieza arriba
	_value_horizontal = 1.0 if _left_handed else 0.0

	emit_signal("axis_changed", "vertical", _value_vertical)

func stop() -> void:
	phase = QTEPhase.IDLE

# ──────────────────────────────────────────────
#  Input del jugador — llamado desde QTEDisplay
# ──────────────────────────────────────────────
func register_input() -> void:
	match phase:
		QTEPhase.VERTICAL:
			# Congela el eje vertical y pasa al horizontal
			phase = QTEPhase.HORIZONTAL
			emit_signal("axis_changed", "horizontal", _value_horizontal)
		QTEPhase.HORIZONTAL:
			# Congela el eje horizontal y termina
			phase = QTEPhase.DONE
			var result := Vector2(_value_horizontal, _value_vertical)
			emit_signal("qte_completed", result)

# ──────────────────────────────────────────────
#  Loop — llamado cada frame desde QTEDisplay
# ──────────────────────────────────────────────
func tick(delta: float) -> void:
	match phase:
		QTEPhase.VERTICAL:
			_value_vertical += _speed_v * delta
			if _value_vertical >= 1.0:
				_value_vertical = 1.0
				# Al llegar al límite se toma ese valor y pasa al siguiente eje
				phase = QTEPhase.HORIZONTAL
				emit_signal("axis_changed", "vertical", _value_vertical)
				emit_signal("axis_changed", "horizontal", _value_horizontal)
			else:
				emit_signal("axis_changed", "vertical", _value_vertical)

		QTEPhase.HORIZONTAL:
			if _left_handed:
				_value_horizontal -= _speed_h * delta
				if _value_horizontal <= 0.0:
					_value_horizontal = 0.0
					_finish()
			else:
				_value_horizontal += _speed_h * delta
				if _value_horizontal >= 1.0:
					_value_horizontal = 1.0
					_finish()
			emit_signal("axis_changed", "horizontal", _value_horizontal)

func _finish() -> void:
	phase = QTEPhase.DONE
	var result := Vector2(_value_horizontal, _value_vertical)
	emit_signal("qte_completed", result)

func get_current_values() -> Vector2:
	return Vector2(_value_horizontal, _value_vertical)

func is_active() -> bool:
	return phase == QTEPhase.VERTICAL or phase == QTEPhase.HORIZONTAL
