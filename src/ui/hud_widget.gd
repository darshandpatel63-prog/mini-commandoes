extends Control
## One draggable touch-control widget used by the HUD editor (and later by the real match HUD).

signal picked(id: String)
signal dragging(id: String)
signal released(id: String)

var control_id: String = ""
var label_text: String = ""
var is_stick: bool = false
var selected: bool = false
var warn: bool = false
var shown: bool = true
var draggable: bool = true
var fill_alpha: float = 0.7
var flash: float = 0.0
var _drag: bool = false
var _grab: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func do_flash() -> void:
	flash = 1.0
	set_process(true)

func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 3.0)
	queue_redraw()
	if flash <= 0.0:
		set_process(false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			picked.emit(control_id)
			if draggable:
				_drag = true
				_grab = event.position
		elif _drag:
			_drag = false
			released.emit(control_id)
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		position += event.position - _grab
		dragging.emit(control_id)
		accept_event()

func _draw() -> void:
	var r: float = minf(size.x, size.y) / 2.0
	var c: Vector2 = size / 2.0
	var a: float = fill_alpha if shown else 0.15
	draw_circle(c, r, Color(0.07, 0.12, 0.10, a))
	draw_arc(c, r - 3.0, 0.0, TAU, 48, Color(0.91, 0.64, 0.24, minf(1.0, a + 0.3)), 6.0, true)
	if is_stick:
		draw_circle(c, r * 0.38, Color(0.91, 0.64, 0.24, a))
	var fs: int = int(clampf(r * 0.30, 22.0, 40.0))
	var txt: String = label_text if shown else label_text + " (off)"
	draw_string(ThemeDB.fallback_font, Vector2(0.0, c.y + float(fs) * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(0.95, 0.96, 0.93, minf(1.0, a + 0.25)))
	if selected:
		draw_arc(c, r + 6.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.2), 6.0, true)
	if warn:
		draw_arc(c, r + 14.0, 0.0, TAU, 48, Color(1.0, 0.35, 0.3), 5.0, true)
	if flash > 0.0:
		draw_circle(c, r, Color(1.0, 1.0, 1.0, flash * 0.5))
