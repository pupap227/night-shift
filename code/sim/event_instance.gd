class_name EventInstance
extends RefCounted
## A fired event awaiting (or past) the player's decision.

var uid := 0
var data: EventData
var arrived_at := 0.0
var deadline := 0.0
var resolved := false
var choice_id := ""
var body_text := ""
var case_uids: Array[int] = []
var auto_resolved := false


func choice(choice_id_: String) -> Dictionary:
	for c in data.choices:
		if c.get("id", "") == choice_id_:
			return c
	return {}
