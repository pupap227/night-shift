class_name Stamp
extends RefCounted
## Physical "rubber stamp" confirmation that lands where the action happened.


static func show(parent: Control, at: Vector2, title: String, sub: String, col: Color) -> void:
	var p := PanelContainer.new()
	var sb := Kit.box(Color(0.03, 0.04, 0.05, 0.92), col, 3, 4, 10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 40
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	p.add_child(vb)
	var t := Kit.label(title, 20, col.lightened(0.35), "display_bold")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	if sub != "":
		var s := Kit.label(sub, 13, Kit.TEXT_DIM, "display_light")
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(minf(260.0, parent.size.x - 60.0), 0)
		vb.add_child(s)
	parent.add_child(p)
	p.reset_size()
	var pos := at - p.size * 0.5 - Vector2(0, 30)
	pos.x = clampf(pos.x, 8, parent.size.x - p.size.x - 8)
	pos.y = clampf(pos.y, 8, parent.size.y - p.size.y - 8)
	p.position = pos
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(1.5, 1.5)
	p.rotation = deg_to_rad(-4.0)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(p, "position:y", p.position.y - 24.0, 0.4)
	tw.parallel().tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
