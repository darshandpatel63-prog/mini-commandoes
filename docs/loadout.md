# Loadout, skills, pets, presets

Code: `src/core/loadout_validator.gd`, `loadout_data.gd`, `profile_data.gd`; UI `scenes/menu/loadout_screen.gd`, `browser_screen.gd` (picker), `characters_screen.gd`.

## Principle
Character (identity) + player-selected skills + player-selected pet + weapons + equipment preferences. Nothing is locked to a character.

## Loadout model (stored in `profile.json`, schema 2)
`{character, active, passives[4], pet, primary, secondary, melee, throwable, start_helmet, start_vest}`. Empty slots are allowed (`""`).
Only ids and small integers are stored. HP/EP/armor/cooldown values are never part of a loadout.

## Skill pool
34 skills in `data/skills.json`: 8 **active** (1 slot), 22 **passive** (4 slots), 4 **pet** abilities (chosen via the pet).
Each skill has: category tag (combat, mobility, defense, survival, support, tactical, utility, crowd_control, recovery, resource, ep), description, cooldown and EP cost (active/pet) or **power cost 1-3** (passive), optional `group`, optional `excludes`, `effects` (stat modifiers), `impl` status.

## Validation rules (`LoadoutValidator.validate` -> error codes)
| Code | Meaning |
|---|---|
| E_CHARACTER / E_PET / E_MELEE / E_THROWABLE | unknown id |
| E_ACTIVE | active slot holds a non-active skill |
| E_PASSIVE_COUNT | passives array is not exactly 4 slots |
| E_PASSIVE_DUP / E_PASSIVE_KIND | duplicate passive / unknown or non-passive skill |
| E_BUDGET | passive power cost total > 8 |
| E_GROUP | too many skills from one group (mitigation 1, ep_economy 1, recovery 2, armor_care 1, melee_boost 1) |
| E_EXCLUDES | two equipped skills (active, passives, pet ability) exclude each other, e.g. Triage + Energy Barrier, Pip + Spotter's Eye |
| E_PRIMARY / E_SECONDARY / E_WEAPON_DUP | weapon class not allowed in that slot / same weapon twice |
| E_START_ARMOR | starting armor level above 1 |
Hostile input (wrong types, arrays in id fields, unknown keys) is rejected, never thrown.
**Anti-stacking** is two-layered: these combination rules plus the global stat caps in docs/combat.md.

## UI flow
LOADOUT screen shows every slot, the computed **build summary** (max HP/EP, EP recovery, damage taken, cooldown, item speed, passive budget, start armor) and VALID/INVALID. Tapping a slot opens the picker: category filter, descriptions, cooldown/EP/cost, **effect preview** generated from data, EQUIP / UNEQUIP. A candidate that would be illegal is shown with the reason and EQUIP is disabled. Changes are saved immediately (only if valid) and can be made any time before a match.

## Presets
- 4 built-in presets (Assault, Defensive, Mobility, Support) in `data/presets.json`; each must validate (checked by `validate_repo.py` and tests).
- Up to **6 custom presets**, names cleaned (control characters removed, trimmed, max 16 chars); same name (case-insensitive) overwrites.
- Presets store the full loadout (character, active, passives, pet, weapons, melee, throwable, start armor).
- Invalid combinations are **never saved**; stored presets that became invalid after a content update are dropped on load.

## Persistence and migration
`profile.json` (schema 2) = loadout + presets + xp/stats, written atomically with SHA-256 integrity and `.bak` recovery. `ProfileData.migrate` upgrades v1 (per-character picks) to v2 keeping character, pet, and weapon picks. On load the loadout is validated; an invalid stored loadout is reset to the default with a note shown in About.
