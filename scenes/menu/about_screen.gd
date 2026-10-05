extends "res://src/ui/screen_base.gd"
## ABOUT: version/build info, device info (useful for bug reports), engine license text.

func _build() -> void:
	add_header("ABOUT")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	var win: Vector2i = DisplayServer.window_get_size()
	var lines := PackedStringArray([
		"Mini Commandoes  [DEBUG BUILD]",
		Version.display_string(),
		"Platform: %s   Window: %d x %d" % [OS.get_name(), win.x, win.y],
		"Save source: profile %s, controls %s%s" % [SaveManager.load_source, ControlsManager.load_source, (" (" + ", ".join(SaveManager.load_notes) + ")") if SaveManager.load_notes.size() > 0 else ""],
		"Base stats for every commando: HP %d, EP %d" % [int(DataRegistry.raw["balance"]["base_hp"]), int(DataRegistry.raw["balance"]["base_ep"])],
		"Content: %d characters, %d skills, %d pets, %d weapons, %d throwables, %d maps, %d modes" % [
			DataRegistry.count("characters"), DataRegistry.count("skills"), DataRegistry.count("pets"),
			DataRegistry.count("weapons"), DataRegistry.count("throwables"),
			DataRegistry.count("maps"), DataRegistry.count("modes")],
		"",
		"An original game. Not affiliated with any other title.",
		"Made with Godot Engine (MIT License).",
		"Commando character model generated with Meshy AI.",
	])
	for l in lines:
		box.add_child(UIKit.label(l, 32, UITheme.C_TEXT, true))
	var lic: Label = UIKit.label(Engine.get_license_text(), 26, UITheme.C_TEXT_DIM, true)
	lic.visible = false
	var tog: Button = UIKit.button("SHOW / HIDE ENGINE LICENSE", _flip.bind(lic))
	box.add_child(tog)
	box.add_child(lic)

func _flip(node: Control) -> void:
	node.visible = not node.visible
