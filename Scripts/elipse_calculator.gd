# ElipseCalculator.gd
# Calcula puntos aleatorios dentro de una elipse para los disparos
# posteriores al primero (que fue determinado por el QTE).
class_name ElipseCalculator
extends RefCounted

# Variables de la elipse (configurables por arma/jugador)
var h: float = 0.0    # Desplazamiento X del centro (0 = encima del disparo anterior)
var k: float = 0.0    # Altura Y donde se genera la elipse
var r: float = 1.0    # Radio base
var a: float = 1.0    # Estiramiento en X
var b: float = 1.0    # Achatamiento en Y

# Punto de anclaje — se actualiza con cada disparo para encadenar elipses
var _anchor: Vector2 = Vector2.ZERO

func setup(p_h: float, p_k: float, p_r: float, p_a: float, p_b: float) -> void:
	h = p_h
	k = p_k
	r = p_r
	a = p_a
	b = p_b

func set_anchor(point: Vector2) -> void:
	_anchor = point

# Genera el siguiente punto aleatorio dentro de la elipse,
# encadenado al disparo anterior (usa n del disparo previo como nuevo h).
func next_point() -> Vector2:
	# t avanza linealmente — usamos tiempo real para variación constante
	var t := fmod(Time.get_ticks_msec() / 1000.0, 2.0) - 1.0  # -1 a 1

	# u y v: números aleatorios entre -1 y 1 influenciados por t
	var u = randf_range(-1.0, 1.0) * (1.0 - abs(t) * 0.3)
	var v = randf_range(-1.0, 1.0) * (1.0 - abs(t) * 0.3)

	# q: ángulo del punto en la elipse
	var q := atan2(v, u)

	# w: distancia del centro (entre 0 y 1, con distribución suave)
	var w := sqrt(abs(u * v))

	# rx y ry: radio en cada eje
	var rx := r * a
	var ry := r * b

	# n y m: coordenadas del punto aleatorio
	# n usa _anchor.x como base (encadenado al disparo anterior)
	var n := _anchor.x + h + rx * w * cos(q)
	var m := k + ry * w * sin(q)

	var point := Vector2(n, m)
	_anchor = point  # El siguiente disparo parte de este punto
	return point

# Versión sin encadenamiento (elipses independientes)
func next_point_independent(center: Vector2) -> Vector2:
	var u := randf_range(-1.0, 1.0)
	var v := randf_range(-1.0, 1.0)
	var q := atan2(v, u)
	var w := sqrt(abs(u * v))
	var rx := r * a
	var ry := r * b
	var n := center.x + h + rx * w * cos(q)
	var m := center.y + k + ry * w * sin(q)
	return Vector2(n, m)
