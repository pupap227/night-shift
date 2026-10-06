class_name CityGlow
extends Node2D
## Additive light on the wet ground: lamp pools, long vertical reflections (wet asphalt),
## the red wash of admissions, cold lab light, vehicle beams. Brightness follows the alarm state.

var model: CityModel
var actors: CityActors
var _tex: Texture2D
var _streak: Texture2D
var _time := 0.0


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	_tex = radial_texture()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0)
	t.fill_to = Vector2(0.5, 1)
	t.width = 16
	t.height = 64
	_streak = t


static func radial_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


var _acc := 0.0


func _process(delta: float) -> void:
	_time += delta
	_acc += delta
	if _acc > (1.0 / 15.0 if Screen.low_power else 1.0 / 30.0):
		_acc = 0.0
		queue_redraw()


func pool(world: Vector2, radius: float, col: Color) -> void:
	draw_texture_rect(_tex, Rect2(world - Vector2(radius, radius * 0.5), Vector2(radius * 2, radius)), false, col)


## Vertical shimmer below a light: the signature of wet asphalt at night.
func streak(world: Vector2, w: float, length: float, col: Color) -> void:
	var wob := 1.0 + 0.08 * sin(_time * 3.0 + world.x * 0.1)
	draw_texture_rect(_streak, Rect2(world.x - w * 0.5, world.y, w, length * wob), false, col)


func _draw() -> void:
	if model == null:
		return
	for l in model.lamps:
		var p := Iso.p(l) + Vector2(5, 0)
		pool(p, 44.0, Color(1.0, 0.7, 0.36, 0.2))
		streak(p + Vector2(0, -2), 5.0, 34.0, Color(1.0, 0.72, 0.4, 0.22))
	# Admissions: red emergency wash + doorway glow + red reflections.
	var er_pulse := 0.7 + 0.3 * sin(_time * 2.2)
	var k := 1.0 + 0.4 * Game.alarm_level
	pool(Iso.pxy(12.4, 20.2), 150.0, Color(0.9, 0.1, 0.08, 0.22 * er_pulse * k))
	pool(Iso.pxy(12.9, 19.6), 60.0, Color(1.0, 0.9, 0.7, 0.3))
	for x in [11.3, 12.8, 14.0]:
		streak(Iso.pxy(x, 20.4), 7.0, 46.0, Color(0.95, 0.15, 0.1, 0.25 * er_pulse * k))
	# Main hall portico: warm spill and reflections on the forecourt.
	pool(Iso.pxy(13.8, 14.6), 80.0, Color(1.0, 0.78, 0.45, 0.2))
	streak(Iso.pxy(13.8, 14.4), 10.0, 40.0, Color(1.0, 0.8, 0.5, 0.2))
	# Surgery: cold green band spill. Lab: cold white. ICU: teal.
	pool(Iso.pxy(20.0, 19.4), 70.0, Color(0.4, 0.95, 0.75, 0.1))
	pool(Iso.pxy(24.5, 19.4), 60.0, Color(0.75, 0.88, 1.0, 0.13))
	pool(Iso.pxy(21.0, 13.4), 50.0, Color(0.3, 0.8, 0.85, 0.09))
	# Yard lamps (fluorescent).
	for q in [Vector2(17, 15), Vector2(17, 20.4), Vector2(22, 20.4), Vector2(14, 24.6), Vector2(21, 14.8)]:
		pool(Iso.p(q), 54.0, Color(0.6, 0.8, 0.85, 0.08))
	# City accents.
	pool(Iso.pxy(5.5, 13.6), 50.0, Color(0.2, 0.35, 1.0, 0.12 + 0.06 * sin(_time * 3.0)))
	pool(Iso.pxy(33.0, 12.6), 70.0, Color(1.0, 0.55, 0.3, 0.14))
	pool(Iso.pxy(13.5, 41.0), 90.0, Color(0.85, 0.95, 1.0, 0.15))
	pool(Iso.pxy(13.5, 5.4), 40.0, Color(0.4, 0.9, 0.85, 0.12))
	pool(Iso.pxy(34.0, 33.5), 150.0, Color(1.0, 0.5, 0.18, 0.1))
	if actors:
		for li in actors.lights:
			pool(li[0], li[1], li[2])
			if li.size() > 3:
				streak(li[0], 6.0, 26.0, Color(li[2].r, li[2].g, li[2].b, li[2].a * 0.8))
