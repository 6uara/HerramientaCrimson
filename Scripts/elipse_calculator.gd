# ElipseCalculator.gd
class_name ElipseCalculator
extends RefCounted

var h: float = 0.0   
var k: float = 0.0   
var r: float = 1.0   
var a: float = 1.0  
var b: float = 1.0    

func setup(p_h: float, p_k: float, p_r: float, p_a: float, p_b: float) -> void:
	h = p_h
	k = p_k
	r = p_r
	a = p_a
	b = p_b

# Genera un punto aleatorio dentro de la elipse
# Fórmula CORRECTA: (x-h)^2/a + (y-k)^2/b = r^2
# Cuando a=1 y b=1, es un círculo: (x-h)^2 + (y-k)^2 = r^2
func next_point() -> Vector2:
	var u: float = randf()
	var v: float = randf()
	var q: float = 2.0 * PI * u
	var w: float = sqrt(v)
	
	# rx y ry = r * sqrt(a)  y  r * sqrt(b)
	# Si a=1, sqrt(1)=1 → rx = r
	# Si b=1, sqrt(1)=1 → ry = r
	var rx: float = r * sqrt(a)
	var ry: float = r * sqrt(b)
	
	var n: float = h + rx * w * cos(q)
	var m: float = k + ry * w * sin(q)
	return Vector2(n, m)

func next_point_from(previous: Vector2) -> Vector2:
	var u: float = randf()
	var v: float = randf()
	var q: float = 2.0 * PI * u
	var w: float = sqrt(v)
	var rx: float = r * sqrt(a)
	var ry: float = r * sqrt(b)
	var n: float = previous.x + rx * w * cos(q)
	var m: float = k + ry * w * sin(q)
	return Vector2(n, m)

func next_point_verbose() -> Dictionary:
	var u: float = randf()
	var v: float = randf()
	var q: float = 2.0 * PI * u
	var w: float = sqrt(v)
	var rx: float = r * sqrt(a)
	var ry: float = r * sqrt(b)
	var n: float = h + rx * w * cos(q)
	var m: float = k + ry * w * sin(q)
	return {
		"u": u, "v": v, "q": q, "w": w,
		"rx": rx, "ry": ry,
		"n": n, "m": m,
		"h": h, "k": k, "r": r, "a": a, "b": b,
		"point": Vector2(n, m),
	}

func next_point_from_verbose(previous: Vector2) -> Dictionary:
	var u: float = randf()
	var v: float = randf()
	var q: float = 2.0 * PI * u
	var w: float = sqrt(v)
	var rx: float = r * sqrt(a)
	var ry: float = r * sqrt(b)
	var n: float = previous.x + rx * w * cos(q)
	var m: float = k + ry * w * sin(q)
	return {
		"u": u, "v": v, "q": q, "w": w,
		"rx": rx, "ry": ry,
		"n": n, "m": m,
		"h": h, "k": k, "r": r, "a": a, "b": b,
		"point": Vector2(n, m),
	}

# ──────────────────────────────────────────────
#  CONVERSIÓN DESMOS ↔ JUEGO
# ──────────────────────────────────────────────
static func desmos_to_game(desmos_set: Dictionary) -> Dictionary:
	# Desmos: h y k van de -1 a 1, Y positivo hacia ARRIBA
	# Juego: h y k van de 0 a 1, Y positivo hacia ABAJO
	return {
		"h": (float(desmos_set.get("h", 0.0)) + 1.0) / 2.0,
		"k": (1.0 - float(desmos_set.get("k", 0.0))) / 2.0,
		"r": float(desmos_set.get("r", 0.1)) / 2.0,
		"a": float(desmos_set.get("a", 1.0)),
		"b": float(desmos_set.get("b", 1.0)),
	}

static func game_to_desmos(game_set: Dictionary) -> Dictionary:
	return {
		"h": float(game_set.get("h", 0.5)) * 2.0 - 1.0,
		"k": 1.0 - float(game_set.get("k", 0.5)) * 2.0,
		"r": float(game_set.get("r", 0.05)) * 2.0,
		"a": float(game_set.get("a", 1.0)),
		"b": float(game_set.get("b", 1.0)),
	}
