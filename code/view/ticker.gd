class_name Ticker
extends VBoxContainer
## Short notifications: one line each, they fade on their own. Tap to look at the place.

var map: MapView
var max_items := 2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	Game.notify.connect(push)


func push(text: String, tone: String, tile: Vector2) -> void:
	var col: Color = {"danger": Kit.RED, "warn": Kit.AMBER, "ok": Kit.GREEN}.get(tone, Kit.COLD)
	var p := PanelContainer.new()
	var sb := Kit.box(Color(0.03, 0.04, 0.06, 0.92), Color(col, 0.6), 1, 18, 8)
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(Kit.icon({"danger": "alarm", "warn": "warning", "ok": "check"}.get(tone, "phone"), 16, col))
	var l := Kit.label(text, 14, Kit.TEXT, "display")
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(0, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if tile.x >= 0:
		p.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and map:
				map.focus_world(Iso.p(tile)))
	add_child(p)
	var text_w := Kit.font("display").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	l.custom_minimum_size.x = minf(text_w + 4, maxf(120.0, size.x - 70))
	while get_child_count() > max_items:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(6.0 if tone == "danger" else 4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
