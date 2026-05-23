class_name PlayerCharacter
extends Character

# ── Stats de combate base ──
@export var cadence: int               = 3
@export var max_ammo: int              = 12

# ── QTE ──
@export var qte_speed_x: float         = 0.4
@export var qte_speed_y: float         = 0.3
@export var left_handed: bool          = false

# ── Sets de elipse — uno por disparo (cantidad = cadence) ──
# Cada set: { "h": float, "k": float, "r": float, "a": float, "b": float }
@export var elipse_sets: Array = []

var current_ammo: int
var bullets_spent_total: int = 0

func _init() -> void:
	super._init()
	current_ammo = max_ammo

func reset() -> void:
	super.reset()
	current_ammo        = max_ammo
	bullets_spent_total = 0

func can_shoot(bullets: int) -> bool:
	return bullets > 0 and bullets <= cadence and current_ammo >= bullets

func consume_ammo(bullets: int) -> void:
	current_ammo        -= bullets
	bullets_spent_total += bullets

func reload() -> void:
	current_ammo = max_ammo

func get_ammo_ratio() -> float:
	return float(current_ammo) / float(max_ammo)

# Devuelve el set de elipse en coordenadas DEL JUEGO (0..1) para un disparo dado.
# Internamente los sets se guardan en coordenadas Desmos (-1..+1) y se convierten acá.
# Si no hay set definido para ese índice, usa el último disponible.
func get_elipse_set(shot_index: int) -> Dictionary:
	var ElipseCalculatorScript = load("res://Scripts/elipse_calculator.gd")
	if elipse_sets.is_empty():
		return ElipseCalculatorScript.desmos_to_game({ "h": 0.0, "k": 0.0, "r": 0.2, "a": 1.0, "b": 1.0 })
	var idx = clamp(shot_index, 0, elipse_sets.size() - 1)
	return ElipseCalculatorScript.desmos_to_game(elipse_sets[idx])

# Devuelve el set en formato Desmos (raw como lo edita el GD)
func get_elipse_set_desmos(shot_index: int) -> Dictionary:
	if elipse_sets.is_empty():
		return { "h": 0.0, "k": 0.0, "r": 0.2, "a": 1.0, "b": 1.0 }
	var idx = clamp(shot_index, 0, elipse_sets.size() - 1)
	return elipse_sets[idx].duplicate()

# Asegura que haya exactamente `cadence` sets en el array
func ensure_elipse_sets() -> void:
	# Si hay menos, agregar defaults
	while elipse_sets.size() < cadence:
		var i = elipse_sets.size()
		# Cada set siguiente tiene un poco más de dispersión (coords Desmos)
		elipse_sets.append({
			"h": 0.0,
			"k": 0.0,
			"r": 0.10 + i * 0.04,
			"a": 1.0 + i * 0.1,
			"b": 1.0,
		})
	# Si hay más, recortar
	while elipse_sets.size() > cadence:
		elipse_sets.pop_back()
