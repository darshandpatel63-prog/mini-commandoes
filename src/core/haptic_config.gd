extends RefCounted
## Haptic settings model + resolution. Master switch/intensity + per-control overrides.
## Output = {fire, duration_ms, amplitude}. Amplitude (0..1) is passed to Android; phones without amplitude control
## ignore it and honour only the duration, which is why presets also differ in duration (documented limitation).

const PRESET_BY_CONTROL := {"fire": "medium", "jump": "low", "melee": "medium", "grenade": "medium", "skill": "high",
	"pet": "low", "reload": "low", "jet": "low", "swap": "low", "interact": "low", "heal": "medium", "ep_item": "medium",
	"crouch": "low", "move": "low", "aim": "low", "ui_button": "low"}

static func _num(v: Variant, fallback: float) -> float:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		var f: float = float(v)
		if not (is_nan(f) or is_inf(f)):
			return f
	return fallback

static func make_control(d: Dictionary, preset_name: String) -> Dictionary:
	if preset_name == "off":
		return {"enabled": false, "preset": "off", "intensity": 0.0, "duration_ms": 0}
	var p: Dictionary = d["rules"]["haptics"]["presets"][preset_name]
	return {"enabled": true, "preset": preset_name, "intensity": float(p["intensity"]), "duration_ms": int(p["duration_ms"])}

static func default_config(d: Dictionary) -> Dictionary:
	var c: Dictionary = {}
	for k in PRESET_BY_CONTROL:
		c[k] = make_control(d, String(PRESET_BY_CONTROL[k]))
	return {"master_enabled": true, "master_intensity": 1.0, "controls": c}

static func resolve(d: Dictionary, cfg: Dictionary, control_id: String) -> Dictionary:
	if not bool(cfg["master_enabled"]):
		return {"fire": false}
	var controls: Dictionary = cfg["controls"]
	if not controls.has(control_id):
		return {"fire": false}
	var c: Dictionary = controls[control_id]
	if not bool(c["enabled"]):
		return {"fire": false}
	var amp: float = clampf(float(c["intensity"]) * float(cfg["master_intensity"]), 0.0, 1.0)
	if amp <= 0.001:
		return {"fire": false}
	var rng: Array = d["rules"]["haptics"]["duration_range_ms"]
	return {"fire": true, "duration_ms": int(clampf(float(c["duration_ms"]), float(rng[0]), float(rng[1]))),
		"amplitude": snappedf(amp, 0.0001)}

## Repairs a stored/loaded config: unknown controls dropped, missing ones defaulted, numbers clamped.
static func sanitize(d: Dictionary, cfg: Variant) -> Dictionary:
	var base: Dictionary = default_config(d)
	if typeof(cfg) != TYPE_DICTIONARY:
		return base
	var out: Dictionary = base.duplicate(true)
	out["master_enabled"] = bool(cfg.get("master_enabled", true)) if typeof(cfg.get("master_enabled", true)) == TYPE_BOOL else true
	out["master_intensity"] = clampf(_num(cfg.get("master_intensity"), 1.0), 0.0, 1.0)
	var rng: Array = d["rules"]["haptics"]["duration_range_ms"]
	var stored: Variant = cfg.get("controls", {})
	if typeof(stored) == TYPE_DICTIONARY:
		for k in base["controls"]:
			var e: Variant = stored.get(k)
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var pr: String = String(e.get("preset", "custom")) if typeof(e.get("preset", "custom")) == TYPE_STRING else "custom"
			out["controls"][k] = {
				"enabled": bool(e.get("enabled", true)) if typeof(e.get("enabled", true)) == TYPE_BOOL else true,
				"preset": pr,
				"intensity": clampf(_num(e.get("intensity"), 0.5), 0.0, 1.0),
				"duration_ms": int(clampf(_num(e.get("duration_ms"), 30.0), 0.0, float(rng[1]))),
			}
	return out

static func with_preset(d: Dictionary, cfg: Dictionary, control_id: String, preset_name: String) -> Dictionary:
	var out: Dictionary = cfg.duplicate(true)
	if out["controls"].has(control_id) and (preset_name == "off" or d["rules"]["haptics"]["presets"].has(preset_name)):
		out["controls"][control_id] = make_control(d, preset_name)
	return out
