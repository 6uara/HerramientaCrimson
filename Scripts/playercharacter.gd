class_name PlayerCharacter
extends Character

# ── Stats de combate base ──
@export var cadence: int               = 3
@export var max_ammo: int              = 12

# ── Chance de impacto (convive con el QTE) ──
@export var hit_chance_base: float     = 0.80
@export var hit_chance_penalty: float  = 0.02

# ── QTE ──
@export var qte_speed_x: float         = 0.4
@export var qte_speed_y: float         = 0.3
@export var left_handed: bool          = false

# ── Elipse (disparos posteriores al QTE) ──
@export var elipse_h: float            = 0.0
@export var elipse_k: float            = 0.05
@export var elipse_r: float            = 0.08
@export var elipse_a: float            = 1.2
@export var elipse_b: float            = 0.8

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

func get_current_hit_chance() -> float:
	return clampf(hit_chance_base - hit_chance_penalty * bullets_spent_total, 0.0, 1.0)
