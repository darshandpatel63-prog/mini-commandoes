extends Node
## Scene switching with a short fade. Screens pass params via go(path, {...}) and read SceneRouter.params.

const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const SETTINGS := "res://scenes/menu/settings_screen.tscn"
const ABOUT := "res://scenes/menu/about_screen.tscn"
const CHARACTERS := "res://scenes/menu/characters_screen.tscn"
const BROWSER := "res://scenes/menu/browser_screen.tscn"
const LOADOUT := "res://scenes/menu/loadout_screen.tscn"
const HUD_EDITOR := "res://scenes/menu/hud_editor.tscn"
const HAPTICS := "res://scenes/menu/haptics_screen.tscn"
const COMBAT_LAB := "res://scenes/menu/combat_lab.tscn"

var params: Dictionary = {}
var _fade: ColorRect
var _busy: bool = false

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.063, 0.102, 0.086, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func go(path: String, p: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	params = p
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.12)
	await tw.finished
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("scene change failed: %s (%d)" % [path, err])
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.12)
	await tw2.finished
	_busy = false
