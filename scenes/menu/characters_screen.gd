extends "res://src/ui/screen_base.gd"
## CHARACTERS: identity only. Every commando has the same base HP/EP; skills, pet and weapons are chosen in LOADOUT.
## Portraits are baked from the Iron Vanguard model (tools/bake_sprites.py), one colorway per commando.

const LoadoutData := preload("res://src/core/loadout_data.gd")

var _d: Dictionary
var _detail: Label
var _select_btn: Button
var _try_btn: Button
var _msg: Label
var _portrait: TextureRect
var _shown_id: String = ""

func _build() -> void:
	_d = DataRegistry.bundle()
	add_header("CHARACTERS")
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(620, 0)
	left.add_theme_constant_override("separation", 16)
	body.add_child(left)
	var grp := ButtonGroup.new()
	for id in _d["characters"]:
		var c: Dictionary = _d["characters"][id]
		var b: Button = UIKit.button("%s\n%s" % [c["name"], c["role"]], _show.bind(String(id)))
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(0, 150)
		left.add_child(b)
		if String(id) == String(SaveManager.loadout()["character"]):
			b.button_pressed = true
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 16)
	body.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 24)
	panel.add_child(prow)
	_detail = UIKit.label("", 32, UITheme.C_TEXT, true)
	prow.add_child(_detail)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(300, 600)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	prow.add_child(_portrait)
	_msg = UIKit.label("", 28, UITheme.C_DAMAGE, true)
	right.add_child(_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_select_btn = UIKit.button("SELECT", _on_select, 0, "confirm")
	_select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_select_btn)
	_try_btn = UIKit.button("USE SUGGESTED BUILD", _on_try)
	_try_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_try_btn)
	right.add_child(row)
	_show(String(SaveManager.loadout()["character"]))

func _show(id: String) -> void:
	var c: Dictionary = _d["characters"].get(id, {})
	if c.is_empty():
		return
	_shown_id = id
	var rules: Dictionary = _d["rules"]
	var t := PackedStringArray()
	t.append("%s  -  %s" % [c["name"], c["role"]])
	t.append(String(c["theme"]))
	t.append("\"" + String(c["personality"]) + "\"")
	t.append("")
	t.append("Base HP %s   Base EP %s" % [UIKit.num(rules["base_hp"]), UIKit.num(rules["base_ep"])])
	t.append("Identical for every commando. Characters differ in looks, personality and role flavor only.")
	t.append("")
	t.append("Your skills, pet, weapons and armor are chosen in LOADOUT, so any commando can use any build.")
	t.append("")
	var pid: String = String(c["suggested_preset"])
	t.append("Suggested build: " + pid.capitalize())
	_detail.text = "\n".join(t)
	var ppath: String = "res://assets/art/commando/portrait_%s.png" % id
	_portrait.texture = load(ppath) if ResourceLoader.exists(ppath) else null
	_msg.text = ""
	var is_sel: bool = String(SaveManager.loadout()["character"]) == _shown_id
	_select_btn.text = "SELECTED" if is_sel else "SELECT"
	_select_btn.disabled = is_sel

func _on_select() -> void:
	SaveManager.select_character(_shown_id)
	_show(_shown_id)

func _on_try() -> void:
	var c: Dictionary = _d["characters"].get(_shown_id, {})
	for p in _d["presets"]:
		if String(p["id"]) == String(c.get("suggested_preset", "")):
			var lo: Dictionary = LoadoutData.normalize(p["loadout"])
			lo["character"] = _shown_id
			var errs: Array = SaveManager.set_loadout(lo)
			_msg.text = "" if errs.is_empty() else "Suggested build could not be applied."
			_show(_shown_id)
			return
