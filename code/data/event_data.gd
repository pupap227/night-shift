class_name EventData
extends Resource
## A scripted or random event. Choices carry data-driven effects resolved by EventDirector.

@export var id: String = ""
@export var time: int = -1                # minutes from shift start, -1 = not timed
@export var category: String = "ambulance"  # ambulance | mass | staff | lab | security | admin | city
@export var icon: String = "ambulance"
@export var urgent: bool = false
@export var title: String = ""
@export var headline: String = ""         # short line for the feed
@export var body: String = ""             # narrative text, supports {template} vars
@export var location: String = ""         # department or city POI id
@export var city_tile: Vector2 = Vector2(-1, -1)
@export var route: String = ""            # ambulance route id on the map
@export var eta: int = 6                  # ambulance travel minutes
@export var patients: Array = []          # [{type, variant, label, condition}]
@export var choices: Array = []           # [{id, label, hint, effects:[...]}]
@export var default_choice: String = ""
@export var decision_minutes: int = 12


static func from_dict(d: Dictionary) -> EventData:
	var e := EventData.new()
	e.id = d.get("id", "")
	e.time = EventData.parse_time(d.get("time", ""))
	e.category = d.get("category", "ambulance")
	e.icon = d.get("icon", "ambulance")
	e.urgent = bool(d.get("urgent", false))
	e.title = d.get("title", "")
	e.headline = d.get("headline", "")
	e.body = d.get("body", "")
	e.location = d.get("location", "")
	var t: Array = d.get("city_tile", [-1, -1])
	e.city_tile = Vector2(t[0], t[1])
	e.route = d.get("route", "")
	e.eta = int(d.get("eta", 6))
	e.patients = d.get("patients", [])
	e.choices = d.get("choices", [])
	e.default_choice = d.get("default_choice", "")
	if e.default_choice == "" and not e.choices.is_empty():
		e.default_choice = e.choices[0].get("id", "")
	e.decision_minutes = int(d.get("decision_minutes", 12))
	return e


## "22:30" -> minutes after shift start (shift starts 22:00, wraps past midnight).
static func parse_time(v) -> int:
	if v is int or v is float:
		return int(v)
	var s := String(v)
	if s == "" or not s.contains(":"):
		return -1
	var parts := s.split(":")
	var m := int(parts[0]) * 60 + int(parts[1])
	var start := 22 * 60
	return (m - start + 1440) % 1440
