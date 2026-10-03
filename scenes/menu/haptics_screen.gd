extends "res://src/ui/screen_base.gd"
## Haptics: master switch + intensity, and a per-control override (preset, intensity, duration, test).
## Changes are saved immediately to controls.json. LIMITATION shown to the player: amplitude depends on phone hardware.

const HapticConfig := preload("res://src/core/haptic_config.gd")
const ORDER := ["off", "low", "medium", "high"]
const LABELS := {"fire": "Fire", "jump": "Jump", "melee": "Melee", "grenade": "Grenade", "skill": "Active skill", "pet": "Pet ability",
	"reload": "Reload", "jet": "Jetpack", "swap": "Weapon swap", "interact": "Interact", "heal": "Heal item", "ep_item": "EP item",
	"crouch": "Crouch", "move": "Move stick", "aim": "Aim stick", "ui_button": "Menu buttons"}

var _d: Dictionary
var _cfg: Dictionary
var _master_btn: Button
var _master_val: Label
var _rows: Dictionary = {}

func _build() -> void:
	_d = DataRegistry.bundle()
	_cfg = ControlsManager.haptics.duplicate(true)
	add_header("HAPTICS")
	content.add_child(UIKit.label("Duration works on every Android phone. Intensity (amplitude) is only honoured by phones with amplitude control; on others Low/Medium/High differ by duration only.", 26, UITheme.C_TEXT_DIM, true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	box.add_child(UIKit.label("MASTER", 44, UITheme.C_ACCENT))
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 12)
	_master_btn = UIKit.make_button("", 240)
	_master_btn.pressed.connect(_toggle_master)
	mrow.add_child(_master_btn)
	var ml: Label = UIKit.label("Master intensity", 32)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ml.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mrow.add_child(ml)
	var mm: Button = UIKit.make_button("-", 104)
	var mp: Button = UIKit.make_button("+", 104)
	_master_val = UIKit.label("", 36, UITheme.C_PRIMARY)
	_master_val.custom_minimum_size = Vector2(130, 0)
	_master_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_master_val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mm.pressed.connect(_bump_master.bind(-0.1))
	mp.pressed.connect(_bump_master.bind(0.1))
	mrow.add_child(mm)
	mrow.add_child(_master_val)
	mrow.add_child(mp)
	box.add_child(mrow)
	box.add_child(UIKit.label("PER CONTROL", 44, UITheme.C_ACCENT))
	for cid in HapticConfig.PRESET_BY_CONTROL:
		_add_row(box, String(cid))
	_refresh_master()

func _add_row(parent: Control, cid: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l: Label = UIKit.label(String(LABELS.get(cid, cid)), 30)
	l.custom_minimum_size = Vector2(300, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var pb: Button = UIKit.make_button("", 230)
	pb.pressed.connect(_cycle_preset.bind(cid))
	row.add_child(pb)
	var iv: Label = _mini_stepper(row, "Strength", _bump_intensity, cid)
	var dv: Label = _mini_stepper(row, "Length", _bump_duration, cid)
	var tb: Button = UIKit.button("TEST", _test.bind(cid), 190)
	row.add_child(tb)
	parent.add_child(row)
	_rows[cid] = {"preset": pb, "int": iv, "dur": dv}
	_refresh_row(cid)

func _mini_stepper(row: HBoxContainer, title: String, cb: Callable, cid: String) -> Label:
	var t: Label = UIKit.label(title, 22, UITheme.C_TEXT_DIM)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	var minus: Button = UIKit.make_button("-", 90)
	var plus: Button = UIKit.make_button("+", 90)
	var val: Label = UIKit.label("", 28, UITheme.C_PRIMARY)
	val.custom_minimum_size = Vector2(110, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	minus.pressed.connect(cb.bind(cid, -1))
	plus.pressed.connect(cb.bind(cid, 1))
	row.add_child(minus)
	row.add_child(val)
	row.add_child(plus)
	return val

func _save() -> void:
	ControlsManager.set_haptics(_cfg)
	_cfg = ControlsManager.haptics.duplicate(true)

func _refresh_master() -> void:
	_master_btn.text = "ON" if bool(_cfg["master_enabled"]) else "OFF"
	_master_val.text = "%d%%" % int(roundf(float(_cfg["master_intensity"]) * 100.0))

func _refresh_row(cid: String) -> void:
	var c: Dictionary = _cfg["controls"][cid]
	var r: Dictionary = _rows[cid]
	r["preset"].text = String(c["preset"]).to_upper()
	r["int"].text = "%d%%" % int(roundf(float(c["intensity"]) * 100.0))
	r["dur"].text = "%d ms" % int(c["duration_ms"])

func _toggle_master() -> void:
	_cfg["master_enabled"] = not bool(_cfg["master_enabled"])
	_save()
	_refresh_master()

func _bump_master(delta: float) -> void:
	_cfg["master_intensity"] = snappedf(clampf(float(_cfg["master_intensity"]) + delta, 0.0, 1.0), 0.01)
	_save()
	_refresh_master()

func _cycle_preset(cid: String) -> void:
	var cur: String = String(_cfg["controls"][cid]["preset"])
	var i: int = ORDER.find(cur)
	_cfg = HapticConfig.with_preset(_d, _cfg, cid, ORDER[(i + 1) % ORDER.size()] if i >= 0 else "low")
	_save()
	_refresh_row(cid)

func _bump_intensity(cid: String, dir: int) -> void:
	var c: Dictionary = _cfg["controls"][cid]
	c["intensity"] = snappedf(clampf(float(c["intensity"]) + 0.1 * float(dir), 0.0, 1.0), 0.01)
	c["preset"] = "custom"
	c["enabled"] = true
	_save()
	_refresh_row(cid)

func _bump_duration(cid: String, dir: int) -> void:
	var rng: Array = _d["rules"]["haptics"]["duration_range_ms"]
	var c: Dictionary = _cfg["controls"][cid]
	c["duration_ms"] = int(clampf(float(c["duration_ms"]) + 5.0 * float(dir), float(rng[0]), float(rng[1])))
	c["preset"] = "custom"
	c["enabled"] = true
	_save()
	_refresh_row(cid)

func _test(cid: String) -> void:
	Haptics.pulse(cid)
