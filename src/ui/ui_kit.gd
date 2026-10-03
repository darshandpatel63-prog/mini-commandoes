extends RefCounted
## Small UI factory helpers shared by all screens.

const UITheme := preload("res://src/ui/ui_theme.gd")

static func label(text: String, size: int = 32, color: Color = UITheme.C_TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## Button with click sound + haptic wired, but no action connected yet.
static func make_button(text: String, min_w: float = 0.0, snd: String = "click") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 104)
	b.pressed.connect(_feedback.bind(snd))
	return b

static func _feedback(snd: String) -> void:
	AudioManager.play_ui(snd)
	Haptics.pulse("ui_button")

static func button(text: String, on_press: Callable, min_w: float = 0.0, snd: String = "click") -> Button:
	var b: Button = make_button(text, min_w, snd)
	b.pressed.connect(on_press)
	return b

## 14.0 -> "14", 0.6 -> "0.6"
static func num(v: Variant) -> String:
	var f: float = float(v)
	if is_equal_approx(f, roundf(f)):
		return str(int(roundf(f)))
	return str(snappedf(f, 0.01))
