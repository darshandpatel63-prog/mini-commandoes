# Character art pipeline (Iron Vanguard -> 2D cut-out sprites)

## Source model verdict (inspected, not guessed)
`Iron_Vanguard_Meshy_AI_2026-10-03_482327.fbx`: binary FBX 7.4, **1 mesh, 704,752 vertices, 1,409,636 triangles, no skeleton, no animation, no UVs, no vertex colors, no texture** (one white material), 41 MB, Z-up, faces -Y, 1.9 units tall.
It depicts a stylized tactical soldier: helmet with headset, plate carrier with pouches, backpack, belt and holster, gloves, boots.
**It cannot be used directly**: the game is 2D, a phone cannot render 1.4M triangles x 40 players, and there is no rig or texture to recolor. It is used as a *source* for baked 2D sprites.

## Pipeline (`tools/bake_sprites.py`, run on a dev machine; the FBX stays out of the repo)
1. Parse the FBX (own reader, `tools/fbx_reader.py`), use vertices + triangle centroids as a dense point cloud.
2. Segment into 7 rigid parts by height/width planes: `body` (head, torso, backpack, shoulder caps), `arm_near/far`, `thigh_near/far`, `shin_near/far` (with boots). Shoulders are plugged into the body so no hole opens when an arm swings.
3. Label **zones** (uniform, vest, helmet, skin, glove, boot, pack, gear) by position boxes, so colorways recolor semantic regions.
4. Render each part orthographically from the side (z-buffer splat, depth smoothing, normals from depth, light + ambient occlusion + outline) at 3x supersampling, downsample to 82 px per unit (character ~156 px tall).
5. Four colorways (palettes in the script): Rook desert tan/charcoal, Juno slate-blue/teal, Mirelle white/red medic, Kade forest green/brown.
6. Write `assets/art/commando/rig.json`: pivots, parent links, rest rotations (legs are baked mid-stride; `rest_rad` makes them stand), texture offsets, wrist anchor.
Output: 28 part PNGs + 4 portraits = ~300 KB.

## In game (`src/ui/commando_rig.gd`)
Node2D hierarchy mirrors rig.json (thigh -> shin, body -> arms). Poses are procedural: idle breathing, run swing, jump/fall tuck, crouch, jetpack tuck + flame, aim (arm rotates to the aim stick, weapon follows), recoil, hit flash. Presentation only; reads simulation state.

## Honest limits
Cut-out look: joints are rigid, seams are hidden by overlap not blended. The mesh's high-frequency noise shows as a stippled "camo" texture on cloth. Outfits differ by **colorway**, not by geometry. Only one body type exists. Weapons are drawn from code (placeholder rifle), not from the model. Facing/animation set is minimal (no melee swing pose yet).
