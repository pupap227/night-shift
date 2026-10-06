class_name CharacterData
extends Resource
## Static description of a staff member. Runtime state lives in StaffMember.

@export var id: String = ""
@export var surname: String = ""
@export var first_name: String = ""
@export var patronymic: String = ""
@export var category: String = "doctor"      # doctor | nurse | orderly | security
@export var role_name: String = ""
@export var age: int = 30
@export var portrait_id: String = ""          # asset id, resolved by Assets
@export var accent: Color = Color.WHITE
@export var skills: Dictionary = {}           # skill_id -> 0..10
@export var key_skills: PackedStringArray = []  # shown on the card
@export var traits: PackedStringArray = []    # trait ids
@export var start_fatigue: float = 10.0
@export var start_stress: float = 10.0
@export var bio: String = ""
@export var motto: String = ""         # one-line character hook shown on the card


func skill(skill_id: String) -> int:
	return int(skills.get(skill_id, 0))


func initials() -> String:
	var s := ""
	if first_name != "":
		s += first_name.substr(0, 1) + ". "
	if patronymic != "":
		s += patronymic.substr(0, 1) + "."
	return s.strip_edges()


static func from_dict(d: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.id = d.get("id", "")
	c.surname = d.get("surname", "")
	c.first_name = d.get("first_name", "")
	c.patronymic = d.get("patronymic", "")
	c.category = d.get("category", "doctor")
	c.role_name = d.get("role", "")
	c.age = int(d.get("age", 30))
	c.portrait_id = d.get("portrait", c.id)
	c.accent = Color.html(d.get("accent", "#8a9bb0"))
	c.skills = d.get("skills", {})
	c.key_skills = PackedStringArray(d.get("key_skills", []))
	c.traits = PackedStringArray(d.get("traits", []))
	c.start_fatigue = float(d.get("fatigue", 10))
	c.start_stress = float(d.get("stress", 10))
	c.bio = d.get("bio", "")
	c.motto = d.get("motto", "")
	return c
