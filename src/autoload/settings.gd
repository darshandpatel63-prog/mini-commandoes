extends Node
## Settings autoload: persistence + applying runtime effects. Logic lives in settings_store.gd.

const SettingsStore := preload("res://src/core/settings_store.gd")
const PATH := "user://settings.cfg"

signal changed(key: String)

var store = SettingsStore.new()

func _ready() -> void:
	store.load_from(PATH)
	apply_runtime()

func get_value(key: String) -> Variant:
	return store.get_value(key)

func set_value(key: String, v: Variant) -> bool:
	if not store.set_value(key, v):
		return false
	store.save_to(PATH)
	apply_runtime()
	changed.emit(key)
	return true

func apply_runtime() -> void:
	var fps: int = int(store.get_value("fps_limit"))
	if bool(store.get_value("battery_mode")):
		fps = mini(fps, 30)
	Engine.max_fps = fps
