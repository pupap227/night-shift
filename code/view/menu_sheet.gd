class_name MenuSheet
extends Control
## Pause menu: shift goals, controls, sound. Information on demand, not on screen all the time.

var _panel: PanelContainer
var _vb: VBoxContainer
var _open := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.03, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Kit.box(Color("0b1119"), Color(1, 1, 1, 0.1), 1, 16, 22))
	add_child(_panel)
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override("separation", 10)
	_panel.add_child(_vb)


func open() -> void:
	for c in _vb.get_children():
		_vb.remove_child(c)
		c.queue_free()
	_vb.add_child(Kit.label("ЦЕЛИ СМЕНЫ", 24, Kit.TEXT, "display_bold"))
	for o in Game.db.shift.get("objectives", []):
		var st := _status(o)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(Kit.label(["•", "✓", "✕"][st], 18, [Kit.TEXT_DIM, Kit.GREEN, Kit.RED][st], "display_bold"))
		var l := Kit.label(o.text, 16, Kit.TEXT if st != 2 else Kit.TEXT_DIM, "display_light")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		_vb.add_child(row)
	_vb.add_child(Kit.label("КАК ИГРАТЬ", 18, Kit.TEXT_DIM, "display_bold"))
	for t in ["Тап по сотруднику — выбрать. Тап по корпусу — отправить.",
			"Или удерживайте карточку и тяните её на корпус или на сигнал «НУЖЕН…».",
			"Зелёный — подходит. Жёлтый — риск. Красный — не рекомендуется.",
			"Снять человека с операции можно. Пациент это почувствует."]:
		var l2 := Kit.label(t, 15, Color("cfc7b4"), "serif")
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_vb.add_child(l2)
	var snd := Kit.big_button("ЗВУК: " + ("ВЫКЛ" if Audio.muted else "ВКЛ"), "ghost", 16)
	snd.pressed.connect(func():
		Audio.set_muted(not Audio.muted)
		snd.text = "ЗВУК: " + ("ВЫКЛ" if Audio.muted else "ВКЛ"))
	_vb.add_child(snd)
	var back := Kit.big_button("ПРОДОЛЖИТЬ", "paper", 18)
	back.pressed.connect(close)
	_vb.add_child(back)
	visible = true
	_open = true
	Game.hold_time(true)
	_layout()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	Game.hold_time(false)


func _layout() -> void:
	var w := minf(Screen.safe.size.x - 24, 460)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.reset_size()
	_panel.position = Screen.safe.get_center() - _panel.size * 0.5


func _process(_d: float) -> void:
	if _open:
		_layout()


func _status(o: Dictionary) -> int:
	match o.type:
		"max_deaths":
			if Game.deaths > int(o.value):
				return 2
		"icu_not_full":
			if Game.icu_was_full:
				return 2
		"alarm_below":
			if Game.alarm_peak_level >= int(o.value):
				return 2
		"money_above":
			if Game.money <= int(o.value):
				return 2
	return 1 if Game.ended else 0
