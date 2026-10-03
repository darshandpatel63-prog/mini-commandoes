# Balance rules and numbers

All starting values are **unbalanced first drafts** tuned by analysis, to be re-tuned by playtests (Phase 9). Nothing here is playtested.

## Rules of thumb
1. Characters never differ in base stats. Power differences come only from the loadout.
2. Passive power budget 8 for 4 slots (cost 1 light, 2 medium, 3 strong).
3. One skill per mitigation group; combined skill damage reduction capped at 40% (`damage_taken_mult >= 0.6`).
4. Armor is meaningful but not excessive: a fresh Level 3 vest raises shots-to-kill by about 1.5x, not 2x+.
5. A helmet matters most against big hits: an unarmored headshot from the sniper kills in 1 shot; any helmet from Level 1 makes it 2.
6. No unlimited healing: apply times, cooldowns, interruption, global heal cap.
7. Active skills: 10-30 s cooldown AND an EP cost; Energy Mender costs no EP but spends it.

## Analysis output (tools/balance_report.py, from the reference model)
```
Base HP 200  Base EP 100 (identical for every character)

Effective HP multiplier (damage needed to kill / base HP), AR-7, fresh armor
level | helmet(head) | vest(body)
  L0  |   x1.12      |  x1.05
  L1  |   x1.26      |  x1.19
  L2  |   x1.40      |  x1.40
  L3  |   x1.40      |  x1.54

Shots to kill (one weapon, fresh armor)
weapon              zone  L0/L0   L1/L1   L2/L2   L3/L3   
vanguard_ar         body  15     17     20     22     
vanguard_ar         head  8      9      10     10     
sidewinder_smg      body  25     30     34     39     
sidewinder_smg      head  17     21     22     24     
hammerhead_sg       body  3      4      4      5      
hammerhead_sg       head  2      3      3      3      
longshot_sr         body  3      3      3      4      
longshot_sr         head  1      2      2      2      
peacekeeper_pistol  body  10     12     13     15     
peacekeeper_pistol  head  5      6      7      8      
scrapper_dmr        body  7      8      8      9      
scrapper_dmr        head  4      4      5      5      

Builds: AR-7 body shots to kill with skills (vest L2)
  none                         20
  combat_conditioning          21
  energy_barrier (EP 100)      24
  both mitigation (illegal)    26
```
Reading it: "L2/L2" means helmet and vest of that level, fresh. The first table counts overkill of the final hit, so shots-to-kill is the clearer metric.

## Skill power table (data/skills.json)
Passive costs: 1 = Steady Footing, Heavy Carry, Soft Landing, Slide Reload, Quick Hands, Pressure Seal, Pack Mule, Steady Breath, Tactical Reload, Spotter's Eye. 2 = Iron Knuckles, Scrap Plating, Jet Tuning, Momentum Strike, Ghost Cloak, Reinforced Plating, Capacitor Bank, Quick Charge, Hardened Helm, Combat Conditioning. 3 = Triage, Energy Barrier.

## How this is verified
The authoring environment cannot run Godot. Therefore: (1) `tools/ref_model.py` implements the rules in Python; (2) `tools/gen_vectors.py` runs 40 scenarios + stats/loadout/authority/haptics/HUD cases and **asserts hand-computed numbers** before writing `tests/vectors/cases.json`; (3) `tests/run_tests.gd` replays those vectors against the GDScript implementation in CI. A mismatch fails CI. Any rule change must update all three plus these docs.
