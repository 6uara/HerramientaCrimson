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
