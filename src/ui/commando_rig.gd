extends Node2D
## Cut-out commando assembled from the baked sprites (assets/art/commando/*, described by rig.json).
## Presentation only: it reads simulation state and never changes it. Origin = feet centre; faces +x (flipped by `facing`).

const RIG_PATH := "res://assets/art/commando/rig.json"
const WORLD_SCALE := 0.667            # texture px -> world px (character ~104 px tall)
const FLAME_POS := Vector2(-28.0, -26.0)

var _rig: Dictionary = {}
var _node: Dictionary = {}            # part -> Node2D
var _rel_rest: Dictionary = {}        # part -> rest rotation relative to its parent node
var _base_pos: Dictionary = {}
var _phase: float = 0.0
var _time: float = 0.0
var _weapon: Node2D
var _flame: Node2D
var _jet_on: bool = false
var flash: float = 0.0

func setup(character_id: String) -> bool:
	var f := FileAccess.open(RIG_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return false
	_rig = parsed
	scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	var folder: String = "res://assets/art/commando/%s/" % character_id
	_build_leg("thigh_far", "shin_far", folder)
	_build_body(folder)
	_build_leg("thigh_near", "shin_near", folder)
	return true

func _part(pn: String) -> Dictionary:
	return _rig["parts"][pn]

func _node_for(pn: String, parent_name: String, parent: Node) -> Node2D:
	var p: Dictionary = _part(pn)
	var n := Node2D.new()
	var piv := Vector2(float(p["pivot"][0]), float(p["pivot"][1]))
	var rest: float = float(p["rest_rad"])
	if parent_name != "":
		var pp: Dictionary = _part(parent_name)
		piv -= Vector2(float(pp["pivot"][0]), float(pp["pivot"][1]))
		rest -= float(pp["rest_rad"])
	n.position = piv
	n.rotation = rest
	_base_pos[pn] = piv
	_rel_rest[pn] = rest
	_node[pn] = n
	parent.add_child(n)
	return n

func _sprite(pn: String, folder: String, parent: Node) -> void:
	var p: Dictionary = _part(pn)
	var s := Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.texture = load(folder + String(p["file"]))
	s.position = Vector2(float(p["texture_offset"][0]), float(p["texture_offset"][1]))
	parent.add_child(s)

func _build_leg(thigh: String, shin: String, folder: String) -> void:
	var tn: Node2D = _node_for(thigh, "", self)
	_sprite(thigh, folder, tn)
	var sn: Node2D = _node_for(shin, thigh, tn)
	_sprite(shin, folder, sn)

func _build_body(folder: String) -> void:
	var b: Node2D = _node_for("body", "", self)
	var far: Node2D = _node_for("arm_far", "body", b)
	_sprite("arm_far", folder, far)
	_sprite("body", folder, b)
	var near: Node2D = _node_for("arm_near", "body", b)
	_sprite("arm_near", folder, near)
	_flame = Node2D.new()
	_flame.position = FLAME_POS
	_flame.show_behind_parent = true
	_flame.draw.connect(_draw_flame)
	b.add_child(_flame)
	b.move_child(_flame, 0)
	var w: Array = _part("arm_near")["wrist"]
	_weapon = Node2D.new()
	_weapon.position = Vector2(float(w[0]), float(w[1]))
	_weapon.rotation = Vector2(float(w[0]), float(w[1])).angle()
	_weapon.draw.connect(_draw_weapon)
	near.add_child(_weapon)

func _draw_weapon() -> void:
	_weapon.draw_rect(Rect2(-18, -4, 20, 9), Color("#2a2d31"))
	_weapon.draw_rect(Rect2(0, -6, 44, 11), Color("#3b4046"))
	_weapon.draw_rect(Rect2(0, -6, 44, 3), Color("#59616a"))
	_weapon.draw_rect(Rect2(44, -3, 26, 6), Color("#23262a"))
	_weapon.draw_rect(Rect2(12, 5, 9, 16), Color("#23262a"))

func _draw_flame() -> void:
	if not _jet_on:
		return
	var fl: float = 30.0 + 10.0 * sin(_time * 55.0) + 6.0 * sin(_time * 31.0)
	_flame.draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(0, fl)]), Color("#FF7A2E"))
	_flame.draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, fl * 0.6)]), Color("#FFE27A"))

func _rot(pn: String, extra: float) -> void:
	(_node[pn] as Node2D).rotation = float(_rel_rest[pn]) + extra

## aim: world direction of the weapon (Vector2.ZERO = relaxed carry pose).
func pose(delta: float, st: Dictionary, facing: int, aim: Vector2, recoil: float) -> void:
	if _node.is_empty():
		return
	_time += delta
	var vx: float = float(st["vx"])
	var on_ground: bool = bool(st["on_ground"])
	var crouch: bool = bool(st["crouching"])
	_jet_on = bool(st["jetting"])
	scale.x = WORLD_SCALE * float(facing)
	var run: float = clampf(absf(vx) / 360.0, 0.0, 1.0) if on_ground else 0.0
	if run > 0.05:
		_phase += delta * (7.0 + 5.0 * run)
	var sw: float = sin(_phase) * 0.75 * run
	var drop: float = 0.0
	if crouch:
		drop = 20.0
		_rot("thigh_near", -0.9)
		_rot("shin_near", 1.6)
		_rot("thigh_far", -0.6)
		_rot("shin_far", 1.3)
	elif not on_ground:
		var tuck: float = 0.35 if _jet_on else 1.0
		_rot("thigh_near", -0.55 * tuck)
		_rot("shin_near", 0.9 * tuck)
		_rot("thigh_far", 0.25 * tuck)
		_rot("shin_far", 0.5 * tuck)
	else:
		_rot("thigh_near", sw)
		_rot("thigh_far", -sw)
		_rot("shin_near", maxf(0.0, sin(_phase - 1.2)) * 1.1 * run)
		_rot("shin_far", maxf(0.0, sin(_phase + PI - 1.2)) * 1.1 * run)
	for n in ["body", "thigh_near", "thigh_far"]:
		(_node[n] as Node2D).position = Vector2(_base_pos[n]) + Vector2(0.0, drop)
	(_node["body"] as Node2D).scale.y = 1.0 + 0.008 * sin(_time * 2.2)
	(_node["body"] as Node2D).rotation = 0.06 * run + (0.12 if crouch else 0.0)
	var phi: float = 0.6
	if aim.length() > 0.05:
		var d: Vector2 = aim.normalized()
		phi = atan2(d.y, absf(d.x))
	var a_rest: float = float(_part("arm_near")["rest_rad"])
	var rot: float = a_rest - PI / 2.0 + phi - (node_rot("body"))
	(_node["arm_near"] as Node2D).rotation = rot
	(_node["arm_far"] as Node2D).rotation = rot + 0.12
	var wr := Vector2(float(_part("arm_near")["wrist"][0]), float(_part("arm_near")["wrist"][1]))
	_weapon.position = wr - wr.normalized() * recoil * 8.0
	var tint: float = clampf(flash, 0.0, 1.0)
	modulate = Color(1.0, 1.0 - 0.6 * tint, 1.0 - 0.6 * tint)
	flash = maxf(0.0, flash - delta * 4.0)
	_flame.queue_redraw()

func node_rot(pn: String) -> float:
	return (_node[pn] as Node2D).rotation
