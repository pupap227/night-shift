class_name PatientTypeData
extends Resource
## A patient (or incident) archetype. Stages are a pipeline through departments:
##   {"department": "er", "duration": 15, "label": "...",
##    "slots": [{"label": "Хирург", "any": ["surgery"], "min": 7}]}

@export var id: String = ""
@export var name: String = ""
@export var icon: String = "patients"
@export var is_patient: bool = true
@export var decay: float = 0.6            # condition loss per game minute while waiting
@export var reward: int = 0
@export var variants: Dictionary = {}     # variant_id -> Array[stage dict]
@export var success_text: String = ""
@export var fail_text: String = ""
@export var fail_effects: Array = []      # effects applied when condition reaches 0


func stages(variant: String) -> Array:
	if variants.has(variant):
		return variants[variant]
	return variants.values()[0]


static func from_dict(d: Dictionary) -> PatientTypeData:
	var p := PatientTypeData.new()
	p.id = d.get("id", "")
	p.name = d.get("name", "")
	p.icon = d.get("icon", "patients")
	p.is_patient = bool(d.get("is_patient", true))
	p.decay = float(d.get("decay", 0.6))
	p.reward = int(d.get("reward", 0))
	p.variants = d.get("variants", {})
	p.success_text = d.get("success_text", "")
	p.fail_text = d.get("fail_text", "")
	p.fail_effects = d.get("fail_effects", [])
	return p
