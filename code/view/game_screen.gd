extends Control
## Root of the game. A presentation layer only: composes map, HUD, signals and the roster
## around the existing Game API, and re-lays them out for phone portrait / phone landscape / desktop.
##
##  PORTRAIT          LANDSCAPE                 DESKTOP
##  ┌──────────┐      ┌──────────────┬────┐     ┌─────────────────────┬──────┐
##  │ HUD      │      │ HUD   signal │ ro │     │ HUD                 │sig-  │
##  │          │      │              │ st │     │        MAP          │nals  │
##  │   MAP    │      │     MAP      │ er │     │                     │      │
##  │ [signal] │      │              │    │     ├─────────────────────┴──────┤
##  │ roster   │      └──────────────┴────┘     │ roster                     │
##  └──────────┘                                └────────────────────────────┘

var map: MapView
var hud: Hud
var rail: SignalRail
var strip: StaffStrip
var strip_bg: Panel
var drag: DragController
var sheet: EventSheet
var ticker: Ticker
var menu: MenuSheet
var title: TitleScreen


func _ready() -> void:
	Game.new_shift()
	map = MapView.new()
	add_child(map)
	strip_bg = Panel.new()
	strip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip_bg)
	strip = StaffStrip.new()
	add_child(strip)
	rail = SignalRail.new()
	rail.map = map
	add_child(rail)
	hud = Hud.new()
	add_child(hud)
	ticker = Ticker.new()
	ticker.map = map
	add_child(ticker)
	drag = DragController.new()
	drag.map = map
	drag.rail = rail
	drag.strip = strip
	drag.blockers = [strip, hud]
	strip.drag = drag
	add_child(drag)
	sheet = EventSheet.new()
	add_child(sheet)
	menu = MenuSheet.new()
	add_child(menu)
	title = TitleScreen.new()
	add_child(title)

	rail.open_event.connect(sheet.open)
	Game.open_event_request.connect(sheet.open)
	hud.menu_pressed.connect(menu.open)
	map.target_clicked.connect(_on_map_target)
	title.start_pressed.connect(func(): Game.start())
	Game.shift_ended.connect(func(s): title.show_report(s))
	Screen.layout_changed.connect(_relayout)
	resized.connect(_relayout)
	_relayout()
	title.show_intro()
	# Debug FPS readout: open the web build with #fps, or run with -- --fps.
	var want_fps := "--fps" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		want_fps = want_fps or str(JavaScriptBridge.eval("location.hash", true)).contains("fps")
	if want_fps:
		_fps = Kit.label("", 13, Kit.GREEN, "mono_bold")
		_fps.z_index = 100
		add_child(_fps)
	if "--capture" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://code/debug/capture.gd"):
		var c: Node = load("res://code/debug/capture.gd").new()
		c.set("main", self)
		add_child(c)


func _relayout() -> void:
	var S := size
	var safe := Screen.safe
	if safe.size.x < 10:
		safe = Rect2(Vector2.ZERO, S)
	var ins_top := safe.position.y
	var ins_bottom := S.y - safe.end.y
	var ins_left := safe.position.x
	var ins_right := S.x - safe.end.x
	map.position = Vector2.ZERO
	map.size = S
	var sb := Kit.box(Color(0.025, 0.035, 0.05, 0.94), Color(1, 1, 1, 0.06), 0, 0)
	sb.border_width_top = 1
	strip_bg.add_theme_stylebox_override("panel", sb)
	match Screen.mode:
		Screen.Mode.PORTRAIT:
			var hud_h := 58.0
			hud.position = Vector2(0, ins_top)
			hud.size = Vector2(S.x, hud_h)
			hud.relayout(true)
			strip.set_vertical(false)
			var strip_h := 196.0
			strip.position = Vector2(ins_left, S.y - ins_bottom - strip_h)
			strip.size = Vector2(S.x - ins_left - ins_right, strip_h)
			strip_bg.position = Vector2(0, strip.position.y + 18)
			strip_bg.size = Vector2(S.x, S.y - strip_bg.position.y)
			rail.max_items = 1
			rail.banner_h = 92.0
			rail.position = Vector2(10 + ins_left, strip.position.y - rail.banner_h - 4)
			rail.size = Vector2(S.x - 20 - ins_left - ins_right, rail.banner_h)
			map.view_rect = Rect2(0, ins_top + hud_h, S.x, rail.position.y - ins_top - hud_h)
			_frame(0.62)
			ticker.position = Vector2(12, ins_top + hud_h + 4)
			ticker.size = Vector2(S.x - 24, 0)
			ticker.max_items = 1
		Screen.Mode.LANDSCAPE:
			var hud_h2 := 50.0
			var side := 236.0
			strip.set_vertical(true)
			strip.position = Vector2(S.x - ins_right - side, ins_top + 4)
			strip.size = Vector2(side, S.y - ins_top - ins_bottom - 4)
			strip_bg.position = Vector2(strip.position.x - 4, 0)
			strip_bg.size = Vector2(S.x - strip_bg.position.x, S.y)
			hud.position = Vector2(0, ins_top)
			hud.size = Vector2(strip_bg.position.x, hud_h2)
			hud.relayout(true)
			rail.max_items = 1
			rail.banner_h = 82.0
			rail.position = Vector2(ins_left + 10, S.y - ins_bottom - rail.banner_h - 10)
			rail.size = Vector2(minf(420.0, strip_bg.position.x - ins_left - 20), rail.banner_h)
			map.view_rect = Rect2(ins_left, ins_top + hud_h2, strip_bg.position.x - ins_left, rail.position.y - ins_top - hud_h2)
			_frame(0.55)
			ticker.position = Vector2(ins_left + 12, ins_top + hud_h2)
			ticker.size = Vector2(strip_bg.position.x - ins_left - 24, 0)
			ticker.max_items = 1
		_:
			var hud_h3 := 64.0
			hud.position = Vector2(0, ins_top)
			hud.size = Vector2(S.x, hud_h3)
			hud.relayout(false)
			strip.set_vertical(false)
			var strip_h2 := 250.0
			strip.position = Vector2(ins_left + 8, S.y - ins_bottom - strip_h2)
			strip.size = Vector2(S.x - 16, strip_h2)
			strip_bg.position = Vector2(0, strip.position.y + 22)
			strip_bg.size = Vector2(S.x, S.y - strip_bg.position.y)
			var col_w := 400.0
			rail.max_items = 5
			rail.banner_h = 100.0
			rail.position = Vector2(S.x - col_w - 16, ins_top + hud_h3 + 8)
			rail.size = Vector2(col_w, strip_bg.position.y - rail.position.y - 12)
			map.view_rect = Rect2(0, hud_h3, S.x - col_w - 24, strip_bg.position.y - hud_h3)
			_frame(1.0)
			ticker.position = Vector2(ins_left + 16, ins_top + hud_h3 + 6)
			ticker.size = Vector2(560, 0)
			ticker.max_items = 2
	for c in [drag, sheet, menu, title]:
		c.position = Vector2.ZERO
		c.size = S
	title.relayout()


var _framed_mode := -1


func _frame(z: float) -> void:
	if _framed_mode != Screen.mode:
		_framed_mode = Screen.mode
		map.frame_hospital(z)


func _on_map_target(t: Dictionary, _at: Vector2) -> void:
	if t.kind == "event":
		var ev := Game.get_event(t.id)
		if ev:
			sheet.open(ev)
	elif t.kind == "dept":
		# Tapping a department with someone waiting opens the event that brought them.
		for c in Game.cases_in(t.id):
			if c.status == PatientCase.Status.WAITING and not c.open_slots().is_empty():
				var ev2 := Game.get_event(c.event_uid)
				if ev2:
					sheet.open(ev2)
					return
		map.focus_dept(t.id)


var _fps: Label


func _process(_d: float) -> void:
	if _fps:
		_fps.text = "%d fps · %dx%d · dpr %.1f" % [Engine.get_frames_per_second(), get_viewport().get_visible_rect().size.x * Screen.dpr, get_viewport().get_visible_rect().size.y * Screen.dpr, Screen.dpr]
		_fps.position = Screen.safe.position + Vector2(8, 60)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				Game.toggle_pause()
			KEY_1, KEY_2, KEY_3:
				Game.set_speed(event.keycode - KEY_0)
			KEY_ESCAPE:
				if sheet.is_open():
					sheet.close()
				else:
					Game.select_staff("")
			_:
				return
		get_viewport().set_input_as_handled()
