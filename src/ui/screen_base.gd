extends Control
## Base for every menu screen: themed background, safe-area margins, header, Android back handling.

const UITheme := preload("res://src/ui/ui_theme.gd")
const UIKit := preload("res://src/ui/ui_kit.gd")

var content: VBoxContainer

func _ready() -> void:
	theme = UITheme.make()
	InputRouter.set_mode(InputRouter.Mode.MENU)
	var bg := ColorRect.new()
	bg.color = UITheme.C_BG_DEEP
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m: Dictionary = _safe_margins()
	margin.add_theme_constant_override("margin_left", 32 + int(m["l"]))
	margin.add_theme_constant_override("margin_right", 32 + int(m["r"]))
	margin.add_theme_constant_override("margin_top", 24 + int(m["t"]))
	margin.add_theme_constant_override("margin_bottom", 24 + int(m["b"]))
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	margin.add_child(content)
	_build()

func _build() -> void:
	pass

func _safe_margins() -> Dictionary:
	var out := {"l": 0, "t": 0, "r": 0, "b": 0}
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return out
	var vp: Vector2 = get_viewport_rect().size
	var sx: float = vp.x / win.x
	var sy: float = vp.y / win.y
	out["l"] = mini(int(maxf(safe.position.x, 0.0) * sx), 200)
	out["t"] = mini(int(maxf(safe.position.y, 0.0) * sy), 200)
	out["r"] = mini(int(maxf(win.x - safe.end.x, 0.0) * sx), 200)
	out["b"] = mini(int(maxf(win.y - safe.end.y, 0.0) * sy), 200)
	return out

func add_header(title: String, show_back: bool = true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	if show_back:
		row.add_child(UIKit.button("< BACK", _on_back, 240, "back"))
	var t: Label = UIKit.label(title, 64, UITheme.C_PRIMARY)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	content.add_child(row)

func _on_back() -> void:
	SceneRouter.go(SceneRouter.MAIN_MENU)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
