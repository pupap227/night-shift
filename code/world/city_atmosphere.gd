class_name CityAtmosphere
extends Node2D
## Chimney smoke drifting over the industrial zone. Drawn above buildings.

var model: CityModel
var _time := 0.0


func _process(delta: float) -> void:
	var k := 1.0 if Game.is_time_flowing() else 0.25
	_time += delta * k
	queue_redraw()


func _draw() -> void:
	if model == null:
		return
	for b in model.buildings:
		if b.style != "chimney":
			continue
		var top := Iso.p(b.rect.get_center(), b.h + 4)
		for i in 14:
			var t := fmod(_time * 0.12 + i / 14.0, 1.0)
			var pos := top + Vector2(t * 140.0 + sin(t * 6.0 + i) * 6.0, -t * 50.0)
			var r := 5.0 + t * 22.0
			draw_circle(pos, r, Color(0.45, 0.47, 0.5, 0.11 * (1.0 - t)))
