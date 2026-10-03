extends "res://src/ui/screen_base.gd"
## Read-only data browser for pets / skills / arsenal / maps (INFO ONLY: no gameplay behind these yet).

const KIND_TITLES := {"pets": "PETS", "skills": "SKILLS", "arsenal": "ARSENAL", "maps": "MAPS"}
var _detail: Label

func _build() -> void:
	var kind: String = String(SceneRouter.params.get("kind", "pets"))
	add_header(String(KIND_TITLES.get(kind, "INFO")) + "  (info only)")
	var items: Array = _items(kind)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var lscroll := ScrollContainer.new()
	lscroll.custom_minimum_size = Vector2(640, 0)
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(lscroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	lscroll.add_child(list)
	var rscroll := ScrollContainer.new()
	rscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(rscroll)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(panel)
	_detail = UIKit.label("Tap an entry.", 32, UITheme.C_TEXT, true)
	panel.add_child(_detail)
	var grp := ButtonGroup.new()
	for it in items:
		var body_text: String = String(it["body"])
		var b: Button = UIKit.button(String(it["title"]), _set_detail.bind(body_text))
		b.toggle_mode = true
		b.button_group = grp
		list.add_child(b)
	if items.size() > 0:
		_detail.text = String(items[0]["body"])

func _items(kind: String) -> Array:
	var out: Array = []
	match kind:
		"pets":
			for id in DataRegistry.tables["pets"]:
				var p: Dictionary = DataRegistry.tables["pets"][id]
				var s: Dictionary = DataRegistry.get_entry("skills", String(p["skill"]))
				out.append({"title": p["name"], "body": "%s\nMovement: %s\nFollow distance: %d px\nRole: %s\n\nSkill - %s [%ds cooldown]\n%s" % [
					p["kind"], p["move"], int(p["follow_dist"]), String(p["combat"]).replace("_", "-"),
					s["name"], int(s["cooldown"]), s["desc"]]})
		"skills":
			var all: Array = DataRegistry.tables["skills"].values()
			all.sort_custom(_skill_less)
			for s in all:
				var cd := ""
				if s.has("cooldown"):
					cd = "\nCooldown: %d s" % int(s["cooldown"])
				out.append({"title": "[%s] %s" % [String(s["kind"]).to_upper(), s["name"]],
					"body": "%s\nCategory: %s%s\n\n%s" % [s["name"], s["cat"], cd, s["desc"]]})
		"arsenal":
			for id in DataRegistry.tables["weapons"]:
				var w: Dictionary = DataRegistry.tables["weapons"][id]
				var dmg := str(w["dmg"])
				if w.has("pellets"):
					dmg += " x%d pellets" % int(w["pellets"])
				out.append({"title": "%s (%s)" % [w["name"], w["cls"]],
					"body": "%s - %s\nDamage %s   RPM %d   Mag %d   Reload %ss\nRange %d px   Spread %s   Recoil %s\nAmmo: %s   Projectile: %s\n\nSpecial: %s\n\nUnbalanced starting values." % [
						w["name"], w["cls"], dmg, int(w["rpm"]), int(w["mag"]), str(w["reload"]),
						int(w["range"]), str(w["spread"]), str(w["recoil"]), w["ammo"], w["proj"], w["special"]]})
			for id in DataRegistry.tables["throwables"]:
				var g: Dictionary = DataRegistry.tables["throwables"][id]
				out.append({"title": "%s (throwable)" % g["name"],
					"body": "%s\nFuse %ss   Radius %d px   Damage %d\nEffect: %s" % [
						g["name"], str(g["fuse"]), int(g["radius"]), int(g["dmg"]), String(g["effect"]).replace("_", " ")]})
		"maps":
			for id in DataRegistry.tables["maps"]:
				var m: Dictionary = DataRegistry.tables["maps"][id]
				out.append({"title": m["name"],
					"body": "%s\n%s\nSize: %d x %d px\nMax players: %d\nPlanned for: %s\nStatus: %s (not playable yet)" % [
						m["name"], m["theme"], int(m["size"][0]), int(m["size"][1]), int(m["max_players"]), m["milestone"], m["status"]]})
	return out

func _set_detail(text: String) -> void:
	_detail.text = text

func _skill_less(a: Dictionary, b: Dictionary) -> bool:
	var order := {"active": 0, "passive": 1, "pet": 2}
	if order[a["kind"]] != order[b["kind"]]:
		return order[a["kind"]] < order[b["kind"]]
	return String(a["name"]) < String(b["name"])
