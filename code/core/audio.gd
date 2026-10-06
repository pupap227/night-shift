extends Node
## Sound architecture: SFX by id + three layered music stems crossfaded by alarm level.
## Ids are mapped to files in res://data/audio.json — replace placeholder WAVs freely.

const MUSIC_LAYERS := ["ambient", "tension", "crisis"]
const POOL_SIZE := 10

var _sfx: Dictionary = {}
var _music: Dictionary = {}       # layer -> AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _intensity := 0
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music", -6.0)
	_ensure_bus("SFX", -3.0)
	var cfg: Dictionary = {}
	if FileAccess.file_exists("res://data/audio.json"):
		cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
	for id in cfg.get("sfx", {}):
		var s := _load_stream(cfg.sfx[id], false)
		if s:
			_sfx[id] = s
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for layer in MUSIC_LAYERS:
		var path: String = cfg.get("music", {}).get(layer, "")
		var stream := _load_stream(path, true) if path != "" else null
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		mp.stream = stream
		mp.volume_db = 0.0 if layer == "ambient" else -60.0
		add_child(mp)
		_music[layer] = mp


func start_music() -> void:
	for layer in _music:
		var mp: AudioStreamPlayer = _music[layer]
		if mp.stream and not mp.playing:
			mp.play()


func play(id: String, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> void:
	if muted or not _sfx.has(id):
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = _sfx[id]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## 0 = calm (ambient), 1 = tension layer in, 2 = crisis layer in.
func set_intensity(level: int) -> void:
	if level == _intensity:
		return
	_intensity = level
	var targets := {"ambient": 0.0, "tension": -60.0 if level < 1 else -4.0, "crisis": -60.0 if level < 2 else -2.0}
	for layer in targets:
		var mp: AudioStreamPlayer = _music.get(layer)
		if mp:
			create_tween().tween_property(mp, "volume_db", targets[layer], 2.5)


func set_muted(v: bool) -> void:
	muted = v
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), v)


func _ensure_bus(bus_name: String, db: float) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_volume_db(i, db)
	AudioServer.set_bus_send(i, "Master")


func _load_stream(path: String, loop: bool) -> AudioStream:
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	elif FileAccess.file_exists(path):
		s = AudioStreamWAV.load_from_file(path)
	if s is AudioStreamWAV and loop:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	return s
