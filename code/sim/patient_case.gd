class_name PatientCase
extends RefCounted
## One patient (or incident) moving through department stages.

enum Status { INBOUND, WAITING, TREATING, DONE, DEAD, FAILED }

var uid := 0
var ptype: PatientTypeData
var variant := ""
var label := ""
var event_uid := -1
var condition := 100.0
var stages: Array = []
var stage_index := 0
var progress := 0.0
var slots: Array = []            # staff id per slot of the current stage, "" = empty
var status: int = Status.INBOUND
var arrive_at := 0.0
var route := ""
var blocked_reason := ""         # why treatment can't start (dept busy, staff walking…)
var complications := 0
var ended_at := -1.0
var ambulance_start := 0.0


func setup(t: PatientTypeData, v: String) -> void:
	ptype = t
	variant = v
	stages = t.stages(v)
	_reset_slots()


func stage() -> Dictionary:
	return stages[mini(stage_index, stages.size() - 1)]


func department() -> String:
	return stage().get("department", "er")


func slot_defs() -> Array:
	return stage().get("slots", [])


func duration() -> float:
	return float(stage().get("duration", 10))


func is_active() -> bool:
	return status == Status.INBOUND or status == Status.WAITING or status == Status.TREATING


func is_last_stage() -> bool:
	return stage_index >= stages.size() - 1


func has_staff(staff_id: String) -> bool:
	return slots.has(staff_id)


func open_slots() -> Array[int]:
	var r: Array[int] = []
	for i in slots.size():
		if slots[i] == "":
			r.append(i)
	return r


func missing_labels() -> PackedStringArray:
	var r := PackedStringArray()
	var defs := slot_defs()
	for i in slots.size():
		if slots[i] == "":
			r.append(defs[i].get("label", "?"))
	return r


func advance_stage() -> bool:
	if is_last_stage():
		return false
	stage_index += 1
	progress = 0.0
	_reset_slots()
	return true


func _reset_slots() -> void:
	slots = []
	for i in slot_defs().size():
		slots.append("")
