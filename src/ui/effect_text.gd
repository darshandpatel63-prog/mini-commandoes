extends RefCounted
## Human-readable descriptions generated from data (so numbers shown to players always match the rules).

const UIKit := preload("res://src/ui/ui_kit.gd")
const STATS := {
	"damage_taken_mult": "damage taken", "head_damage_taken_mult": "headshot damage taken", "durability_loss_mult": "armor durability loss",
	"skill_cooldown_mult": "skill cooldowns", "heal_apply_time_mult": "item apply time", "move_speed_mult": "move speed",
	"ep_regen_mult": "EP recovery speed", "reload_time_mult": "reload time", "melee_damage_mult": "melee damage",
	"jet_regen_mult": "jetpack recharge", "fall_damage_mult": "fall damage",
}
const STATUS := {
	"pipeline": "Fully simulated in the Combat Lab.",
	"pending_stat": "Stat is resolved; the system that uses it arrives in a later phase.",
	"behavior": "Behavior arrives with the match simulation (later phase). Cost and cooldown already apply.",
}

static func effect(e: Dictionary) -> String:
	var stat: String = String(e.get("stat", ""))
	var v: float = float(e.get("value", 0.0))
	if String(e.get("op", "")) == "mult":
		var pct: int = int(roundf((v - 1.0) * 100.0))
		return "%s%d%% %s" % ["+" if pct >= 0 else "", pct, String(STATS.get(stat, stat))]
	match stat:
		"ep_max_bonus": return "+%s maximum EP" % UIKit.num(v)
		"ep_barrier": return "EP absorbs %d%% of damage that would hit HP" % int(roundf(v * 100.0))
		"heal_slots_bonus": return "+%s healing item slots" % UIKit.num(v)
	return "%s %s" % [UIKit.num(v), stat]

static func _names(d: Dictionary, ids: Array) -> String:
	var out: PackedStringArray = []
	for i in ids:
		out.append(String(d["skills"].get(String(i), {}).get("name", String(i))))
	return ", ".join(out)

static func skill_text(d: Dictionary, s: Dictionary) -> String:
	var t := PackedStringArray()
	t.append(String(s["name"]))
	var meta: String = "%s skill  |  %s" % [String(s["kind"]).capitalize(), String(s["cat"])]
	if s.has("cost"):
		meta += "  |  power cost %d of %d" % [int(s["cost"]), int(d["rules"]["loadout"]["passive_budget"])]
	t.append(meta)
	if s.has("cooldown"):
		t.append("Cooldown %s s   |   EP cost %s" % [UIKit.num(s["cooldown"]), UIKit.num(s.get("ep_cost", 0))])
	t.append("")
	t.append(String(s["desc"]))
	var effs: Array = s.get("effects", [])
	if effs.size() > 0:
		t.append("")
		t.append("EFFECTS")
		for e in effs:
			t.append("- " + effect(e))
	var ae: Dictionary = s.get("active_effect", {})
	if not ae.is_empty():
		t.append("")
		t.append("PREVIEW")
		match String(ae["type"]):
			"shield": t.append("- Shield of %s HP for %s s" % [UIKit.num(ae["amount"]), UIKit.num(ae["duration"])])
			"heal_over_time": t.append("- Heals %s HP over %s s" % [UIKit.num(ae["total"]), UIKit.num(ae["duration"])])
			"convert_ep": t.append("- Converts up to %s EP into %s HP over %s s" % [UIKit.num(ae["ep_total"]), UIKit.num(float(ae["ep_total"]) / float(d["rules"]["ep"]["convert_ep_per_hp"])), UIKit.num(ae["duration"])])
			"temp_mods":
				for e in ae["effects"]:
					t.append("- %s for %s s" % [effect(e), UIKit.num(ae["duration"])])
	if s.has("group"):
		var lim: int = int(d["rules"]["loadout"]["group_limits"].get(String(s["group"]), 99))
		t.append("")
		t.append("Group \"%s\": at most %d equipped." % [String(s["group"]), lim])
	if s.has("excludes"):
		t.append("Cannot be combined with: " + _names(d, s["excludes"]))
	t.append("")
	t.append(String(STATUS.get(String(s.get("impl", "behavior")), "")))
	return "\n".join(t)
