extends Control
## BOOT SCENE - infrastructure check screen, NOT the main menu (see PROJECT.md placeholder tracker P1).
## Proves: engine starts on device, data loads, version stamping works.

func _ready() -> void:
	var l: Label = $Center/Box/Info
	var lines := PackedStringArray()
	lines.append(Version.display_string())
	for t in ["characters", "skills", "pets", "weapons", "throwables", "maps", "modes"]:
		lines.append("%s: %d" % [t, DataRegistry.count(t)])
	if DataRegistry.load_errors.size() > 0:
		lines.append("DATA ERRORS: " + ", ".join(DataRegistry.load_errors))
	l.text = "\n".join(lines)
