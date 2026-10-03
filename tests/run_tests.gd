extends SceneTree
## Headless test runner (no addon, blueprint D5).
## Run: godot --headless --path . --script res://tests/run_tests.gd   (exit code 0 = all pass)

const SaveIO := preload("res://src/core/save_io.gd")
const SettingsStore := preload("res://src/core/settings_store.gd")
const ProfileData := preload("res://src/core/profile_data.gd")

var _fails: int = 0
var _passes: int = 0

func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("FAIL: " + msg)

func _init() -> void:
	var reg = load("res://src/autoload/data_registry.gd").new()
	reg.reload_all()
	test_data_loads(reg)
	test_character_skill_slots(reg)
	test_profile_defaults_reference_real_content(reg)
	test_save_roundtrip()
	test_save_backup_recovery()
	test_save_tamper_detected()
	test_settings_defaults_and_validation()
	test_settings_persistence()
	test_profile_migrate_and_character()
	print("tests: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)

func test_data_loads(reg) -> void:
	check(reg.load_errors.is_empty(), "data load errors: %s" % [reg.load_errors])
	check(reg.count("characters") >= 2, "need >= 2 characters")
	check(reg.count("maps") == 5, "need 5 maps in data")

func test_character_skill_slots(reg) -> void:
	for id in reg.tables.get("characters", {}):
		var c: Dictionary = reg.get_entry("characters", id)
		check(c.get("passives", []).size() == 4, "%s must have 4 passives" % id)
		check(not reg.get_entry("skills", c.get("active", "")).is_empty(), "%s active skill resolves" % id)
		check(not reg.get_entry("skills", c.get("pet_skill", "")).is_empty(), "%s pet skill resolves" % id)

func test_profile_defaults_reference_real_content(reg) -> void:
	var d: Dictionary = ProfileData.defaults()
	check(not reg.get_entry("characters", d["selected_character"]).is_empty(), "default character exists")
	check(not reg.get_entry("pets", d["selected_pet"]).is_empty(), "default pet exists")
	var lo: Dictionary = d["loadout"]
	check(not reg.get_entry("weapons", lo["primary"]).is_empty(), "default primary exists")
	check(not reg.get_entry("weapons", lo["secondary"]).is_empty(), "default secondary exists")
	check(not reg.get_entry("throwables", lo["throwable"]).is_empty(), "default throwable exists")
	var c: Dictionary = reg.get_entry("characters", d["selected_character"])
	check(c.get("pet", "") == d["selected_pet"], "default pet matches default character")

func test_save_roundtrip() -> void:
	var path := "user://_t_profile.json"
	SaveIO.remove_all(path)
	check(SaveIO.write(path, {"name": "A", "n": 5, "list": [1, 2]}, 1), "write succeeds")
	var r: Dictionary = SaveIO.read(path)
	check(r["source"] == "main", "read from main")
	check(r["data"]["name"] == "A" and int(r["data"]["n"]) == 5, "roundtrip values")
	check(int(r["version"]) == 1, "schema version kept")
	SaveIO.remove_all(path)
	check(SaveIO.read(path)["source"] == "none", "missing file -> none")

func test_save_backup_recovery() -> void:
	var path := "user://_t_profile2.json"
	SaveIO.remove_all(path)
	SaveIO.write(path, {"gen": 1}, 1)
	SaveIO.write(path, {"gen": 2}, 1)
	check(int(SaveIO.read(path)["data"]["gen"]) == 2, "latest generation read")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("garbage{{{")
	f.close()
	var r: Dictionary = SaveIO.read(path)
	check(r["source"] == "backup" and int(r["data"]["gen"]) == 1, "corrupt main -> previous generation from backup")
	var f2 := FileAccess.open(path + ".bak", FileAccess.WRITE)
	f2.store_string("also garbage")
	f2.close()
	check(SaveIO.read(path)["source"] == "none", "both corrupt -> none (defaults)")
	SaveIO.remove_all(path)

func test_save_tamper_detected() -> void:
	var path := "user://_t_profile3.json"
	SaveIO.remove_all(path)
	SaveIO.write(path, {"xp": 10}, 1)
	var f := FileAccess.open(path, FileAccess.READ)
	var txt: String = f.get_as_text()
	f.close()
	var parsed: Dictionary = JSON.parse_string(txt)
	parsed["body"] = String(parsed["body"]).replace("10", "99")
	var w := FileAccess.open(path, FileAccess.WRITE)
	w.store_string(JSON.stringify(parsed))
	w.close()
	check(SaveIO.read(path)["source"] == "none", "edited body fails integrity check")
	SaveIO.remove_all(path)

func test_settings_defaults_and_validation() -> void:
	var s := SettingsStore.new()
	check(float(s.get_value("music_volume")) == 0.8, "default music volume")
	check(s.set_value("music_volume", 5.0) and float(s.get_value("music_volume")) == 1.0, "volume clamped to 1.0")
	check(s.set_value("music_volume", -1) and float(s.get_value("music_volume")) == 0.0, "volume clamped to 0.0")
	check(not s.set_value("no_such_key", 1), "unknown key rejected")
	check(not s.set_value("fps_limit", 45), "fps 45 rejected")
	check(s.set_value("fps_limit", 90) and int(s.get_value("fps_limit")) == 90, "fps 90 accepted")
	check(not s.set_value("vibration", "yes"), "wrong type rejected")
	check(not s.set_value("sensitivity", NAN), "NaN rejected")
	check(not s.set_value("language", "xx"), "unknown language rejected")
	check(s.set_value("control_size", 9.0) and float(s.get_value("control_size")) == 1.4, "control size clamped")

func test_settings_persistence() -> void:
	var path := "user://_t_settings.cfg"
	var s := SettingsStore.new()
	s.set_value("sfx_volume", 0.3)
	s.set_value("vibration", false)
	s.set_value("fps_limit", 30)
	check(s.save_to(path), "settings save")
	var s2 := SettingsStore.new()
	check(s2.load_from(path), "settings load")
	check(is_equal_approx(float(s2.get_value("sfx_volume")), 0.3), "sfx persisted")
	check(bool(s2.get_value("vibration")) == false and int(s2.get_value("fps_limit")) == 30, "bool/int persisted")
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "fps_limit", 45)
	cfg.set_value("settings", "music_volume", 7.0)
	cfg.save(path)
	var s3 := SettingsStore.new()
	s3.load_from(path)
	check(int(s3.get_value("fps_limit")) == 60, "invalid stored fps ignored -> default")
	check(float(s3.get_value("music_volume")) == 1.0, "out-of-range stored volume clamped")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_profile_migrate_and_character() -> void:
	var m: Dictionary = ProfileData.migrate({"xp": 12.0, "custom": "keep"}, 1)
	check(m.has("selected_character") and m.has("loadout") and m.has("stats"), "missing keys filled")
	check(typeof(m["xp"]) == TYPE_INT and m["xp"] == 12, "xp coerced to int")
	check(m["custom"] == "keep", "unknown keys preserved")
	var p: Dictionary = ProfileData.apply_character(ProfileData.defaults(), {"id": "kade", "pet": "talon"})
	check(p["selected_character"] == "kade" and p["selected_pet"] == "talon", "apply_character sets character and pet")
	check(ProfileData.defaults()["selected_character"] == "rook", "apply_character does not mutate input")
