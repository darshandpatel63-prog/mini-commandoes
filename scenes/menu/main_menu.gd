extends "res://src/ui/screen_base.gd"
## MAIN MENU. Every button is either FUNCTIONAL or disabled with the phase that will enable it.

func _entries() -> Array:
	# [label, scene path or "", browser kind or "", disabled note]
	return [
		["PLAY", "", "", "Phase 6"],
		["CHARACTERS", SceneRouter.CHARACTERS, "", ""],
		["PETS", SceneRouter.BROWSER, "pets", ""],
		["LOADOUT", "", "", "Phase 3"],
		["SKILLS", SceneRouter.BROWSER, "skills", ""],
		["ARSENAL", SceneRouter.BROWSER, "arsenal", ""],
		["MAPS", SceneRouter.BROWSER, "maps", ""],
		["MISSIONS", "", "", "Later"],
		["TRAINING", "", "", "Phase 2"],
		["SETTINGS", SceneRouter.SETTINGS, "", ""],
		["ABOUT", SceneRouter.ABOUT, "", ""],
	]

func _go(path: String, kind: String) -> void:
	SceneRouter.go(path, {"kind": kind})

func _build() -> void:
	GameState.set_state(GameState.AppState.MENU)
	var title: Label = UIKit.label("MINI COMMANDOES", 96, UITheme.C_PRIMARY)
	content.add_child(title)
	var ch: Dictionary = DataRegistry.get_entry("characters", String(SaveManager.profile.get("selected_character", "")))
	var sel := "Selected commando: %s (%s)" % [ch.get("name", "?"), ch.get("role", "?")]
	content.add_child(UIKit.label(sel, 36, UITheme.C_TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	for e in _entries():
		var label_text: String = e[0]
		var path: String = e[1]
		var kind: String = e[2]
		var note: String = e[3]
		var b: Button
		if path == "":
			b = UIKit.make_button("%s
(%s)" % [label_text, note])
			b.disabled = true
		else:
			b = UIKit.button(label_text, _go.bind(path, kind))
		b.custom_minimum_size = Vector2(0, 130)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	content.add_child(UIKit.label(Version.display_string() + "   [DEBUG BUILD]", 28, UITheme.C_TEXT_DIM))

func _on_back() -> void:
	get_tree().quit()
