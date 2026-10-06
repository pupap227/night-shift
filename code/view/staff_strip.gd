class_name StaffStrip
extends Control
## The roster. Horizontal strip (portrait phone / desktop) or vertical list (phone landscape).
## One gesture recogniser for touch and mouse:
##   tap            -> select / deselect
##   swipe along    -> scroll the strip
##   hold ~0.25 s, or pull toward the map -> lift the card and drag it (DragController)

signal card_tapped(staff_id: String)

const HOLD_TIME := 0.24
const SLOP := 10.0

var vertical := false
var drag: DragController
var cards: Array[PersonCard] = []
var _scroll := 0.0
var _scroll_target := 0.0
var _press := false
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _press_card: PersonCard
var _mode := ""            # "", "scroll", "drag"
var _scroll0 := 0.0
var _vel := 0.0
var _last_pos := Vector2.ZERO
var _gap := 10.0
var _pad := 12.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for sid in Game.staff:
		var c := PersonCard.new()
		c.setup(sid, "row" if vertical else "tall")
		add_child(c)
		cards.append(c)
	resized.connect(_layout)
	_layout()


func set_vertical(v: bool) -> void:
	if v == vertical and not cards.is_empty():
		return
	vertical = v
	for c in cards:
		c.layout = "row" if v else "tall"
	_scroll = 0.0
	_scroll_target = 0.0
	_layout()


func content_length() -> float:
	if cards.is_empty():
		return 0.0
	var s := cards[0].base_size()
	var n := cards.size()
	return _pad * 2 + n * (s.y if vertical else s.x) + (n - 1) * _gap


func _max_scroll() -> float:
	var view := size.y if vertical else size.x
	return maxf(0.0, content_length() - view)


func _layout() -> void:
	if cards.is_empty():
		return
	var s := cards[0].base_size()
	_scroll = clampf(_scroll, 0.0, _max_scroll())
	for i in cards.size():
		var c := cards[i]
		c.size = s
		if vertical:
			c.position = Vector2((size.x - s.x) * 0.5, _pad + i * (s.y + _gap) - _scroll)
		else:
			var y := size.y - s.y - 8.0
			c.position = Vector2(_pad + i * (s.x + _gap) - _scroll, maxf(14.0, y))


func card_for(sid: String) -> PersonCard:
	for c in cards:
		if c.staff_id == sid:
			return c
	return null


func _card_at(p: Vector2) -> PersonCard:
	for c in cards:
		if Rect2(c.position, c.size).has_point(p):
			return c
	return null


func _process(delta: float) -> void:
	if _press and _mode == "" and _press_card and Time.get_ticks_msec() / 1000.0 - _press_time > HOLD_TIME:
		_start_drag(get_global_transform() * _last_pos)
	if not _press and _mode == "":
		if absf(_vel) > 1.0:
			_scroll_target += _vel * delta
			_vel = lerpf(_vel, 0.0, minf(1.0, delta * 5.0))
		_scroll_target = clampf(_scroll_target, 0.0, _max_scroll())
		_scroll = lerpf(_scroll, _scroll_target, minf(1.0, delta * 14.0))
	_layout()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] and mb.pressed:
			_scroll_target -= 80.0
		elif mb.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT] and mb.pressed:
			_scroll_target += 80.0
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = true
				_press_pos = mb.position
				_last_pos = mb.position
				_press_time = Time.get_ticks_msec() / 1000.0
				_press_card = _card_at(mb.position)
				_mode = ""
				_scroll0 = _scroll
				_vel = 0.0
			else:
				if _mode == "drag":
					drag.release(get_global_transform() * mb.position)
				elif _mode == "" and _press_card:
					_tap(_press_card)
				elif _mode == "" and _press_card == null:
					Game.select_staff("")
				_press = false
				_mode = ""
				_press_card = null
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			Game.select_staff("")
		accept_event()
	elif event is InputEventMouseMotion and _press:
		var mm := event as InputEventMouseMotion
		var d := mm.position - _press_pos
		var along := d.y if vertical else d.x
		var across := d.x if vertical else d.y
		if _mode == "":
			# Pulling the card toward the map (up in a strip, left in the side list) lifts it.
			if _press_card and ((not vertical and across < -SLOP and absf(across) > absf(along)) or (vertical and across < -SLOP and absf(across) > absf(along))):
				_start_drag(get_global_transform() * mm.position)
			elif absf(along) > SLOP:
				_mode = "scroll"
		if _mode == "scroll":
			var prev := _scroll
			_scroll = clampf(_scroll0 - along, -40.0, _max_scroll() + 40.0)
			_scroll_target = _scroll
			_vel = (_scroll - prev) / maxf(0.001, get_process_delta_time())
		elif _mode == "drag":
			drag.move(get_global_transform() * mm.position)
		_last_pos = mm.position
		accept_event()


func _tap(c: PersonCard) -> void:
	Game.select_staff(c.staff_id)
	card_tapped.emit(c.staff_id)


func _start_drag(p: Vector2) -> void:
	if _press_card == null:
		return
	var s := _press_card.staff()
	if s.is_locked():
		_mode = "scroll"
		Audio.play("error", -8.0)
		var tw := _press_card.create_tween()
		var x := _press_card.position.x
		for i in 4:
			tw.tween_property(_press_card, "position:x", x + (5 if i % 2 == 0 else -5), 0.04)
		return
	_mode = "drag"
	drag.begin(_press_card, p)
