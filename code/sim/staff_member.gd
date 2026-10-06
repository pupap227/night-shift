class_name StaffMember
extends RefCounted
## Runtime state of one staff member during a shift.

enum State { AVAILABLE, ON_DUTY, MOVING, WORKING, RESTING, EXHAUSTED }

const STATE_LABELS := {
	State.AVAILABLE: "СВОБОДЕН",
	State.ON_DUTY: "ДЕЖУРИТ",
	State.MOVING: "В ПУТИ",
	State.WORKING: "НА ЗАДАНИИ",
	State.RESTING: "ОТДЫХ",
	State.EXHAUSTED: "БЕЗ СИЛ",
}

var data: CharacterData
var id: String
var fatigue := 0.0
var stress := 0.0
var state: int = State.AVAILABLE
var location := "staffroom"        # department id the staff is at / heading to
var case_uid := -1                 # PatientCase uid or -1
var rest_on_arrival := false
var rest_until := -1.0             # forced rest end (game minutes), -1 = voluntary
var path: PackedVector2Array = []  # tile waypoints of the current walk
var move_start := 0.0
var move_end := 0.0
var stand_tile := Vector2.ZERO     # where the token stands when not walking
var mods: Dictionary = {}
var cases_done := 0
var risky := false                 # currently filling a slot above their level


func setup(d: CharacterData, trait_db: Dictionary) -> void:
	data = d
	id = d.id
	fatigue = d.start_fatigue
	stress = d.start_stress
	for t_id in d.traits:
		var t: TraitData = trait_db.get(t_id)
		if t == null:
			continue
		for k in t.modifiers:
			mods[k] = mods.get(k, 0.0) + float(t.modifiers[k])


func mod(key: String) -> float:
	return float(mods.get(key, 0.0))


func skill(skill_id: String) -> float:
	return data.skill(skill_id) + mod("skill_" + skill_id)


func gender_female() -> bool:
	return data.surname.ends_with("а")


func is_locked() -> bool:
	return state == State.EXHAUSTED or (state == State.RESTING and rest_until > 0.0)


func is_free() -> bool:
	return case_uid < 0 and not is_locked() and state != State.MOVING


func efficiency(alarm_level: int) -> float:
	var f := 1.0
	f *= 1.0 - clampf((fatigue - 50.0) / 100.0, 0.0, 0.45)
	f *= 1.0 - clampf((stress - 60.0) / 120.0 * (1.0 + mod("stress_penalty")), 0.0, 0.5)
	f *= 1.0 + mod("work_speed")
	if alarm_level >= 1:
		f *= 1.0 + mod("alarm_work_speed")
	return f


## Tiles per game minute.
func walk_speed() -> float:
	return (2.4 + data.skill("speed") * 0.35) * (1.0 + mod("travel_speed"))


func position_at(t: float) -> Vector2:
	if state != State.MOVING or path.size() < 2:
		return stand_tile
	var k := clampf(inverse_lerp(move_start, move_end, t), 0.0, 1.0)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var d := k * total
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if d <= seg or i == path.size() - 1:
			return path[i - 1].lerp(path[i], clampf(d / maxf(seg, 0.001), 0.0, 1.0))
		d -= seg
	return path[path.size() - 1]


func state_label() -> String:
	return STATE_LABELS.get(state, "")
