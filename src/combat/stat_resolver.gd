extends RefCounted
## Resolves modifier lists into capped stats. The ONLY place where stat stacking limits are enforced.

static func resolve(rules: Dictionary, mods: Array) -> Dictionary:
	var out: Dictionary = (rules["stat_defaults"] as Dictionary).duplicate()
	for m in mods:
		var s: String = String(m.get("stat", ""))
		if not out.has(s):
			continue
		var op: String = String(m.get("op", ""))
		var v: float = float(m.get("value", 0.0))
		if op == "mult":
			out[s] = float(out[s]) * v
		elif op == "add":
			out[s] = float(out[s]) + v
	var caps: Dictionary = rules["stat_caps"]
	for s in caps:
		var c: Array = caps[s]
		out[s] = clampf(float(out[s]), float(c[0]), float(c[1]))
	return out

static func of(rules: Dictionary, st: Dictionary, now: float) -> Dictionary:
	var mods: Array = (st["passive_mods"] as Array).duplicate()
	for m in st["temp_mods"]:
		if float(m["expires"]) > now:
			mods.append(m)
	return resolve(rules, mods)
