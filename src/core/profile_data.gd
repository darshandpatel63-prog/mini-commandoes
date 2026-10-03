extends RefCounted
## Player profile (profile.json): loadout, custom presets, xp, stats. Schema 2 (v1 had per-character skills/pets).
## Max HP / EP / armor values are NEVER stored here: they are derived from balance.json (see authority.gd).

const SCHEMA := 2

static func default_loadout() -> Dictionary:
	return {"character": "rook", "active": "shockwave_slam", "passives": ["iron_knuckles", "quick_hands", "steady_footing", "capacitor_bank"],
		"pet": "bulwark", "primary": "hammerhead_sg", "secondary": "peacekeeper_pistol", "melee": "impact_gauntlet",
		"throwable": "splinter", "start_helmet": 1, "start_vest": 1}

static func defaults() -> Dictionary:
	return {"loadout": default_loadout(), "presets": [], "xp": 0, "unlocks": [],
		"stats": {"matches": 0, "kills": 0, "deaths": 0}}

static func migrate(data: Dictionary, from_version: int) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	if from_version < 2:
		var lo: Dictionary = default_loadout()
		var old: Variant = d.get("loadout")
		if typeof(old) == TYPE_DICTIONARY:
			for k in ["primary", "secondary", "throwable"]:
				if typeof(old.get(k)) == TYPE_STRING:
					lo[k] = old[k]
		if typeof(d.get("selected_character")) == TYPE_STRING:
			lo["character"] = d["selected_character"]
		if typeof(d.get("selected_pet")) == TYPE_STRING:
			lo["pet"] = d["selected_pet"]
		d["loadout"] = lo
		d.erase("selected_character")
		d.erase("selected_pet")
	var def: Dictionary = defaults()
	for k in def:
		if not d.has(k):
			d[k] = def[k]
	d["xp"] = int(d.get("xp", 0))
	return d
