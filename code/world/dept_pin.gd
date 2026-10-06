class_name DeptPin
extends Control
## A department marker floating over its building: round enamel badge with an icon,
## a name plate, a red "help needed" alarm, progress of the current treatment,
## staff present as dots, and — while targeting — a big verdict (ПОДХОДИТ / РИСК / НЕ РЕКОМЕНДУЕТСЯ).

const R := 17.0

var map: MapView
var dept: DepartmentData
var _icon: Texture2D
var _time := 0.0
var _bump := 0.0


func setup(m: MapView, d: DepartmentData) -> void:
	map = m
	dept = d
	_icon = Assets.icon(d.icon)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(220, 80)


func bump() -> void:
	_bump = 1.0


func _anchor_world() -> Vector2:
	return map.pin_world(dept)


func _anchor_world_legacy() -> Vector2:
	var b: Dictionary = map.model.building_by_id.get(dept.building_id, {})
	if b.is_empty():
		return Iso.p(dept.entrance) - Vector2(0, 30)
	return Iso.p(b.rect.get_center(), b.h) - Vector2(0, 16)


## Badge centre in map-local coords.
func badge_center() -> Vector2:
	return map.world_to_screen(_anchor_world())


func place() -> void:
	var c := badge_center()
	position = (c - Vector2(size.x * 0.5, R)).round()
	visible = Rect2(Vector2(-100, -100), map.size + Vector2(200, 200)).has_point(c)
	queue_redraw()


func hit_rect() -> Rect2:
	var c := badge_center()
	var w := 40.0
	if _plate_visible():
		w = 150.0
	return Rect2(c - Vector2(w * 0.5, R + 4), Vector2(w, R * 2 + (26 if _plate_visible() else 8)))


func _process(delta: float) -> void:
	_time += delta
	_bump = maxf(0.0, _bump - delta * 2.5)


func _needs() -> PackedStringArray:
	var need := PackedStringArray()
	for c in Game.cases_in(dept.id):
		if c.status == PatientCase.Status.WAITING:
			for m in c.missing_labels():
				if not need.has(m.to_upper()):
					need.append(m.to_upper())
	return need


func _plate_visible() -> bool:
	if map.verdicts.has(dept.id):
		return true
	if not _needs().is_empty():
		return true
	if map.selected.get("id", "") == dept.id or map.hover.get("id", "") == dept.id:
		return true
	return not Screen.is_phone() or map.zoom > 0.95


func _draw() -> void:
	var c := Vector2(size.x * 0.5, R)
	var need := _needs()
	var verdict: Dictionary = map.verdicts.get(dept.id, {})
	var ring := Color(0.85, 0.9, 0.95, 0.75)
	var fill := Color(0.04, 0.06, 0.09, 0.92)
	var icol := Kit.TEXT
	if dept.id == "morgue":
		ring = Color(0.5, 0.55, 0.6, 0.6)
		icol = Kit.TEXT_DIM
	if not need.is_empty():
		ring = Kit.RED
		var pr := R + 6.0 + 8.0 * fmod(_time * 1.2, 1.0)
		draw_arc(c, pr, 0, TAU, 32, Color(Kit.RED, 0.8 * (1.0 - fmod(_time * 1.2, 1.0))), 2.0, true)
	if not verdict.is_empty():
		ring = verdict.color
		if map.drag_hover_dept == dept.id:
			draw_circle(c, R + 9.0, Color(ring, 0.25))
	var s := 1.0 + 0.25 * _bump
	if map.targeting_staff != "" and verdict.is_empty() and dept.accepts_staff == false:
		modulate.a = 0.35
	else:
		modulate.a = 1.0
	draw_circle(c, R * s, fill)
	draw_arc(c, R * s, 0, TAU, 40, ring, 2.5, true)
	# Treatment progress arc.
	var treating := Game.case_in_treatment(dept.id)
	if treating:
		var k := clampf(treating.progress / treating.duration(), 0, 1)
		draw_arc(c, R * s + 4.0, -PI / 2, -PI / 2 + TAU * k, 40, Kit.GREEN, 3.0, true)
	if _icon:
		var isz := 18.0 * s
		draw_texture_rect(_icon, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, ring if not need.is_empty() else icol)
	if not need.is_empty():
		draw_circle(c + Vector2(R * 0.75, -R * 0.75), 7.0, Kit.RED)
		draw_string(Kit.font("display_bold"), c + Vector2(R * 0.75 - 2.5, -R * 0.75 + 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# Staff dots.
	var present := Game.staff_at(dept.id).filter(func(st): return st.state != StaffMember.State.MOVING)
	for i in present.size():
		var dx := (i - (present.size() - 1) * 0.5) * 7.0
		draw_circle(c + Vector2(dx, R + 6.0), 2.6, present[i].data.accent)
	if not _plate_visible():
		return
	var title := dept.short_name.to_upper()
	var sub := ""
	var sub_col := Kit.TEXT_DIM
	if not verdict.is_empty():
		sub = verdict.label
		sub_col = verdict.color
	elif not need.is_empty():
		sub = "НУЖЕН " + need[0] + (" +%d" % (need.size() - 1) if need.size() > 1 else "")
		sub_col = Kit.RED.lightened(0.2)
	elif treating:
		sub = treating.stage().get("label", "").to_upper()
		sub_col = Kit.GREEN
	var ft := Kit.font("display")
	var fs := 13
	var tw := ft.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sw := Kit.font("display_bold").get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x if sub != "" else 0.0
	var w := maxf(tw, sw) + 16.0
	var py := c.y + R + 11.0
	var rect := Rect2(c.x - w * 0.5, py, w, 18.0 + (15.0 if sub != "" else 0.0))
	draw_style_box(Kit.box(Color(0.03, 0.045, 0.07, 0.88), Color(ring, 0.5), 1, 4), rect)
	draw_string(ft, Vector2(c.x - tw * 0.5, py + 14), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Kit.TEXT)
	if sub != "":
		draw_string(Kit.font("display_bold"), Vector2(c.x - sw * 0.5, py + 29), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sub_col)
