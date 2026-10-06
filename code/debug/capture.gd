extends Node
## Scripted playthrough with REAL pointer events routed through the GUI (tap, hold-drag, release).
##   godot --path . -- --capture [--dpr=3] [--safe=t,r,b,l] [--tag=name]
## Screenshots go to user://shots/<tag>_*.png

const OUT := "user://shots/"

var main: Control
var fails: Array[String] = []
var tag := "shot"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	DirAccess.make_dir_recursive_absolute(OUT)
	await wait(1.0)
	await shot("0_intro")
	await tap_control(_find_button(main.title, "НАЧАТЬ СМЕНУ"))
	await wait(0.6)
	Game.paused = true
	await advance(1)
	await wait(0.8)
	await shot("1_map")
	# First event arrives -> big signal.
	await advance(6)
	await wait(0.6)
	await shot("2_signal")
	check(Game.pending_events().size() == 1, "event pending")
	# Tap the signal -> event sheet.
	await tap_global(main.rail.get_global_rect().position + Vector2(main.rail.size.x * 0.5, main.rail.banner_h * 0.5))
	await wait(0.5)
	await shot("3_sheet")
	check(main.sheet.is_open(), "sheet opens from signal")
	await tap_control(_find_button(main.sheet, "ПРИНЯТЬ"))
	await wait(0.4)
	main.sheet.close()
	await wait(0.3)
	await advance(3)
	# Tap a card -> targeting on the map.
	var volkov: PersonCard = main.strip.card_for("doctor_volkov")
	await tap_global(volkov.get_global_rect().get_center())
	await wait(0.5)
	await shot("4_selected")
	check(Game.selected_staff_id == "doctor_volkov", "tap selects card")
	Game.select_staff("")
	await wait(0.3)
	# Hold & drag Volkov onto admissions.
	var er := _dept_global("er")
	await drag_card("doctor_volkov", er, "5_dragging")
	await wait(0.25)
	await shot("6_assigned")
	check(Game.staff["doctor_volkov"].location == "er", "drag assigns Volkov to admissions")
	await drag_card("nurse_smirnova", _dept_global("er"), "")
	await advance(18)
	await wait(0.5)
	await shot("7_need_or")
	for sid in ["doctor_volkov", "doctor_gusev", "nurse_smirnova"]:
		await drag_card(sid, _dept_global("or1"), "")
		await wait(0.1)
	check(Game.staff["doctor_gusev"].location == "or1", "OR team assigned by drag")
	await advance_to("23:21")
	await wait(0.6)
	await shot("8_crisis")
	# Interrupt warning while dragging Volkov away from surgery.
	await drag_card("doctor_volkov", _dept_global("er"), "9_interrupt", false)
	await release(_dept_global("er") + Vector2(0, -2000))
	await wait(0.3)
	print("RESULT: ", "OK" if fails.is_empty() else "FAILS " + str(fails))
	get_tree().quit()


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails.append(what)


func advance(n: int) -> void:
	for i in n:
		if Game.ended:
			return
		Game._last_tick += 1
		Game.minutes = Game._last_tick
		Game._tick_minute(Game._last_tick)
		Game.time_changed.emit(Game.minutes)
		await get_tree().process_frame


func advance_to(clock: String) -> void:
	await advance(maxi(0, EventData.parse_time(clock) - Game._last_tick))


func _dept_global(dept_id: String) -> Vector2:
	var m: MapView = main.map
	return m.get_global_transform() * m.dept_screen(dept_id)


func _find_button(root: Node, text: String) -> Control:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text == text and n.is_visible_in_tree():
			return n
	push_error("button not found: " + text)
	return null


func _btn(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_viewport().push_input(e, true)


func _motion(pos: Vector2, rel: Vector2, held: bool) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(e, true)


func tap_control(c: Control) -> void:
	if c == null:
		fails.append("missing control")
		return
	await tap_global(c.get_global_rect().get_center())


func tap_global(p: Vector2) -> void:
	_motion(p, Vector2.ZERO, false)
	await get_tree().process_frame
	_btn(p, true)
	await get_tree().process_frame
	_btn(p, false)
	await get_tree().process_frame


func drag_card(sid: String, to: Vector2, mid_shot: String, do_release := true) -> void:
	var card: PersonCard = main.strip.card_for(sid)
	var a := card.get_global_rect().get_center()
	_motion(a, Vector2.ZERO, false)
	await get_tree().process_frame
	_btn(a, true)
	await wait(0.32)       # hold to lift
	var prev := a
	for i in range(1, 16):
		var p := a.lerp(to, float(i) / 15.0)
		_motion(p, p - prev, true)
		prev = p
		await get_tree().process_frame
	await wait(0.2)
	if mid_shot != "":
		await shot(mid_shot)
	if do_release:
		await release(to)


func release(p: Vector2) -> void:
	_btn(p, false)
	await get_tree().process_frame
	await get_tree().process_frame


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + tag + "_" + name + ".png")
	print("shot ", name)
