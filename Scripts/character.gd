class_name Character
extends RefCounted

@export var character_name: String = "Character"
@export var max_hp: float = 100.0
@export var speed: float = 1.0       # Multiplica qué tan rápido llena el ATB
@export var damage: float = 20.0
@export var atb_max: float = 100.0   # Cuánto hay que llenar para actuar

var current_hp: float
var atb: float = 0.0
var is_alive: bool = true

func _init() -> void:
	current_hp = max_hp

func reset() -> void:
	current_hp = max_hp
	atb = 0.0
	is_alive = true

func take_damage(amount: float) -> void:
	current_hp = max(0.0, current_hp - amount)
	if current_hp <= 0.0:
		is_alive = false

func tick_atb(delta: float) -> bool:
	# Retorna true cuando el ATB se llena y es el turno de actuar
	if not is_alive:
		return false
	atb += delta * speed * 50.0  # 50 es el factor base de velocidad
	if atb >= atb_max:
		atb = atb_max
		return true
	return false

func consume_atb() -> void:
	atb = 0.0

func get_atb_ratio() -> float:
	return atb / atb_max
