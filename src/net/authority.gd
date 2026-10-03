extends RefCounted
## HOST-SIDE admission of a client's claimed loadout. The client may only send selection ids; this module
## whitelists keys, validates with the same rules as the UI, and derives ALL gameplay values (HP, EP, armor,
## cooldowns, damage) from balance.json + data tables. Nothing numeric from the client is ever trusted.

const LoadoutData := preload("res://src/core/loadout_data.gd")
const Validator := preload("res://src/core/loadout_validator.gd")
const Combatant := preload("res://src/combat/combatant.gd")

## Returns {"ok": bool, "errors": Array, "loadout": Dictionary, "max_hp": float}
static func admit(d: Dictionary, claimed: Variant) -> Dictionary:
	var lo: Dictionary = LoadoutData.whitelist(claimed)
	var errs: Array = Validator.validate(d, lo)
	if errs.size() > 0:
		return {"ok": false, "errors": errs, "loadout": LoadoutData.default_loadout(d), "max_hp": float(d["rules"]["base_hp"])}
	return {"ok": true, "errors": [], "loadout": lo, "max_hp": float(d["rules"]["base_hp"])}

static func make_combatant(d: Dictionary, admitted_loadout: Dictionary) -> Dictionary:
	return Combatant.from_loadout(d, admitted_loadout)
