extends RefCounted
## EP, healing, items, heal-over-time, EP->HP conversion, triage and time-based expiry.
## HP/EP recovery are separate systems (docs/combat.md). All functions take explicit `now` seconds.

const StatResolver := preload("res://src/combat/stat_resolver.gd")
const EPS := 1e-9

static func max_ep(d: Dictionary, st: Dictionary, now: float) -> float:
	return float(d["rules"]["base_ep"]) + float(StatResolver.of(d["rules"], st, now)["ep_max_bonus"])

## Mutates `st` (caller passes its own copy). Returns false when not enough EP.
static func ep_spend(st: Dictionary, amount: float, now: float) -> bool:
	if float(st["ep"]) + EPS < amount:
		return false
	st["ep"] = float(st["ep"]) - amount
	if amount > 0.0:
		st["ep_last_spent"] = now
	return true

static func _repair_target(d: Dictionary, st: Dictionary) -> String:
	var best: String = ""
	var ratio: float = 2.0
	for piece_name in ["helmet", "vest"]:
		var p: Dictionary = st[piece_name]
		var full: float = float(d["armor"][piece_name][int(p["level"])]["durability"])
		if int(p["level"]) > 0 and float(p["dur"]) < full - EPS:
			var r: float = float(p["dur"]) / full
			if r < ratio:
				best = piece_name
				ratio = r
	return best

## Returns {"state": new_state, "err": ""|CODE}
static func item_start(d: Dictionary, st0: Dictionary, item_id: String, now: float) -> Dictionary:
	var st: Dictionary = st0.duplicate(true)
	var items: Dictionary = d["rules"]["items"]
	if not items.has(item_id):
		return {"state": st, "err": "UNKNOWN_ITEM"}
	var it: Dictionary = items[item_id]
	if not bool(st["alive"]) or bool(st["downed"]):
		return {"state": st, "err": "DOWNED"}
	if st["using"] != null:
		return {"state": st, "err": "BUSY"}
	if now < float(st["heal_cd_until"]):
		return {"state": st, "err": "COOLDOWN"}
	if int((st["inventory"] as Dictionary).get(item_id, 0)) <= 0:
		return {"state": st, "err": "NONE"}
	var stats: Dictionary = StatResolver.of(d["rules"], st, now)
	var kind: String = String(it["kind"])
	if kind == "hp" and float(st["hp"]) >= float(st["max_hp"]) - EPS:
		return {"state": st, "err": "FULL"}
	if kind == "ep" and float(st["ep"]) >= max_ep(d, st, now) - EPS:
		return {"state": st, "err": "FULL"}
	if kind == "durability" and _repair_target(d, st) == "":
		return {"state": st, "err": "FULL"}
	st["using"] = {"item": item_id, "finish_at": now + float(it["apply_time"]) * float(stats["heal_apply_time_mult"]),
		"interruptible": bool(it["interruptible"])}
	return {"state": st, "err": ""}

## Advances time: expiry, EP regen, HoT (global cap), EP->HP conversion, item completion, triage.
static func tick(d: Dictionary, st0: Dictionary, dt: float, now: float) -> Dictionary:
	var st: Dictionary = st0.duplicate(true)
	var live_mods: Array = []
	for m in st["temp_mods"]:
		if float(m["expires"]) > now:
			live_mods.append(m)
	st["temp_mods"] = live_mods
	if float(st["shield"]) > 0.0 and float(st["shield_expires"]) <= now:
		st["shield"] = 0.0
	var rules: Dictionary = d["rules"]
	var stats: Dictionary = StatResolver.of(rules, st, now)
	var mx: float = float(rules["base_ep"]) + float(stats["ep_max_bonus"])
	if now - float(st["ep_last_spent"]) >= float(rules["ep"]["regen_delay"]):
		st["ep"] = minf(mx, float(st["ep"]) + float(rules["ep"]["regen_per_s"]) * float(stats["ep_regen_mult"]) * dt)
	else:
		st["ep"] = minf(float(st["ep"]), mx)
	if not bool(st["alive"]) or bool(st["downed"]):
		st["hots"] = []
		st["converts"] = []
		st["using"] = null
		return st
	# heal over time, with a global heal-rate cap
	var hots: Array = st["hots"]
	if hots.size() > 0:
		var amts: Array = []
		var total: float = 0.0
		for h in hots:
			var a: float = minf(float(h["rate"]) * dt, float(h["remaining"]))
			amts.append(a)
			total += a
		var cap: float = float(rules["max_heal_per_s"]) * dt
		var scale: float = 1.0 if total <= cap else cap / total
		var healed: float = 0.0
		for i in hots.size():
			var used: float = float(amts[i]) * scale
			hots[i]["remaining"] = float(hots[i]["remaining"]) - used
			healed += used
		st["hp"] = minf(float(st["max_hp"]), float(st["hp"]) + healed)
		var kept_h: Array = []
		for h in hots:
			if float(h["remaining"]) > EPS and float(h["expires_at"]) > now:
				kept_h.append(h)
		st["hots"] = kept_h
	# EP -> HP conversion (only via the Energy Mender active)
	var ratio: float = float(rules["ep"]["convert_ep_per_hp"])
	var kept_c: Array = []
	for c in st["converts"]:
		var use: float = minf(minf(float(c["ep_rate"]) * dt, float(c["remaining"])), minf(float(st["ep"]), (float(st["max_hp"]) - float(st["hp"])) * ratio))
		if use > 0.0:
			st["hp"] = float(st["hp"]) + use / ratio
			st["ep"] = float(st["ep"]) - use
			c["remaining"] = float(c["remaining"]) - use
			st["ep_last_spent"] = now
		if float(c["remaining"]) > EPS and float(st["hp"]) < float(st["max_hp"]) - EPS:
			kept_c.append(c)
	st["converts"] = kept_c
	# item completion
	if st["using"] != null:
		var u: Dictionary = st["using"]
		if now + EPS >= float(u["finish_at"]):
			var it: Dictionary = rules["items"][String(u["item"])]
			var kind: String = String(it["kind"])
			if kind == "hp":
				st["hp"] = minf(float(st["max_hp"]), float(st["hp"]) + float(it["amount"]))
			elif kind == "ep":
				st["ep"] = minf(mx, float(st["ep"]) + float(it["amount"]))
			elif kind == "durability":
				var t: String = _repair_target(d, st)
				if t != "":
					var full: float = float(d["armor"][t][int(st[t]["level"])]["durability"])
					st[t]["dur"] = minf(full, float(st[t]["dur"]) + float(it["amount"]))
			var inv: Dictionary = st["inventory"]
			inv[String(u["item"])] = int(inv.get(String(u["item"]), 0)) - 1
			st["heal_cd_until"] = now + float(rules["item_cooldown"])
			st["using"] = null
	# triage passive
	if (st["flags"] as Array).has("triage") and float(st["hp"]) < 0.30 * float(st["max_hp"]) and now >= float(st["triage_ready_at"]):
		(st["hots"] as Array).append({"rate": 2.0, "remaining": 0.40 * float(st["max_hp"]) - float(st["hp"]), "expires_at": now + 60.0})
		st["triage_ready_at"] = now + 20.0
	return st
