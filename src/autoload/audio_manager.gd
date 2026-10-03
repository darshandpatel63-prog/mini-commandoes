extends Node
## Buses + pooled UI/SFX playback. Streams are looked up by id; missing files are skipped quietly.

const BUSES := ["Music", "SFX", "Voice", "UI"]
const SFX_DIR := "res://assets/audio/sfx/"

var _cache: Dictionary = {}
var _ui_pool: Array[AudioStreamPlayer] = []
var _missing: Dictionary = {}

func _ready() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_ui_pool.append(p)
	Settings.changed.connect(func(_k: String) -> void: apply_volumes())
	apply_volumes()

func apply_volumes() -> void:
	_set_bus("Music", float(Settings.get_value("music_volume")))
	_set_bus("SFX", float(Settings.get_value("sfx_volume")))
	_set_bus("UI", float(Settings.get_value("sfx_volume")))
	_set_bus("Voice", float(Settings.get_value("voice_volume")))

func _set_bus(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))

func _stream(file_id: String) -> AudioStream:
	if _cache.has(file_id):
		return _cache[file_id]
	var path: String = SFX_DIR + file_id + ".wav"
	if not ResourceLoader.exists(path):
		if not _missing.has(file_id):
			_missing[file_id] = true
			push_warning("audio missing: " + path)
		return null
	var s: AudioStream = load(path)
	_cache[file_id] = s
	return s

func play_ui(id: String) -> void:
	var s: AudioStream = _stream("ui_" + id)
	if s == null:
		return
	for p in _ui_pool:
		if not p.playing:
			p.stream = s
			p.play()
			return
	_ui_pool[0].stream = s
	_ui_pool[0].play()
