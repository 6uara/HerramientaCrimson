# QTEController.gd
# Maneja el recorrido del QTE: vertical primero (rebota), luego horizontal (rebota).
# Confirmación manual del jugador.
class_name QTEController
extends Node

signal axis_changed(axis: String, value: float)
signal qte_completed(point: Vector2)

enum QTEPhase { IDLE, VERTICAL, HORIZONTAL, DONE }
var phase: QTEPhase = QTEPhase.IDLE

# Valores normalizados 0.0 - 1.0
var _value_vertical: float = 1.0      # 1.0 = abajo, 0.0 = arriba (vertical va de abajo a arriba)
var _value_horizontal: float = 0.0    # 0.0 = izquierda, 1.0 = derecha

# Dirección del movimiento (rebote)
var _dir_v: int = -1   # -1 sube, +1 baja
var _dir_h: int = 1    # +1 derecha, -1 izquierda (se setea según mano hábil)

var _speed_v: float = 0.0
var _speed_h: float = 0.0
var _left_handed: bool = false

func start(player: Object) -> void:
	phase = QTEPhase.VERTICAL
	_left_handed = player.left_handed

	# Vida faltante % multiplica la velocidad
	var hp_missing_pct: float = 1.0 - (float(player.current_hp) / float(player.max_hp))
	var speed_multiplier: float = 1.0 + hp_missing_pct

	_speed_v = player.qte_speed_y * speed_multiplier
	_speed_h = player.qte_speed_x * speed_multiplier

	# Posición inicial vertical: abajo, va hacia arriba
	_value_vertical = 1.0
	_dir_v = -1

	# Posición inicial horizontal: depende de mano hábil
	if _left_handed:
		_value_horizontal = 1.0
		_dir_h = -1
	else:
		_value_horizontal = 0.0
		_dir_h = 1

	emit_signal("axis_changed", "vertical", _value_vertical)

func stop() -> void:
	phase = QTEPhase.IDLE

# Input del jugador
func register_input() -> void:
	match phase:
		QTEPhase.VERTICAL:
			# Fija eje vertical y pasa al horizontal
			phase = QTEPhase.HORIZONTAL
			emit_signal("axis_changed", "horizontal", _value_horizontal)
		QTEPhase.HORIZONTAL:
			# Fija horizontal y termina
			phase = QTEPhase.DONE
			var result := Vector2(_value_horizontal, _value_vertical)
			emit_signal("qte_completed", result)

func tick(delta: float) -> void:
	match phase:
		QTEPhase.VERTICAL:
			_value_vertical += _dir_v * _speed_v * delta
			# Rebote en extremos
			if _value_vertical <= 0.0:
				_value_vertical = 0.0
				_dir_v = 1
			elif _value_vertical >= 1.0:
				_value_vertical = 1.0
				_dir_v = -1
			emit_signal("axis_changed", "vertical", _value_vertical)

		QTEPhase.HORIZONTAL:
			_value_horizontal += _dir_h * _speed_h * delta
			# Rebote en extremos
			if _value_horizontal <= 0.0:
				_value_horizontal = 0.0
				_dir_h = 1
			elif _value_horizontal >= 1.0:
				_value_horizontal = 1.0
				_dir_h = -1
			emit_signal("axis_changed", "horizontal", _value_horizontal)

func get_current_values() -> Vector2:
	return Vector2(_value_horizontal, _value_vertical)

func is_active() -> bool:
	return phase == QTEPhase.VERTICAL or phase == QTEPhase.HORIZONTAL
