# QTEController.gd
class_name QTEController
extends Node

signal axis_changed(axis: String, value: float)
signal qte_completed(point: Vector2)

# Franja horizontal útil del QTE (en coords normalizadas 0..1).
# El espacio matemático es cuadrado, pero la silueta (sprite alto y angosto)
# ocupa todo el ALTO y solo una franja del ANCHO. Limitamos X para que ningún
# disparo caiga en el espacio vacío a los lados del personaje.
# Ej: 0.25 a 0.75 = la silueta ocupa el 50% central del ancho del cuadrado.
# Franja horizontal útil — valores por defecto, se sobreescriben con set_x_band()
# desde el QTEDisplay según el tamaño real de la textura del enemigo.
var x_min: float = 0.05
var x_max: float = 0.95

func set_x_band(new_min: float, new_max: float) -> void:
	x_min = new_min
	x_max = new_max

enum QTEPhase { IDLE, VERTICAL, HORIZONTAL, DONE }
var phase: QTEPhase = QTEPhase.IDLE

var _value_vertical: float = 0.5
var _value_horizontal: float = 0.5
var _dir_v: int = -1
var _dir_h: int = 1
var _speed_v: float = 0.0
var _speed_h: float = 0.0
var _left_handed: bool = false

func start(player: Object) -> void:
	print("[QTEController] start - left_handed: ", player.left_handed)
	phase = QTEPhase.VERTICAL
	_left_handed = player.left_handed

	var hp_missing_pct: float = 1.0 - (float(player.current_hp) / float(player.max_hp))
	var speed_multiplier: float = 1.0 + hp_missing_pct

	_speed_v = player.qte_speed_y * speed_multiplier
	_speed_h = player.qte_speed_x * speed_multiplier

	_value_vertical = 0.5
	_dir_v = -1

	if _left_handed:
		_value_horizontal = x_max  # zurdo empieza desde la derecha de la franja
		_dir_h = -1
	else:
		_value_horizontal = x_min  # diestro empieza desde la izquierda de la franja
		_dir_h = 1

	print("[QTEController] speeds - v: ", _speed_v, " h: ", _speed_h)
	emit_signal("axis_changed", "vertical", _value_vertical)

func stop() -> void:
	phase = QTEPhase.IDLE

func register_input() -> void:
	print("[QTEController] register_input - phase: ", phase)
	match phase:
		QTEPhase.VERTICAL:
			phase = QTEPhase.HORIZONTAL
			emit_signal("axis_changed", "horizontal", _value_horizontal)
		QTEPhase.HORIZONTAL:
			phase = QTEPhase.DONE
			var result := Vector2(_value_horizontal, _value_vertical)
			print("[QTEController] qte_completed: ", result)
			emit_signal("qte_completed", result)

func tick(delta: float) -> void:
	match phase:
		QTEPhase.VERTICAL:
			_value_vertical += _dir_v * _speed_v * delta
			# El alto usa todo el cuadrado (el sprite es alto, ocupa todo el eje Y)
			if _value_vertical <= 0.0:
				_value_vertical = 0.0
				_dir_v = 1
			elif _value_vertical >= 1.0:
				_value_vertical = 1.0
				_dir_v = -1
			emit_signal("axis_changed", "vertical", _value_vertical)

		QTEPhase.HORIZONTAL:
			_value_horizontal += _dir_h * _speed_h * delta
			# Rebota dentro de la franja útil del ancho (la silueta no ocupa todo el cuadrado)
			if _value_horizontal <= x_min:
				_value_horizontal = x_min
				_dir_h = 1
			elif _value_horizontal >= x_max:
				_value_horizontal = x_max
				_dir_h = -1
			emit_signal("axis_changed", "horizontal", _value_horizontal)

func get_current_values() -> Vector2:
	return Vector2(_value_horizontal, _value_vertical)

func is_active() -> bool:
	return phase == QTEPhase.VERTICAL or phase == QTEPhase.HORIZONTAL
