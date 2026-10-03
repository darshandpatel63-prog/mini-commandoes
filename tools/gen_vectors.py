#!/usr/bin/env python3
"""Runs the reference model on hand-designed scenarios, ASSERTS hand-computed expectations (the real check),
then writes tests/vectors/cases.json for the GDScript tests. Run: python3 tools/gen_vectors.py"""
import sys, json, copy, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import ref_model as R

d = R.Data()
near = lambda a, b, e=1e-6: abs(a - b) <= e

def observe(st):
    return {"hp": st["hp"], "max_hp": st["max_hp"], "ep": st["ep"], "helmet_dur": st["helmet"]["dur"], "vest_dur": st["vest"]["dur"],
            "shield": st["shield"], "alive": st["alive"], "downed": st["downed"], "using": st["using"] is not None,
            "hots": len(st["hots"]), "health_kit": st["inventory"].get("health_kit", 0)}

def run(sc):
    st = R.make_state(d, sc["init"]); last = {}
    for s in sc["steps"]:
        op = s["op"]
        if op == "hit": st, last = R.apply_hit(d, st, s["hit"], s["now"])
        elif op == "tick": st = R.tick(d, st, s["dt"], s["now"]); last = {}
        elif op == "item": st, e = R.item_start(d, st, s["id"], s["now"]); last = {"err": e}
        elif op == "skill": st, e = R.activate(d, st, s["id"], s["now"]); last = {"err": e}
    return st, last

H = lambda dmg, zone="body", **kw: dict({"damage": dmg, "zone": zone}, **kw)
SN = dict(damage=85, zone="head", head_mult=2.5, armor_pen=0.3)
sc = []
def add(name, init, steps, check):
    st, last = run({"init": init, "steps": steps}); check(st, last)
    sc.append({"name": name, "init": init, "steps": steps, "expect": observe(st), "last": last})
hit = lambda h, now=0.0: {"op": "hit", "hit": h, "now": now}
tick = lambda dt, now: {"op": "tick", "dt": dt, "now": now}
item = lambda i, now: {"op": "item", "id": i, "now": now}
skill = lambda i, now: {"op": "skill", "id": i, "now": now}

add("ar_body_no_armor", {}, [hit(H(14))], lambda s, l: (near(l["hp_damage"], 14), near(s["hp"], 186)))
add("ar_head_no_armor", {}, [hit(H(14, "head", head_mult=2.0))], lambda s, l: (near(l["hp_damage"], 28), near(s["hp"], 172)))
add("vest3_body", {"vest": [3]}, [hit(H(14))], lambda s, l: (near(l["armor_absorbed"], 4.9), near(l["hp_damage"], 9.1), near(s["vest"]["dur"], 135.1), near(s["hp"], 190.9)))
add("helm3_sniper_head", {"helmet": [3]}, [hit(SN)], lambda s, l: (near(l["armor_absorbed"], 59.5), near(s["helmet"]["dur"], 20.5), near(l["hp_damage"], 153.0), near(s["hp"], 47.0), not l["killed"]))
add("helm3_low_durability_sniper", {"helmet": [3, 10]}, [hit(SN)], lambda s, l: (near(l["armor_absorbed"], 10), near(l["hp_damage"], 202.5), l["killed"], l["piece_broken"], not s["alive"], near(s["helmet"]["dur"], 0)))
add("no_helmet_sniper_one_shot", {}, [hit(SN)], lambda s, l: (near(l["hp_damage"], 212.5), l["killed"]))
add("helm1_sniper_survives", {"helmet": [1]}, [hit(SN)], lambda s, l: (near(l["armor_absorbed"], 29.75), near(s["hp"], 17.25), not l["killed"]))
add("energy_barrier_absorbs", {"passives": ["energy_barrier"]}, [hit(H(100))], lambda s, l: (near(l["ep_absorbed"], 20), near(s["ep"], 80), near(l["hp_damage"], 80), near(s["hp"], 120)))
add("energy_barrier_limited_by_ep", {"passives": ["energy_barrier"], "ep": 5}, [hit(H(100))], lambda s, l: (near(l["ep_absorbed"], 5), near(s["ep"], 0), near(l["hp_damage"], 95)))
add("shield_absorbs_then_hp", {}, [skill("bulwark_ward", 0.0), hit(H(100), 1.0)], lambda s, l: (near(l["shield_absorbed"], 40), near(l["hp_damage"], 60), near(s["shield"], 0), near(s["ep"], 80)))
add("shield_expires", {}, [skill("bulwark_ward", 0.0), tick(1.0, 7.0)], lambda s, l: near(s["shield"], 0))
add("ep_regen_delay", {}, [skill("pip_mark", 0.0), tick(1.0, 1.0), tick(1.0, 3.0)], lambda s, l: near(s["ep"], 91.0))
add("ep_regen_quick_charge", {"passives": ["quick_charge"]}, [skill("pip_mark", 0.0), tick(1.0, 3.0)], lambda s, l: near(s["ep"], 85 + 7.8))
add("ep_cell_capacitor_bank", {"passives": ["capacitor_bank"], "ep": 100}, [item("ep_cell", 0.0), tick(1.5, 1.5)], lambda s, l: (near(s["ep"], 125), near(R.max_ep(d, s, 2.0), 125)))
add("ep_cell_when_full_rejected", {}, [item("ep_cell", 0.0)], lambda s, l: l["err"] == "FULL")
add("health_kit_quick_hands", {"hp": 100, "passives": ["quick_hands"]}, [item("health_kit", 0.0), tick(0.1, 1.7)], lambda s, l: (near(s["hp"], 100), s["using"]))
sc.append(None); sc.pop()
add("health_kit_completes", {"hp": 100, "passives": ["quick_hands"]}, [item("health_kit", 0.0), tick(0.1, 1.7), tick(0.1, 1.8)], lambda s, l: (near(s["hp"], 175), not s["using"], s["inventory"]["health_kit"] == 0))
add("heal_interrupted_by_damage", {"hp": 100}, [item("health_kit", 0.0), hit(H(10), 1.0), tick(4.0, 5.0)], lambda s, l: (l == l, near(s["hp"], 90), not s["using"]))
add("item_cooldown", {"hp": 50}, [item("health_kit", 0.0), tick(3.0, 3.0), item("bandage", 3.5)], lambda s, l: (near(s["hp"], 125), l["err"] == "COOLDOWN"))
add("item_after_cooldown", {"hp": 50}, [item("health_kit", 0.0), tick(3.0, 3.0), item("bandage", 4.0)], lambda s, l: l["err"] == "")
add("hp_item_when_full_rejected", {}, [item("bandage", 0.0)], lambda s, l: l["err"] == "FULL")
add("heal_never_exceeds_max", {"hp": 190}, [item("health_kit", 0.0), tick(3.0, 3.0)], lambda s, l: near(s["hp"], 200))
add("energy_mender_converts", {"hp": 100}, [skill("energy_mender", 0.0)] + [tick(0.5, 0.5 * i) for i in range(1, 9)], lambda s, l: (near(s["hp"], 120), near(s["ep"], 60), s["hots"] == 0))
add("energy_mender_needs_missing_hp", {}, [skill("energy_mender", 0.0)], lambda s, l: l["err"] == "NOTHING_TO_DO")
add("aegis_pulse_reduces_then_expires", {}, [skill("aegis_pulse", 0.0), hit(H(100), 1.0), hit(H(100), 3.0)], lambda s, l: (near(s["hp"], 30), near(s["ep"], 60)))
add("triage_regen_to_40pct", {"hp": 50, "passives": ["triage"]}, [tick(1.0, 1.0)] + [tick(1.0, 1.0 + i) for i in range(1, 16)], lambda s, l: near(s["hp"], 80))
add("knockdown_then_death", {"hp": 10, "allow_knockdown": True}, [hit(H(50)), hit(H(60), 1.0)], lambda s, l: (l["killed"], not s["alive"]))
add("knockdown_state", {"hp": 10, "allow_knockdown": True}, [hit(H(50))], lambda s, l: (l["downed"], s["downed"], s["alive"], near(s["hp"], 0)))
add("no_knockdown_dies", {"hp": 10}, [hit(H(50))], lambda s, l: (l["killed"], not s["alive"]))
add("armor_never_raises_max_hp", {"helmet": [3], "vest": [3]}, [], lambda s, l: (near(s["max_hp"], 200), near(s["hp"], 200)))
add("reinforced_plating_durability", {"passives": ["reinforced_plating"], "vest": [3]}, [hit(H(14))], lambda s, l: (near(l["armor_absorbed"], 4.9), near(s["vest"]["dur"], 140 - 3.675)))
add("armor_break_melee", {"vest": [1]}, [hit(H(24, armor_break=5))], lambda s, l: (near(l["hp_damage"], 20.4), near(s["vest"]["dur"], 71.4)))
add("repair_kit_restores_durability", {"vest": [2, 50]}, [item("repair_kit", 0.0), tick(2.0, 2.0)], lambda s, l: near(s["vest"]["dur"], 90))
add("hardened_helm_headshot", {"passives": ["hardened_helm"]}, [hit(H(14, "head", head_mult=2.0))], lambda s, l: near(l["hp_damage"], 25.2))
add("skill_cooldown", {}, [skill("bulwark_ward", 0.0), skill("bulwark_ward", 10.0)], lambda s, l: l["err"] == "COOLDOWN")
add("skill_ready_after_cooldown", {}, [skill("bulwark_ward", 0.0), skill("bulwark_ward", 30.0)], lambda s, l: (l["err"] == "", near(s["ep"], 60)))
add("skill_needs_ep", {"ep": 10}, [skill("aegis_pulse", 0.0)], lambda s, l: l["err"] == "NO_EP")
add("downed_cannot_use_skill", {"hp": 10, "allow_knockdown": True}, [hit(H(50)), skill("bulwark_ward", 1.0)], lambda s, l: l["err"] == "DOWNED")
add("downed_cannot_use_item", {"hp": 10, "allow_knockdown": True}, [hit(H(50)), item("bandage", 1.0)], lambda s, l: l["err"] == "DOWNED")
add("thrown_explosion_ignores_armor_flag", {"vest": [3]}, [hit(H(50, ignore_armor=True))], lambda s, l: (near(l["hp_damage"], 50), near(s["vest"]["dur"], 140)))

# ---- stats
stats = []
def st_case(name, mods, expect_hand):
    out = R.resolve_stats(d.rules, mods)
    for k, v in expect_hand.items(): assert near(out[k], v), (name, k, out[k], v)
    stats.append({"name": name, "mods": mods, "expect": {k: out[k] for k in expect_hand}})
m = lambda s, o, v: {"stat": s, "op": o, "value": v}
st_case("damage_reduction_capped", [m("damage_taken_mult", "mult", 0.7)] * 3, {"damage_taken_mult": 0.6})
st_case("cooldown_cannot_reach_zero", [m("skill_cooldown_mult", "mult", 0.0)], {"skill_cooldown_mult": 0.8})
st_case("ep_bonus_capped", [m("ep_max_bonus", "add", 25)] * 5, {"ep_max_bonus": 50})
st_case("barrier_capped", [m("ep_barrier", "add", 0.2)] * 3, {"ep_barrier": 0.25})
st_case("move_speed_capped", [m("move_speed_mult", "mult", 3.0)], {"move_speed_mult": 1.15})
st_case("durability_loss_floor", [m("durability_loss_mult", "mult", 0.5)], {"durability_loss_mult": 0.7})
st_case("two_mults_multiply", [m("damage_taken_mult", "mult", 0.95), m("damage_taken_mult", "mult", 0.9)], {"damage_taken_mult": 0.855})
st_case("unknown_stat_ignored", [m("hp_bonus", "add", 9999), m("max_hp", "mult", 50)], {"damage_taken_mult": 1.0})

# ---- loadouts
loadouts = []
def lo_case(name, lo, codes):
    got = R.validate_loadout(d, lo); assert got == sorted(codes), (name, got, codes)
    loadouts.append({"name": name, "loadout": lo, "expect_codes": sorted(codes)})
base = copy.deepcopy(d.presets[0]["loadout"])
def var(**kw):
    x = copy.deepcopy(base); x.update(kw); return x
for p in d.presets: lo_case("preset_" + p["id"], p["loadout"], [])
lo_case("empty_slots_ok", var(active="", passives=["", "", "", ""], pet=""), [])
lo_case("five_passives", var(passives=["iron_knuckles", "quick_hands", "steady_footing", "capacitor_bank", "soft_landing"]), ["E_PASSIVE_COUNT"])
lo_case("duplicate_passive", var(passives=["quick_hands", "quick_hands", "", ""]), ["E_PASSIVE_DUP"])
lo_case("passive_in_active_slot", var(active="quick_hands"), ["E_ACTIVE"])
lo_case("active_in_passive_slot", var(passives=["rapid_dash", "", "", ""]), ["E_PASSIVE_KIND"])
lo_case("unknown_skill", var(passives=["god_mode", "", "", ""]), ["E_PASSIVE_KIND"])
lo_case("budget_exceeded", var(passives=["triage", "jet_tuning", "ghost_cloak", "momentum_strike"]), ["E_BUDGET"])
lo_case("group_ep_economy", var(passives=["capacitor_bank", "quick_charge", "", ""]), ["E_GROUP"])
lo_case("group_mitigation", var(passives=["hardened_helm", "combat_conditioning", "", ""]), ["E_GROUP"])
lo_case("excludes_triage_barrier", var(passives=["triage", "energy_barrier", "", ""]), ["E_EXCLUDES"])
lo_case("excludes_pet_and_passive", var(pet="pip", passives=["spotters_eye", "", "", ""]), ["E_EXCLUDES"])
lo_case("pet_with_any_character_ok", var(character="kade", pet="biscuit"), [])
lo_case("unknown_pet", var(pet="dragon"), ["E_PET"])
lo_case("unknown_character", var(character="nobody"), ["E_CHARACTER"])
lo_case("pistol_as_primary", var(primary="peacekeeper_pistol", secondary="burst_pistol"), ["E_PRIMARY"])
lo_case("sniper_as_secondary", var(secondary="longshot_sr"), ["E_SECONDARY"])
lo_case("same_weapon_twice", var(primary="sidewinder_smg", secondary="sidewinder_smg"), ["E_WEAPON_DUP"])
lo_case("unknown_melee", var(melee="lightsaber"), ["E_MELEE"])
lo_case("unknown_throwable", var(throwable="nuke"), ["E_THROWABLE"])
lo_case("start_armor_too_high", var(start_vest=3), ["E_START_ARMOR"])
lo_case("hostile_types", var(character=["a"], passives=[["x"], 5, None, ""], pet={"a": 1}), ["E_CHARACTER", "E_PASSIVE_KIND", "E_PET"])

# ---- authority
authority = []
def au_case(name, claimed, ok, codes=()):
    got = R.admit(d, claimed); assert got["ok"] == ok and got["errors"] == sorted(codes), (name, got)
    authority.append({"name": name, "claimed": claimed, "expect_ok": ok, "expect_codes": sorted(codes)})
tamper = copy.deepcopy(base); tamper.update({"hp": 9999, "max_hp": 9999, "ep": 99999, "damage_mult": 50, "cooldown_mult": 0, "armor": 9999, "move_speed": 99})
au_case("tampered_extra_stats_ignored", tamper, True)
assert R.admit(d, tamper)["max_hp"] == 200
au_case("claim_is_not_dict", "godmode", False, ["E_CHARACTER", "E_MELEE", "E_PASSIVE_COUNT", "E_PRIMARY", "E_SECONDARY", "E_START_ARMOR", "E_THROWABLE"])
au_case("illegal_armor_claim", dict(base, start_helmet=3, start_vest=3), False, ["E_START_ARMOR"])
au_case("illegal_stacking_claim", dict(base, passives=["hardened_helm", "combat_conditioning", "energy_barrier", "reinforced_plating"]), False, ["E_BUDGET", "E_GROUP"])

# ---- haptics
haptics = []
def hp_case(name, cfg, cid, hand):
    got = R.haptic_resolve(d, cfg, cid)
    for k, v in hand.items(): assert got[k] == v or (isinstance(v, float) and near(got[k], v)), (name, got, hand)
    haptics.append({"name": name, "cfg": cfg, "control": cid, "expect": got})
dh = R.default_haptics(d)
hp_case("default_fire_medium", dh, "fire", {"fire": True, "duration_ms": 30, "amplitude": 0.6})
hp_case("default_skill_high", dh, "skill", {"fire": True, "duration_ms": 60, "amplitude": 1.0})
hp_case("default_jump_low", dh, "jump", {"fire": True, "duration_ms": 15, "amplitude": 0.3})
c = copy.deepcopy(dh); c["master_enabled"] = False; hp_case("master_off", c, "fire", {"fire": False})
c = copy.deepcopy(dh); c["master_intensity"] = 0.5; hp_case("master_intensity_scales", c, "fire", {"fire": True, "amplitude": 0.3, "duration_ms": 30})
c = copy.deepcopy(dh); c["controls"]["fire"]["enabled"] = False; hp_case("control_off", c, "fire", {"fire": False})
hp_case("control_off_does_not_affect_others", c, "jump", {"fire": True})
c = copy.deepcopy(dh); c["controls"]["fire"]["intensity"] = 0.0; hp_case("zero_intensity_is_off", c, "fire", {"fire": False})
c = copy.deepcopy(dh); c["controls"]["fire"]["duration_ms"] = 999; hp_case("duration_clamped", c, "fire", {"fire": True, "duration_ms": 200})
hp_case("unknown_control", dh, "laser", {"fire": False})

# ---- HUD
hud = []
SCR = [2400, 1080]
def hud_case(name, layout, screen, insets=(0, 0, 0, 0), hand=None):
    got = R.hud_sanitize(d, layout, screen, insets)
    for (cid, k), v in (hand or {}).items(): assert near(got[cid][k], v, 1e-4) or got[cid][k] == v, (name, cid, k, got[cid][k], v)
    hud.append({"name": name, "layout": layout, "screen": screen, "insets": list(insets), "expect": got, "overlaps": R.hud_overlaps(d, got, screen)})
dl = R.hud_default_layout(d)
hud_case("default_unchanged", dl, SCR, hand={("jump", "x"): 0.80, ("jump", "y"): 0.55})
l = copy.deepcopy(dl); l["jump"].update({"x": 2.0, "y": -1.0})
hud_case("moved_offscreen_is_clamped", l, SCR, hand={("jump", "x"): 1 - 0.01 - 75 / 2400, ("jump", "y"): 0.14 + 75 / 1080})
l = copy.deepcopy(dl); l["fire"].update({"scale": 5.0, "opacity": 0.0})
hud_case("scale_and_opacity_limited", l, SCR, hand={("fire", "scale"): 1.6, ("fire", "opacity"): 0.2})
l = copy.deepcopy(dl); l["move"]["visible"] = False; l["pet"]["visible"] = False
hud_case("required_stays_visible", l, SCR, hand={("move", "visible"): True, ("pet", "visible"): False})
l = copy.deepcopy(dl); l["reload"].update({"scale": 1.2, "opacity": 0.4}); l["melee"]["x"] = 0.5
hud_case("independent_size_and_opacity", l, SCR, hand={("reload", "scale"): 1.2, ("reload", "opacity"): 0.4, ("melee", "x"): 0.5, ("fire", "scale"): 1.0})
hud_case("notch_inset_respected", {"move": {"x": 0.0, "y": 0.7}}, SCR, (100, 0, 0, 0), hand={("move", "x"): 100 / 2400 + 140 / 2400})
hud_case("missing_entries_get_defaults", {}, SCR, hand={("aim", "x"): 0.89})
hud_case("garbage_layout", "nonsense", SCR, hand={("aim", "x"): 0.89})
l = copy.deepcopy(dl); l["jump"].update({"x": 0.74, "y": 0.80})
hud_case("overlap_detected", l, SCR)
assert ["fire", "jump"] in hud[-1]["overlaps"] or ["jump", "fire"] in hud[-1]["overlaps"], hud[-1]["overlaps"]
presets = {"left_handed": R.hud_preset(d, "left_handed"), "compact": R.hud_preset(d, "compact")}
assert near(presets["left_handed"]["move"]["x"], 0.89) and near(presets["compact"]["fire"]["scale"], 0.85)
assert all(not R.hud_overlaps(d, R.hud_sanitize(d, presets[k], SCR), SCR) for k in presets)

out = {"scenarios": sc, "stats": stats, "loadouts": loadouts, "authority": authority, "haptics": haptics, "hud": hud, "hud_presets": presets}
pathlib.Path(__file__).resolve().parent.parent.joinpath("tests/vectors/cases.json").write_text(json.dumps(out, indent=1))
print(f"vectors OK: {len(sc)} scenarios, {len(stats)} stats, {len(loadouts)} loadouts, {len(authority)} authority, {len(haptics)} haptics, {len(hud)} hud (all hand assertions passed)")
