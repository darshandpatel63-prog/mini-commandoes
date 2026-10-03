extends RefCounted
## Pure settings logic (no engine singletons) so it is unit-testable headless.

const SECTION := "settings"
const DEFAULTS := {
	"music_volume": 0.8,
	"sfx_volume": 0.9,
	"voice_volume": 0.9,
	"graphics_quality": 1,
	"fps_limit": 60,
	"sensitivity": 1.0,
	"aim_mode": 0,
	"battery_mode": false,
	"language": "en",
}
const RANGES := {
	"music_volume": [0.0, 1.0],
	"sfx_volume": [0.0, 1.0],
	"voice_volume": [0.0, 1.0],
	"sensitivity": [0.5, 2.0],
}
const ALLOWED := {
	"graphics_quality": [0, 1, 2],
	"fps_limit": [30, 60, 90],
	"aim_mode": [0, 1],
	"language": ["en"],
}

var values: Dictionary = {}

func _init() -> void:
	values = DEFAULTS.duplicate(true)

func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

## Validates type and range; returns false (and changes nothing) for invalid input.
func set_value(key: String, v: Variant) -> bool:
	if not DEFAULTS.has(key):
		return false
	var d: Variant = DEFAULTS[key]
	var t: int = typeof(v)
	match typeof(d):
		TYPE_BOOL:
			if t != TYPE_BOOL:
				return false
			values[key] = v
		TYPE_FLOAT:
			if t != TYPE_FLOAT and t != TYPE_INT:
				return false
			var f: float = float(v)
			if is_nan(f) or is_inf(f):
				return false
			var r: Array = RANGES.get(key, [0.0, 1.0])
			values[key] = clampf(f, float(r[0]), float(r[1]))
		TYPE_INT:
			if t != TYPE_INT and t != TYPE_FLOAT:
				return false
			var iv: int = int(v)
			var allowed_i: Array = ALLOWED.get(key, [])
			if not allowed_i.has(iv):
				return false
			values[key] = iv
		TYPE_STRING:
			if t != TYPE_STRING:
				return false
			var allowed_s: Array = ALLOWED.get(key, [])
			if not allowed_s.has(v):
				return false
			values[key] = v
		_:
			return false
	return true

func load_from(path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	for key in DEFAULTS:
		if cfg.has_section_key(SECTION, key):
			set_value(key, cfg.get_value(SECTION, key))  # invalid values ignored -> default stays
	return true

func save_to(path: String) -> bool:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value(SECTION, key, values[key])
	return cfg.save(path) == OK
