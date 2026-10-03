extends Control
## BOOT: shows version + data counts + save status for ~1.2 s, then opens the main menu.
## If data failed to load it stays here and shows the errors.

func _ready() -> void:
	var l: Label = $Center/Box/Info
	var lines := PackedStringArray()
	lines.append(Version.display_string())
	for t in ["characters", "skills", "pets", "weapons", "throwables", "maps", "modes"]:
		lines.append("%s: %d" % [t, DataRegistry.count(t)])
	lines.append("save: " + SaveManager.load_source)
	if DataRegistry.load_errors.size() > 0:
		lines.append("DATA ERRORS: " + ", ".join(DataRegistry.load_errors))
	l.text = "\n".join(lines)
	if DataRegistry.load_errors.is_empty():
		await get_tree().create_timer(1.2).timeout
		SceneRouter.go(SceneRouter.MAIN_MENU)
