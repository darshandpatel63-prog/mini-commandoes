# Combat model: HP, EP, armor, damage pipeline, recovery

Single source of numbers: `data/balance.json` (rules), `data/armor.json` (helmet/vest), `data/weapons.json`, `data/skills.json`.
Code: `src/combat/` (`damage_pipeline.gd`, `vitals.gd`, `skill_exec.gd`, `stat_resolver.gd`, `combatant.gd`).
Reference implementation used for verification: `tools/ref_model.py` (see docs/balance.md "How this is verified").

## Equal base stats
Every commando has **Base HP 200** and **Base EP 100** (`balance.json: base_hp, base_ep`). Nothing else can change `max_hp`:
characters are identity-only (validator rejects gameplay keys in `characters.json`), armor never adds HP, skills have no HP stat.
Temporary protection is a separate layer (**shield**, **armor durability**, **EP barrier**), never extra base HP.

## Resources
| Resource | Purpose | Max | Notes |
|---|---|---|---|
| HP | life | 200 | only damaged by the pipeline; healed by items, heal-over-time, EP conversion |
| EP | pays for active skills (and pet abilities), powers the EP barrier passive | 100 (+25 Capacitor Bank, cap +50) | separate bar, not "another HP bar" |
| Helmet durability | absorbs head damage | L1 40 / L2 60 / L3 80 | breaks at 0 (no protection) |
| Vest durability | absorbs body damage | L1 80 / L2 110 / L3 140 | breaks at 0 |
| Shield | temporary absorb layer (Bulwark Ward 40 HP, 6 s) | no stacking: max(current, new) | expires |

## EP rules
- Spend: active skill and pet ability each have `ep_cost` (0-40). Not enough EP = refused (`NO_EP`). Cooldown applies as well.
- Recovery: after **2.5 s** without spending EP, regenerate **6 EP/s** (x Quick Charge up to 1.5). Regen is capped at max EP.
- **EP items**: EP Cell +50 EP, 1.5 s apply time (see Items).
- **EP -> HP** is never automatic. Only the **Energy Mender** active converts: up to 40 EP into 20 HP over 4 s (2 EP per HP), only while HP is missing, stops at full HP, EP spent is exactly what was converted.
- **HP -> EP** conversion does not exist.
- **EP barrier** (Energy Barrier passive): absorbs 20% of the damage that has already passed armor/modifiers/shield, at 1 EP per 1 damage absorbed, limited by current EP. Spending EP restarts the regen delay.

## Armor
Per hit to a zone (head -> helmet, body -> vest), if the piece has durability > 0:
`absorbed = damage * reduction(level) * (1 - weapon.armor_pen)`; durability cost = `absorbed * durability_loss_mult`;
if the cost exceeds remaining durability, absorption is scaled down to what is left (the hit that breaks the piece protects partially).
`armor_break` (e.g. melee) removes extra durability after absorption. Explosions/falls may set `ignore_armor`.

| Level | Helmet reduction / durability | Vest reduction / durability |
|---|---|---|
| 0 | none | none |
| 1 | 20% / 40 | 15% / 80 |
| 2 | 30% / 60 | 25% / 110 |
| 3 | 40% / 80 | 35% / 140 |

Start-of-match armor is limited to level 1 (`start_armor_max_level`); levels 2-3 are loot.
Repair Kit restores 40 durability to the most damaged piece.

## Damage pipeline (the ONLY way HP changes)
`DamagePipeline.apply_hit(rules_bundle, state, hit, now) -> {state, report}`
1. **Hit location**: `zone` = head or body; head multiplies by the weapon's `head_mult`.
2. **Helmet / vest** (above).
3. **Skill modifiers**: `damage_taken_mult`, and `head_damage_taken_mult` for head hits (both capped by `stat_caps`).
4. **Temporary shield** (until it expires).
5. **EP barrier**.
6. **HP damage**; damage > 0 interrupts an item being used.
7. **Death / knockdown**: with knockdown allowed (team/survival modes) HP 0 -> downed with a 50 HP bleed-out pool; further damage kills. Without knockdown HP 0 = dead. Dead targets ignore further hits; spawn-protected targets (`invuln_until`) are not damaged.

The order is data (`damage_pipeline_order` in balance.json, documentation only) and fixed in code; do not reorder without updating this file, the reference model and the test vectors.

## Stat modifiers and stacking limits
Skills never edit damage code. They contribute `{stat, op, value}` modifiers; `StatResolver` multiplies/adds them and **clamps every stat to `stat_caps`**:
| Stat | Cap |
|---|---|
| damage_taken_mult | 0.60 - 1.00 (at most 40% less damage from skills combined) |
| head_damage_taken_mult | 0.85 - 1.00 |
| durability_loss_mult | 0.70 - 1.00 |
| skill_cooldown_mult | 0.80 - 1.00 (cooldown can never reach 0) |
| heal_apply_time_mult | 0.60 - 1.00 |
| move_speed_mult | 0.90 - 1.15 |
| ep_regen_mult | 1.00 - 1.50 |
| ep_max_bonus | 0 - 50 |
| ep_barrier | 0 - 0.25 |
| reload_time_mult / melee_damage_mult / jet_regen_mult | 0.70-1.00 / 1.00-1.40 / 1.00-1.40 |
Temporary effects (active skills) go through the same resolver, so an active plus passives cannot exceed the caps.

## Healing and recovery
| Item | Effect | Apply time | Notes |
|---|---|---|---|
| Bandage | +25 HP | 1.5 s | |
| Health Kit | +75 HP | 3.0 s | |
| EP Cell | +50 EP | 1.5 s | |
| Repair Kit | +40 durability | 2.0 s | |
Rules: one item at a time (`BUSY`), global 1.0 s cooldown after use (`COOLDOWN`), inventory count required (`NONE`), refused when it would be wasted (`FULL`), refused while downed/dead, **interrupted by damage**, never exceeds max HP/EP. Quick Hands makes apply time x0.6.
Heal-over-time (Field Pulse 40 HP/5 s, Biscuit Patch 45 HP/3 s, Triage) is limited by a **global heal cap of 40 HP/s**.
**Triage** (passive): below 30% HP regenerates 2 HP/s until 40% HP, internal cooldown 20 s; cannot be combined with Energy Barrier.

## What is simulated today
`pipeline` skills (shield, heal-over-time, EP conversion, damage reduction, durability, EP economy, item speed) are fully simulated and testable in the **Combat Lab**.
`pending_stat` skills resolve a stat that the jetpack/inventory/etc. will consume in later phases. `behavior` skills (dash, scan, slam, ...) already charge EP and cooldown but their world effect needs the match simulation (Phase 2+). Each skill shows its status in the skill browser.
