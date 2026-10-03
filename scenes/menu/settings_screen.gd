extends "res://src/ui/screen_base.gd"
## SETTINGS: all rows are functional and persisted (user://settings.cfg).

const QUALITY := ["Low", "Medium", "High"]
const AIM := ["Drag to aim + fire", "Separate fire button"]

func _build() -> void:
	add_header("SETTINGS")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)
	box.add_child(UIKit.label("AUDIO", 44, UITheme.C_ACCENT))
	_stepper(box, "music_volume", "Music", 0.0, 1.0, 0.1)
	_stepper(box, "sfx_volume", "Sound effects", 0.0, 1.0, 0.1)
	_stepper(box, "voice_volume", "Voice", 0.0, 1.0, 0.1)
	box.add_child(UIKit.label("GRAPHICS", 44, UITheme.C_ACCENT))
	_cycle(box, "graphics_quality", "Quality (applied in later phase)", [0, 1, 2], QUALITY)
	_cycle(box, "fps_limit", "FPS limit", [30, 60, 90], ["30", "60", "90"])
	_toggle(box, "battery_mode", "Battery saver (caps 30 FPS)")
	box.add_child(UIKit.label("CONTROLS", 44, UITheme.C_ACCENT))
	_stepper(box, "control_size", "Button size", 0.7, 1.4, 0.1)
	_stepper(box, "control_opacity", "Button opacity", 0.3, 1.0, 0.1)
	_stepper(box, "sensitivity", "Aim sensitivity", 0.5, 2.0, 0.1)
	_cycle(box, "aim_mode", "Aim mode", [0, 1], AIM)
	box.add_child(UIKit.label("HAPTICS + LANGUAGE", 44, UITheme.C_ACCENT))
	_toggle(box, "vibration", "Vibration")
	box.add_child(UIKit.label("Language: English (more languages later)", 32, UITheme.C_TEXT_DIM))

func _row(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l: Label = UIKit.label(text, 32)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	parent.add_child(row)
	return row

func _stepper(parent: Control, key: String, text: String, lo: float, hi: float, step: float) -> void:
	var row: HBoxContainer = _row(parent, text)
	var val: Label = UIKit.label("", 36, UITheme.C_PRIMARY)
	val.custom_minimum_size = Vector2(130, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var minus: Button = UIKit.make_button("-", 104)
	var plus: Button = UIKit.make_button("+", 104)
	row.add_child(minus)
	row.add_child(val)
	row.add_child(plus)
	minus.pressed.connect(_bump.bind(key, -step, lo, hi, val))
	plus.pressed.connect(_bump.bind(key, step, lo, hi, val))
	_show_pct(key, val)

func _bump(key: String, d: float, lo: float, hi: float, val: Label) -> void:
	var v: float = float(Settings.get_value(key)) + d
	Settings.set_value(key, snappedf(clampf(v, lo, hi), 0.01))
	_show_pct(key, val)

func _show_pct(key: String, val: Label) -> void:
	val.text = "%d%%" % int(round(float(Settings.get_value(key)) * 100.0))

func _cycle(parent: Control, key: String, text: String, options: Array, names: Array) -> void:
	var row: HBoxContainer = _row(parent, text)
	var b: Button = UIKit.make_button("", 420)
	row.add_child(b)
	b.pressed.connect(_cycle_next.bind(key, options, names, b))
	_cycle_show(key, options, names, b)

func _cycle_next(key: String, options: Array, names: Array, b: Button) -> void:
	var i: int = options.find(Settings.get_value(key))
	Settings.set_value(key, options[(i + 1) % options.size()])
	_cycle_show(key, options, names, b)

func _cycle_show(key: String, options: Array, names: Array, b: Button) -> void:
	var i: int = options.find(Settings.get_value(key))
	b.text = String(names[maxi(i, 0)])

func _toggle(parent: Control, key: String, text: String) -> void:
	var row: HBoxContainer = _row(parent, text)
	var b: Button = UIKit.make_button("", 240)
	row.add_child(b)
	b.pressed.connect(_toggle_flip.bind(key, b))
	_toggle_show(key, b)

func _toggle_flip(key: String, b: Button) -> void:
	Settings.set_value(key, not bool(Settings.get_value(key)))
	_toggle_show(key, b)

func _toggle_show(key: String, b: Button) -> void:
	b.text = "ON" if bool(Settings.get_value(key)) else "OFF"
