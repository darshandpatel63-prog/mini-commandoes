extends "res://src/ui/screen_base.gd"
## LOADOUT: review and edit the complete build before a match. Every edit is validated; invalid builds are never saved.

const LoadoutData := preload("res://src/core/loadout_data.gd")
const Validator := preload("res://src/core/loadout_validator.gd")
const Combatant := preload("res://src/combat/combatant.gd")
const StatResolver := preload("res://src/combat/stat_resolver.gd")

var _d: Dictionary
var _lo: Dictionary
var _summary: Label
var _name_edit: LineEdit
var _msg: Label
var _custom_box: VBoxContainer

func _build() -> void:
	_d = DataRegistry.bundle()
	_lo = SaveManager.loadout()
	add_header("LOADOUT")
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var lscroll := ScrollContainer.new()
	lscroll.custom_minimum_size = Vector2(1120, 0)
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(lscroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	lscroll.add_child(rows)
	_slot_row(rows, "CHARACTER", _character_name(), _open_characters)
	_slot_row(rows, "ACTIVE SKILL", _skill_name(String(_lo.get("active", ""))), _open_picker.bind("active", 0))
	for i in 4:
		_slot_row(rows, "PASSIVE %d" % (i + 1), _skill_name(String(_lo["passives"][i])), _open_picker.bind("passive", i))
	var pet_id: String = String(_lo.get("pet", ""))
	_slot_row(rows, "PET", String(_d["pets"].get(pet_id, {}).get("name", "- empty -")) if pet_id != "" else "- empty -", _open_picker.bind("pet", 0))
	_slot_row(rows, "PRIMARY WEAPON", String(_d["weapons"].get(String(_lo["primary"]), {}).get("name", "?")), _open_picker.bind("primary", 0))
	_slot_row(rows, "SECONDARY WEAPON", String(_d["weapons"].get(String(_lo["secondary"]), {}).get("name", "?")), _open_picker.bind("secondary", 0))
	_slot_row(rows, "MELEE", String(_d["melee"].get(String(_lo["melee"]), {}).get("name", "?")), _open_picker.bind("melee", 0))
	_slot_row(rows, "GRENADE / UTILITY", String(_d["throwables"].get(String(_lo["throwable"]), {}).get("name", "?")), _open_picker.bind("throwable", 0))
	_armor_row(rows, "START HELMET", "start_helmet")
	_armor_row(rows, "START VEST", "start_vest")
	rows.add_child(UIKit.label("Higher armor levels (2-3) must be found as loot in a match.", 26, UITheme.C_TEXT_DIM, true))
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right)
	var rbox := VBoxContainer.new()
	rbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rbox.add_theme_constant_override("separation", 14)
	right.add_child(rbox)
	rbox.add_child(UIKit.label("BUILD SUMMARY", 44, UITheme.C_ACCENT))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary = UIKit.label("", 30, UITheme.C_TEXT, true)
	panel.add_child(_summary)
	rbox.add_child(panel)
	_msg = UIKit.label("", 28, UITheme.C_DAMAGE, true)
	rbox.add_child(_msg)
	rbox.add_child(UIKit.label("PRESETS", 44, UITheme.C_ACCENT))
	var built := GridContainer.new()
	built.columns = 2
	built.add_theme_constant_override("h_separation", 12)
	built.add_theme_constant_override("v_separation", 12)
	for p in _d["presets"]:
		var b: Button = UIKit.button(String(p["name"]), _apply_loadout.bind(p["loadout"]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		built.add_child(b)
	rbox.add_child(built)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name your build"
	_name_edit.max_length = int(_d["rules"]["loadout"]["preset_name_max"])
	_name_edit.custom_minimum_size = Vector2(0, 90)
	rbox.add_child(_name_edit)
	rbox.add_child(UIKit.button("SAVE CURRENT BUILD AS PRESET", _save_preset, 0, "confirm"))
	_custom_box = VBoxContainer.new()
	_custom_box.add_theme_constant_override("separation", 10)
	rbox.add_child(_custom_box)
	_refresh()

func _character_name() -> String:
	return String(_d["characters"].get(String(_lo.get("character", "")), {}).get("name", "?"))

func _skill_name(id: String) -> String:
	if id == "":
		return "- empty -"
	return String(_d["skills"].get(id, {}).get("name", id))

func _slot_row(parent: Control, label_text: String, value_text: String, on_press: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l: Label = UIKit.label(label_text, 28, UITheme.C_TEXT_DIM)
	l.custom_minimum_size = Vector2(300, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var b: Button = UIKit.button(value_text, on_press)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	parent.add_child(row)

func _armor_row(parent: Control, label_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l: Label = UIKit.label(label_text, 28, UITheme.C_TEXT_DIM)
	l.custom_minimum_size = Vector2(300, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var b: Button = UIKit.make_button("", 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	b.pressed.connect(_cycle_armor.bind(key, b))
	_armor_text(key, b)
	parent.add_child(row)

func _armor_text(key: String, b: Button) -> void:
	var lvl: int = int(_lo.get(key, 0))
	b.text = "None" if lvl == 0 else "Level %d" % lvl

func _cycle_armor(key: String, b: Button) -> void:
	var mx: int = int(_d["rules"]["loadout"]["start_armor_max_level"])
	var nxt: int = (int(_lo.get(key, 0)) + 1) % (mx + 1)
	_commit(LoadoutData.with_slot(_lo, key, 0, nxt))
	_armor_text(key, b)

func _commit(candidate: Dictionary) -> void:
	var errs: Array = SaveManager.set_loadout(candidate)
	if errs.is_empty():
		_lo = SaveManager.loadout()
		_msg.text = ""
	else:
		_msg.text = _error_text(errs)
	_refresh()

func _error_text(errs: Array) -> String:
	var t := PackedStringArray()
	for e in errs:
		t.append("- " + Validator.describe(String(e)))
	return "\n".join(t)

func _open_characters() -> void:
	SceneRouter.go(SceneRouter.CHARACTERS)

func _open_picker(kind: String, slot: int) -> void:
	SceneRouter.go(SceneRouter.BROWSER, {"kind": kind, "slot": slot})

func _apply_loadout(lo: Dictionary) -> void:
	_commit(LoadoutData.normalize(lo))
	SceneRouter.go(SceneRouter.LOADOUT)

func _save_preset() -> void:
	var errs: Array = SaveManager.save_preset(_name_edit.text)
	if errs.is_empty():
		_msg.text = ""
		_name_edit.text = ""
	else:
		var t := PackedStringArray()
		for e in errs:
			var code: String = String(e)
			if code == "E_PRESET_NAME":
				t.append("- Enter a name for the preset.")
			elif code == "E_PRESET_FULL":
				t.append("- Maximum custom presets reached. Delete one first.")
			else:
				t.append("- " + Validator.describe(code))
		_msg.text = "\n".join(t)
	_refresh()

func _load_custom(preset_name: String) -> void:
	for p in SaveManager.presets():
		if String(p["name"]) == preset_name:
			_apply_loadout(p["loadout"])
			return

func _delete_custom(preset_name: String) -> void:
	SaveManager.delete_preset(preset_name)
	_refresh()

func _refresh() -> void:
	var errs: Array = Validator.validate(_d, _lo)
	var st: Dictionary = Combatant.from_loadout(_d, _lo)
	var stats: Dictionary = StatResolver.of(_d["rules"], st, 0.0)
	var rules: Dictionary = _d["rules"]
	var cost: int = 0
	for p in _lo["passives"]:
		if String(p) != "":
			cost += int(_d["skills"].get(String(p), {}).get("cost", 0))
	var t := PackedStringArray()
	t.append("Max HP  %s   (same for every commando)" % UIKit.num(st["max_hp"]))
	t.append("Max EP  %s   EP recovery  %s/s" % [UIKit.num(float(rules["base_ep"]) + float(stats["ep_max_bonus"])), UIKit.num(float(rules["ep"]["regen_per_s"]) * float(stats["ep_regen_mult"]))])
	t.append("Damage taken  x%s   Headshot extra  x%s" % [UIKit.num(stats["damage_taken_mult"]), UIKit.num(stats["head_damage_taken_mult"])])
	t.append("Skill cooldowns  x%s   Item apply time  x%s" % [UIKit.num(stats["skill_cooldown_mult"]), UIKit.num(stats["heal_apply_time_mult"])])
	if float(stats["ep_barrier"]) > 0.0:
		t.append("EP barrier: absorbs %d%% of damage using EP" % int(roundf(float(stats["ep_barrier"]) * 100.0)))
	t.append("Passive power budget  %d / %d" % [cost, int(rules["loadout"]["passive_budget"])])
	var hl: int = int(st["helmet"]["level"])
	var vl: int = int(st["vest"]["level"])
	t.append("Start armor: helmet L%d (%s dur), vest L%d (%s dur)" % [hl, UIKit.num(st["helmet"]["dur"]), vl, UIKit.num(st["vest"]["dur"])])
	t.append("")
	t.append("BUILD VALID" if errs.is_empty() else "INVALID BUILD:\n" + _error_text(errs))
	_summary.text = "\n".join(t)
	for c in _custom_box.get_children():
		c.queue_free()
	var list: Array = SaveManager.presets()
	if list.size() > 0:
		_custom_box.add_child(UIKit.label("YOUR PRESETS", 32, UITheme.C_TEXT_DIM))
	for p in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var pname: String = String(p["name"])
		var lb: Button = UIKit.button(pname, _load_custom.bind(pname))
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lb)
		row.add_child(UIKit.button("DELETE", _delete_custom.bind(pname), 220, "back"))
		_custom_box.add_child(row)
