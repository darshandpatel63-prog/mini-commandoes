extends Node
## Plays haptics through Android's vibrator using the player's per-control settings.
## Limitation (documented): Godot passes (duration, amplitude) to Android; phones without amplitude control
## ignore amplitude and honour only duration. Presets therefore differ in BOTH values.

const HapticConfig := preload("res://src/core/haptic_config.gd")
var last: Dictionary = {}

func pulse(control_id: String) -> void:
	var r: Dictionary = HapticConfig.resolve(DataRegistry.bundle(), ControlsManager.haptics, control_id)
	last = r
	if bool(r.get("fire", false)):
		Input.vibrate_handheld(int(r["duration_ms"]), float(r["amplitude"]))
