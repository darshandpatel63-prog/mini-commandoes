# Multiplayer fairness and validation

Status: the **admission/validation logic** exists and is tested headless. The network transport (ENet, Phase 6) does not exist yet, so nothing here is "Network verified".

## What the client may control
Visual preferences, HUD position/size/opacity, haptics, and a **loadout selection (ids only)**.

## What the client can never set
HP, max HP, EP, armor values/durability, damage, fire rate, cooldowns, skill power, movement speed, invulnerability. They are not stored in any file the client controls and are never read from a client message.

## Mechanism (`src/net/authority.gd`)
1. The client sends its **claimed loadout** (ids). 
2. `Authority.admit` **whitelists keys** (`character, active, passives, pet, primary, secondary, melee, throwable, start_helmet, start_vest`); every other key (hp, max_hp, ep, damage_mult, ...) is dropped.
3. The same `LoadoutValidator` as the UI validates it (unknown ids, 5 passives, duplicates, budget, groups, exclusions, slot classes, start armor).
4. Invalid claim -> rejected (host falls back to the default loadout or refuses the join).
5. The host builds the combatant with `Combatant.from_loadout`: **max HP/EP come from `balance.json`**, passive modifiers from `skills.json`, start armor from `armor.json`. The client's local numbers are irrelevant.
6. All combat is resolved by the host through `DamagePipeline`; clients only send inputs (see blueprint section 19).

## Editing local files
`profile.json` / `controls.json` carry an integrity hash (corruption/tamper detection, not security) and even if a player forges one, the loadout is re-validated on load and again by the host, and numbers such as HP are not part of the format. A forged `"hp": 9999` is ignored.

## Not covered yet (honest list)
Transport-level validation (packet size, rate limits, input speed/fire-rate checks) arrives with Phase 6. Lag compensation, reconnect and cheat tests (TEST_PLAN T21) are planned. This is LAN-grade protection, not competitive anti-cheat.
