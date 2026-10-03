extends Node
## Profile persistence (atomic write + backup + integrity hash). Loadouts are validated on load and before every save:
## an illegal combination is never written and never survives a load. See docs/loadout.md.

const SaveIO := preload("res://src/core/save_io.gd")
const ProfileData := preload("res://src/core/profile_data.gd")
const LoadoutData := preload("res://src/core/loadout_data.gd")
const Validator := preload("res://src/core/loadout_validator.gd")
const PATH := "user://profile.json"

signal profile_changed

var profile: Dictionary = {}
var load_source: String = "none"   # main | backup | none
var load_notes: PackedStringArray = []

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	load_notes.clear()
	var r: Dictionary = SaveIO.read(PATH)
	load_source = String(r["source"])
	if load_source == "none":
		profile = ProfileData.defaults()
	else:
		profile = ProfileData.migrate(r["data"], int(r["version"]))
	var d: Dictionary = DataRegistry.bundle()
	profile["loadout"] = LoadoutData.normalize(profile["loadout"])
	if Validator.validate(d, profile["loadout"]).size() > 0:
		load_notes.append("stored loadout was invalid, reset to default")
		profile["loadout"] = LoadoutData.default_loadout(d)
	profile["presets"] = LoadoutData.sanitize_presets(d, profile.get("presets"))

func save_profile() -> bool:
	return SaveIO.write(PATH, profile, ProfileData.SCHEMA)

func loadout() -> Dictionary:
	return (profile["loadout"] as Dictionary).duplicate(true)

func presets() -> Array:
	return (profile["presets"] as Array).duplicate(true)

## Returns validation error codes (empty = saved).
func set_loadout(lo: Dictionary) -> Array:
	var errs: Array = Validator.validate(DataRegistry.bundle(), lo)
	if errs.size() > 0:
		return errs
	profile["loadout"] = LoadoutData.normalize(lo)
	profile_changed.emit()
	save_profile()
	return []

func select_character(id: String) -> bool:
	if DataRegistry.get_entry("characters", id).is_empty():
		return false
	return set_loadout(LoadoutData.with_slot(loadout(), "character", 0, id)).is_empty()

## Returns error codes (empty = saved).
func save_preset(raw_name: String) -> Array:
	var r: Dictionary = LoadoutData.save_preset(DataRegistry.bundle(), presets(), raw_name, loadout())
	if bool(r["ok"]):
		profile["presets"] = r["presets"]
		profile_changed.emit()
		save_profile()
	return r["errors"]

func delete_preset(preset_name: String) -> void:
	profile["presets"] = LoadoutData.delete_preset(presets(), preset_name)
	profile_changed.emit()
	save_profile()
