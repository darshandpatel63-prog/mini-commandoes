extends RefCounted
## controls.json model (HUD layout + haptics), versioned separately from the gameplay profile.

const SCHEMA := 1
const HudLayout := preload("res://src/core/hud_layout.gd")
const HapticConfig := preload("res://src/core/haptic_config.gd")

static func defaults(d: Dictionary) -> Dictionary:
	return {"layout_preset": "default", "hud": HudLayout.default_layout(d), "haptics": HapticConfig.default_config(d)}

static func migrate(d: Dictionary, data: Dictionary, _from_version: int) -> Dictionary:
	var out: Dictionary = defaults(d)
	if typeof(data.get("hud")) == TYPE_DICTIONARY:
		out["hud"] = data["hud"]            # clamped against the real screen when loaded (sanitize)
	if typeof(data.get("layout_preset")) == TYPE_STRING:
		out["layout_preset"] = String(data["layout_preset"])
	out["haptics"] = HapticConfig.sanitize(d, data.get("haptics"))
	return out
