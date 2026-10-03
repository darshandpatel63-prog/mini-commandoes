extends RefCounted
## Global theme built from the blueprint §24 design tokens. One theme, no per-screen styling.

const C_BG_DEEP := Color("#101A16")
const C_BG_PANEL := Color("#1B2A22")
const C_BG_RAISED := Color("#26382E")
const C_PRIMARY := Color("#E8A33D")
const C_PRIMARY_DARK := Color("#B9791C")
const C_SECONDARY := Color("#7FB069")
const C_ACCENT := Color("#4FD1C5")
const C_TEXT := Color("#F2F4EE")
const C_TEXT_DIM := Color("#9FB0A4")
const C_SUCCESS := Color("#5BD66F")
const C_WARNING := Color("#FFC247")
const C_DAMAGE := Color("#FF5A4F")

static var _theme: Theme = null

static func _box(c: Color, radius: int = 16, mh: int = 32, mv: int = 26) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(radius)
	b.content_margin_left = mh
	b.content_margin_right = mh
	b.content_margin_top = mv
	b.content_margin_bottom = mv
	return b

static func make() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 32
	t.set_color("font_color", "Label", C_TEXT)
	t.set_font_size("font_size", "Label", 32)
	t.set_stylebox("normal", "Button", _box(C_BG_RAISED))
	t.set_stylebox("hover", "Button", _box(C_BG_RAISED.lightened(0.12)))
	t.set_stylebox("pressed", "Button", _box(C_PRIMARY_DARK))
	t.set_stylebox("hover_pressed", "Button", _box(C_PRIMARY_DARK))
	t.set_stylebox("disabled", "Button", _box(C_BG_PANEL))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font_size("font_size", "Button", 36)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_TEXT)
	t.set_color("font_pressed_color", "Button", C_TEXT)
	t.set_color("font_hover_pressed_color", "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", C_TEXT_DIM)
	t.set_stylebox("panel", "PanelContainer", _box(C_BG_PANEL, 20, 24, 24))
	_theme = t
	return t
