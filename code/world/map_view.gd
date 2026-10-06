class_name MapView
extends Control
## The city map — the hero of the screen. Owns camera, picking, touch pan / pinch,
## department pins and "targeting" (a staff member is selected or being dragged:
## the map dims and departments light up green / yellow / red with a verdict).

signal target_clicked(target: Dictionary, screen_pos: Vector2)
signal background_clicked

const ZOOM_MIN := 0.38
const ZOOM_MAX := 2.2
const VERDICT_GOOD := Color("62c27a")
const VERDICT_WARN := Color("e0b043")
const VERDICT_BAD := Color("e0483f")
const VERDICT_REST := Color("9fb6cf")
const VERDICT_DUTY := Color("7f93a8")

var model := CityModel.new()
var world := Node2D.new()
var ground := CityGround.new()
var glow := CityGlow.new()
var actors := CityActors.new()
var dim_layer := DimLayer.new()
var buildings := CityBuildings.new()
var atmosphere := CityAtmosphere.new()
var markers := CityMarkers.new()
var rain: RainLayer
var pins_layer := Control.new()
var crisis_tint := ColorRect.new()

var zoom := 1.0
var center := Vector2.ZERO
var view_rect := Rect2()          # part of the map not covered by overlays (local coords)
var hover: Dictionary = {}
var selected: Dictionary = {}
var targeting_staff := ""
var drag_hover_dept := ""
var verdicts: Dictionary = {}      # dept id -> {color, label, preview}

var _pins: Dictionary = {}
var _building_target: Dictionary = {}
var _press := false
var _press_pos := Vector2.ZERO
var _press_center := Vector2.ZERO
var _panning := false
var _touches: Dictionary = {}
var _pinch_d0 := 0.0
var _pinch_z0 := 1.0
var _cam_tween: Tween
var _dim := 0.0
var _time := 0.0
var _dirty := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	model.load_from(Game.db.city_map)
	for n in [ground, glow, actors, dim_layer, buildings, atmosphere, markers]:
		if "model" in n:
			n.model = model
	glow.actors = actors
	markers.actors = actors
	markers.map = self
	add_child(world)
	for n in [ground, glow, actors, dim_layer, buildings, atmosphere, markers]:
		world.add_child(n)
	actors.setup(model)
	buildings.setup(model)
	rain = RainLayer.new()
	add_child(rain)
	rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vignette := TextureRect.new()
	vignette.texture = _vignette_texture()
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crisis_tint.color = Color(0.6, 0.04, 0.04, 0.0)
	crisis_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crisis_tint)
	crisis_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pins_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pins_layer)
	pins_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for d: DepartmentData in Game.db.departments.values():
		if d.building_id != "":
			_building_target[d.building_id] = {"kind": "dept", "id": d.id}
		if d.kind == "department" or d.kind == "rest" or d.id == "morgue":
			var pin := DeptPin.new()
			pin.setup(self, d)
			pins_layer.add_child(pin)
			_pins[d.id] = pin
	for p in model.pois:
		if p.has("building"):
			_building_target[p.building] = {"kind": "poi", "id": p.id}
	center = Iso.p(model.camera_start)
	zoom = model.camera_zoom
	Game.selection_changed.connect(func(sid): set_targeting(sid))
	Game.staff_changed.connect(func(_id): _dirty = true)
	Game.case_changed.connect(func(_c): _dirty = true)
	Game.focus_request.connect(focus_dept)


func _vignette_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.0, 0.01, 0.03, 0.85))
	g.add_point(0.5, Color(0, 0, 0, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.45)
	t.fill_to = Vector2(1.05, 1.0)
	t.width = 256
	t.height = 256
	return t


# ------------------------------------------------------------------ camera

func world_to_screen(w: Vector2) -> Vector2:
	return (w - center) * zoom + _view_center()


func screen_to_world(s: Vector2) -> Vector2:
	return (s - _view_center()) / zoom + center


func _view_center() -> Vector2:
	var vr := view_rect if view_rect.size.x > 10 else Rect2(Vector2.ZERO, size)
	return vr.get_center()


func frame_hospital(z: float) -> void:
	zoom = z
	center = Iso.p(model.camera_start)


func focus_dept(dept_id: String) -> void:
	var d: DepartmentData = Game.db.departments.get(dept_id)
	if d:
		focus_world(Iso.p(d.entrance) - Vector2(0, 20))


func focus_world(w: Vector2) -> void:
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(self, "center", w, 0.5)


func dept_screen(dept_id: String) -> Vector2:
	var d: DepartmentData = Game.db.departments[dept_id]
	var b: Dictionary = model.building_by_id.get(d.building_id, {})
	if b.is_empty():
		return world_to_screen(Iso.p(d.entrance))
	return world_to_screen(Iso.p(b.rect.get_center(), b.h * 0.55))


func _clamp_center() -> void:
	var b := model.world_bounds()
	center.x = clampf(center.x, b.position.x + 300, b.end.x - 300)
	center.y = clampf(center.y, b.position.y + 200, b.end.y - 200)


func _process(delta: float) -> void:
	_time += delta
	_clamp_center()
	world.position = _view_center() - center * zoom
	world.scale = Vector2(zoom, zoom)
	var target_dim := 0.62 if targeting_staff != "" else 0.0
	if Game.dragging_staff_id == "" and targeting_staff != "":
		target_dim = 0.42
	_dim = move_toward(_dim, target_dim, delta * 3.5)
	dim_layer.amount = _dim
	var keep := {}
	for dep_id in verdicts:
		var d: DepartmentData = Game.db.departments[dep_id]
		if d.building_id != "":
			keep[d.building_id] = true
	buildings.set_dim(_dim, keep)
	if _dirty:
		_dirty = false
		_refresh_verdicts()
	_update_highlights()
	var ta := 0.0
	if Game.alarm_level == 2:
		ta = 0.06 + 0.04 * sin(_time * 3.0)
	elif Game.alarm_level == 1:
		ta = 0.02
	crisis_tint.color.a = lerpf(crisis_tint.color.a, ta, delta * 3.0)
	for id in _pins:
		_pins[id].place()


# ------------------------------------------------------------------ targeting

func set_targeting(sid: String) -> void:
	targeting_staff = sid
	_refresh_verdicts()


func _refresh_verdicts() -> void:
	verdicts.clear()
	if targeting_staff == "":
		return
	var s: StaffMember = Game.staff[targeting_staff]
	for d: DepartmentData in Game.db.departments.values():
		if not d.accepts_staff:
			continue
		var pv := Game.preview(targeting_staff, {"dept": d.id})
		if not pv.ok and s.location == d.id:
			continue   # already there — not a choice, not a warning
		verdicts[d.id] = verdict_for(pv, d)


static func verdict_for(pv: Dictionary, d: DepartmentData) -> Dictionary:
	if not pv.get("ok", false):
		return {"color": VERDICT_BAD, "label": "НЕ РЕКОМЕНДУЕТСЯ", "preview": pv}
	match pv.kind:
		"case":
			if pv.fit == Assignment.Fit.GOOD and pv.warning == "":
				return {"color": VERDICT_GOOD, "label": "ПОДХОДИТ", "preview": pv}
			if pv.fit == Assignment.Fit.GOOD:
				return {"color": VERDICT_WARN, "label": "ПРЕРВЁТ ЗАДАЧУ", "preview": pv}
			return {"color": VERDICT_WARN, "label": "РИСК", "preview": pv}
		"rest":
			return {"color": VERDICT_REST, "label": "ОТДЫХ", "preview": pv}
	return {"color": VERDICT_DUTY, "label": "ДЕЖУРСТВО", "preview": pv}


func _update_highlights() -> void:
	var h := {}
	for dep_id in verdicts:
		var d: DepartmentData = Game.db.departments[dep_id]
		if d.building_id == "":
			continue
		var c: Color = verdicts[dep_id].color
		c.a = 1.0 if dep_id == drag_hover_dept else (0.35 if c == VERDICT_DUTY else 0.8)
		h[d.building_id] = c
	for t in [hover, selected]:
		if t.is_empty() or t.kind != "dept":
			continue
		var bid: String = Game.db.departments[t.id].building_id
		if bid != "" and not h.has(bid):
			h[bid] = Color(0.92, 0.95, 1.0, 0.85 if t == selected else 0.4)
	buildings.set_highlight(h)


# ------------------------------------------------------------------ picking

func target_at(local: Vector2) -> Dictionary:
	for id in _pins:
		if _pins[id].visible and _pins[id].hit_rect().grow(6).has_point(local):
			return {"kind": "dept", "id": id}
	var w := screen_to_world(local)
	for ev in Game.events:
		if ev.data.city_tile.x < 0:
			continue
		var head := Iso.p(ev.data.city_tile) - Vector2(0, 44)
		if head.distance_to(w) < 18.0 / zoom * 0.8 + 6.0 and (not ev.resolved or Game.minutes - ev.arrived_at < 25.0):
			return {"kind": "event", "id": ev.uid}
	for i in range(model.buildings.size() - 1, -1, -1):
		var b: Dictionary = model.buildings[i]
		if Geometry2D.is_point_in_polygon(w, b.silhouette):
			return _building_target.get(b.id, {})
	var tile := Iso.to_tile(w)
	if Rect2(18, 21, 4, 3).has_point(tile):
		return {"kind": "dept", "id": "parking"}
	if Rect2(0, 36, 44, 3).has_point(tile):
		return {"kind": "poi", "id": "highway"}
	return {}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			var pts: Array = _touches.values()
			_pinch_d0 = pts[0].distance_to(pts[1])
			_pinch_z0 = zoom
			_press = false
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2 and _pinch_d0 > 0.0:
			var pts: Array = _touches.values()
			var mid: Vector2 = (pts[0] + pts[1]) * 0.5
			var before := screen_to_world(mid)
			zoom = clampf(_pinch_z0 * pts[0].distance_to(pts[1]) / _pinch_d0, ZOOM_MIN, ZOOM_MAX)
			center += before - screen_to_world(mid)
		return
	if event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
		return
	if event is InputEventPanGesture:
		center += event.delta * 12.0 / zoom
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.12)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_press = true
				_panning = false
				_press_pos = mb.position
				_press_center = center
			else:
				if _press and not _panning and _touches.size() < 2:
					if mb.button_index == MOUSE_BUTTON_LEFT:
						_click(mb.position)
					else:
						Game.select_staff("")
						selected = {}
						background_clicked.emit()
				_press = false
				_panning = false
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _press and _touches.size() < 2:
			if not _panning and mm.position.distance_to(_press_pos) > 9.0:
				_panning = true
				if _cam_tween:
					_cam_tween.kill()
			if _panning:
				center = _press_center - (mm.position - _press_pos) / zoom
		elif not _press:
			hover = target_at(mm.position)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hover.is_empty() else Control.CURSOR_ARROW


func _click(pos: Vector2) -> void:
	var t := target_at(pos)
	if t.is_empty():
		selected = {}
		background_clicked.emit()
		return
	click_target(t, pos)


func click_target(t: Dictionary, pos: Vector2) -> void:
	if t.kind == "staff":
		Game.select_staff(t.id)
		return
	if t.kind == "dept" and targeting_staff != "":
		var d: DepartmentData = Game.db.departments[t.id]
		if d.accepts_staff:
			var sid := targeting_staff
			var r := Game.assign(sid, {"dept": t.id})
			assignment_feedback(sid, r, t.id)
			if r.ok:
				Game.select_staff("")
			return
	selected = t
	Audio.play("click", -10.0)
	target_clicked.emit(t, pos)


## Visual confirmation after any assignment attempt (tap or drop).
func assignment_feedback(sid: String, r: Dictionary, dept_id: String) -> void:
	var at := dept_screen(dept_id)
	if r.ok:
		var s: StaffMember = Game.staff[sid]
		var d: DepartmentData = Game.db.departments[dept_id]
		var verb := "ОТДЫХАЕТ" if r.kind == "rest" else ("НА ДЕЖУРСТВЕ" if r.kind == "duty" else ("НАЗНАЧЕНА" if s.gender_female() else "НАЗНАЧЕН"))
		var col := VERDICT_GOOD if r.fit == Assignment.Fit.GOOD and r.warning == "" else VERDICT_WARN
		if r.kind == "rest":
			col = VERDICT_REST
		Stamp.show(self, at, "%s %s" % [s.data.surname.to_upper(), verb], d.short_name.to_upper(), col)
		if _pins.has(dept_id):
			_pins[dept_id].bump()
	else:
		Stamp.show(self, at, "НЕЛЬЗЯ", r.get("text", ""), VERDICT_BAD)


func _zoom_at(screen: Vector2, factor: float) -> void:
	var before := screen_to_world(screen)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	center += before - screen_to_world(screen)


func pan_by(v: Vector2) -> void:
	center += v / zoom


func pin(dept_id: String) -> DeptPin:
	return _pins.get(dept_id)


# ------------------------------------------------------------------ inner: dim layer

class DimLayer extends Node2D:
	var amount := 0.0:
		set(v):
			if not is_equal_approx(v, amount):
				amount = v
				queue_redraw()

	func _draw() -> void:
		if amount <= 0.001:
			return
		draw_rect(Rect2(-6000, -3000, 12000, 8000), Color(0.01, 0.015, 0.03, amount * 0.75))
