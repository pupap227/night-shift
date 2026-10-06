extends Node
## Game state + simulation clock. UI and map only read state and listen to signals;
## every player action goes through the public API at the bottom (select / preview / assign / resolve).

signal time_changed(minutes: float)
signal speed_changed(speed: int, paused: bool)
signal staff_changed(staff_id: String)
signal selection_changed(staff_id: String)
signal case_added(c: PatientCase)
signal case_changed(c: PatientCase)
signal case_removed(c: PatientCase)
signal event_arrived(ev: EventInstance)
signal event_resolved(ev: EventInstance)
signal city_news(n: CityEventData)
signal stats_changed
signal alarm_level_changed(level: int)
signal notify(text: String, tone: String, tile: Vector2)
signal assigned(staff_id: String, result: Dictionary)
signal ambulance_dispatched(case_uid: int, route_id: String, start_min: float, end_min: float)
signal ambulance_arrived(case_uid: int)
signal patient_died(c: PatientCase)
signal shift_started
signal shift_ended(summary: Dictionary)
signal open_event_request(ev: EventInstance)
signal focus_request(target_id: String)
signal drag_state_changed(staff_id: String)   # "" when drag ends

const ALARM_LABELS := ["СПОКОЙНО", "НАПРЯЖЕНИЕ", "КРИЗИС"]

var db := DataDB.new()
var director: EventDirector

# --- clock
var minutes := 0.0
var duration := 480.0
var seconds_per_minute := 1.5
var speed := 1
var paused := true
var running := false
var ended := false
var _last_tick := -1
var _pause_holds := 0

# --- hospital
var day := 12
var money := 0
var reputation := 62
var alarm := 0.0
var alarm_spike := 0.0
var alarm_level := 0
var alarm_peak_level := 0
var flags: Dictionary = {}
var icu_was_full := false
var overflow_beds := 0

var staff: Dictionary = {}               # id -> StaffMember (data order)
var cases: Array[PatientCase] = []
var events: Array[EventInstance] = []
var city_news_log: Array = []
var selected_staff_id := ""
var dragging_staff_id := ""

var treated := 0
var deaths := 0
var redirected := 0
var _uid := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	db.load_all()
	director = EventDirector.new(self)
	new_shift()


func new_shift() -> void:
	var sh := db.shift
	day = int(sh.get("day", 1))
	duration = float(sh.get("duration_minutes", 480))
	seconds_per_minute = float(sh.get("seconds_per_minute", 1.5))
	money = int(sh.get("money", 40000))
	reputation = int(sh.get("reputation", 60))
	minutes = 0.0
	_last_tick = -1
	alarm = 0.0
	alarm_spike = 0.0
	alarm_level = 0
	flags.clear()
	staff.clear()
	cases.clear()
	events.clear()
	city_news_log.clear()
	for c: CharacterData in db.characters.values():
		var s := StaffMember.new()
		s.setup(c, db.traits)
		s.location = "staffroom"
		staff[s.id] = s
	for s: StaffMember in staff.values():
		s.stand_tile = _stand_tile_for(s, "staffroom")
	# Fresh department occupancy from data.
	for d: DepartmentData in db.departments.values():
		d.set_meta("occupied", d.beds_occupied)
	director = EventDirector.new(self)


func start() -> void:
	running = true
	paused = false
	ended = false
	Audio.start_music()
	speed_changed.emit(speed, paused)
	shift_started.emit()


func _process(delta: float) -> void:
	if not running or ended or paused or _pause_holds > 0:
		return
	minutes += delta * speed / seconds_per_minute
	while int(minutes) > _last_tick:
		_last_tick += 1
		_tick_minute(_last_tick)
		if ended:
			return
	time_changed.emit(minutes)


# ---------------------------------------------------------------- clock helpers

func clock_string(m: float = -1.0) -> String:
	if m < 0:
		m = minutes
	var start := 22 * 60
	var t := (start + int(m)) % 1440
	return "%02d:%02d" % [t / 60, t % 60]


func set_speed(s: int) -> void:
	speed = clampi(s, 1, 3)
	paused = false
	speed_changed.emit(speed, paused)


func toggle_pause() -> void:
	paused = not paused
	speed_changed.emit(speed, paused)


## Modal UI (event dialog) holds time while open.
func hold_time(on: bool) -> void:
	_pause_holds = maxi(0, _pause_holds + (1 if on else -1))
	speed_changed.emit(speed, paused or _pause_holds > 0)


func is_time_flowing() -> bool:
	return running and not paused and _pause_holds == 0 and not ended


func next_uid() -> int:
	_uid += 1
	return _uid


# ---------------------------------------------------------------- simulation

func _tick_minute(m: int) -> void:
	director.check(m)
	for ev in events:
		if not ev.resolved and m >= ev.deadline:
			director.resolve(ev, ev.data.default_choice, true)
	_tick_cases(m)
	_tick_staff(m)
	_tick_alarm()
	recompute_stats()
	if m >= int(duration):
		_end_shift()


func _tick_cases(m: int) -> void:
	for c: PatientCase in cases.duplicate():
		if not c.is_active():
			continue
		var dept_id := c.department()
		if c.status == PatientCase.Status.INBOUND:
			c.condition -= c.ptype.decay * 0.45
			if m >= c.arrive_at:
				c.status = PatientCase.Status.WAITING
				ambulance_arrived.emit(c.uid)
				notify.emit("Скорая у приёмного: %s" % c.label, "info", _dept_tile("er"))
				Audio.play("door", -4.0)
		else:
			var staffed := _all_slots_present(c)
			var capacity_ok := _has_capacity(c)
			if staffed and capacity_ok:
				if c.status != PatientCase.Status.TREATING:
					c.status = PatientCase.Status.TREATING
					Audio.play("beep", -8.0)
				c.blocked_reason = ""
				var speed_sum := 0.0
				var defs := c.slot_defs()
				for i in c.slots.size():
					var s: StaffMember = staff[c.slots[i]]
					speed_sum += Assignment.slot_speed(s, defs[i], alarm_level)
				var work := speed_sum / maxf(1.0, c.slots.size())
				if c.stage().get("lab", false) and flags.get("lab_slow", false):
					work *= 0.5
				c.progress += work
				c.condition = minf(100.0, c.condition + 0.12)
				_roll_complication(c)
				if c.progress >= c.duration():
					_complete_stage(c)
			else:
				c.status = PatientCase.Status.WAITING
				var decay := c.ptype.decay
				var filled := c.slots.size() - c.open_slots().size()
				if filled > 0:
					decay *= 0.6
				if _duty_carers(dept_id) > 0:
					decay *= 0.75
				c.condition -= decay
				if not capacity_ok:
					c.blocked_reason = "%s занята" % db.departments[dept_id].short_name
					if dept_id == "icu":
						icu_was_full = true
				elif filled == c.slots.size():
					c.blocked_reason = "персонал в пути"
				else:
					c.blocked_reason = "нужен: " + ", ".join(c.missing_labels()).to_lower()
		if c.condition <= 0.0:
			_fail_case(c)
		else:
			case_changed.emit(c)


func _roll_complication(c: PatientCase) -> void:
	var defs := c.slot_defs()
	for i in c.slots.size():
		var s: StaffMember = staff[c.slots[i]]
		if Assignment.slot_fit(s, defs[i]) != Assignment.Fit.RISKY:
			continue
		var chance := 0.025 * (1.0 + s.mod("complication_chance"))
		if randf() < chance:
			c.condition -= 9.0
			c.complications += 1
			s.stress = clampf(s.stress + 6.0 * (1.0 + s.mod("risky_stress")), 0, 100)
			notify.emit("Осложнение: %s не справляется (%s)" % [s.data.surname, c.label], "warn", _dept_tile(c.department()))
			Audio.play("beep", -2.0, 0.2)


func _complete_stage(c: PatientCase) -> void:
	var dept_id := c.department()
	var released: Array = c.slots.duplicate()
	for sid in released:
		var s: StaffMember = staff.get(sid)
		if s:
			s.case_uid = -1
			s.risky = false
			s.state = StaffMember.State.ON_DUTY
			s.stress = clampf(s.stress - 2.0, 0, 100)
			staff_changed.emit(s.id)
	if c.advance_stage():
		c.status = PatientCase.Status.WAITING
		var nd: DepartmentData = db.departments[c.department()]
		notify.emit("%s → %s: нужны %s" % [c.label, nd.name, ", ".join(c.missing_labels()).to_lower()], "warn", _dept_tile(nd.id))
		Audio.play("phone", -8.0)
	else:
		c.status = PatientCase.Status.DONE
		c.ended_at = minutes
		for sid in released:
			var s2: StaffMember = staff.get(sid)
			if s2:
				s2.cases_done += 1
		if c.ptype.is_patient:
			treated += 1
			money += c.ptype.reward
			reputation = mini(100, reputation + 1)
			var ward: DepartmentData = db.departments["ward"]
			var occ: int = ward.get_meta("occupied", ward.beds_occupied)
			if occ >= ward.beds:
				overflow_beds += 1
				notify.emit("Мест нет: %s лежит в коридоре" % c.label, "warn", _dept_tile("ward"))
			ward.set_meta("occupied", occ + 1)
			notify.emit("Спасён: %s  +%d ₽" % [c.label, c.ptype.reward], "ok", _dept_tile(dept_id))
		else:
			notify.emit(c.ptype.success_text if c.ptype.success_text != "" else "Инцидент улажен", "ok", _dept_tile(dept_id))
		Audio.play("confirm", -6.0)
		case_removed.emit(c)
	case_changed.emit(c)


func _fail_case(c: PatientCase) -> void:
	c.condition = 0.0
	c.ended_at = minutes
	for sid in c.slots:
		var s: StaffMember = staff.get(sid)
		if s:
			s.case_uid = -1
			s.state = StaffMember.State.ON_DUTY if s.state == StaffMember.State.WORKING else s.state
			s.stress = clampf(s.stress + 15.0, 0, 100)
			staff_changed.emit(s.id)
	if c.ptype.is_patient:
		c.status = PatientCase.Status.DEAD
		deaths += 1
		alarm_spike += 18.0
		reputation = maxi(0, reputation - 5)
		for s2: StaffMember in staff.values():
			s2.stress = clampf(s2.stress + 4.0, 0, 100)
		notify.emit("Пациент скончался: %s" % c.label, "danger", _dept_tile(c.department()))
		Audio.play("flatline")
		patient_died.emit(c)
	else:
		c.status = PatientCase.Status.FAILED
		director.apply_effects(c.ptype.fail_effects)
		notify.emit(c.ptype.fail_text, "danger", _dept_tile(c.department()))
		Audio.play("error")
	case_changed.emit(c)
	case_removed.emit(c)


func _tick_staff(_m: int) -> void:
	for s: StaffMember in staff.values():
		var before_state := s.state
		var fg := 1.0 + s.mod("fatigue_gain")
		var sg := 1.0 + s.mod("stress_gain")
		var rec := 1.0 + s.mod("recovery")
		match s.state:
			StaffMember.State.MOVING:
				s.fatigue += 0.08 * fg
				if minutes >= s.move_end:
					_arrive(s)
			StaffMember.State.WORKING:
				var c := get_case(s.case_uid)
				var treating := c != null and c.status == PatientCase.Status.TREATING
				s.fatigue += (0.2 if treating else 0.06) * fg
				var team := 1.0
				if c:
					for other in c.slots:
						if other != "" and other != s.id:
							team += staff[other].mod("team_stress")
				s.stress += (0.07 if treating else 0.03) * sg * (1.0 + 0.6 * alarm_level) * team
				if treating and s.risky:
					s.stress += 0.08 * (1.0 + s.mod("risky_stress"))
			StaffMember.State.ON_DUTY:
				s.fatigue += 0.04 * fg
				s.stress += 0.02 * alarm_level * sg
				_try_auto_join(s)
			StaffMember.State.AVAILABLE:
				s.fatigue -= 0.04 * rec
				s.stress -= 0.06
			StaffMember.State.RESTING, StaffMember.State.EXHAUSTED:
				s.fatigue -= 0.45 * rec
				s.stress -= 0.22
				if s.rest_until > 0.0 and minutes >= s.rest_until:
					s.rest_until = -1.0
					s.state = StaffMember.State.AVAILABLE
					notify.emit("%s снова в строю" % s.data.surname, "ok", s.stand_tile)
		s.fatigue = clampf(s.fatigue, 0, 100)
		s.stress = clampf(s.stress, 0, 100)
		if s.fatigue >= 100.0 and s.state != StaffMember.State.EXHAUSTED:
			force_rest(s, 45.0, "без сил, упала в ординаторской" if s.gender_female() else "без сил, упал в ординаторской", true)
		elif s.stress >= 100.0 and s.state != StaffMember.State.EXHAUSTED:
			s.stress = 70.0
			force_rest(s, 30.0, "нервный срыв", true)
		staff_changed.emit(s.id)
		if before_state != s.state:
			recompute_stats()


func _arrive(s: StaffMember) -> void:
	s.path = PackedVector2Array()
	if s.case_uid >= 0:
		s.state = StaffMember.State.WORKING
		Audio.play("steps", -14.0)
	elif s.rest_on_arrival:
		s.rest_on_arrival = false
		s.state = StaffMember.State.RESTING
	elif s.location == "staffroom":
		s.state = StaffMember.State.AVAILABLE
	else:
		s.state = StaffMember.State.ON_DUTY
		_try_auto_join(s)


func _try_auto_join(s: StaffMember) -> void:
	if s.state != StaffMember.State.ON_DUTY or s.case_uid >= 0:
		return
	var target := _best_case_in(s, s.location, true)
	if target == null:
		return
	var slot := Assignment.best_slot(s, target)
	if slot.index < 0:
		return
	target.slots[slot.index] = s.id
	s.case_uid = target.uid
	s.risky = false
	s.state = StaffMember.State.WORKING
	notify.emit("%s подключается: %s" % [s.data.surname, target.label], "info", _dept_tile(s.location))
	staff_changed.emit(s.id)
	case_changed.emit(target)


func _tick_alarm() -> void:
	var target := 0.0
	for c in cases:
		if not c.is_active():
			continue
		if c.status == PatientCase.Status.WAITING:
			target += 6.0 + (100.0 - c.condition) * 0.22
			if c.condition < 35.0:
				target += 10.0
		elif c.status == PatientCase.Status.INBOUND:
			target += 4.0
		else:
			target += 2.0
	for ev in events:
		if not ev.resolved and ev.data.urgent:
			target += 6.0
	for s: StaffMember in staff.values():
		if s.state == StaffMember.State.EXHAUSTED:
			target += 6.0
	target += overflow_beds * 4.0
	alarm_spike = maxf(0.0, alarm_spike - 0.35)
	var goal := clampf(target + alarm_spike, 0.0, 100.0)
	alarm += clampf(goal - alarm, -1.2, 2.5)
	var lvl := 0 if alarm < 35.0 else (1 if alarm < 70.0 else 2)
	if lvl != alarm_level:
		var rising := lvl > alarm_level
		alarm_level = lvl
		alarm_peak_level = maxi(alarm_peak_level, lvl)
		Audio.set_intensity(lvl)
		if rising:
			Audio.play("alarm", -6.0 if lvl == 1 else 0.0)
			notify.emit("Уровень тревоги: %s" % ALARM_LABELS[lvl], "danger" if lvl == 2 else "warn", Vector2(-1, -1))
		alarm_level_changed.emit(lvl)


func _end_shift() -> void:
	ended = true
	running = false
	for ev in events:
		if not ev.resolved:
			director.resolve(ev, ev.data.default_choice, true)
	var still := 0
	for c in cases:
		if c.is_active() and c.ptype.is_patient:
			still += 1
	var summary := {
		"treated": treated, "deaths": deaths, "money": money, "reputation": reputation,
		"still_in_care": still, "flags": flags.duplicate(), "alarm_peak": alarm_peak_level,
		"exhausted": staff.values().filter(func(s): return s.fatigue > 80.0).map(func(s): return s.data.surname),
	}
	Audio.set_intensity(0)
	shift_ended.emit(summary)


# ---------------------------------------------------------------- queries

func get_case(uid: int) -> PatientCase:
	for c in cases:
		if c.uid == uid:
			return c
	return null


func get_event(uid: int) -> EventInstance:
	for e in events:
		if e.uid == uid:
			return e
	return null


func active_cases() -> Array[PatientCase]:
	var r: Array[PatientCase] = []
	for c in cases:
		if c.is_active():
			r.append(c)
	return r


func cases_in(dept_id: String) -> Array[PatientCase]:
	var r: Array[PatientCase] = []
	for c in cases:
		if c.is_active() and c.department() == dept_id:
			r.append(c)
	return r


func staff_at(dept_id: String) -> Array[StaffMember]:
	var r: Array[StaffMember] = []
	for s: StaffMember in staff.values():
		if s.location == dept_id:
			r.append(s)
	return r


func case_in_treatment(dept_id: String) -> PatientCase:
	for c in cases:
		if c.status == PatientCase.Status.TREATING and c.department() == dept_id:
			return c
	return null


func count_free(category: String) -> int:
	var n := 0
	for s: StaffMember in staff.values():
		if s.data.category == category and s.is_free():
			n += 1
	return n


func free_beds() -> int:
	var w: DepartmentData = db.departments["ward"]
	return maxi(0, w.beds - int(w.get_meta("occupied", w.beds_occupied)))


func icu_free() -> int:
	var d: DepartmentData = db.departments["icu"]
	var treating := 0
	for c in cases:
		if c.status == PatientCase.Status.TREATING and c.department() == "icu":
			treating += 1
	return maxi(0, d.beds - d.beds_occupied - treating)


func staff_load() -> float:
	var busy := 0
	for s: StaffMember in staff.values():
		if s.case_uid >= 0 or s.is_locked():
			busy += 1
	return float(busy) / maxf(1.0, staff.size())


func staff_status_line(sid: String) -> String:
	var s: StaffMember = staff.get(sid)
	if s == null:
		return "?"
	var c := get_case(s.case_uid)
	if c:
		return "%s занят — %s (%s)" % [s.data.surname, c.stage().get("label", ""), c.label]
	if s.is_locked():
		return "%s отдыхает" % s.data.surname
	return "%s свободен" % s.data.surname if not s.gender_female() else "%s свободна" % s.data.surname


func pending_events() -> Array[EventInstance]:
	var r: Array[EventInstance] = []
	for e in events:
		if not e.resolved:
			r.append(e)
	return r


func recompute_stats() -> void:
	stats_changed.emit()


func _has_capacity(c: PatientCase) -> bool:
	if c.status == PatientCase.Status.TREATING:
		return true
	var d: DepartmentData = db.departments[c.department()]
	var treating := 0
	for o in cases:
		if o != c and o.status == PatientCase.Status.TREATING and o.department() == d.id:
			treating += 1
	var cap := d.concurrent_cases
	if d.id == "icu":
		cap = d.beds - d.beds_occupied
	return treating < cap


func _all_slots_present(c: PatientCase) -> bool:
	for sid in c.slots:
		if sid == "":
			return false
		var s: StaffMember = staff[sid]
		if s.state != StaffMember.State.WORKING:
			return false
	return true


func _duty_carers(dept_id: String) -> int:
	var n := 0
	for s: StaffMember in staff.values():
		if s.location == dept_id and s.state == StaffMember.State.ON_DUTY and s.skill("care") >= 4:
			n += 1
	return n


func _best_case_in(s: StaffMember, dept_id: String, good_only: bool) -> PatientCase:
	var best: PatientCase = null
	var best_score := -INF
	for c in cases:
		if not c.is_active() or c.department() != dept_id:
			continue
		var slot := Assignment.best_slot(s, c)
		if slot.index < 0 or (good_only and slot.fit != Assignment.Fit.GOOD):
			continue
		var score: float = slot.fit * 1000.0 - c.condition
		if score > best_score:
			best_score = score
			best = c
	return best


# ---------------------------------------------------------------- map geometry helpers

func _dept_tile(dept_id: String) -> Vector2:
	var d: DepartmentData = db.departments.get(dept_id)
	return d.entrance if d else Vector2(-1, -1)


func _stand_tile_for(s: StaffMember, dept_id: String) -> Vector2:
	var base := _dept_tile(dept_id)
	var i := 0
	for o: StaffMember in staff.values():
		if o == s:
			break
		if o.location == dept_id:
			i += 1
	return base + Vector2((i % 4) * 0.42 - 0.63, (i / 4) * 0.38 + 0.05)


func walk_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var hp: Dictionary = db.city_map.get("hospital_paths", {})
	var corridors: Array = hp.get("corridors", [15.0])
	var cx: float = hp.get("connector_x", 17.0)
	var c1 := _nearest(corridors, from.y)
	var c2 := _nearest(corridors, to.y)
	var pts: Array[Vector2] = [from, Vector2(from.x, c1)]
	if absf(c1 - c2) > 0.01:
		pts.append(Vector2(cx, c1))
		pts.append(Vector2(cx, c2))
	pts.append(Vector2(to.x, c2))
	pts.append(to)
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.05:
			out.append(p)
	return out


func _nearest(values: Array, v: float) -> float:
	var best: float = values[0]
	for x in values:
		if absf(x - v) < absf(best - v):
			best = x
	return best


func _path_length(p: PackedVector2Array) -> float:
	var t := 0.0
	for i in range(1, p.size()):
		t += p[i - 1].distance_to(p[i])
	return t


# ---------------------------------------------------------------- player API

func select_staff(sid: String) -> void:
	if selected_staff_id == sid:
		sid = ""
	selected_staff_id = sid
	if sid != "":
		Audio.play("click", -6.0)
	selection_changed.emit(sid)


func set_dragging(sid: String) -> void:
	dragging_staff_id = sid
	drag_state_changed.emit(sid)


## What would happen if staff `sid` were sent to target {"dept": id} or {"case": uid}.
## Returns {ok, kind, text, detail, warning, fit, case_uid, slot, travel, dept}.
func preview(sid: String, target: Dictionary) -> Dictionary:
	var s: StaffMember = staff.get(sid)
	var r := {"ok": false, "kind": "invalid", "text": "", "detail": "", "warning": "", "fit": 0,
		"case_uid": -1, "slot": -1, "travel": 0.0, "dept": ""}
	if s == null or ended:
		return r
	if s.is_locked():
		r.text = "%s: %s" % [s.data.surname, "без сил" if s.state == StaffMember.State.EXHAUSTED else "на отдыхе"]
		r.detail = "Вернётся через %d мин" % int(maxf(0.0, s.rest_until - minutes))
		return r
	var c: PatientCase = null
	var dept_id := ""
	if target.has("case"):
		c = get_case(int(target.case))
		if c == null or not c.is_active():
			r.text = "Случай закрыт"
			return r
		dept_id = c.department()
	else:
		dept_id = String(target.get("dept", ""))
	var d: DepartmentData = db.departments.get(dept_id)
	if d == null:
		r.text = "Здесь нет задач для персонала"
		return r
	r.dept = dept_id
	if not d.accepts_staff:
		r.text = "%s — сюда нельзя назначить" % d.name
		return r
	if c == null and d.kind == "department":
		c = _best_case_in(s, dept_id, false)
	var current := get_case(s.case_uid)
	if c != null:
		var slot := Assignment.best_slot(s, c)
		if slot.index < 0:
			if c.has_staff(s.id):
				r.text = "%s уже работает здесь" % s.data.surname
			else:
				r.text = "%s не подходит: нужны %s" % [s.data.surname, ", ".join(c.missing_labels()).to_lower()]
				if c.open_slots().is_empty():
					r.text = "Все места заняты: %s" % c.label
			return r
		if current == c:
			r.text = "%s уже на этом случае" % s.data.surname
			return r
		r.ok = true
		r.kind = "case"
		r.case_uid = c.uid
		r.slot = slot.index
		r.fit = slot.fit
		var stage := c.stage()
		r.text = "%s → %s" % [slot.label.to_upper(), c.label]
		var est := c.duration() * (1.0 - c.progress / maxf(1.0, c.duration()))
		est /= maxf(0.2, Assignment.slot_speed(s, c.slot_defs()[slot.index], alarm_level))
		r.detail = "%s · ~%d мин · усталость +%d" % [stage.get("label", ""), int(est), int(est * 0.2 * (1.0 + s.mod("fatigue_gain")))]
		if slot.fit == Assignment.Fit.RISKY:
			r.warning = "РИСК: не по уровню (%d/%d) — медленнее, возможны осложнения" % [int(slot.skill), int(c.slot_defs()[slot.index].get("min", 0))]
	elif d.kind == "rest":
		if s.location == "staffroom" and (s.state == StaffMember.State.RESTING or s.state == StaffMember.State.AVAILABLE) and s.case_uid < 0:
			r.text = "%s уже в ординаторской" % s.data.surname
			return r
		r.ok = true
		r.kind = "rest"
		r.fit = Assignment.Fit.GOOD
		r.text = "ОТДЫХ · %s" % d.short_name
		r.detail = "Усталость −27/час, стресс −13/час"
	else:
		if s.location == dept_id and s.case_uid < 0 and s.state == StaffMember.State.ON_DUTY:
			r.text = "%s уже дежурит здесь" % s.data.surname
			return r
		r.ok = true
		r.kind = "duty"
		r.fit = Assignment.Fit.GOOD
		r.text = "ДЕЖУРСТВО · %s" % d.short_name
		r.detail = "Замедляет ухудшение ожидающих, подключится к новым пациентам"
	r.travel = _travel_minutes(s, dept_id)
	r.detail += " · в пути %d мин" % int(ceil(r.travel)) if r.travel >= 0.5 else ""
	if current != null and current != c and current.is_active():
		var verb := "ПРЕРВЁТ" if current.status == PatientCase.Status.TREATING else "ОСТАВИТ"
		r.warning = "%s: %s — %s" % [verb, current.stage().get("label", "").to_lower(), current.label]
	return r


func assign(sid: String, target: Dictionary) -> Dictionary:
	var r := preview(sid, target)
	var s: StaffMember = staff.get(sid)
	if not r.ok:
		Audio.play("error", -4.0)
		assigned.emit(sid, r)
		return r
	# Leaving a current case = the dilemma made concrete.
	var current := get_case(s.case_uid)
	if current != null and current.uid != r.case_uid:
		var i := current.slots.find(s.id)
		if i >= 0:
			current.slots[i] = ""
		if current.status == PatientCase.Status.TREATING:
			current.status = PatientCase.Status.WAITING
			notify.emit("%s покидает «%s»: %s без %s" % [s.data.surname, current.stage().get("label", ""), current.label,
				current.slot_defs()[i].get("label", "").to_lower() if i >= 0 else "врача"], "danger", _dept_tile(current.department()))
		case_changed.emit(current)
	s.case_uid = -1
	s.risky = false
	s.rest_until = -1.0
	s.rest_on_arrival = false
	var dept_id: String = r.dept
	if r.kind == "case":
		var c := get_case(r.case_uid)
		c.slots[r.slot] = s.id
		s.case_uid = c.uid
		s.risky = r.fit == Assignment.Fit.RISKY
		case_changed.emit(c)
	elif r.kind == "rest":
		s.rest_on_arrival = true
	_send(s, dept_id)
	Audio.play("assign")
	assigned.emit(sid, r)
	staff_changed.emit(sid)
	recompute_stats()
	return r


func force_rest(s: StaffMember, mins: float, reason: String, collapse := false) -> void:
	var c := get_case(s.case_uid)
	if c:
		var i := c.slots.find(s.id)
		if i >= 0:
			c.slots[i] = ""
		if c.status == PatientCase.Status.TREATING:
			c.status = PatientCase.Status.WAITING
		case_changed.emit(c)
	s.case_uid = -1
	s.risky = false
	_send(s, "staffroom")
	s.state = StaffMember.State.EXHAUSTED if collapse else StaffMember.State.RESTING
	s.path = PackedVector2Array()
	s.stand_tile = _stand_tile_for(s, "staffroom")
	s.rest_until = minutes + mins
	notify.emit("%s — %s (%d мин)" % [s.data.surname, reason, int(mins)], "danger" if collapse else "warn", s.stand_tile)
	if collapse:
		Audio.play("error")
	staff_changed.emit(s.id)


func send_to_rest(sid: String) -> Dictionary:
	return assign(sid, {"dept": "staffroom"})


func resolve_event(ev: EventInstance, choice_id: String) -> void:
	director.resolve(ev, choice_id)
	if choice_id.begins_with("redirect") or choice_id == "refuse":
		redirected += ev.data.patients.size()


func _travel_minutes(s: StaffMember, dept_id: String) -> float:
	var from := s.position_at(minutes)
	var to := _dept_tile(dept_id)
	return _path_length(walk_path(from, to)) / s.walk_speed()


func _send(s: StaffMember, dept_id: String) -> void:
	var from := s.position_at(minutes)
	s.location = dept_id
	var stand := _stand_tile_for(s, dept_id)
	var p := walk_path(from, stand)
	var mins := _path_length(p) / s.walk_speed()
	s.stand_tile = stand
	if mins < 0.3:
		s.path = PackedVector2Array()
		s.state = StaffMember.State.MOVING
		s.move_start = minutes
		s.move_end = minutes
		_arrive(s)
		return
	s.path = p
	s.move_start = minutes
	s.move_end = minutes + mins
	s.state = StaffMember.State.MOVING
