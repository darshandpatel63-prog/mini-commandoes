extends RefCounted
## Player profile defaults, schema migration and pure helpers (headless-testable).

const SCHEMA := 1

static func defaults() -> Dictionary:
	return {
		"selected_character": "rook",
		"selected_pet": "bulwark",
		"loadout": {"primary": "vanguard_ar", "secondary": "peacekeeper_pistol",
			"throwable": "splinter", "backpack_level": 1},
		"xp": 0,
		"unlocks": [],
		"stats": {"matches": 0, "kills": 0, "deaths": 0},
	}

## Brings loaded data up to the current schema. Never throws away unknown keys.
static func migrate(data: Dictionary, from_version: int) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	# Future: if from_version < 2: ...transform...
	var def: Dictionary = defaults()
	for k in def:
		if not d.has(k):
			d[k] = def[k]
	d["xp"] = int(d.get("xp", 0))
	if from_version > SCHEMA:
		push_warning("profile written by a newer version (%d > %d)" % [from_version, SCHEMA])
	return d

static func apply_character(profile: Dictionary, character: Dictionary) -> Dictionary:
	var p: Dictionary = profile.duplicate(true)
	p["selected_character"] = String(character.get("id", p["selected_character"]))
	p["selected_pet"] = String(character.get("pet", p["selected_pet"]))
	return p
