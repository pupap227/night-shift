class_name SignalBanner
extends Control
## One big, glanceable signal: an incoming event that needs a decision, or a patient
## that needs a specific person. Custom-drawn; the whole banner is the tap target.

signal tapped(banner: SignalBanner)
signal swiped(banner: SignalBanner)

var _press_x := 0.0

var kind := "event"          # event | case
var uid := -1
var compact := false
var drop_preview: Dictionary = {}
var _time := 0.0
var _flash := 0.0
var _art: Texture2D


func setup(k: String, id: int) -> void:
	kind = k
	uid = id
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func ev() -> EventInstance:
	return Game.get_event(uid) if kind == "event" else null


func pcase() -> PatientCase:
	return Game.get_case(uid) if kind == "case" else null


func alive() -> bool:
	if kind == "event":
		var e := ev()
		return e != null and not e.resolved
	var c := pcase()
	return c != null and c.is_active()


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 1.6)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_x = event.position.x
		elif absf(event.position.x - _press_x) > 50.0:
			swiped.emit(self)
		else:
			tapped.emit(self)
		accept_event()


## [{label, count, icon}] for an event's patients (all stages) or a case's open slots.
func needs() -> Array:
	var counts := {}
	var order: Array = []
	if kind == "event":
		var e := ev()
		if e == null:
			return []
		for p in e.data.patients:
			var t: PatientTypeData = Game.db.patient_types.get(p.type)
			if t == null:
				continue
			for st in t.stages(p.get("variant", "")):
				for sl in st.get("slots", []):
					var l: String = sl.label
					if not counts.has(l):
						order.append(l)
					counts[l] = counts.get(l, 0) + 1
		if e.data.patients.size() == 1:
			for k in counts:
				counts[k] = 1
	else:
		var c := pcase()
		if c == null:
			return []
		for l in c.missing_labels():
			if not counts.has(l):
				order.append(l)
			counts[l] = counts.get(l, 0) + 1
	return order.map(func(l): return {"label": l, "count": counts[l], "icon": Kit.role_icon(l)})


func _draw() -> void:
	var w := size.x
	var h := size.y
	var accent := Kit.AMBER
	var icon_id := "phone"
	var caption := ""
	var title := ""
	var urgent := false
	var e := ev()
	var c := pcase()
	if e:
		urgent = e.data.urgent
		accent = Kit.RED if urgent else Kit.AMBER
		icon_id = e.data.icon
		caption = "%s · %s" % [EventSheet.CATEGORY.get(e.data.category, ""), Game.clock_string(e.arrived_at)]
		title = e.data.title
	elif c:
		icon_id = c.ptype.icon
		var n := needs()
		if c.status == PatientCase.Status.INBOUND:
			accent = Kit.COLD
			caption = "СКОРАЯ В ПУТИ · %s" % Kit.mins(c.arrive_at - Game.minutes)
		elif c.status == PatientCase.Status.TREATING:
			accent = Kit.GREEN
			caption = "%s · %s" % [c.stage().get("label", "").to_upper(), Kit.mins(c.duration() - c.progress)]
		elif not n.is_empty():
			accent = Kit.RED
			urgent = true
			caption = "НУЖЕН " + n[0].label.to_upper() + (" И ЕЩЁ %d" % (n.size() - 1) if n.size() > 1 else "")
		else:
			caption = c.blocked_reason.to_upper()
		title = c.label
	# Body
	var bg := Color(0.045, 0.06, 0.085, 0.95)
	var sb := Kit.box(bg, Color(accent, 0.55 if not urgent else 0.6 + 0.4 * sin(_time * 4.0)), 2 if urgent else 1, 10)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	draw_style_box(sb, Rect2(0, 0, w, h))
	if _flash > 0.0:
		draw_style_box(Kit.box(Color(Kit.GREEN, 0.25 * _flash), Color(0, 0, 0, 0), 0, 10), Rect2(0, 0, w, h))
	# Icon block
	var bw := h * 0.62 if not compact else h * 0.7
	var ib := Rect2(0, 0, bw, h)
	var ibox := Kit.box(accent.darkened(0.35) if urgent else Color(accent, 0.18), Color(0, 0, 0, 0), 0, 10)
	ibox.corner_radius_top_right = 0
	ibox.corner_radius_bottom_right = 0
	draw_style_box(ibox, ib)
	var ic := Assets.icon(icon_id)
	if ic:
		var isz := minf(bw * 0.55, 34.0)
		draw_texture_rect(ic, Rect2(ib.get_center() - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, Color.WHITE if urgent else accent.lightened(0.3))
	var x := bw + 12.0
	var right := 64.0
	var tw := w - x - right
	draw_string(Kit.font("display_bold"), Vector2(x, 21), caption, HORIZONTAL_ALIGNMENT_LEFT, tw, 12, accent.lightened(0.25))
	draw_string(Kit.font("display"), Vector2(x, 46 if not compact else 42), title, HORIZONTAL_ALIGNMENT_LEFT, tw, 22 if not compact else 18, Kit.TEXT)
	# Needs row: role chips with icons.
	var nx := x
	var ny := h - 20.0
	if c and c.ptype.is_patient and c.status != PatientCase.Status.INBOUND:
		var cc := Kit.cond_color(c.condition)
		var hic := Assets.icon("heart")
		if hic:
			draw_texture_rect(hic, Rect2(nx, ny - 7, 14, 14), false, cc)
		draw_rect(Rect2(nx + 18, ny - 2, 54, 4), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(nx + 18, ny - 2, 54 * clampf(c.condition / 100.0, 0, 1), 4), cc)
		draw_string(Kit.font("mono_bold"), Vector2(nx + 76, ny + 4), "%d%%" % int(c.condition), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cc)
		nx += 116
	if not (c and c.status == PatientCase.Status.TREATING):
		for n in needs():
			var label: String = ("%d× " % n.count if n.count > 1 else "") + n.label.to_lower()
			var f := Kit.font("display")
			var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			if nx + lw + 26 > w - right - 8:
				draw_string(f, Vector2(nx, ny + 4), "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Kit.TEXT_DIM)
				break
			draw_style_box(Kit.box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.1), 1, 9), Rect2(nx, ny - 9, lw + 24, 18))
			var ri := Assets.icon(n.icon)
			if ri:
				draw_texture_rect(ri, Rect2(nx + 4, ny - 6, 12, 12), false, Kit.TEXT_DIM)
			draw_string(f, Vector2(nx + 19, ny + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Kit.TEXT)
			nx += lw + 30
	# Right: countdown ring / drop verdict / chevron
	var rc := Vector2(w - right * 0.5, h * 0.42)
	if not drop_preview.is_empty():
		var ok: bool = drop_preview.get("ok", false)
		var col := Kit.GREEN if ok and drop_preview.fit == Assignment.Fit.GOOD else (Kit.AMBER if ok else Kit.RED)
		draw_style_box(Kit.box(Color(col, 0.16), col, 2, 10), Rect2(1, 1, w - 2, h - 2))
		draw_string(Kit.font("display_bold"), Vector2(w - right - 20, h - 14), "СЮДА" if ok else "НЕТ", HORIZONTAL_ALIGNMENT_RIGHT, right + 8, 14, col)
	if e:
		var left := maxf(0.0, e.deadline - Game.minutes)
		var k := clampf(left / maxf(1.0, e.data.decision_minutes), 0, 1)
		draw_arc(rc, 17, 0, TAU, 40, Color(1, 1, 1, 0.1), 3.0, true)
		draw_arc(rc, 17, -PI / 2, -PI / 2 + TAU * k, 40, accent if k > 0.3 else Kit.RED, 3.0, true)
		var t := str(int(ceil(left)))
		var fw := Kit.font("mono_bold").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(Kit.font("mono_bold"), rc + Vector2(-fw * 0.5, 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Kit.TEXT)
		if drop_preview.is_empty():
			draw_string(Kit.font("display_bold"), Vector2(w - right + 4, h - 13), "ОТКРЫТЬ", HORIZONTAL_ALIGNMENT_LEFT, right - 8, 11, accent.lightened(0.3))
	elif c and drop_preview.is_empty():
		var hint := "›"
		if Game.selected_staff_id != "" and c.is_active():
			hint = "СЮДА?"
		draw_string(Kit.font("display_bold"), Vector2(w - right + 4, h * 0.5 + 6), hint, HORIZONTAL_ALIGNMENT_CENTER, right - 10, 16 if hint == "›" else 12, Kit.TEXT_DIM)
