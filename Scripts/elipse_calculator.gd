# ElipseCalculator.gd
# Genera puntos aleatorios dentro de una elipse usando las fórmulas del GDD:
#   q  = 2π · u
#   w  = √v
#   rx = r · √a
#   ry = r · √b
#   n  = h + rx · w · cos(q)
#   m  = k + ry · w · sin(q)
class_name ElipseCalculator
extends RefCounted

# Variables de la elipse (configurables por arma/jugador)
var h: float = 0.0    # centro X de la elipse
var k: float = 0.0    # centro Y de la elipse
var r: float = 1.0    # radio general
var a: float = 1.0    # escala horizontal
var b: float = 1.0    # escala vertical

func setup(p_h: float, p_k: float, p_r: float, p_a: float, p_b: float) -> void:
	h = p_h
	k = p_k
	r = p_r
	a = p_a
	b = p_b

# Genera punto aleatorio dentro de la elipse independiente (h, k son absolutos)
func next_point() -> Vector2:
	var u: float = randf()        # 0..1
	var v: float = randf()        # 0..1
	var q: float = 2.0 * PI * u   # ángulo
	var w: float = sqrt(v)        # distancia normalizada
	var rx: float = r * sqrt(a)
	var ry: float = r * sqrt(b)
	var n: float = h + rx * w * cos(q)
	var m: float = k + ry * w * sin(q)
	return Vector2(n, m)

# Genera punto encadenado a un punto anterior (usa el anterior como nuevo h)
# El doc dice: "se cambia la fórmula de punto aleatorio (n,m) se cambian
# los valores h y se reemplaza por la variable n"
# m2 mantiene k igual (no se reemplaza).
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



# Versiones "verbose" que devuelven un Dictionary con TODAS las variables intermedias.
# Útil para debug/análisis: muestra u, v, q, w, rx, ry, n, m.
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
# El GD edita los sets de elipse en coordenadas Desmos (-1 a +1, con +Y arriba).
# El juego usa coordenadas normalizadas (0 a 1, con +Y abajo).
#
# Mapeos:
#   x:   -1..+1   →   0..1     →  x_game = (x_desmos + 1) / 2
#   y:   -1..+1   →   1..0     →  y_game = (1 - y_desmos) / 2  (Y invertido)
#   r:    0..2    →   0..1     →  r_game = r_desmos / 2        (rango es 2 unidades)
#   a/b:  factores adimensionales, no se convierten

static func desmos_to_game(desmos_set: Dictionary) -> Dictionary:
	return {
		"h": (float(desmos_set.get("h", 0.0)) + 1.0) / 2.0,
		"k": (1.0 - float(desmos_set.get("k", 0.0))) / 2.0,
		"r":  float(desmos_set.get("r", 0.1)) / 2.0,
		"a":  float(desmos_set.get("a", 1.0)),
		"b":  float(desmos_set.get("b", 1.0)),
	}

static func game_to_desmos(game_set: Dictionary) -> Dictionary:
	return {
		"h": float(game_set.get("h", 0.5)) * 2.0 - 1.0,
		"k": 1.0 - float(game_set.get("k", 0.5)) * 2.0,
		"r": float(game_set.get("r", 0.05)) * 2.0,
		"a": float(game_set.get("a", 1.0)),
		"b": float(game_set.get("b", 1.0)),
	}
