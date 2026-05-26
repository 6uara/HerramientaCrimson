# QTEController.gd
class_name QTEController
extends Node

signal axis_changed(axis: String, value: float)
signal qte_completed(point: Vector2)

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
		_value_horizontal = 1.0
		_dir_h = -1
	else:
		_value_horizontal = 0.0
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
			if _value_vertical <= 0.0:
				_value_vertical = 0.0
				_dir_v = 1
			elif _value_vertical >= 1.0:
				_value_vertical = 1.0
				_dir_v = -1
			emit_signal("axis_changed", "vertical", _value_vertical)

		QTEPhase.HORIZONTAL:
			_value_horizontal += _dir_h * _speed_h * delta
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
