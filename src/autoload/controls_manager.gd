extends Node
## HUD layout + haptic settings persistence (user://controls.json, schema 1).

const SaveIO := preload("res://src/core/save_io.gd")
const ControlsData := preload("res://src/core/controls_data.gd")
const HudLayout := preload("res://src/core/hud_layout.gd")
const HapticConfig := preload("res://src/core/haptic_config.gd")
const PATH := "user://controls.json"

var layout_preset: String = "default"
var hud: Dictionary = {}
var haptics: Dictionary = {}
var load_source: String = "none"

func _ready() -> void:
	load_data()

func screen_size() -> Vector2:
	var s: Vector2 = get_viewport().get_visible_rect().size
	if s.x < 100.0 or s.y < 100.0:
		return Vector2(2400, 1080)
	return s

func load_data() -> void:
	var d: Dictionary = DataRegistry.bundle()
	var r: Dictionary = SaveIO.read(PATH)
	load_source = String(r["source"])
	var data: Dictionary = ControlsData.defaults(d)
	if load_source != "none":
		data = ControlsData.migrate(d, r["data"], int(r["version"]))
	layout_preset = String(data["layout_preset"])
	haptics = data["haptics"]
	hud = HudLayout.sanitize(d, data["hud"], screen_size())

func save_data() -> bool:
	return SaveIO.write(PATH, {"layout_preset": layout_preset, "hud": hud, "haptics": haptics}, ControlsData.SCHEMA)

func set_hud(layout: Dictionary, preset_name: String) -> bool:
	hud = HudLayout.sanitize(DataRegistry.bundle(), layout, screen_size())
	layout_preset = preset_name
	return save_data()

func set_haptics(cfg: Dictionary) -> bool:
	haptics = HapticConfig.sanitize(DataRegistry.bundle(), cfg)
	return save_data()
