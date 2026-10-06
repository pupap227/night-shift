class_name TitleScreen
extends Control
## Opening briefing and the end-of-shift report. The living map stays visible underneath.

signal start_pressed

var _vb: VBoxContainer
var _bg: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.color = Color(0.01, 0.015, 0.03, 0.72)
	add_child(_bg)
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override("separation", 12)
	add_child(_vb)


func relayout() -> void:
	_bg.size = size
	var s := Screen.safe
	var w := minf(s.size.x - 40, 560)
	_vb.custom_minimum_size = Vector2(w, 0)
	_vb.reset_size()
	var y := s.position.y + maxf(20.0, (s.size.y - _vb.size.y) * (0.55 if Screen.mode == Screen.Mode.PORTRAIT else 0.5))
	_vb.position = Vector2(s.position.x + (s.size.x - w) * 0.5, y)


func _clear() -> void:
	for c in _vb.get_children():
		_vb.remove_child(c)
		c.queue_free()


func show_intro() -> void:
	_clear()
	var small := Screen.mode != Screen.Mode.DESKTOP
	var cap := Kit.label("%s · %s" % [Game.db.shift.get("hospital_name", "").to_upper(), Game.db.shift.get("hospital_subtitle", "").to_upper()], 13, Kit.TEXT_DIM, "display_bold")
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vb.add_child(cap)
	var t := Kit.label("НОЧНАЯ СМЕНА", 64 if not small else 56, Kit.TEXT, "display_bold")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.add_theme_constant_override("line_spacing", -14)
	_vb.add_child(t)
	_vb.add_child(Kit.label("День %d  ·  22:00 — 06:00  ·  ливень" % Game.day, 18, Kit.WARM, "display"))
	var p := Kit.label("Главврач на конференции. Дежурный администратор — вы. Восемь человек, сорок коек, одна операционная. До утра.", 17, Color("ddd5c2"), "serif")
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vb.add_child(p)
	var how := Kit.label("Выберите человека внизу и отправьте его в корпус — тапом или перетаскиванием.", 14, Kit.TEXT_DIM, "display_light")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vb.add_child(how)
	var b := Kit.big_button("НАЧАТЬ СМЕНУ", "emergency", 20)
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(func():
		Audio.play("confirm")
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func():
			visible = false
			start_pressed.emit()))
	_vb.add_child(b)
	visible = true
	modulate.a = 1.0
	relayout.call_deferred()


func show_report(s: Dictionary) -> void:
	_clear()
	_vb.add_child(Kit.label("06:00 · СМЕНА ОКОНЧЕНА", 14, Kit.WARM, "display_bold"))
	_vb.add_child(Kit.label("РАПОРТ", 54, Kit.TEXT, "display_bold"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	for r in [["СПАСЕНО", str(s.treated), Kit.GREEN], ["УМЕРЛО", str(s.deaths), Kit.RED if s.deaths > 0 else Kit.TEXT],
			["ДОВЕРИЕ", str(s.reputation), Kit.TEXT]]:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -6)
		v.add_child(Kit.label(r[1], 40, r[2], "display_bold"))
		v.add_child(Kit.label(r[0], 12, Kit.TEXT_DIM, "display_bold"))
		grid.add_child(v)
	_vb.add_child(grid)
	var f: Dictionary = s.flags
	var story := PackedStringArray()
	if f.get("toxic_seen", false):
		story.append("Двое пациентов с одинаковыми симптомами. Оба — с «Химмаша».")
	if f.get("police_interest", false):
		story.append("Лейтенант из «УАЗа» заходил дважды. Спрашивал, кто дежурил.")
	if f.get("vip_refused", false):
		story.append("Крылов из горздрава просил передать: «Я запомнил».")
	if story.is_empty():
		story.append("Город проснулся. Никто не знает, что было этой ночью. Кроме вас.")
	for line in story:
		var l := Kit.label("— " + line, 16, Color("ddd5c2"), "serif")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_vb.add_child(l)
	var b := Kit.big_button("НОВАЯ СМЕНА", "paper", 18)
	b.pressed.connect(func():
		Game.new_shift()
		get_tree().reload_current_scene())
	_vb.add_child(b)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	relayout.call_deferred()
