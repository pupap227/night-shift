class_name DataDB
extends RefCounted
## Loads all game content from res://data/*.json into typed Resources.
## Adding a doctor / event / patient type / department = editing JSON only.

const DATA_DIR := "res://data/"

var characters: Dictionary = {}      # id -> CharacterData (insertion order preserved)
var traits: Dictionary = {}          # id -> TraitData
var departments: Dictionary = {}     # id -> DepartmentData
var patient_types: Dictionary = {}   # id -> PatientTypeData
var events: Dictionary = {}          # id -> EventData
var city_events: Array[CityEventData] = []
var skills: Dictionary = {}          # skill_id -> {label, short}
var categories: Array = []           # [{id, label}]
var shift: Dictionary = {}
var city_map: Dictionary = {}


func load_all() -> void:
	var meta: Dictionary = _read("meta.json")
	skills = meta.get("skills", {})
	categories = meta.get("categories", [])
	for d in _read("traits.json").get("traits", []):
		var t := TraitData.from_dict(d)
		traits[t.id] = t
	for d in _read("characters.json").get("characters", []):
		var c := CharacterData.from_dict(d)
		characters[c.id] = c
	for d in _read("departments.json").get("departments", []):
		var dep := DepartmentData.from_dict(d)
		departments[dep.id] = dep
	for d in _read("patients.json").get("patient_types", []):
		var p := PatientTypeData.from_dict(d)
		patient_types[p.id] = p
	for d in _read("events.json").get("events", []):
		var e := EventData.from_dict(d)
		events[e.id] = e
	for d in _read("city_events.json").get("city_events", []):
		city_events.append(CityEventData.from_dict(d))
	shift = _read("shift_01.json")
	city_map = _read("city_map.json")


func skill_label(skill_id: String) -> String:
	return skills.get(skill_id, {}).get("label", skill_id)


## Optional JSON (empty dict when absent).
func read_json(file: String) -> Dictionary:
	if not FileAccess.file_exists(DATA_DIR + file):
		return {}
	return _read(file)


func _read(file: String) -> Dictionary:
	var path := DATA_DIR + file
	if not FileAccess.file_exists(path):
		push_error("DataDB: missing " + path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed == null or not parsed is Dictionary:
		push_error("DataDB: invalid JSON in " + path)
		return {}
	return parsed
