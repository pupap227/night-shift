class_name DragController
extends Control
## Physical drag & drop of a person onto the map or onto an event card.
## lift (scale + shadow) -> map dims, valid targets glow -> forecast bubble follows the finger ->
## release: snap into the target and stamp, or fly back home.

var map: MapView
var rail: SignalRail
var strip: StaffStrip
var ghost: PersonCard
var _sid := ""
var _origin := Rect2()
var _pos := Vector2.ZERO
var _bubble: PanelContainer
var _b_title: Label
var _b_detail: Label
var _b_warn: Label
var _b_style: StyleBoxFlat
var _target: Dictionary = {}
var _finger := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = PanelContainer.new()
	_b_style = Kit.box(Color(0.03, 0.04, 0.06, 0.96), Kit.GREEN, 2, 8, 10)
	_bubble.add_theme_stylebox_override("panel", _b_style)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	_bubble.add_child(vb)
	_b_title = Kit.label("", 18, Kit.TEXT, "display_bold")
	_b_detail = Kit.label("", 13, Kit.TEXT_DIM, "display_light")
	_b_warn = Kit.label("", 13, Kit.AMBER, "display")
	for l in [_b_title, _b_detail, _b_warn]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
	_bubble.visible = false
	add_child(_bubble)


func active() -> bool:
	return _sid != ""


func begin(card: PersonCard, at: Vector2) -> void:
	_sid = card.staff_id
	_origin = Rect2(card.global_position, card.size)
	Game.select_staff(_sid)
	Game.set_dragging(_sid)
	ghost = PersonCard.new()
	ghost.ghost = true
	ghost.setup(_sid, card.layout)
	ghost.size = card.base_size()
	ghost.pivot_offset = ghost.size * 0.5
	add_child(ghost)
	move_child(ghost, 0)
	ghost.global_position = _origin.position
	var tw := ghost.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(1.12, 1.12), 0.16)
	tw.tween_property(ghost, "rotation", deg_to_rad(-4.0), 0.16)
	Audio.play("pickup", -2.0)
	Input.vibrate_handheld(15)
	move(at)


func move(at: Vector2) -> void:
	if not active():
		return
	_finger = at
	# Keep the card above the finger so the target stays visible.
	var lift := Vector2(0, -ghost.size.y * 0.75 - (30.0 if Screen.touch or Screen.is_phone() else 0.0))
	var p := at + lift - ghost.size * 0.5
	ghost.global_position = ghost.global_position.lerp(p, 0.55) if ghost.global_position.distance_to(p) > 2 else p
	_update_target(at)


func _update_target(at: Vector2) -> void:
	_target = {}
	var pv := {}
	map.drag_hover_dept = ""
	var case_uid := rail.case_at(at) if rail else -1
	if case_uid >= 0:
		_target = {"case": case_uid}
		pv = Game.preview(_sid, _target)
		rail.set_drop_hover(case_uid, pv)
	else:
		if rail:
			rail.set_drop_hover(-1, {})
		var local := map.get_global_transform().affine_inverse() * at
		if Rect2(Vector2.ZERO, map.size).has_point(local) and not _over_ui(at):
			var t := map.target_at(local)
			if t.get("kind", "") == "dept":
				_target = {"dept": t.id}
				pv = Game.preview(_sid, _target)
				map.drag_hover_dept = t.id
	if _target.is_empty():
		_bubble.visible = false
		return
	var verdict := MapView.verdict_for(pv, Game.db.departments.get(pv.get("dept", ""), null)) if not pv.is_empty() else {}
	_show_bubble(pv, verdict)


## Card strip / rail / HUD sit on top of the map: dropping there must not hit buildings below.
var blockers: Array[Control] = []


func _over_ui(at: Vector2) -> bool:
	for b in blockers:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(at):
			return true
	return false


func _show_bubble(pv: Dictionary, verdict: Dictionary) -> void:
	_bubble.visible = true
	var col: Color = verdict.get("color", Kit.RED)
	_b_style.border_color = col
	if pv.get("ok", false) and pv.get("kind", "") == "case":
		_b_title.text = verdict.get("label", "") + "  ·  " + pv.text
	elif pv.get("ok", false):
		_b_title.text = pv.text
	else:
		_b_title.text = verdict.get("label", "")
	_b_title.add_theme_color_override("font_color", col.lightened(0.25))
	_b_detail.text = pv.get("detail", "") if pv.get("ok", false) else pv.get("text", "")
	_b_warn.text = pv.get("warning", "")
	_b_warn.visible = _b_warn.text != ""
	_b_warn.add_theme_color_override("font_color", Kit.RED.lightened(0.2) if _b_warn.text.begins_with("ПРЕРВ") else Kit.AMBER)
	var w := minf(330.0, size.x - 24.0)
	_bubble.custom_minimum_size = Vector2(w, 0)
	_bubble.reset_size()
	var p := ghost.global_position + Vector2(ghost.size.x * 0.5 - w * 0.5, -_bubble.size.y - 14)
	if p.y < 8:
		p.y = ghost.global_position.y + ghost.size.y * 1.12 + 10
	p.x = clampf(p.x, 8, size.x - w - 8)
	_bubble.global_position = p


func release(at: Vector2) -> void:
	if not active():
		return
	_update_target(at)
	var sid := _sid
	var target := _target
	_bubble.visible = false
	if rail:
		rail.set_drop_hover(-1, {})
	map.drag_hover_dept = ""
	var g := ghost
	ghost = null
	_sid = ""
	Game.set_dragging("")
	if target.is_empty():
		_fly_back(g)
		return
	var r := Game.assign(sid, target)
	if not r.ok:
		_fly_back(g)
		Stamp.show(map, map.get_global_transform().affine_inverse() * at, "НЕЛЬЗЯ", r.text, Kit.RED)
		return
	# Snap into the target and shrink away.
	var dest := at
	if target.has("dept"):
		dest = map.get_global_transform() * map.dept_screen(target.dept)
		map.assignment_feedback(sid, r, target.dept)
	else:
		dest = rail.case_global_center(target.case)
		rail.flash_case(target.case)
		var s: StaffMember = Game.staff[sid]
		Stamp.show(map, map.get_global_transform().affine_inverse() * dest, "%s %s" % [s.data.surname.to_upper(), "НАЗНАЧЕНА" if s.gender_female() else "НАЗНАЧЕН"], r.text, Kit.GREEN if r.fit == Assignment.Fit.GOOD else Kit.AMBER)
	Audio.play("drop", -4.0)
	Input.vibrate_handheld(25)
	var tw := g.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(g, "global_position", dest - g.size * 0.5, 0.22)
	tw.tween_property(g, "scale", Vector2(0.15, 0.15), 0.22)
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(g.queue_free)
	var card := strip.card_for(sid) if strip else null
	if card:
		card.flash()
	Game.select_staff("")


func _fly_back(g: PersonCard) -> void:
	Audio.play("error", -10.0)
	var tw := g.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "global_position", _origin.position, 0.25)
	tw.tween_property(g, "scale", Vector2.ONE, 0.25)
	tw.tween_property(g, "rotation", 0.0, 0.25)
	tw.chain().tween_callback(g.queue_free)
