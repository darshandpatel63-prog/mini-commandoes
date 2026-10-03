extends "res://src/ui/screen_base.gd"
## CHARACTERS: browse the roster, see stats + skills + pet, SELECT saves to the profile.
## Character art preview is a PLACEHOLDER until the rig exists (Phase 4).

var _detail: Label
var _select_btn: Button
var _shown_id: String = ""

func _build() -> void:
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
	for id in DataRegistry.tables["characters"]:
		var c: Dictionary = DataRegistry.get_entry("characters", id)
		var cid: String = String(id)
		var b: Button = UIKit.button("%s\n%s" % [c["name"], c["role"]], _show.bind(cid))
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(0, 150)
		left.add_child(b)
	left.add_child(UIKit.label("UI PLACEHOLDER: character art preview arrives with the rig (Phase 4).", 26, UITheme.C_TEXT_DIM, true))
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
	_detail = UIKit.label("", 32, UITheme.C_TEXT, true)
	panel.add_child(_detail)
	_select_btn = UIKit.button("SELECT", _on_select, 0, "confirm")
	right.add_child(_select_btn)
	_show(String(SaveManager.profile.get("selected_character", "rook")))

func _skill_line(skill_id: String) -> String:
	var s: Dictionary = DataRegistry.get_entry("skills", skill_id)
	if s.is_empty():
		return "- ?"
	var cd := ""
	if s.has("cooldown"):
		cd = " [%ds cooldown]" % int(s["cooldown"])
	return "- %s%s: %s" % [s["name"], cd, s["desc"]]

func _show(id: String) -> void:
	var c: Dictionary = DataRegistry.get_entry("characters", id)
	if c.is_empty():
		return
	_shown_id = id
	var st: Dictionary = c["stats"]
	var pet: Dictionary = DataRegistry.get_entry("pets", String(c["pet"]))
	var t := PackedStringArray()
	t.append("%s  -  %s" % [c["name"], c["role"]])
	t.append(String(c["theme"]))
	t.append("")
	t.append("HP %d   Armor cap %d   Move x%s   Jet fuel x%s   Melee x%s" % [
		int(st["hp"]), int(st["armor_cap"]), str(st["move"]), str(st["jet_fuel"]), str(st["melee"])])
	t.append("Weapon affinity: " + ", ".join(PackedStringArray(c["affinity"])))
	t.append("")
	t.append("ACTIVE SKILL")
	t.append(_skill_line(String(c["active"])))
	t.append("")
	t.append("PASSIVES")
	for p in c["passives"]:
		t.append(_skill_line(String(p)))
	t.append("")
	t.append("PET: %s (%s)" % [pet.get("name", "?"), pet.get("kind", "?")])
	t.append(_skill_line(String(c["pet_skill"])))
	t.append("")
	t.append("Values are unbalanced starting numbers (tuned in playtests).")
	_detail.text = "\n".join(t)
	_refresh_select()

func _refresh_select() -> void:
	var is_sel: bool = String(SaveManager.profile.get("selected_character", "")) == _shown_id
	_select_btn.text = "SELECTED" if is_sel else "SELECT"
	_select_btn.disabled = is_sel

func _on_select() -> void:
	SaveManager.select_character(_shown_id)
	_refresh_select()
