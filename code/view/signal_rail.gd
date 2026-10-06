class_name SignalRail
extends Control
## Where the night talks to you. Phone: one big signal at a time (most urgent first,
## swipe or tap the pager to see the next). Desktop: a short stack.
## Banners are also drop targets for staff cards.

signal open_event(ev: EventInstance)

var max_items := 1
var banner_h := 92.0
var map: MapView
var _banners: Dictionary = {}     # key -> SignalBanner
var _order: Array = []            # keys, by priority
var _page := 0
var _pager: Button
var _acc := 0.0
var _swipe_x := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pager = Button.new()
	_pager.flat = true
	_pager.focus_mode = Control.FOCUS_NONE
	_pager.add_theme_font_override("font", Kit.font("display_bold"))
	_pager.add_theme_font_size_override("font_size", 13)
	_pager.add_theme_color_override("font_color", Kit.TEXT)
	_pager.pressed.connect(next_page)
	add_child(_pager)
	Game.event_arrived.connect(func(ev): _sync(); _jump_to("e%d" % ev.uid))
	Game.event_resolved.connect(func(_e): _sync())
	Game.case_added.connect(func(_c): _sync())
	Game.case_removed.connect(func(_c): _sync())


func _key_items() -> Array:
	var items: Array = []
	for ev in Game.pending_events():
		items.append({"key": "e%d" % ev.uid, "kind": "event", "uid": ev.uid, "p": (0.0 if ev.data.urgent else 50.0) + ev.deadline - Game.minutes})
	for c in Game.active_cases():
		var p := 0.0
		match c.status:
			PatientCase.Status.WAITING:
				p = (100.0 if not c.open_slots().is_empty() else 300.0) + c.condition
			PatientCase.Status.INBOUND:
				if max_items <= 1:
					continue
				p = 500.0 + c.arrive_at
			PatientCase.Status.TREATING:
				if max_items <= 2:
					continue
				p = 800.0 + c.condition
		items.append({"key": "c%d" % c.uid, "kind": "case", "uid": c.uid, "p": p})
	items.sort_custom(func(a, b): return a.p < b.p)
	return items


func _sync() -> void:
	var items := _key_items()
	var keys := items.map(func(i): return i.key)
	for k in _banners.keys():
		if not keys.has(k):
			var b: SignalBanner = _banners[k]
			_banners.erase(k)
			var tw := b.create_tween()
			tw.tween_property(b, "modulate:a", 0.0, 0.2)
			tw.tween_callback(b.queue_free)
	for it in items:
		if not _banners.has(it.key):
			var b := SignalBanner.new()
			b.setup(it.kind, it.uid)
			b.tapped.connect(_on_tap)
			add_child(b)
			b.modulate.a = 0.0
			_banners[it.key] = b
			b.swiped.connect(func(_b): next_page())
			if it.kind == "case":
				Audio.play("beep", -12.0)
	_order = keys
	_layout(true)


func _jump_to(key: String) -> void:
	var i := _order.find(key)
	if i >= 0 and max_items <= 1:
		_page = i
		_layout(true)


func _process(delta: float) -> void:
	_acc += delta
	if _acc > 0.7:
		_acc = 0.0
		var keys := _key_items().map(func(i): return i.key)
		if keys != _order:
			_sync()


func _layout(animate := false) -> void:
	var visible_keys: Array = []
	if max_items <= 1:
		_page = clampi(_page, 0, maxi(0, _order.size() - 1))
		if not _order.is_empty():
			visible_keys = [_order[_page]]
	else:
		visible_keys = _order.slice(0, max_items)
	var y := 0.0
	for k in _banners:
		var b: SignalBanner = _banners[k]
		var show := visible_keys.has(k)
		b.compact = max_items <= 1 and size.x < 420
		if not show:
			b.visible = false
			continue
		var target := Vector2(0, y)
		b.size = Vector2(size.x, banner_h)
		if not b.visible or b.modulate.a < 0.5:
			b.visible = true
			b.position = target + Vector2(40, 0)
			var tw := b.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "position", target, 0.28)
			tw.tween_property(b, "modulate:a", 1.0, 0.2)
		else:
			b.position = target
		y += banner_h + 8.0
	_pager.visible = max_items <= 1 and _order.size() > 1
	if _pager.visible:
		_pager.text = "%d / %d  ›" % [_page + 1, _order.size()]
		_pager.size = Vector2(80, 30)
		_pager.position = Vector2(size.x - 80, -30)


func next_page() -> void:
	if _order.size() > 1:
		_page = (_page + 1) % _order.size()
		Audio.play("click", -10.0)
		_layout(true)


func _on_tap(b: SignalBanner) -> void:
	if b.kind == "event":
		open_event.emit(b.ev())
		return
	var c := b.pcase()
	if c == null:
		return
	if Game.selected_staff_id != "":
		var sid := Game.selected_staff_id
		var r := Game.assign(sid, {"case": c.uid})
		if r.ok:
			b.flash()
			map.assignment_feedback(sid, r, c.department())
			Game.select_staff("")
		else:
			Stamp.show(map, map.dept_screen(c.department()), "НЕЛЬЗЯ", r.text, Kit.RED)
		return
	Game.focus_request.emit(c.department())
	var e := Game.get_event(c.event_uid)
	if e:
		open_event.emit(e)


func _gui_input(_e: InputEvent) -> void:
	pass


# ---- drop target API (used by DragController)

func case_at(global: Vector2) -> int:
	for k in _banners:
		var b: SignalBanner = _banners[k]
		if b.visible and b.kind == "case" and b.alive() and b.get_global_rect().has_point(global):
			return b.uid
	return -1


func set_drop_hover(case_uid: int, pv: Dictionary) -> void:
	for k in _banners:
		var b: SignalBanner = _banners[k]
		b.drop_preview = pv if (b.kind == "case" and b.uid == case_uid) else {}


func case_global_center(case_uid: int) -> Vector2:
	var b: SignalBanner = _banners.get("c%d" % case_uid)
	return b.get_global_rect().get_center() if b else get_global_rect().get_center()


func flash_case(case_uid: int) -> void:
	var b: SignalBanner = _banners.get("c%d" % case_uid)
	if b:
		b.flash()


func content_height() -> float:
	var n := 1 if max_items <= 1 else mini(max_items, _order.size())
	return n * (banner_h + 8.0) if not _order.is_empty() else 0.0
