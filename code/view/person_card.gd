class_name PersonCard
extends Control
## A person, not a row of stats: full-bleed portrait, name, role, one-line character hook,
## what they are doing right now, and only two gauges (fatigue, stress).
## Layout "tall" (strip of cards) or "row" (compact list for phone landscape).
## Input is handled by StaffStrip; this control only draws.

var staff_id := ""
var layout := "tall"
var ghost := false            # true for the copy that follows the finger while dragging
var lifted := 0.0             # 0..1 selection lift (animated)
var dimmed := 0.0             # 0..1 when another card is selected
var _portrait: Texture2D
var _fade: Texture2D
var _fat := 0.0
var _str := 0.0
var _flash := 0.0
var _time := 0.0
var _lift_tw: Tween
var _sig := ""


func setup(sid: String, lay: String) -> void:
	staff_id = sid
	layout = lay
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := staff()
	_portrait = Assets.portrait(s.data.portrait_id)
	_fat = s.fatigue
	_str = s.stress
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.05, 0.0))
	g.add_point(0.45, Color(0.02, 0.03, 0.05, 0.55))
	g.set_color(g.get_point_count() - 1, Color(0.02, 0.03, 0.05, 0.97))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	_fade = gt
	if not ghost:
		Game.selection_changed.connect(func(_id): _on_selection())


func staff() -> StaffMember:
	return Game.staff[staff_id]


func base_size() -> Vector2:
	if layout == "row":
		return Vector2(214, 66)
	return Vector2(122, 176) if Screen.is_phone() else Vector2(156, 222)


func _on_selection() -> void:
	var sel := Game.selected_staff_id
	var target := 1.0 if sel == staff_id else 0.0
	var dim_t := 1.0 if sel != "" and sel != staff_id else 0.0
	if _lift_tw:
		_lift_tw.kill()
	_lift_tw = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lift_tw.tween_property(self, "lifted", target, 0.22)
	_lift_tw.tween_property(self, "dimmed", dim_t, 0.18)


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_time += delta
	var s := staff()
	_fat = lerpf(_fat, s.fatigue, minf(1.0, delta * 5.0))
	_str = lerpf(_str, s.stress, minf(1.0, delta * 5.0))
	_flash = maxf(0.0, _flash - delta * 1.8)
	var sig := "%d|%d|%d|%s|%.2f|%.2f|%.2f|%s" % [int(_fat), int(_str), s.state, s.case_uid, lifted, dimmed, _flash, Game.selected_staff_id == staff_id]
	if s.state == StaffMember.State.WORKING or s.state == StaffMember.State.MOVING or s.is_locked():
		sig += str(int(Game.minutes))
	if sig != _sig or ghost:
		_sig = sig
		queue_redraw()


## Short status: label + colour. "ОПЕРАЦИЯ · 12 мин" beats "НА ЗАДАНИИ".
func status() -> Array:
	var s := staff()
	var c := Game.get_case(s.case_uid)
	var d: DepartmentData = Game.db.departments.get(s.location)
	match s.state:
		StaffMember.State.WORKING:
			if c and c.status == PatientCase.Status.INBOUND:
				return ["ЖДЁТ СКОРУЮ", Kit.COLD]
			if c:
				return ["%s · %s" % [c.stage().get("label", "").to_upper(), Kit.mins(c.duration() - c.progress)], Kit.AMBER]
		StaffMember.State.MOVING:
			return ["→ " + (d.short_name.to_upper() if d else ""), Kit.COLD]
		StaffMember.State.ON_DUTY:
			return ["ДЕЖУРИТ: " + (d.short_name.to_upper() if d else ""), Color("8fb3d6")]
		StaffMember.State.AVAILABLE:
			return ["СВОБОДЕН" if not s.gender_female() else "СВОБОДНА", Kit.GREEN]
		StaffMember.State.RESTING:
			return ["ОТДЫХАЕТ", Kit.TEXT_DIM]
		StaffMember.State.EXHAUSTED:
			return ["БЕЗ СИЛ · " + Kit.mins(s.rest_until - Game.minutes), Kit.RED]
	return [s.state_label(), Kit.TEXT]


func _draw() -> void:
	if layout == "row":
		_draw_row()
	else:
		_draw_tall()


func _draw_tall() -> void:
	var s := staff()
	var sz := base_size()
	var lift := lifted * (10.0 if not ghost else 0.0)
	var k := 1.0 + lifted * 0.06
	var r := Rect2(Vector2(sz.x * (1.0 - k) * 0.5, -lift - sz.y * (k - 1.0)), sz * k)
	var selected := Game.selected_staff_id == staff_id and not ghost
	var locked := s.is_locked()
	# Shadow
	if selected or ghost:
		draw_style_box(Kit.box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 10), Rect2(r.position + Vector2(4, 10), r.size))
	draw_style_box(Kit.box(Color("0d131b"), Color(0, 0, 0, 0), 0, 8), r)
	# Portrait (cover)
	if _portrait:
		var tw := float(_portrait.get_width())
		var th := float(_portrait.get_height())
		var src_h := tw * r.size.y / r.size.x
		var src := Rect2(0, maxf(0.0, th * 0.08), tw, minf(th, src_h))
		if src_h > th:
			var src_w := th * r.size.x / r.size.y
			src = Rect2((tw - src_w) * 0.5, 0, src_w, th)
		var mod := Color.WHITE
		if locked:
			mod = Color(0.45, 0.42, 0.45)
		draw_texture_rect_region(_portrait, r.grow(-1), src, mod)
	var fade_h := r.size.y * 0.62
	draw_texture_rect(_fade, Rect2(r.position.x + 1, r.end.y - fade_h, r.size.x - 2, fade_h - 1), false)
	# Status pill
	var st := status()
	var small := Screen.is_phone()
	var fpill := Kit.font("display_bold")
	var pfs := 10 if small else 11
	var pt: String = st[0]
	var pw := minf(fpill.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x + 14, r.size.x - 10)
	var pill := Rect2(r.position + Vector2(5, 5), Vector2(pw, 17))
	draw_style_box(Kit.box(Color(0.02, 0.03, 0.05, 0.85), Color(st[1], 0.9), 1, 9), pill)
	draw_string(fpill, pill.position + Vector2(7, 12.5), pt, HORIZONTAL_ALIGNMENT_LEFT, pw - 10, pfs, st[1].lightened(0.15))
	# Name block
	var nfs := 17 if small else 20
	var y := r.end.y - (68.0 if small else 82.0)
	draw_string(Kit.font("display_bold"), Vector2(r.position.x + 8, y), s.data.surname.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, nfs, Kit.TEXT)
	y += 14.0 if small else 16.0
	draw_string(Kit.font("display_light"), Vector2(r.position.x + 8, y), "%s · %d" % [s.data.role_name, s.data.age], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 11 if small else 13, s.data.accent.lightened(0.25))
	y += 13.0 if small else 16.0
	var mfs := 10 if small else 12
	draw_multiline_string(Kit.font("serif_italic"), Vector2(r.position.x + 8, y), "«%s»" % s.data.motto, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 14, mfs, 2, Kit.PAPER_DIM)
	y += (mfs + 2.0) * 2.0 - 2.0
	_gauges(Rect2(r.position.x + 8, y, r.size.x - 16, 10))
	# Border / selection
	var bc := Color(1, 1, 1, 0.08)
	var bw := 1.0
	if selected or ghost:
		bc = s.data.accent.lightened(0.2)
		bw = 2.5
	if _flash > 0.0:
		bc = bc.lerp(Kit.GREEN, _flash)
		bw = 3.0
	var border := Kit.box(Color(0, 0, 0, 0), bc, int(bw), 8)
	border.draw_center = false
	draw_style_box(border, r)
	if dimmed > 0.0 and not ghost:
		draw_style_box(Kit.box(Color(0.0, 0.01, 0.03, 0.45 * dimmed), Color(0, 0, 0, 0), 0, 8), r)


func _gauges(r: Rect2) -> void:
	var half := (r.size.x - 6) * 0.5
	_gauge(Rect2(r.position, Vector2(half, r.size.y)), "fatigue", _fat)
	_gauge(Rect2(r.position + Vector2(half + 6, 0), Vector2(half, r.size.y)), "stress", _str)


func _gauge(r: Rect2, glyph: String, v: float) -> void:
	var col := Color("aab6c2")
	if v >= 80:
		col = Kit.RED
	elif v >= 55:
		col = Kit.AMBER
	var o := r.position + Vector2(0, 1)
	if glyph == "fatigue":   # lightning bolt
		draw_colored_polygon(PackedVector2Array([o + Vector2(4, 0), o + Vector2(0, 5), o + Vector2(3, 5), o + Vector2(2, 9), o + Vector2(7, 3), o + Vector2(4, 3), o + Vector2(6, 0)]), col)
	else:                    # warning triangle
		draw_colored_polygon(PackedVector2Array([o + Vector2(3.5, 0), o + Vector2(7, 8), o + Vector2(0, 8)]), col)
		draw_line(o + Vector2(3.5, 2.5), o + Vector2(3.5, 5.5), Color(0.05, 0.07, 0.1), 1.2)
	var bx := r.position.x + 10
	var bw := r.size.x - 10
	draw_rect(Rect2(bx, r.position.y + 4, bw, 3), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(bx, r.position.y + 4, bw * clampf(v / 100.0, 0, 1), 3), col)


func _draw_row() -> void:
	var s := staff()
	var sz := base_size()
	var selected := Game.selected_staff_id == staff_id and not ghost
	var off := Vector2(-8.0 * lifted, 0)
	var r := Rect2(off, sz)
	draw_style_box(Kit.box(Color("0f1620") if not selected else Color("172231"), Color(1, 1, 1, 0.06), 1, 8), r)
	if _portrait:
		var tw := float(_portrait.get_width())
		var src := Rect2(tw * 0.18, tw * 0.17, tw * 0.64, tw * 0.64)
		draw_texture_rect_region(_portrait, Rect2(r.position + Vector2(3, 3), Vector2(r.size.y - 6, r.size.y - 6)), src, Color(0.5, 0.5, 0.55) if s.is_locked() else Color.WHITE)
	var x := r.position.x + r.size.y + 4
	var w := r.size.x - r.size.y - 10
	draw_string(Kit.font("display_bold"), Vector2(x, r.position.y + 19), s.data.surname.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 16, Kit.TEXT)
	draw_string(Kit.font("display_light"), Vector2(x + 2 + Kit.font("display_bold").get_string_size(s.data.surname.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 4, r.position.y + 19), s.data.role_name, HORIZONTAL_ALIGNMENT_LEFT, w - 80, 11, s.data.accent.lightened(0.2))
	var st := status()
	draw_string(Kit.font("display_bold"), Vector2(x, r.position.y + 36), st[0], HORIZONTAL_ALIGNMENT_LEFT, w, 11, st[1])
	_gauges(Rect2(x, r.position.y + 44, w, 10))
	var bc := s.data.accent.lightened(0.2) if (selected or ghost) else Color(0, 0, 0, 0)
	if _flash > 0.0:
		bc = Kit.GREEN
	if bc.a > 0:
		var b := Kit.box(Color(0, 0, 0, 0), bc, 2, 8)
		b.draw_center = false
		draw_style_box(b, r)
	if dimmed > 0.0 and not ghost:
		draw_style_box(Kit.box(Color(0, 0.01, 0.03, 0.4 * dimmed), Color(0, 0, 0, 0), 0, 8), r)
