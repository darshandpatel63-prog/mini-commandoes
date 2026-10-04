extends Control
## In-match touch controls built from the player's saved HUD layout (ControlsManager.hud).
## Multi-touch: every finger binds to the control it first touched. Read `state` / `consume(id)` from the match.

const HudLayout := preload("res://src/core/hud_layout.gd")
const HudWidget := preload("res://src/ui/hud_widget.gd")
const STICKS := ["move", "aim"]

var state: Dictionary = {"move": 0.0, "aim": Vector2.ZERO, "aim_active": false, "jet": false, "crouch": false, "fire_held": false}
var _d: Dictionary
var _scr: Vector2
var _layout: Dictionary = {}
var _widgets: Dictionary = {}
var _binds: Dictionary = {}          # finger index -> control id
var _edges: Dictionary = {}
var _held: Dictionary = {}
var _order: Array = []

func setup(d: Dictionary, scr: Vector2) -> void:
	_d = d
	_scr = scr
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout = HudLayout.sanitize(d, ControlsManager.hud, scr)
	var ctl: Dictionary = HudLayout.controls(d)
	for cid in ctl:
		var e: Dictionary = _layout[cid]
		if not bool(e["visible"]):
			continue
		var w = HudWidget.new()
		w.interactive = false
		w.control_id = String(cid)
		w.label_text = String(ctl[cid]["label"])
		w.is_stick = bool(ctl[cid]["stick"])
		var sz: float = float(ctl[cid]["size"]) * float(e["scale"])
		w.size = Vector2(sz, sz)
		w.position = Vector2(float(e["x"]) * scr.x - sz / 2.0, float(e["y"]) * scr.y - sz / 2.0)
		w.fill_alpha = float(e["opacity"])
		w.draggable = false
		add_child(w)
		_widgets[cid] = w
		_order.append(cid)

func consume(id: String) -> bool:
	var v: bool = bool(_edges.get(id, false))
	_edges[id] = false
	return v

func held(id: String) -> bool:
	return bool(_held.get(id, false))

func _hit(pos: Vector2) -> String:
	for i in range(_order.size() - 1, -1, -1):
		var cid: String = _order[i]
		var w = _widgets[cid]
		var c: Vector2 = w.position + w.size / 2.0
		if pos.distance_to(c) <= minf(w.size.x, w.size.y) / 2.0 * 1.15:
			return cid
	return ""

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var cid: String = _hit(event.position)
			if cid != "":
				_binds[event.index] = cid
				_press(cid, event.position)
		else:
			if _binds.has(event.index):
				_release(String(_binds[event.index]))
				_binds.erase(event.index)
	elif event is InputEventScreenDrag:
		if _binds.has(event.index):
			var cid2: String = String(_binds[event.index])
			if STICKS.has(cid2):
				_update_stick(cid2, event.position)

func _press(cid: String, pos: Vector2) -> void:
	_held[cid] = true
	_edges[cid] = true
	_widgets[cid].held = true
	_widgets[cid].queue_redraw()
	if STICKS.has(cid):
		_update_stick(cid, pos)
	else:
		Haptics.pulse(cid)
		match cid:
			"jet": state["jet"] = true
			"crouch": state["crouch"] = true
			"fire": state["fire_held"] = true

func _release(cid: String) -> void:
	_held[cid] = false
	_widgets[cid].held = false
	if STICKS.has(cid):
		_widgets[cid].knob_offset = Vector2.ZERO
		if cid == "move":
			state["move"] = 0.0
		else:
			state["aim"] = Vector2.ZERO
			state["aim_active"] = false
	else:
		match cid:
			"jet": state["jet"] = false
			"crouch": state["crouch"] = false
			"fire": state["fire_held"] = false
	_widgets[cid].queue_redraw()

func _update_stick(cid: String, pos: Vector2) -> void:
	var w = _widgets[cid]
	var c: Vector2 = w.position + w.size / 2.0
	var r: float = minf(w.size.x, w.size.y) / 2.0
	var v: Vector2 = (pos - c) / r
	if v.length() > 1.0:
		v = v.normalized()
	w.knob_offset = v * r * 0.55
	w.queue_redraw()
	if cid == "move":
		state["move"] = clampf(v.x * 1.6, -1.0, 1.0) if absf(v.x) > 0.18 else 0.0
		state["crouch"] = v.y > 0.7 or bool(_held.get("crouch", false))
	else:
		state["aim"] = v
		state["aim_active"] = v.length() > 0.2
