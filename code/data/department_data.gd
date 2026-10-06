class_name DepartmentData
extends Resource
## A hospital department or any clickable map location (city POI).

@export var id: String = ""
@export var name: String = ""
@export var short_name: String = ""
@export var kind: String = "department"   # department | rest | service | city
@export var icon: String = "hospital"
@export var accepts_staff: bool = true
@export var concurrent_cases: int = 1    # how many cases can be treated at once
@export var beds: int = 0
@export var beds_occupied: int = 0
@export var description: String = ""
@export var building_id: String = ""     # map building that represents this location
@export var entrance: Vector2 = Vector2.ZERO  # tile coords where staff stand


static func from_dict(d: Dictionary) -> DepartmentData:
	var r := DepartmentData.new()
	r.id = d.get("id", "")
	r.name = d.get("name", "")
	r.short_name = d.get("short", r.name)
	r.kind = d.get("kind", "department")
	r.icon = d.get("icon", "hospital")
	r.accepts_staff = bool(d.get("accepts_staff", true))
	r.concurrent_cases = int(d.get("concurrent_cases", 1))
	r.beds = int(d.get("beds", 0))
	r.beds_occupied = int(d.get("beds_occupied", 0))
	r.description = d.get("description", "")
	r.building_id = d.get("building", "")
	var e: Array = d.get("entrance", [0, 0])
	r.entrance = Vector2(e[0], e[1])
	return r
