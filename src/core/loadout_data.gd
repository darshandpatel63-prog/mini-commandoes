extends RefCounted
## Loadout construction helpers: defaults, slot editing, normalization (after JSON load) and custom presets.

const Validator := preload("res://src/core/loadout_validator.gd")
const KEYS := ["character", "active", "passives", "pet", "primary", "secondary", "melee", "throwable", "start_helmet", "start_vest"]

static func default_loadout(d: Dictionary) -> Dictionary:
	return ((d["presets"] as Array)[0]["loadout"] as Dictionary).duplicate(true)

## Only whitelisted keys survive; everything else (hp, damage, ...) is dropped. Used for untrusted claims.
static func whitelist(claimed: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(claimed) == TYPE_DICTIONARY:
		for k in KEYS:
			if claimed.has(k):
				out[k] = claimed[k].duplicate(true) if (typeof(claimed[k]) == TYPE_ARRAY or typeof(claimed[k]) == TYPE_DICTIONARY) else claimed[k]
	return out

## Cleans types after loading JSON (floats -> ints, pads passives to 4). NOT used for network claims.
static func normalize(lo: Dictionary, slots: int = 4) -> Dictionary:
	var out: Dictionary = whitelist(lo)
	for k in ["start_helmet", "start_vest"]:
		if out.has(k) and (typeof(out[k]) == TYPE_FLOAT or typeof(out[k]) == TYPE_INT):
			out[k] = int(out[k])
	var p: Array = []
	if typeof(out.get("passives")) == TYPE_ARRAY:
		p = (out["passives"] as Array).duplicate()
	while p.size() < slots:
		p.append("")
	out["passives"] = p.slice(0, slots)
	return out

## kind: character|active|passive|pet|primary|secondary|melee|throwable|start_helmet|start_vest
static func with_slot(lo: Dictionary, kind: String, index: int, value: Variant) -> Dictionary:
	var out: Dictionary = lo.duplicate(true)
	if kind == "passive":
		var p: Array = out["passives"]
		if index >= 0 and index < p.size():
			p[index] = value
	elif out.has(kind):
		out[kind] = value
	return out

static func clean_name(raw: String, max_len: int) -> String:
	var s: String = ""
	for i in raw.length():
		var c: String = raw.substr(i, 1)
		if c.unicode_at(0) >= 32 and c.unicode_at(0) != 127:
			s += c
	return s.strip_edges().substr(0, max_len).strip_edges()

## Returns {"ok": bool, "presets": Array, "errors": Array}. Never stores an invalid loadout.
static func save_preset(d: Dictionary, presets: Array, raw_name: String, lo: Dictionary) -> Dictionary:
	var rules: Dictionary = d["rules"]["loadout"]
	var errors: Array = Validator.validate(d, lo)
	var nm: String = clean_name(raw_name, int(rules["preset_name_max"]))
	if nm == "":
		errors.append("E_PRESET_NAME")
	var list: Array = presets.duplicate(true)
	var idx: int = -1
	for i in list.size():
		if String(list[i]["name"]).to_lower() == nm.to_lower():
			idx = i
	if idx < 0 and list.size() >= int(rules["max_custom_presets"]):
		errors.append("E_PRESET_FULL")
	if errors.size() > 0:
		return {"ok": false, "presets": presets, "errors": errors}
	var entry: Dictionary = {"name": nm, "loadout": normalize(lo)}
	if idx >= 0:
		list[idx] = entry
	else:
		list.append(entry)
	return {"ok": true, "presets": list, "errors": []}

static func delete_preset(presets: Array, nm: String) -> Array:
	var out: Array = []
	for p in presets:
		if String(p["name"]).to_lower() != nm.to_lower():
			out.append(p)
	return out

## Drops stored presets that are no longer valid (e.g. content changed in an update).
static func sanitize_presets(d: Dictionary, stored: Variant) -> Array:
	var out: Array = []
	if typeof(stored) != TYPE_ARRAY:
		return out
	for p in stored:
		if typeof(p) != TYPE_DICTIONARY or typeof(p.get("name")) != TYPE_STRING:
			continue
		var lo: Dictionary = normalize(p.get("loadout", {}) if typeof(p.get("loadout")) == TYPE_DICTIONARY else {})
		if Validator.validate(d, lo).is_empty() and out.size() < int(d["rules"]["loadout"]["max_custom_presets"]):
			out.append({"name": clean_name(String(p["name"]), int(d["rules"]["loadout"]["preset_name_max"])), "loadout": lo})
	return out
