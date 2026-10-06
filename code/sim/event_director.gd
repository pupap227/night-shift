class_name EventDirector
extends RefCounted
## Fires timed events and city news, formats their text, applies choice effects.
## Effects are plain data, so new events never need new code unless they need a new effect type.

var game: Node
var _fired: Dictionary = {}
var _news_fired: Dictionary = {}
var _scheduled: Array = []   # [{event_id, at}]


func _init(g: Node) -> void:
	game = g


func check(minute: int) -> void:
	for e: EventData in game.db.events.values():
		if e.time >= 0 and e.time <= minute and not _fired.has(e.id):
			fire(e)
	for s in _scheduled.duplicate():
		if s.at <= minute:
			_scheduled.erase(s)
			var e2: EventData = game.db.events.get(s.event_id)
			if e2:
				fire(e2)
	for n: CityEventData in game.db.city_events:
		if n.time <= minute and not _news_fired.has(n.id):
			_news_fired[n.id] = true
			game.city_news_log.push_front({"data": n, "at": float(n.time)})
			game.city_news.emit(n)


func fire(e: EventData) -> EventInstance:
	_fired[e.id] = true
	var ev := EventInstance.new()
	ev.uid = game.next_uid()
	ev.data = e
	ev.arrived_at = game.minutes
	ev.deadline = game.minutes + e.decision_minutes
	ev.body_text = format_text(e.body)
	game.events.append(ev)
	match e.category:
		"ambulance", "mass":
			Audio.play("phone")
		"security":
			Audio.play("alarm")
		_:
			Audio.play("phone", -4.0)
	game.event_arrived.emit(ev)
	return ev


func resolve(ev: EventInstance, choice_id: String, auto := false) -> void:
	if ev.resolved:
		return
	var c := ev.choice(choice_id)
	ev.resolved = true
	ev.choice_id = choice_id
	ev.auto_resolved = auto
	apply_effects(c.get("effects", []), ev)
	if auto:
		game.notify.emit("Решение принято без вас: «%s» — %s" % [ev.data.title, c.get("label", "")], "warn", Vector2(-1, -1))
	game.event_resolved.emit(ev)
	game.recompute_stats()


func apply_effects(effects: Array, ev: EventInstance = null) -> void:
	for fx in effects:
		match fx.get("type", ""):
			"spawn_patients":
				_spawn(ev, fx)
			"money":
				game.money += int(fx.value)
			"reputation":
				game.reputation = clampi(game.reputation + int(fx.value), 0, 100)
			"alarm":
				game.alarm_spike += float(fx.value)
			"flag":
				game.flags[fx.key] = fx.get("value", true)
			"staff_stress":
				var s: StaffMember = game.staff.get(fx.staff)
				if s:
					s.stress = clampf(s.stress + float(fx.value), 0, 100)
					game.staff_changed.emit(s.id)
			"staff_rest":
				var s2: StaffMember = game.staff.get(fx.staff)
				if s2:
					game.force_rest(s2, float(fx.get("minutes", 60)), "отпущена на отдых" if s2.gender_female() else "отпущен на отдых")
			"dept_stress":
				for s3: StaffMember in game.staff.values():
					if s3.location == fx.department and s3.state != StaffMember.State.MOVING:
						s3.stress = clampf(s3.stress + float(fx.value), 0, 100)
						game.staff_changed.emit(s3.id)
			"schedule_event":
				_scheduled.append({"event_id": fx.event, "at": game.minutes + float(fx.get("delay", 30))})
			"notify":
				game.notify.emit(fx.text, fx.get("tone", "info"), Vector2(-1, -1))


func _spawn(ev: EventInstance, fx: Dictionary) -> void:
	var e := ev.data
	var specs: Array = e.patients
	var idx: Array = fx.get("indices", range(specs.size()))
	var n := 0
	for i in idx:
		var spec: Dictionary = specs[i]
		var t: PatientTypeData = game.db.patient_types.get(spec.get("type", ""))
		if t == null:
			push_warning("Unknown patient type " + str(spec))
			continue
		var c := PatientCase.new()
		c.uid = game.next_uid()
		c.setup(t, fx.get("variant", spec.get("variant", "")))
		c.label = spec.get("label", t.name)
		c.condition = float(spec.get("condition", 80))
		c.event_uid = ev.uid
		c.route = e.route
		c.ambulance_start = game.minutes
		c.arrive_at = game.minutes + e.eta + n * 1.5
		c.status = PatientCase.Status.INBOUND if e.eta > 0 else PatientCase.Status.WAITING
		ev.case_uids.append(c.uid)
		game.cases.append(c)
		game.case_added.emit(c)
		if e.eta > 0 and e.route != "":
			game.ambulance_dispatched.emit(c.uid, e.route, c.ambulance_start, c.arrive_at)
		n += 1
	if n > 0 and e.eta > 0:
		Audio.play("siren", -6.0)


## Replaces {var} and {var:arg} with live game values.
func format_text(text: String) -> String:
	var re := RegEx.create_from_string("\\{([a-z_]+)(?::([a-z_]+))?\\}")
	var out := text
	for m in re.search_all(text):
		out = out.replace(m.get_string(0), _var(m.get_string(1), m.get_string(2)))
	return out


func _var(key: String, arg: String) -> String:
	match key:
		"free_doctors":
			return str(game.count_free("doctor"))
		"free_nurses":
			return str(game.count_free("nurse"))
		"free_beds":
			return str(game.free_beds())
		"icu_free":
			return str(game.icu_free())
		"or_status":
			var c: PatientCase = game.case_in_treatment("or1")
			return "свободна" if c == null else "занята (%s)" % c.label
		"lab_status":
			return "работает вполсилы — нет реагентов" if game.flags.get("lab_slow", false) else "в норме"
		"surgeon_status":
			return game.staff_status_line("doctor_volkov")
		"cardio_status":
			return game.staff_status_line("doctor_orlova")
		"fatigue":
			var s: StaffMember = game.staff.get(arg)
			return str(int(s.fatigue)) if s else "?"
		"stress":
			var s2: StaffMember = game.staff.get(arg)
			return str(int(s2.stress)) if s2 else "?"
	return "{%s}" % key
