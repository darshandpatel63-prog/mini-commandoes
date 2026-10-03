extends RefCounted
## Activation of active and pet skills: cooldown + EP cost + effect. Behavior-only skills (dash, scan...) still
## pay cost and cooldown here; their world effect arrives with the simulation (Phase 2+).

const StatResolver := preload("res://src/combat/stat_resolver.gd")
const Vitals := preload("res://src/combat/vitals.gd")
const EPS := 1e-9

## Returns {"state": new_state, "err": ""|CODE}
static func activate(d: Dictionary, st0: Dictionary, skill_id: String, now: float) -> Dictionary:
	var st: Dictionary = st0.duplicate(true)
	var skills: Dictionary = d["skills"]
	if not skills.has(skill_id):
		return {"state": st, "err": "UNKNOWN_SKILL"}
	var s: Dictionary = skills[skill_id]
	if String(s["kind"]) != "active" and String(s["kind"]) != "pet":
		return {"state": st, "err": "UNKNOWN_SKILL"}
	if not bool(st["alive"]) or bool(st["downed"]):
		return {"state": st, "err": "DOWNED"}
	if now < float((st["cooldowns"] as Dictionary).get(skill_id, 0.0)):
		return {"state": st, "err": "COOLDOWN"}
	var eff: Dictionary = s.get("active_effect", {})
	if not eff.is_empty() and String(eff["type"]) == "convert_ep" and float(st["hp"]) >= float(st["max_hp"]) - EPS:
		return {"state": st, "err": "NOTHING_TO_DO"}
	if not Vitals.ep_spend(st, float(s.get("ep_cost", 0)), now):
		return {"state": st, "err": "NO_EP"}
	var stats: Dictionary = StatResolver.of(d["rules"], st, now)
	st["cooldowns"][skill_id] = now + float(s["cooldown"]) * float(stats["skill_cooldown_mult"])
	if not eff.is_empty():
		var t: String = String(eff["type"])
		if t == "shield":
			st["shield"] = maxf(float(st["shield"]), float(eff["amount"]))
			st["shield_expires"] = now + float(eff["duration"])
		elif t == "heal_over_time":
			(st["hots"] as Array).append({"rate": float(eff["total"]) / float(eff["duration"]), "remaining": float(eff["total"]), "expires_at": now + float(eff["duration"])})
		elif t == "convert_ep":
			(st["converts"] as Array).append({"ep_rate": float(eff["ep_total"]) / float(eff["duration"]), "remaining": float(eff["ep_total"])})
		elif t == "temp_mods":
			for e in eff["effects"]:
				var m: Dictionary = (e as Dictionary).duplicate()
				m["expires"] = now + float(eff["duration"])
				(st["temp_mods"] as Array).append(m)
	return {"state": st, "err": ""}
