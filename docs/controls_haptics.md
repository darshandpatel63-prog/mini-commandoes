# Touch controls (HUD) and haptics

Code: `src/core/hud_layout.gd`, `haptic_config.gd`, `controls_data.gd`; `src/ui/hud_widget.gd`; screens `hud_editor.gd`, `haptics_screen.gd`; autoloads `ControlsManager`, `Haptics`. File: `user://controls.json` (schema 1).

## Controls (15)
move, aim, fire, jump, jet, reload, melee, grenade, swap, skill, pet, interact, heal, ep_item, crouch. **Required (cannot be hidden):** move, aim, jump, jet. Default layout: `data/hud_default.json` (checked: no overlaps, no clamping at 1920/2160/2400/2560 x 1080).

## Per-control settings
| Setting | Range | Rule |
|---|---|---|
| Position | normalized centre x,y | control must stay fully inside the screen, inside notch/system insets, below the reserved top strip (14% of height, where bars/minimap live) |
| Size | 60%-160% | independent per control |
| Opacity | 20%-100% | independent per control |
| Visibility | on/off | refused for required controls |
Invalid or missing data is repaired on load (`HudLayout.sanitize`). Overlapping touch circles are detected and shown as a warning in the editor (not blocking).

## HUD editor (Settings -> Customize HUD)
Representative HUD preview; drag a control to move it; tap to select; a floating panel (placed on the opposite half of the screen) offers SIZE -/+, FADE -/+, SHOWN/HIDDEN, HAPTIC preset, RESET (this control). Toolbar: CANCEL, RESET ALL, LAYOUT preset (Default / Left handed / Compact / Custom), TEST (buttons flash, play sound and vibrate with their configured haptics; no dragging), SAVE. Android Back = cancel. Unsaved changes are discarded without prompt (known limitation).

## Haptics (Settings -> Haptics, also per control in the editor)
Master ON/OFF + master intensity. Per control: preset **Off / Low / Medium / High / Custom**, **Strength** (intensity 0-100%), **Length** (5-200 ms), TEST. Controls: the 15 HUD controls + menu buttons.
| Preset | Strength | Length |
|---|---|---|
| Low | 30% | 15 ms |
| Medium | 60% | 30 ms |
| High | 100% | 60 ms |
Effective amplitude = control strength x master intensity (0 = no vibration). Defaults: Fire Medium, Jump Low, Melee Medium, Grenade Medium, Skill High, Pet Low, ...
All settings persist in `controls.json` and are restored on start.

## Android limitation (not hidden)
Godot calls Android's vibrator with (duration, amplitude). **Duration works on every phone.** **Amplitude is honoured only on phones with amplitude control**; Godot does not expose whether a phone has it, so the app cannot detect it. On other phones Strength has no effect. Because of this, presets differ in **both** strength and length so Low/Medium/High are still distinguishable. Fine intensity beyond that is not claimed. This screen says so to the player.
