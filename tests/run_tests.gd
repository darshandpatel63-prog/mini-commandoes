extends SceneTree
## Minimal headless test runner (no addon, per blueprint decision D5).
## Run: godot --headless --path . --script res://tests/run_tests.gd
## Exit code 0 = all pass. Add tests as `func test_*()` that call check().

var _fails := 0
var _passes := 0

func check(cond: bool, msg: String) -> void:
	if cond: _passes += 1
	else:
		_fails += 1
		printerr("FAIL: " + msg)

func _init() -> void:
	var reg = load("res://src/autoload/data_registry.gd").new()
	reg.reload_all()
	test_data_loads(reg)
	test_character_skill_slots(reg)
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
