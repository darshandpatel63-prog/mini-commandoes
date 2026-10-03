extends "res://src/ui/screen_base.gd"
## Picker / browser. Equip kinds (active, passive, pet, primary, secondary, melee, throwable) edit the loadout;
## browse kinds (skills, arsenal, maps) are information only. Candidates are validated BEFORE they can be equipped.

const LoadoutData := preload("res://src/core/loadout_data.gd")
const Validator := preload("res://src/core/loadout_validator.gd")
const EffectText := preload("res://src/ui/effect_text.gd")

const EQUIP_KINDS := ["active", "passive", "pet", "primary", "secondary", "melee", "throwable"]
const CLEARABLE := ["active", "passive", "pet"]
const TITLES := {"active": "ACTIVE SKILL", "passive": "PASSIVE SKILL", "pet": "PET", "primary": "PRIMARY WEAPON",
	"secondary": "SECONDARY WEAPON", "melee": "MELEE", "throwable": "GRENADE / UTILITY",
	"skills": "SKILLS  (info)", "arsenal": "ARSENAL  (info)", "maps": "MAPS  (info)"}

var _d: Dictionary
var _lo: Dictionary
var _kind: String = "skills"
var _slot: int = 0
var _items: Array = []
var _shown: Array = []
var _cats: Array = ["All"]
var _cat_index: int = 0
var _sel: int = -1
var _list: VBoxContainer
var _detail: Label
var _msg: Label
var _equip_btn: Button
var _clear_btn: Button
var _filter_btn: Button

func _build() -> void:
	_d = DataRegistry.bundle()
	_lo = SaveManager.loadout()
	_kind = String(SceneRouter.params.get("kind", "skills"))
	_slot = int(SceneRouter.params.get("slot", 0))
	var title: String = String(TITLES.get(_kind, "INFO"))
	if _kind == "passive":
		title = "PASSIVE SLOT %d" % (_slot + 1)
	add_header(title)
	_items = _make_items()
	for it in _items:
		if not _cats.has(String(it["cat"])) and String(it["cat"]) != "":
			_cats.append(String(it["cat"]))
	if _cats.size() > 2:
		_filter_btn = UIKit.button("", _next_filter)
		content.add_child(_filter_btn)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var lscroll := ScrollContainer.new()
	lscroll.custom_minimum_size = Vector2(700, 0)
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(lscroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	lscroll.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	var rscroll := ScrollContainer.new()
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rscroll)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(panel)
	_detail = UIKit.label("", 30, UITheme.C_TEXT, true)
	panel.add_child(_detail)
	_msg = UIKit.label("", 28, UITheme.C_DAMAGE, true)
	right.add_child(_msg)
	if EQUIP_KINDS.has(_kind):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_equip_btn = UIKit.button("EQUIP", _on_equip, 0, "confirm")
		_equip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_equip_btn)
		if CLEARABLE.has(_kind):
			_clear_btn = UIKit.button("UNEQUIP", _on_unequip, 0, "back")
			_clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(_clear_btn)
		right.add_child(row)
	_refill()

func _on_back() -> void:
	if EQUIP_KINDS.has(_kind):
		SceneRouter.go(SceneRouter.LOADOUT)
	else:
		SceneRouter.go(SceneRouter.MAIN_MENU)

func _make_items() -> Array:
	var out: Array = []
	match _kind:
		"active", "passive", "skills":
			var want: String = _kind if _kind != "skills" else ""
			var all: Array = _d["skills"].values()
			all.sort_custom(_skill_less)
			for s in all:
				if want != "" and String(s["kind"]) != want:
					continue
				var prefix: String = "[%s] " % String(s["kind"]).to_upper() if _kind == "skills" else ""
				out.append({"id": s["id"], "cat": s["cat"], "title": prefix + String(s["name"]), "body": EffectText.skill_text(_d, s)})
		"pet":
			for id in _d["pets"]:
				var p: Dictionary = _d["pets"][id]
				var s: Dictionary = _d["skills"][String(p["skill"])]
				out.append({"id": id, "cat": "", "title": p["name"], "body": "%s (%s)\nFollows at %d px. Pets are non-combatants and can be paired with ANY commando.\n\nABILITY\n%s" % [p["kind"], p["move"], int(p["follow_dist"]), EffectText.skill_text(_d, s)]})
		"primary", "secondary", "arsenal":
			var classes: Array = []
			if _kind == "primary":
				classes = _d["rules"]["loadout"]["primary_classes"]
			elif _kind == "secondary":
				classes = _d["rules"]["loadout"]["secondary_classes"]
			for id in _d["weapons"]:
				var w: Dictionary = _d["weapons"][id]
				if classes.size() > 0 and not classes.has(String(w["cls"])):
					continue
				var dmg: String = UIKit.num(w["dmg"])
				if w.has("pellets"):
					dmg += " x%d pellets" % int(w["pellets"])
				out.append({"id": id, "cat": w["cls"], "title": "%s (%s)" % [w["name"], w["cls"]],
					"body": "%s - %s\nDamage %s   RPM %s   Mag %s   Reload %s s\nRange %s px   Spread %s   Recoil %s\nHeadshot x%s   Armor penetration %d%%\nAmmo: %s   Projectile: %s\n\nSpecial: %s\n\nUnbalanced starting values." % [
						w["name"], w["cls"], dmg, UIKit.num(w["rpm"]), UIKit.num(w["mag"]), UIKit.num(w["reload"]),
						UIKit.num(w["range"]), UIKit.num(w["spread"]), UIKit.num(w["recoil"]), UIKit.num(w["head_mult"]),
						int(roundf(float(w["armor_pen"]) * 100.0)), w["ammo"], w["proj"], w["special"]]})
			if _kind == "arsenal":
				for id in _d["melee"]:
					var m: Dictionary = _d["melee"][id]
					out.append({"id": id, "cat": "melee", "title": "%s (melee)" % m["name"], "body": _melee_text(m)})
				for id in _d["throwables"]:
					out.append({"id": id, "cat": "throwable", "title": "%s (throwable)" % _d["throwables"][id]["name"], "body": _throw_text(_d["throwables"][id])})
		"melee":
			for id in _d["melee"]:
				out.append({"id": id, "cat": "", "title": _d["melee"][id]["name"], "body": _melee_text(_d["melee"][id])})
		"throwable":
			for id in _d["throwables"]:
				out.append({"id": id, "cat": "", "title": _d["throwables"][id]["name"], "body": _throw_text(_d["throwables"][id])})
		"maps":
			for id in DataRegistry.tables["maps"]:
				var mp: Dictionary = DataRegistry.tables["maps"][id]
				out.append({"id": id, "cat": "", "title": mp["name"],
					"body": "%s\n%s\nSize: %d x %d px\nMax players: %d\nPlanned for: %s\nStatus: %s (not playable yet)" % [
						mp["name"], mp["theme"], int(mp["size"][0]), int(mp["size"][1]), int(mp["max_players"]), mp["milestone"], mp["status"]]})
	return out

func _melee_text(m: Dictionary) -> String:
	return "%s\nDamage %s   Attack time %s s\nKnockback x%s   Armor break %s\n\n%s" % [m["name"], UIKit.num(m["dmg"]), UIKit.num(m["rate"]), UIKit.num(m["knockback"]), UIKit.num(m["armor_break"]), m["special"]]

func _throw_text(g: Dictionary) -> String:
	return "%s\nFuse %s s   Radius %s px   Damage %s\nEffect: %s" % [g["name"], UIKit.num(g["fuse"]), UIKit.num(g["radius"]), UIKit.num(g["dmg"]), String(g["effect"]).replace("_", " ")]

func _next_filter() -> void:
	_cat_index = (_cat_index + 1) % _cats.size()
	_refill()

func _equipped_id() -> String:
	match _kind:
		"active": return String(_lo.get("active", ""))
		"passive": return String(_lo["passives"][_slot])
		"pet": return String(_lo.get("pet", ""))
		"primary": return String(_lo.get("primary", ""))
		"secondary": return String(_lo.get("secondary", ""))
		"melee": return String(_lo.get("melee", ""))
		"throwable": return String(_lo.get("throwable", ""))
	return ""

func _refill() -> void:
	if _filter_btn != null:
		_filter_btn.text = "CATEGORY: %s   (tap to change)" % String(_cats[_cat_index]).to_upper()
	_shown = []
	for it in _items:
		if _cat_index == 0 or String(it["cat"]) == String(_cats[_cat_index]):
			_shown.append(it)
	for c in _list.get_children():
		c.queue_free()
	var grp := ButtonGroup.new()
	for i in _shown.size():
		var label_text: String = String(_shown[i]["title"])
		if EQUIP_KINDS.has(_kind) and String(_shown[i]["id"]) == _equipped_id():
			label_text += "   (equipped)"
		var b: Button = UIKit.button(label_text, _select.bind(i))
		b.toggle_mode = true
		b.button_group = grp
		_list.add_child(b)
		if i == 0:
			b.button_pressed = true
	if _shown.size() > 0:
		_select(0)
	else:
		_detail.text = "Nothing here."

func _select(i: int) -> void:
	_sel = i
	var it: Dictionary = _shown[i]
	var text: String = String(it["body"])
	_msg.text = ""
	if EQUIP_KINDS.has(_kind):
		var errs: Array = Validator.validate(_d, _candidate(String(it["id"])))
		var same: bool = String(it["id"]) == _equipped_id()
		if same:
			_msg.text = "Already equipped in this slot."
		elif errs.size() > 0:
			var t := PackedStringArray()
			for e in errs:
				t.append("- " + Validator.describe(String(e)))
			_msg.text = "Cannot equip:\n" + "\n".join(t)
		_equip_btn.disabled = same or errs.size() > 0
		if _clear_btn != null:
			_clear_btn.disabled = _equipped_id() == ""
	_detail.text = text

func _candidate(item_id: String) -> Dictionary:
	return LoadoutData.with_slot(_lo, _kind, _slot, item_id)

func _on_equip() -> void:
	if _sel < 0:
		return
	var errs: Array = SaveManager.set_loadout(_candidate(String(_shown[_sel]["id"])))
	if errs.is_empty():
		SceneRouter.go(SceneRouter.LOADOUT)
	else:
		_msg.text = "Cannot equip: " + Validator.describe(String(errs[0]))

func _on_unequip() -> void:
	var errs: Array = SaveManager.set_loadout(_candidate(""))
	if errs.is_empty():
		SceneRouter.go(SceneRouter.LOADOUT)
	else:
		_msg.text = "Cannot unequip: " + Validator.describe(String(errs[0]))

func _skill_less(a: Dictionary, b: Dictionary) -> bool:
	var order := {"active": 0, "passive": 1, "pet": 2}
	if order[a["kind"]] != order[b["kind"]]:
		return order[a["kind"]] < order[b["kind"]]
	return String(a["name"]) < String(b["name"])
