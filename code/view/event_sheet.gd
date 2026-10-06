class_name EventSheet
extends Control
## An opened event: illustration, story, who is needed (with faces of who could go),
## and the decision as big buttons with their consequences. After the decision it becomes
## a dispatch card: tap a face to send that person. Time is held while it is open.
## Phone portrait: bottom sheet. Landscape / desktop: centred card.

const CATEGORY := {
	"ambulance": "СКОРАЯ ПОМОЩЬ", "mass": "МАССОВОЕ ПОСТУПЛЕНИЕ", "staff": "ПЕРСОНАЛ",
	"lab": "ЛАБОРАТОРИЯ", "security": "ОХРАНА", "admin": "ЗВОНОК СВЕРХУ", "city": "ГОРОД",
}

var _ev: EventInstance
var _open := false
var _dim: ColorRect
var _panel: PanelContainer
var _scroll: ScrollContainer
var _vb: VBoxContainer
var _art: EventArt
var _close: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.01, 0.03, 0.7)
	_dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(_dim)
	_panel = PanelContainer.new()
	var sb := Kit.box(Color("0b1119"), Color(1, 1, 1, 0.08), 1, 16)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 30
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_vb = VBoxContainer.new()
	_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vb.add_theme_constant_override("separation", 0)
	_scroll.add_child(_vb)
	_close = Button.new()
	_close.icon = Assets.icon("close")
	_close.expand_icon = true
	_close.flat = true
	_close.custom_minimum_size = Vector2(44, 44)
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(close)
	add_child(_close)
	Game.event_resolved.connect(func(e): if _open and e == _ev: _rebuild())


func is_open() -> bool:
	return _open


func open(ev: EventInstance) -> void:
	if ev == null:
		return
	_ev = ev
	if not _open:
		_open = true
		Game.hold_time(true)
	visible = true
	_rebuild()
	_layout()
	var target := _panel.position
	_panel.position.y += 80
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "position", target, 0.28)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)
	Audio.play("click", -6.0)


func close() -> void:
	if not _open:
		return
	_open = false
	Game.hold_time(false)
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func(): visible = false)


func _process(_d: float) -> void:
	if _open:
		_layout()


func _layout() -> void:
	_dim.size = size
	var safe := Screen.safe
	var w := minf(size.x, 620.0)
	if Screen.mode == Screen.Mode.PORTRAIT:
		w = size.x
		var h := minf(size.y - safe.position.y - 24.0, _vb.get_combined_minimum_size().y + (size.y - safe.end.y) + 8)
		_panel.size = Vector2(w, h)
		_panel.position = Vector2(0, size.y - h + 12)
		_vb.add_theme_constant_override("separation", 0)
	else:
		var maxh := safe.size.y - 24.0
		var h2 := minf(maxh, _vb.get_combined_minimum_size().y + 4)
		_panel.size = Vector2(w, h2)
		_panel.position = Vector2(safe.get_center().x - w * 0.5, safe.get_center().y - h2 * 0.5)
	_scroll.custom_minimum_size = _panel.size
	_close.position = _panel.position + Vector2(_panel.size.x - 52, 8)


func _pad(c: Control, h := 18.0, v := 0.0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(h))
	m.add_theme_constant_override("margin_right", int(h))
	m.add_theme_constant_override("margin_top", int(v))
	m.add_theme_constant_override("margin_bottom", int(v))
	m.add_child(c)
	return m


func _rebuild() -> void:
	for c in _vb.get_children():
		_vb.remove_child(c)
		c.queue_free()
	var e := _ev.data
	var accent := Kit.RED if e.urgent else Kit.AMBER
	# Illustration header with caption + timer.
	var land := Screen.mode == Screen.Mode.LANDSCAPE
	var art_h := 96.0 if land else 190.0
	_art = EventArt.new()
	_art.setup(_ev)
	_art.custom_minimum_size = Vector2(0, art_h)
	_vb.add_child(_art)
	var cap := HBoxContainer.new()
	cap.add_theme_constant_override("separation", 8)
	var ib := PanelContainer.new()
	ib.add_theme_stylebox_override("panel", Kit.box(accent, Color(0, 0, 0, 0), 0, 6, 5))
	ib.add_child(Kit.icon(e.icon, 18, Color.WHITE))
	cap.add_child(ib)
	var ct := Kit.label("%s · %s" % [CATEGORY.get(e.category, ""), Game.clock_string(_ev.arrived_at)], 14, accent.lightened(0.3), "display_bold")
	ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.add_child(ct)
	if not _ev.resolved:
		cap.add_child(Kit.label("решить за " + Kit.mins(_ev.deadline - Game.minutes), 14, Kit.TEXT_DIM, "display"))
	_vb.add_child(_pad(cap, 18, 0))
	var title := Kit.label(e.title, 24 if land else 30, Kit.TEXT, "display_bold")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vb.add_child(_pad(title, 18, 4))
	var body := Kit.label(_ev.body_text, 14 if land else 16, Color("ddd5c2"), "serif")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("line_spacing", 3)
	_vb.add_child(_pad(body, 18, 6))
	# What is needed, with faces of people who could go.
	var needs := _needs()
	if not needs.is_empty():
		_vb.add_child(_pad(Kit.label("НУЖНЫ", 13, Kit.TEXT_DIM, "display_bold"), 18, 6))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for n in needs:
			flow.add_child(_need_chip(n))
		_vb.add_child(_pad(flow, 18, 2))
	if not _ev.resolved:
		var choices: BoxContainer = HBoxContainer.new() if land else VBoxContainer.new()
		choices.add_theme_constant_override("separation", 10)
		for i in e.choices.size():
			var ch: Dictionary = e.choices[i]
			var b := Kit.big_button(ch.label.to_upper(), "emergency" if i == 0 and e.urgent else ("paper" if i == 0 else "ghost"), 15 if land else 18)
			b.clip_text = true
			var cid: String = ch.id
			b.pressed.connect(func():
				Audio.play("confirm", -4.0)
				Game.resolve_event(_ev, cid))
			var v := VBoxContainer.new()
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_theme_constant_override("separation", 2)
			v.add_child(b)
			var hint := Kit.label(ch.get("hint", ""), 13, Kit.TEXT_DIM, "display_light")
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(hint)
			choices.add_child(v)
		_vb.add_child(_pad(choices, 18, 14))
	else:
		var cases := _ev.case_uids.map(func(u): return Game.get_case(u)).filter(func(c): return c != null)
		if cases.is_empty():
			_vb.add_child(_pad(Kit.label("Решение: «%s»." % _ev.choice(_ev.choice_id).get("label", ""), 15, Kit.TEXT_DIM, "serif_italic"), 18, 12))
		for c in cases:
			_dispatch_section(c)
	var back := Kit.big_button("НАЗАД К КАРТЕ", "ghost", 15)
	back.pressed.connect(close)
	_vb.add_child(_pad(back, 18, 8))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, maxf(12.0, size.y - Screen.safe.end.y + 8))
	_vb.add_child(spacer)


func _needs() -> Array:
	var counts := {}
	var order: Array = []
	var slots_by_label := {}
	for p in _ev.data.patients:
		var t: PatientTypeData = Game.db.patient_types.get(p.type)
		if t == null:
			continue
		for st in t.stages(p.get("variant", "")):
			for sl in st.get("slots", []):
				if not counts.has(sl.label):
					order.append(sl.label)
					slots_by_label[sl.label] = sl
				counts[sl.label] = counts.get(sl.label, 0) + 1
	return order.map(func(l): return {"label": l, "count": counts[l] if _ev.data.patients.size() > 1 else 1, "slot": slots_by_label[l]})


func _need_chip(n: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.12), 1, 20, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(Kit.icon(Kit.role_icon(n.label), 18, Kit.TEXT))
	h.add_child(Kit.label(("%d× " % n.count if n.count > 1 else "") + n.label.to_upper(), 14, Kit.TEXT, "display"))
	# Faces of free people who fit this role.
	var shown := 0
	for s: StaffMember in Game.staff.values():
		if shown >= 3:
			break
		if Assignment.slot_fit(s, n.slot) == Assignment.Fit.GOOD and s.is_free():
			h.add_child(_face(s, 26, Kit.GREEN))
			shown += 1
	if shown == 0:
		h.add_child(Kit.label("никого", 13, Kit.RED.lightened(0.2), "display_light"))
	return p


func _face(s: StaffMember, sz: float, ring: Color) -> Control:
	var f := FaceDot.new()
	f.setup(s, sz, ring)
	return f


func _dispatch_section(c: PatientCase) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(Kit.icon(c.ptype.icon, 18, Kit.cond_color(c.condition)))
	var l := Kit.label(c.label, 18, Kit.TEXT, "display")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(l)
	head.add_child(Kit.label("%d%%" % int(c.condition), 16, Kit.cond_color(c.condition), "mono_bold"))
	_vb.add_child(_pad(head, 18, 10))
	if not c.is_active():
		return
	var d: DepartmentData = Game.db.departments[c.department()]
	var miss := c.missing_labels()
	var line := "%s · %s" % [d.short_name, c.stage().get("label", "").to_lower()]
	if not miss.is_empty():
		line += " · нужен: " + ", ".join(miss).to_lower()
	_vb.add_child(_pad(Kit.label(line, 14, Kit.RED.lightened(0.25) if not miss.is_empty() else Kit.TEXT_DIM, "display_light"), 18, 0))
	if miss.is_empty():
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	var rows: Array = []
	for s: StaffMember in Game.staff.values():
		var pv := Game.preview(s.id, {"case": c.uid})
		if pv.ok:
			rows.append({"s": s, "pv": pv})
	rows.sort_custom(func(a, b): return a.pv.fit > b.pv.fit or (a.pv.fit == b.pv.fit and a.s.is_free() and not b.s.is_free()))
	for r in rows.slice(0, 6):
		var col := Kit.GREEN if r.pv.fit == Assignment.Fit.GOOD and r.pv.warning == "" else Kit.AMBER
		var btn := DispatchFace.new()
		btn.setup(r.s, r.pv, col)
		var uid := c.uid
		var sid: String = r.s.id
		btn.pressed.connect(func():
			var res := Game.assign(sid, {"case": uid})
			if res.ok:
				Audio.play("assign")
				_rebuild())
		flow.add_child(btn)
	_vb.add_child(_pad(flow, 18, 8))


# ------------------------------------------------------------------ small widgets

class FaceDot extends Control:
	var _tex: Texture2D
	var _ring: Color

	func setup(s: StaffMember, sz: float, ring: Color) -> void:
		_tex = Assets.portrait(s.data.portrait_id)
		_ring = ring
		custom_minimum_size = Vector2(sz, sz)
		tooltip_text = s.data.surname
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var r := size.x * 0.5
		draw_circle(Vector2(r, r), r, Color("10161e"))
		if _tex:
			var tw := float(_tex.get_width())
			draw_texture_rect_region(_tex, Rect2(2, 2, size.x - 4, size.y - 4), Rect2(tw * 0.24, tw * 0.22, tw * 0.52, tw * 0.52))
		draw_arc(Vector2(r, r), r - 1, 0, TAU, 32, _ring, 2.0, true)


class DispatchFace extends Button:
	var _s: StaffMember
	var _pv: Dictionary
	var _col: Color
	var _tex: Texture2D

	func setup(s: StaffMember, pv: Dictionary, col: Color) -> void:
		_s = s
		_pv = pv
		_col = col
		_tex = Assets.portrait(s.data.portrait_id)
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(78, 104)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = pv.get("warning", "") if pv.get("warning", "") != "" else pv.get("detail", "")

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 32)
		draw_circle(c, 30, Color("10161e"))
		if _tex:
			var tw := float(_tex.get_width())
			draw_texture_rect_region(_tex, Rect2(c - Vector2(28, 28), Vector2(56, 56)), Rect2(tw * 0.22, tw * 0.2, tw * 0.56, tw * 0.56))
		draw_arc(c, 29, 0, TAU, 40, _col, 3.0, true)
		var f := Kit.font("display_bold")
		var n := _s.data.surname.to_upper()
		draw_string(f, Vector2(0, 80), n, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Kit.TEXT)
		var tag := "ПОДХОДИТ" if _col == Kit.GREEN else ("ПРЕРВЁТ" if _pv.get("warning", "").begins_with("ПРЕРВ") else "РИСК")
		if not _s.is_free() and tag == "ПОДХОДИТ":
			tag = "ЗАНЯТ"
		draw_string(Kit.font("display"), Vector2(0, 96), tag, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, _col)
