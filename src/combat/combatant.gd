extends RefCounted
## Builds combatant state dictionaries. Max HP ALWAYS comes from balance.json (equal for everyone):
## characters, armor and skills can never change base HP.

static func _piece(d: Dictionary, piece_name: String, spec: Array) -> Dictionary:
	var level: int = int(spec[0]) if spec.size() > 0 else 0
	var tbl: Array = d["armor"][piece_name]
	level = clampi(level, 0, tbl.size() - 1)
	var dur: float = float(spec[1]) if spec.size() > 1 else float(tbl[level]["durability"])
	return {"level": level, "dur": dur}

static func make(d: Dictionary, spec: Dictionary) -> Dictionary:
	var r: Dictionary = d["rules"]
	var inv: Dictionary = (spec.get("inventory", r["default_inventory"]) as Dictionary).duplicate()
	var st: Dictionary = {
		"alive": true, "downed": false, "allow_knockdown": bool(spec.get("allow_knockdown", false)),
		"hp": float(spec.get("hp", r["base_hp"])), "max_hp": float(r["base_hp"]), "down_hp": 0.0,
		"ep": float(spec.get("ep", r["base_ep"])), "ep_last_spent": -1000.0,
		"shield": 0.0, "shield_expires": 0.0, "invuln_until": 0.0,
		"helmet": _piece(d, "helmet", spec.get("helmet", [0])),
		"vest": _piece(d, "vest", spec.get("vest", [0])),
		"passive_mods": [], "temp_mods": [], "flags": [], "hots": [], "converts": [],
		"cooldowns": {}, "heal_cd_until": 0.0, "using": null, "triage_ready_at": 0.0,
		"inventory": inv,
	}
	for sid in spec.get("passives", []):
		var s: Dictionary = d["skills"].get(String(sid), {})
		st["passive_mods"].append_array((s.get("effects", []) as Array).duplicate(true))
		st["flags"].append_array(s.get("rules", []))
	return st

## State for an already-validated loadout (see loadout_validator.gd / authority.gd).
static func from_loadout(d: Dictionary, lo: Dictionary) -> Dictionary:
	var passives: Array = []
	for p in lo.get("passives", []):
		if String(p) != "":
			passives.append(String(p))
	return make(d, {"passives": passives, "helmet": [int(lo.get("start_helmet", 0))], "vest": [int(lo.get("start_vest", 0))]})
