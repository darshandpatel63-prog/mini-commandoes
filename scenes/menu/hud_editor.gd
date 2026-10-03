extends "res://src/ui/screen_base.gd"
## Settings -> Controls -> Customize HUD. Drag controls on a representative gameplay HUD, resize, fade, hide, test,
## then SAVE or CANCEL. All limits come from HudLayout (data/balance.json), not from this screen.

const HudLayout := preload("res://src/core/hud_layout.gd")
const HapticConfig := preload("res://src/core/haptic_config.gd")
const HudWidget := preload("res://src/ui/hud_widget.gd")
const PRESETS := ["default", "left_handed", "compact"]
const HAPTIC_ORDER := ["off", "low", "medium", "high"]

var _d: Dictionary
var _layout: Dictionary = {}
var _hap: Dictionary = {}
var _preset: String = "default"
var _scr: Vector2 = Vector2(2400, 1080)
var _insets: Array = [0, 0, 0, 0]
var _canvas: Control
var _widgets: Dictionary = {}
var _selected: String = ""
var _test: bool = false
var _panel: PanelContainer
var _p_name: Label
var _p_size: Label
var _p_op: Label
var _vis_btn: Button
var _hap_btn: Button
var _test_btn: Button
var _preset_btn: Button
var _warn: Label

func _build() -> void:
	_d = DataRegistry.bundle()
	_scr = get_viewport_rect().size
	var m: Dictionary = _safe_margins()
	_insets = [int(m["l"]), int(m["t"]), int(m["r"]), int(m["b"])]
	_layout = HudLayout.sanitize(_d, ControlsManager.hud, _scr, _insets)
	_hap = ControlsManager.haptics.duplicate(true)
	_preset = ControlsManager.layout_preset
	content.visible = false
	_canvas = Control.new()
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_mock_hud()
	var ctl: Dictionary = HudLayout.controls(_d)
	for cid in ctl:
		var w = HudWidget.new()   # untyped on purpose: custom properties
		w.control_id = String(cid)
		w.label_text = String(ctl[cid]["label"])
		w.is_stick = bool(ctl[cid]["stick"])
		w.picked.connect(_on_picked)
		w.dragging.connect(_on_dragging)
		w.released.connect(_on_released)
		_canvas.add_child(w)
		_widgets[cid] = w
	_build_toolbar()
	_build_panel()
	_place_all()
	_update_warnings()

func _build_mock_hud() -> void:
	var l: float = 32.0 + float(_insets[0])
	var ground := ColorRect.new()
	ground.color = Color(0.11, 0.16, 0.13)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(ground)
	ground.position = Vector2(0, _scr.y * 0.93)
	ground.size = Vector2(_scr.x, _scr.y * 0.07)
	for i in 3:
		var plat := ColorRect.new()
		plat.color = Color(0.15, 0.22, 0.18)
		plat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(plat)
		plat.position = Vector2(_scr.x * (0.25 + 0.22 * float(i)), _scr.y * (0.52 + 0.08 * float(i % 2)))
		plat.size = Vector2(_scr.x * 0.14, 22)
	var bars := [["HP 200", Color("#5BD66F"), 520.0], ["EP 100", Color("#4FD1C5"), 420.0], ["HELMET / VEST", Color("#7FA8D6"), 320.0]]
	for i in bars.size():
		var bar := ColorRect.new()
		bar.color = bars[i][1]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(bar)
		bar.position = Vector2(l, 122.0 + float(i) * 24.0)
		bar.size = Vector2(float(bars[i][2]) * 0.6, 16)
		bar.modulate.a = 0.55
		var lb: Label = UIKit.label(String(bars[i][0]), 18)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(lb)
		lb.position = bar.position + Vector2(bar.size.x + 12.0, -8.0)
	var mini := ColorRect.new()
	mini.color = Color(0.2, 0.3, 0.25, 0.4)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(mini)
	mini.size = Vector2(280, 160)
	mini.position = Vector2(_scr.x - 312.0 - float(_insets[2]), 24.0)
	var tag: Label = UIKit.label("HUD PREVIEW", 34, Color(1, 1, 1, 0.25))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(tag)
	tag.position = Vector2(_scr.x * 0.5 - 110.0, _scr.y * 0.42)

func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24.0 + float(_insets[0])
	bar.offset_right = -(24.0 + float(_insets[2]))
	bar.offset_top = 8.0 + float(_insets[1])
	bar.offset_bottom = bar.offset_top + 104.0
	bar.add_child(UIKit.button("CANCEL", _on_back, 0, "back"))
	bar.add_child(UIKit.button("RESET ALL", _reset_all))
	_preset_btn = UIKit.button("", _cycle_preset)
	bar.add_child(_preset_btn)
	_test_btn = UIKit.button("", _toggle_test)
	bar.add_child(_test_btn)
	_warn = UIKit.label("", 26, UITheme.C_WARNING)
	_warn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_warn)
	bar.add_child(UIKit.button("SAVE", _save, 260, "confirm"))
	for c in bar.get_children():
		if c is Button:
			(c as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_toolbar()

func _build_panel() -> void:
	_panel = PanelContainer.new()
	add_child(_panel)
	_panel.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_panel.add_child(row)
	_p_name = UIKit.label("", 32, UITheme.C_PRIMARY)
	_p_name.custom_minimum_size = Vector2(190, 0)
	_p_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_p_name)
	_p_size = _stepper(row, "SIZE", _step_scale)
	_p_op = _stepper(row, "FADE", _step_opacity)
	_vis_btn = UIKit.button("", _toggle_visible)
	row.add_child(_vis_btn)
	_hap_btn = UIKit.button("", _cycle_haptic)
	row.add_child(_hap_btn)
	row.add_child(UIKit.button("RESET", _reset_one, 0, "back"))

func _stepper(row: HBoxContainer, title: String, cb: Callable) -> Label:
	var t: Label = UIKit.label(title, 24, UITheme.C_TEXT_DIM)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	var minus: Button = UIKit.make_button("-", 90)
	var plus: Button = UIKit.make_button("+", 90)
	var val: Label = UIKit.label("", 32, UITheme.C_TEXT)
	val.custom_minimum_size = Vector2(100, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(minus)
	row.add_child(val)
	row.add_child(plus)
	minus.pressed.connect(cb.bind(-1))
	plus.pressed.connect(cb.bind(1))
	return val

func _on_back() -> void:
	SceneRouter.go(SceneRouter.SETTINGS)

func _place_all() -> void:
	for cid in _widgets:
		_place(String(cid))

func _place(cid: String) -> void:
	var w = _widgets[cid]
	var e: Dictionary = _layout[cid]
	var sz: float = float(HudLayout.controls(_d)[cid]["size"]) * float(e["scale"])
	w.size = Vector2(sz, sz)
	w.position = Vector2(float(e["x"]) * _scr.x - sz / 2.0, float(e["y"]) * _scr.y - sz / 2.0)
	w.fill_alpha = float(e["opacity"])
	w.shown = bool(e["visible"])
	w.selected = (cid == _selected)
	w.draggable = not _test
	w.queue_redraw()

func _sanitize_all() -> void:
	_layout = HudLayout.sanitize(_d, _layout, _scr, _insets)

func _changed() -> void:
	_preset = "custom"
	_sanitize_all()
	_place_all()
	_refresh_toolbar()
	_refresh_panel()
	_update_warnings()

func _on_picked(cid: String) -> void:
	if _test:
		_widgets[cid].do_flash()
		AudioManager.play_ui("click")
		Haptics.pulse(cid)
		return
	_selected = cid
	_place_all()
	_panel.visible = true
	_refresh_panel()
	_position_panel()

func _on_dragging(cid: String) -> void:
	var w: Control = _widgets[cid]
	var c: Vector2 = w.position + w.size / 2.0
	_layout[cid]["x"] = c.x / _scr.x
	_layout[cid]["y"] = c.y / _scr.y

func _on_released(cid: String) -> void:
	_changed()

func _position_panel() -> void:
	var cy: float = float(_layout[_selected]["y"])
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if cy > 0.5 else Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 24.0 + float(_insets[0])
	_panel.offset_right = -(24.0 + float(_insets[2]))
	if cy > 0.5:
		_panel.offset_top = 124.0 + float(_insets[1])
		_panel.offset_bottom = _panel.offset_top + 130.0
	else:
		_panel.offset_bottom = -(12.0 + float(_insets[3]))
		_panel.offset_top = _panel.offset_bottom - 130.0

func _refresh_panel() -> void:
	if _selected == "":
		return
	var c: Dictionary = HudLayout.controls(_d)[_selected]
	var e: Dictionary = _layout[_selected]
	_p_name.text = String(c["label"])
	_p_size.text = "%d%%" % int(roundf(float(e["scale"]) * 100.0))
	_p_op.text = "%d%%" % int(roundf(float(e["opacity"]) * 100.0))
	_vis_btn.text = "REQUIRED" if bool(c["required"]) else ("SHOWN" if bool(e["visible"]) else "HIDDEN")
	_vis_btn.disabled = bool(c["required"])
	var hc: Dictionary = _hap["controls"].get(_selected, {})
	_hap_btn.text = "HAPTIC: " + (String(hc.get("preset", "-")).to_upper() if not hc.is_empty() else "-")
	_hap_btn.disabled = hc.is_empty()

func _refresh_toolbar() -> void:
	_preset_btn.text = "LAYOUT: " + _preset.replace("_", " ").to_upper()
	_test_btn.text = "TEST: ON" if _test else "TEST: OFF"

func _update_warnings() -> void:
	var pairs: Array = HudLayout.overlaps(_d, _layout, _scr)
	var flagged: Dictionary = {}
	for p in pairs:
		flagged[String(p[0])] = true
		flagged[String(p[1])] = true
	for cid in _widgets:
		var w = _widgets[cid]
		w.warn = flagged.has(cid)
		w.queue_redraw()
	_warn.text = "" if pairs.is_empty() else "Some buttons overlap"

func _step_scale(dir: int) -> void:
	if _selected == "":
		return
	_layout[_selected]["scale"] = float(_layout[_selected]["scale"]) + 0.1 * float(dir)
	_changed()

func _step_opacity(dir: int) -> void:
	if _selected == "":
		return
	_layout[_selected]["opacity"] = float(_layout[_selected]["opacity"]) + 0.1 * float(dir)
	_changed()

func _toggle_visible() -> void:
	if _selected == "":
		return
	_layout[_selected]["visible"] = not bool(_layout[_selected]["visible"])
	_changed()

func _cycle_haptic() -> void:
	if _selected == "":
		return
	var cur: String = String(_hap["controls"][_selected].get("preset", "off"))
	var i: int = HAPTIC_ORDER.find(cur)
	var nxt: String = HAPTIC_ORDER[(i + 1) % HAPTIC_ORDER.size()] if i >= 0 else "low"
	_hap = HapticConfig.with_preset(_d, _hap, _selected, nxt)
	_refresh_panel()

func _reset_one() -> void:
	if _selected == "":
		return
	_layout = HudLayout.reset_control(_d, _layout, _selected)
	_changed()

func _reset_all() -> void:
	_layout = HudLayout.default_layout(_d)
	_sanitize_all()
	_preset = "default"
	_place_all()
	_refresh_toolbar()
	_refresh_panel()
	_update_warnings()

func _cycle_preset() -> void:
	var i: int = PRESETS.find(_preset)
	_preset = PRESETS[(i + 1) % PRESETS.size()] if i >= 0 else PRESETS[0]
	_layout = HudLayout.preset(_d, _preset)
	_sanitize_all()
	_place_all()
	_refresh_toolbar()
	_refresh_panel()
	_update_warnings()

func _toggle_test() -> void:
	_test = not _test
	_panel.visible = false if _test else (_selected != "")
	_place_all()
	_refresh_toolbar()

func _save() -> void:
	ControlsManager.set_hud(_layout, _preset)
	ControlsManager.set_haptics(_hap)
	SceneRouter.go(SceneRouter.SETTINGS)
