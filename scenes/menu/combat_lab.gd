extends "res://src/ui/screen_base.gd"
## COMBAT LAB: a test dummy that is YOU. Uses the real damage pipeline, EP, recovery and skill code with your current
## loadout, so HP / EP / armor / skills can be verified on the phone. Not a game mode; weapons are not simulated.

const Combatant := preload("res://src/combat/combatant.gd")
const DamagePipeline := preload("res://src/combat/damage_pipeline.gd")
const Vitals := preload("res://src/combat/vitals.gd")
const SkillExec := preload("res://src/combat/skill_exec.gd")
const StatResolver := preload("res://src/combat/stat_resolver.gd")

var _d: Dictionary
var _lo: Dictionary
var _st: Dictionary = {}
var _now: float = 0.0
var _knock: bool = false
var _helm: int = 1
var _vest: int = 1
var _log: Array = []
var _hp_bar: ProgressBar
var _ep_bar: ProgressBar
var _helm_bar: ProgressBar
var _vest_bar: ProgressBar
var _hp_lbl: Label
var _ep_lbl: Label
var _helm_lbl: Label
var _vest_lbl: Label
var _info: Label
var _log_lbl: Label
var _knock_btn: Button
var _helm_btn: Button
var _vest_btn: Button

func _build() -> void:
	_d = DataRegistry.bundle()
	_lo = SaveManager.loadout()
	_helm = int(_lo.get("start_helmet", 0))
	_vest = int(_lo.get("start_vest", 0))
	add_header("COMBAT LAB")
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(640, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_hp_lbl = UIKit.label("", 28)
	left.add_child(_hp_lbl)
	_hp_bar = _bar(Color("#5BD66F"))
	left.add_child(_hp_bar)
	_ep_lbl = UIKit.label("", 28)
	left.add_child(_ep_lbl)
	_ep_bar = _bar(Color("#4FD1C5"))
	left.add_child(_ep_bar)
	_helm_lbl = UIKit.label("", 28)
	left.add_child(_helm_lbl)
	_helm_bar = _bar(Color("#7FA8D6"))
	left.add_child(_helm_bar)
	_vest_lbl = UIKit.label("", 28)
	left.add_child(_vest_lbl)
	_vest_bar = _bar(Color("#7FA8D6"))
	left.add_child(_vest_bar)
	_info = UIKit.label("", 26, UITheme.C_TEXT_DIM, true)
	left.add_child(_info)
	var mid := ScrollContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(mid)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(panel)
	_log_lbl = UIKit.label("", 26, UITheme.C_TEXT, true)
	panel.add_child(_log_lbl)
	var rs := ScrollContainer.new()
	rs.custom_minimum_size = Vector2(760, 0)
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(rs)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	rs.add_child(grid)
	_btn(grid, "BODY SHOT", _shoot.bind("body"))
	_btn(grid, "HEAD SHOT", _shoot.bind("head"))
	_btn(grid, "MELEE HIT", _melee)
	_btn(grid, "BLAST 90", _blast)
	_btn(grid, "FALL 30 (no armor)", _fall)
	_btn(grid, "ACTIVE SKILL", _skill.bind("active"))
	_btn(grid, "PET ABILITY", _skill.bind("pet"))
	_btn(grid, "BANDAGE", _item.bind("bandage"))
	_btn(grid, "HEALTH KIT", _item.bind("health_kit"))
	_btn(grid, "EP CELL", _item.bind("ep_cell"))
	_btn(grid, "REPAIR KIT", _item.bind("repair_kit"))
	_btn(grid, "RESET DUMMY", _reset)
	_knock_btn = _btn(grid, "", _toggle_knock)
	_helm_btn = _btn(grid, "", _cycle_helm)
	_vest_btn = _btn(grid, "", _cycle_vest)
	_reset()

func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 34)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(8)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.C_BG_RAISED
	bg.set_corner_radius_all(8)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b

func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b: Button = UIKit.button(text, cb)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b

func _passives() -> Array:
	var out: Array = []
	for p in _lo["passives"]:
		if String(p) != "":
			out.append(String(p))
	return out

func _reset() -> void:
	_st = Combatant.make(_d, {"passives": _passives(), "helmet": [_helm], "vest": [_vest], "allow_knockdown": _knock})
	_now = 0.0
	_log = ["Dummy reset with your loadout."]
	_refresh_buttons()

func _refresh_buttons() -> void:
	_knock_btn.text = "KNOCKDOWN: " + ("ON" if _knock else "OFF")
	_helm_btn.text = "HELMET LV %d" % _helm
	_vest_btn.text = "VEST LV %d" % _vest

func _toggle_knock() -> void:
	_knock = not _knock
	_reset()

func _cycle_helm() -> void:
	_helm = (_helm + 1) % 4
	_reset()

func _cycle_vest() -> void:
	_vest = (_vest + 1) % 4
	_reset()

func _say(line: String) -> void:
	_log.push_front("[%.1fs] %s" % [_now, line])
	while _log.size() > 14:
		_log.pop_back()

func _hit(h: Dictionary, label_text: String) -> void:
	var r: Dictionary = DamagePipeline.apply_hit(_d, _st, h, _now)
	_st = r["state"]
	var rep: Dictionary = r["report"]
	var parts := PackedStringArray()
	if float(rep["armor_absorbed"]) > 0.0:
		parts.append("%s absorbed %s" % [String(rep["piece"]), UIKit.num(snappedf(float(rep["armor_absorbed"]), 0.1))])
	if float(rep["shield_absorbed"]) > 0.0:
		parts.append("shield %s" % UIKit.num(snappedf(float(rep["shield_absorbed"]), 0.1)))
	if float(rep["ep_absorbed"]) > 0.0:
		parts.append("EP barrier %s" % UIKit.num(snappedf(float(rep["ep_absorbed"]), 0.1)))
	var flags := ""
	if bool(rep["piece_broken"]):
		flags += "  ARMOR BROKEN"
	if bool(rep["interrupted"]):
		flags += "  item use interrupted"
	if bool(rep["downed"]):
		flags += "  DOWNED"
	if bool(rep["killed"]):
		flags += "  KILLED"
	_say("%s -> HP -%s  (%s)%s" % [label_text, UIKit.num(snappedf(float(rep["hp_damage"]), 0.1)), ", ".join(parts) if parts.size() > 0 else "no mitigation", flags])

func _shoot(zone: String) -> void:
	var w: Dictionary = _d["weapons"][String(_lo["primary"])]
	var pellets: int = int(w.get("pellets", 1))
	for i in pellets:
		var r: Dictionary = DamagePipeline.apply_hit(_d, _st, {"damage": w["dmg"], "zone": zone, "head_mult": w["head_mult"], "armor_pen": w["armor_pen"]}, _now)
		_st = r["state"]
		if i == pellets - 1:
			var rep: Dictionary = r["report"]
			_say("%s %s%s -> HP now %s%s" % [String(w["name"]), zone.to_upper(), (" x%d pellets" % pellets) if pellets > 1 else "", UIKit.num(snappedf(float(_st["hp"]), 0.1)), "  KILLED" if bool(rep["killed"]) else ("  DOWNED" if bool(rep["downed"]) else "")])

func _melee() -> void:
	var m: Dictionary = _d["melee"][String(_lo["melee"])]
	_hit({"damage": m["dmg"], "zone": "body", "armor_break": m["armor_break"]}, String(m["name"]))

func _blast() -> void:
	_hit({"damage": 90.0, "zone": "body"}, "Blast 90")

func _fall() -> void:
	_hit({"damage": 30.0, "zone": "body", "ignore_armor": true}, "Fall 30")

func _skill(which: String) -> void:
	var sid: String = String(_lo.get("active", "")) if which == "active" else String(_d["pets"].get(String(_lo.get("pet", "")), {}).get("skill", ""))
	if sid == "":
		_say("No %s equipped." % which)
		return
	var r: Dictionary = SkillExec.activate(_d, _st, sid, _now)
	_st = r["state"]
	var skill_name: String = String(_d["skills"][sid]["name"])
	_say("%s: %s" % [skill_name, "activated" if String(r["err"]) == "" else "refused (" + String(r["err"]) + ")"])

func _item(item_id: String) -> void:
	var r: Dictionary = Vitals.item_start(_d, _st, item_id, _now)
	_st = r["state"]
	_say("%s: %s" % [item_id, "started" if String(r["err"]) == "" else "refused (" + String(r["err"]) + ")"])

func _process(delta: float) -> void:
	if _st.is_empty():
		return
	_now += delta
	_st = Vitals.tick(_d, _st, delta, _now)
	_update()

func _update() -> void:
	var stats: Dictionary = StatResolver.of(_d["rules"], _st, _now)
	var mx_ep: float = Vitals.max_ep(_d, _st, _now)
	_hp_bar.max_value = float(_st["max_hp"])
	_hp_bar.value = float(_st["hp"]) if not bool(_st["downed"]) else float(_st["down_hp"])
	_ep_bar.max_value = mx_ep
	_ep_bar.value = float(_st["ep"])
	var state_txt: String = "" if bool(_st["alive"]) and not bool(_st["downed"]) else ("  DOWNED" if bool(_st["downed"]) else "  DEAD")
	_hp_lbl.text = "HP %s / %s%s%s" % [UIKit.num(snappedf(float(_hp_bar.value), 0.1)), UIKit.num(_st["max_hp"]), state_txt, ("   shield %s" % UIKit.num(snappedf(float(_st["shield"]), 0.1))) if float(_st["shield"]) > 0.0 else ""]
	_ep_lbl.text = "EP %s / %s" % [UIKit.num(snappedf(float(_st["ep"]), 0.1)), UIKit.num(mx_ep)]
	_set_piece("helmet", _helm_bar, _helm_lbl, "HELMET")
	_set_piece("vest", _vest_bar, _vest_lbl, "VEST")
	var info := PackedStringArray()
	info.append("Damage taken x%s, headshot x%s, cooldowns x%s" % [UIKit.num(stats["damage_taken_mult"]), UIKit.num(stats["head_damage_taken_mult"]), UIKit.num(stats["skill_cooldown_mult"])])
	if _st["using"] != null:
		info.append("Using %s: %s s left" % [String(_st["using"]["item"]), UIKit.num(snappedf(maxf(0.0, float(_st["using"]["finish_at"]) - _now), 0.1))])
	for sid in _st["cooldowns"]:
		var left_s: float = float(_st["cooldowns"][sid]) - _now
		if left_s > 0.0:
			info.append("%s ready in %s s" % [String(_d["skills"][sid]["name"]), UIKit.num(snappedf(left_s, 0.1))])
	var inv: Dictionary = _st["inventory"]
	info.append("Items: bandage %d, kit %d, EP cell %d, repair %d" % [int(inv.get("bandage", 0)), int(inv.get("health_kit", 0)), int(inv.get("ep_cell", 0)), int(inv.get("repair_kit", 0))])
	_info.text = "\n".join(info)
	_log_lbl.text = "\n".join(PackedStringArray(_log))

func _set_piece(piece_name: String, bar: ProgressBar, lbl: Label, title: String) -> void:
	var p: Dictionary = _st[piece_name]
	var full: float = float(_d["armor"][piece_name][int(p["level"])]["durability"])
	bar.max_value = maxf(full, 1.0)
	bar.value = float(p["dur"])
	lbl.text = "%s L%d  %s / %s%s" % [title, int(p["level"]), UIKit.num(snappedf(float(p["dur"]), 0.1)), UIKit.num(full), "  BROKEN" if int(p["level"]) > 0 and float(p["dur"]) <= 0.0 else ""]
