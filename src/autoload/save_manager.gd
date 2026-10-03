extends Node
## Profile persistence (atomic write + backup + integrity hash). See blueprint §26.

const SaveIO := preload("res://src/core/save_io.gd")
const ProfileData := preload("res://src/core/profile_data.gd")
const PATH := "user://profile.json"

signal profile_changed

var profile: Dictionary = {}
var load_source: String = "none"   # main | backup | none

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	var r: Dictionary = SaveIO.read(PATH)
	load_source = String(r["source"])
	if load_source == "none":
		profile = ProfileData.defaults()
	else:
		profile = ProfileData.migrate(r["data"], int(r["version"]))
	_validate_ids()

func _validate_ids() -> void:
	if DataRegistry.get_entry("characters", String(profile.get("selected_character", ""))).is_empty():
		profile = ProfileData.apply_character(profile, DataRegistry.get_entry("characters", "rook"))

func save_profile() -> bool:
	return SaveIO.write(PATH, profile, ProfileData.SCHEMA)

func select_character(id: String) -> bool:
	var c: Dictionary = DataRegistry.get_entry("characters", id)
	if c.is_empty():
		return false
	profile = ProfileData.apply_character(profile, c)
	profile_changed.emit()
	return save_profile()
