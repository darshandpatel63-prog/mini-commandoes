extends RefCounted
## THE damage pipeline. Every damage source goes through apply_hit(); nothing else may change HP.
## Order (docs/combat.md): hit location -> armor -> skill modifiers -> temp shield -> EP barrier -> HP -> death/knockdown.

const StatResolver := preload("res://src/combat/stat_resolver.gd")
const EPS := 1e-9

## hit: {damage, zone("head"|"body"), head_mult, armor_pen, armor_break, ignore_armor}
## Returns {"state": new_state, "report": {...}}. Input state is never mutated.
static func apply_hit(d: Dictionary, st0: Dictionary, hit: Dictionary, now: float) -> Dictionary:
	var st: Dictionary = st0.duplicate(true)
	var rep: Dictionary = {"hp_damage": 0.0, "armor_absorbed": 0.0, "shield_absorbed": 0.0, "ep_absorbed": 0.0,
		"piece": "", "piece_broken": false, "killed": false, "downed": false, "interrupted": false, "blocked": false}
	if not bool(st["alive"]):
		return {"state": st, "report": rep}
	if float(st["invuln_until"]) > now:
		rep["blocked"] = true
		return {"state": st, "report": rep}
	var stats: Dictionary = StatResolver.of(d["rules"], st, now)
	var zone: String = String(hit.get("zone", "body"))
	var raw: float = float(hit["damage"])
	if zone == "head":
		raw *= float(hit.get("head_mult", 1.0))
	# 2. helmet / vest
	var piece_name: String = "helmet" if zone == "head" else "vest"
	var piece: Dictionary = st[piece_name]
	var ignore: bool = bool(hit.get("ignore_armor", false))
	if not ignore and int(piece["level"]) > 0 and float(piece["dur"]) > EPS:
		var before: float = float(piece["dur"])
		var tbl: Dictionary = d["armor"][piece_name][int(piece["level"])]
		var absorbed: float = raw * float(tbl["reduction"]) * (1.0 - float(hit.get("armor_pen", 0.0)))
		var cost: float = absorbed * float(stats["durability_loss_mult"])
		if cost > float(piece["dur"]):
			absorbed *= float(piece["dur"]) / cost
			cost = float(piece["dur"])
		piece["dur"] = float(piece["dur"]) - cost
		raw -= absorbed
		rep["armor_absorbed"] = absorbed
		rep["piece"] = piece_name
		var ab: float = float(hit.get("armor_break", 0.0))
		if ab > 0.0:
			piece["dur"] = maxf(0.0, float(piece["dur"]) - ab)
		if float(piece["dur"]) <= EPS:
			piece["dur"] = 0.0
			if before > EPS:
				rep["piece_broken"] = true
	# 3. skill modifiers
	raw *= float(stats["damage_taken_mult"])
	if zone == "head":
		raw *= float(stats["head_damage_taken_mult"])
	# 4. temporary shield
	if float(st["shield"]) > 0.0 and float(st["shield_expires"]) > now:
		var s: float = minf(float(st["shield"]), raw)
		st["shield"] = float(st["shield"]) - s
		raw -= s
		rep["shield_absorbed"] = s
	# 5. EP barrier
	var ratio: float = float(stats["ep_barrier"])
	if ratio > 0.0 and float(st["ep"]) > 0.0 and raw > 0.0:
		var per: float = float(d["rules"]["ep"]["barrier_hp_per_ep"])
		var use: float = minf(raw * ratio / per, float(st["ep"]))
		var ep_abs: float = use * per
		st["ep"] = float(st["ep"]) - use
		st["ep_last_spent"] = now
		raw -= ep_abs
		rep["ep_absorbed"] = ep_abs
	# 6. HP
	rep["hp_damage"] = raw
	if raw > 0.0 and st["using"] != null and bool((st["using"] as Dictionary).get("interruptible", true)):
		st["using"] = null
		rep["interrupted"] = true
	# 7. death / knockdown
	if bool(st["downed"]):
		st["down_hp"] = float(st["down_hp"]) - raw
		if float(st["down_hp"]) <= 0.0:
			st["down_hp"] = 0.0
			st["alive"] = false
			st["downed"] = false
			rep["killed"] = true
	else:
		st["hp"] = float(st["hp"]) - raw
		if float(st["hp"]) <= 0.0:
			st["hp"] = 0.0
			if bool(st["allow_knockdown"]):
				st["downed"] = true
				st["down_hp"] = float(d["rules"]["knockdown_hp"])
				rep["downed"] = true
			else:
				st["alive"] = false
				rep["killed"] = true
	return {"state": st, "report": rep}
