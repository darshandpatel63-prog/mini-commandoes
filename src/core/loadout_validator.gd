extends RefCounted
## Validates a loadout against balance rules. Used by the loadout UI, the save system, presets and the host (authority.gd).
## Returns a sorted, de-duplicated Array of error codes (empty = valid). Hostile/garbage input never throws.

const MESSAGES := {
	"E_FORMAT": "Loadout data is malformed.",
	"E_CHARACTER": "Unknown character.",
	"E_ACTIVE": "Active slot needs an active skill.",
	"E_PASSIVE_COUNT": "Exactly 4 passive slots are required.",
	"E_PASSIVE_DUP": "The same passive is equipped twice.",
	"E_PASSIVE_KIND": "A passive slot holds an unknown or non-passive skill.",
	"E_BUDGET": "Passive power budget exceeded.",
	"E_GROUP": "Too many skills from one group (see skill description).",
	"E_EXCLUDES": "Two equipped skills cannot be combined.",
	"E_PET": "Unknown pet.",
	"E_PRIMARY": "Primary weapon is invalid for this slot.",
	"E_SECONDARY": "Secondary weapon is invalid for this slot.",
	"E_WEAPON_DUP": "Primary and secondary must be different weapons.",
	"E_MELEE": "Unknown melee weapon.",
	"E_THROWABLE": "Unknown throwable.",
	"E_START_ARMOR": "Starting armor level is not allowed (higher levels must be looted).",
}

static func _is_empty(v: Variant) -> bool:
	return v == null or (typeof(v) == TYPE_STRING and String(v) == "")

static func _is_str(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING

static func describe(code: String) -> String:
	return String(MESSAGES.get(code, code))

static func validate(d: Dictionary, lo: Variant) -> Array:
	if typeof(lo) != TYPE_DICTIONARY:
		return ["E_FORMAT"]
	var errs: Dictionary = {}
	var L: Dictionary = d["rules"]["loadout"]
	var skills: Dictionary = d["skills"]
	if not _is_str(lo.get("character")) or not d["characters"].has(String(lo.get("character"))):
		errs["E_CHARACTER"] = true
	var active: String = ""
	var av: Variant = lo.get("active", "")
	if not _is_empty(av):
		if not _is_str(av) or not skills.has(String(av)) or String(skills[String(av)]["kind"]) != "active":
			errs["E_ACTIVE"] = true
		else:
			active = String(av)
	var passives: Variant = lo.get("passives", [])
	var plist: Array = []
	if typeof(passives) != TYPE_ARRAY:
		errs["E_PASSIVE_COUNT"] = true
	else:
		plist = passives
		if plist.size() != int(L["passive_slots"]):
			errs["E_PASSIVE_COUNT"] = true
	var filled: Array = []
	for p in plist:
		if _is_empty(p):
			continue
		if not _is_str(p):
			errs["E_PASSIVE_KIND"] = true
			continue
		filled.append(String(p))
	var seen: Dictionary = {}
	for p in filled:
		seen[p] = true
	if seen.size() != filled.size():
		errs["E_PASSIVE_DUP"] = true
	var cost: int = 0
	var groups: Dictionary = {}
	var good: Array = []
	for p in seen.keys():
		if not skills.has(p) or String(skills[p]["kind"]) != "passive":
			errs["E_PASSIVE_KIND"] = true
			continue
		good.append(p)
		cost += int(skills[p]["cost"])
		var g: String = String(skills[p].get("group", ""))
		if g != "":
			groups[g] = int(groups.get(g, 0)) + 1
	if cost > int(L["passive_budget"]):
		errs["E_BUDGET"] = true
	for g in groups:
		if int(groups[g]) > int((L["group_limits"] as Dictionary).get(g, 99)):
			errs["E_GROUP"] = true
			break
	var pet_skill: String = ""
	var pv: Variant = lo.get("pet", "")
	if not _is_empty(pv):
		if not _is_str(pv) or not d["pets"].has(String(pv)):
			errs["E_PET"] = true
		else:
			pet_skill = String(d["pets"][String(pv)]["skill"])
	var equipped: Dictionary = {}
	if active != "":
		equipped[active] = true
	for p in good:
		equipped[p] = true
	if pet_skill != "":
		equipped[pet_skill] = true
	for sid in equipped:
		for ex in skills.get(sid, {}).get("excludes", []):
			if equipped.has(String(ex)):
				errs["E_EXCLUDES"] = true
	var pr: Variant = lo.get("primary")
	var se: Variant = lo.get("secondary")
	var weapons: Dictionary = d["weapons"]
	if not _is_str(pr) or not weapons.has(String(pr)) or not (L["primary_classes"] as Array).has(String(weapons[String(pr)]["cls"])):
		errs["E_PRIMARY"] = true
	if not _is_str(se) or not weapons.has(String(se)) or not (L["secondary_classes"] as Array).has(String(weapons[String(se)]["cls"])):
		errs["E_SECONDARY"] = true
	if _is_str(pr) and _is_str(se) and String(pr) == String(se) and weapons.has(String(pr)):
		errs["E_WEAPON_DUP"] = true
	if not _is_str(lo.get("melee")) or not d["melee"].has(String(lo.get("melee"))):
		errs["E_MELEE"] = true
	if not _is_str(lo.get("throwable")) or not d["throwables"].has(String(lo.get("throwable"))):
		errs["E_THROWABLE"] = true
	for k in ["start_helmet", "start_vest"]:
		var v: Variant = lo.get(k)
		var ok: bool = (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and float(v) == floorf(float(v)) \
			and float(v) >= 0.0 and float(v) <= float(L["start_armor_max_level"])
		if not ok:
			errs["E_START_ARMOR"] = true
			break
	var out: Array = errs.keys()
	out.sort()
	return out
