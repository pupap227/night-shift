extends Node
## Headless simulation smoke test: godot --headless --path . scenes/debug/sim_test.tscn

func _ready() -> void:
	var g = Game
	g.start()
	g.paused = true
	print("staff: ", g.staff.size(), " events: ", g.db.events.size(), " types: ", g.db.patient_types.size())
	g.notify.connect(func(t, tone, _tile): print("  [%s] %s %s" % [g.clock_string(), tone, t]))
	g.event_arrived.connect(func(ev): print("EVENT %s %s" % [g.clock_string(), ev.data.title]))
	for m in 481:
		g._last_tick = m
		g.minutes = m
		g._tick_minute(m)
		# naive autoplayer: accept everything, assign first fitting free staff
		for ev in g.pending_events():
			g.resolve_event(ev, ev.data.choices[0].id)
		for c in g.active_cases():
			for i in c.slots.size():
				if c.slots[i] != "":
					continue
				for s in g.staff.values():
					if s.is_free():
						var p = g.preview(s.id, {"case": c.uid})
						if p.ok and p.slot == i and p.fit == 2:
							g.assign(s.id, {"case": c.uid})
							break
		if g.ended:
			break
	print("END treated=%d deaths=%d money=%d rep=%d alarm_peak=%d" % [g.treated, g.deaths, g.money, g.reputation, g.alarm_peak_level])
	for s in g.staff.values():
		print("  %s fat=%d str=%d done=%d" % [s.data.surname, s.fatigue, s.stress, s.cases_done])
	get_tree().quit()
