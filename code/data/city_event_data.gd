class_name CityEventData
extends Resource
## Narrative city news. No direct gameplay, but may mark a district on the map.

@export var id: String = ""
@export var time: int = 0
@export var icon: String = "news"
@export var title: String = ""
@export var district: String = ""
@export var tone: String = "info"    # info | warn | danger


static func from_dict(d: Dictionary) -> CityEventData:
	var c := CityEventData.new()
	c.id = d.get("id", "")
	c.time = EventData.parse_time(d.get("time", "22:00"))
	c.icon = d.get("icon", "news")
	c.title = d.get("title", "")
	c.district = d.get("district", "")
	c.tone = d.get("tone", "info")
	return c
