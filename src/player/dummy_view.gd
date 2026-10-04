extends Node2D
## Training dummy: a combatant (real HP/armor state) with a simple body drawn from code. Presentation only.

var state: Dictionary = {}
var d: Dictionary = {}
var flash: float = 0.0
var down_time: float = 0.0

func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
		queue_redraw()

func _draw() -> void:
	if state.is_empty():
		return
	var alive: bool = bool(state["alive"])
	var body: Color = Color("#7a5a3a") if alive else Color(0.3, 0.3, 0.3, 0.5)
	body = body.lerp(Color.WHITE, flash * 0.7)
	draw_rect(Rect2(-18, -92, 36, 92), body)                       # torso + legs
	draw_circle(Vector2(0, -80), 14.0, body.lightened(0.15))       # head
	var hl: int = int(state["helmet"]["level"])
	var vl: int = int(state["vest"]["level"])
	if hl > 0 and float(state["helmet"]["dur"]) > 0.0:
		draw_arc(Vector2(0, -80), 15.0, PI, TAU, 14, Color("#7FA8D6"), 4.0)
	if vl > 0 and float(state["vest"]["dur"]) > 0.0:
		draw_rect(Rect2(-18, -64, 36, 30), Color(0.5, 0.66, 0.84, 0.55))
	var frac: float = clampf(float(state["hp"]) / float(state["max_hp"]), 0.0, 1.0)
	draw_rect(Rect2(-24, -116, 48, 7), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-24, -116, 48.0 * frac, 7), Color("#5BD66F") if frac > 0.4 else Color("#FF5A4F"))
	draw_string(ThemeDB.fallback_font, Vector2(-24, -122), "H%d V%d" % [hl, vl], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
