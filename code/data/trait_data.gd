class_name TraitData
extends Resource
## A character trait. Modifiers are generic multipliers/offsets read by the simulation:
##   fatigue_gain, recovery, stress_gain, work_speed, alarm_work_speed, travel_speed,
##   risky_stress, complication_chance, skill_<id>

@export var id: String = ""
@export var label: String = ""
@export var positive: bool = true
@export var description: String = ""
@export var modifiers: Dictionary = {}


static func from_dict(d: Dictionary) -> TraitData:
	var t := TraitData.new()
	t.id = d.get("id", "")
	t.label = d.get("label", "")
	t.positive = bool(d.get("positive", true))
	t.description = d.get("description", "")
	t.modifiers = d.get("modifiers", {})
	return t
