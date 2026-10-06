class_name Assignment
extends RefCounted
## Pure functions: how well does a staff member fit a slot / a case.

enum Fit { NONE, RISKY, GOOD }

const RISKY_MARGIN := 3


static func slot_skill(s: StaffMember, slot: Dictionary) -> float:
	var best := 0.0
	for sk in slot.get("any", []):
		best = maxf(best, s.skill(sk))
	return best


static func slot_fit(s: StaffMember, slot: Dictionary) -> int:
	var v := slot_skill(s, slot)
	var need := float(slot.get("min", 1))
	if v >= need:
		return Fit.GOOD
	if v >= need - RISKY_MARGIN and v >= 2.0:
		return Fit.RISKY
	return Fit.NONE


## Best open slot of the case's current stage for this staff member.
## Returns {index, fit, skill, label} or {index:-1}.
static func best_slot(s: StaffMember, c: PatientCase) -> Dictionary:
	var defs := c.slot_defs()
	var best := {"index": -1, "fit": Fit.NONE, "skill": -1.0, "label": "", "score": -1.0}
	for i in c.slots.size():
		if c.slots[i] != "" and c.slots[i] != s.id:
			continue
		var f := slot_fit(s, defs[i])
		if f == Fit.NONE:
			continue
		var sk := slot_skill(s, defs[i])
		# Prefer good fits, then the slot that most needs this person's specialty.
		var score: float = f * 100.0 + sk - float(defs[i].get("min", 0)) * 0.1
		if score > best.score:
			best = {"index": i, "fit": f, "skill": sk, "label": defs[i].get("label", ""), "score": score}
	return best


## Work speed contribution of a staff member in a slot (1.0 = nominal).
static func slot_speed(s: StaffMember, slot: Dictionary, alarm_level: int) -> float:
	var sk := slot_skill(s, slot)
	var need := maxf(1.0, float(slot.get("min", 1)))
	var k := clampf(0.75 + (sk - need) * 0.08, 0.6, 1.25)
	if sk < need:
		k = 1.0 - 0.5 * (1.0 + s.mod("risky_penalty"))
	return k * s.efficiency(alarm_level)
