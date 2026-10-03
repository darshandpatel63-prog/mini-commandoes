extends RefCounted
## HUD layout rules: clamping to valid screen area, size/opacity limits, required controls, overlap detection.
## Layout = {control_id: {x, y, scale, opacity, visible}} with x,y = normalized centre. Sizes in logical px (1080 px height basis).

static func controls(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for c in d["hud"]:
		out[String(c["id"])] = c
	return out

static func default_layout(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for c in d["hud"]:
		out[String(c["id"])] = {"x": float(c["x"]), "y": float(c["y"]), "scale": float(c["scale"]),
			"opacity": float(c["opacity"]), "visible": bool(c["visible"])}
	return out

static func _num(v: Variant, fallback: float) -> float:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		var f: float = float(v)
		if is_nan(f) or is_inf(f):
			return fallback
		return f
	return fallback

## insets = [left, top, right, bottom] in logical px (notch / system bars).
static func sanitize(d: Dictionary, layout: Variant, screen: Vector2, insets: Array = [0, 0, 0, 0]) -> Dictionary:
	var H: Dictionary = d["rules"]["hud"]
	var ctl: Dictionary = controls(d)
	var dflt: Dictionary = default_layout(d)
	var out: Dictionary = {}
	var sr: Array = H["scale_range"]
	var orng: Array = H["opacity_range"]
	var m: float = float(H["margin"])
	for cid in ctl:
		var c: Dictionary = ctl[cid]
		var e: Dictionary = dflt[cid]
		if typeof(layout) == TYPE_DICTIONARY and typeof(layout.get(cid)) == TYPE_DICTIONARY:
			e = layout[cid]
		var scale: float = clampf(_num(e.get("scale"), 1.0), float(sr[0]), float(sr[1]))
		var opacity: float = clampf(_num(e.get("opacity"), 0.7), float(orng[0]), float(orng[1]))
		var visible: bool = true if bool(c["required"]) else (bool(e.get("visible", true)) if typeof(e.get("visible", true)) == TYPE_BOOL else true)
		var hw: float = float(c["size"]) * scale / 2.0 / screen.x
		var hh: float = float(c["size"]) * scale / 2.0 / screen.y
		var xmin: float = maxf(m, float(insets[0]) / screen.x) + hw
		var xmax: float = 1.0 - maxf(m, float(insets[2]) / screen.x) - hw
		var ymin: float = maxf(float(H["top_reserved"]), float(insets[1]) / screen.y) + hh
		var ymax: float = 1.0 - maxf(m, float(insets[3]) / screen.y) - hh
		var x: float = 0.5
		var y: float = 0.5
		if xmin <= xmax:
			x = clampf(_num(e.get("x"), float(dflt[cid]["x"])), xmin, xmax)
		if ymin <= ymax:
			y = clampf(_num(e.get("y"), float(dflt[cid]["y"])), ymin, ymax)
		out[cid] = {"x": snappedf(x, 0.00001), "y": snappedf(y, 0.00001), "scale": snappedf(scale, 0.0001),
			"opacity": snappedf(opacity, 0.0001), "visible": visible}
	return out

## Returns Array of [id_a, id_b] for visible controls whose touch circles overlap too much.
static func overlaps(d: Dictionary, layout: Dictionary, screen: Vector2) -> Array:
	var ctl: Dictionary = controls(d)
	var f: float = float(d["rules"]["hud"]["overlap_factor"])
	var ids: Array = []
	for cid in ctl:
		if bool(layout[cid]["visible"]):
			ids.append(cid)
	var pairs: Array = []
	for a in ids.size():
		for b in range(a + 1, ids.size()):
			var ia: String = ids[a]
			var ib: String = ids[b]
			var ra: float = float(ctl[ia]["size"]) * float(layout[ia]["scale"]) / 2.0
			var rb: float = float(ctl[ib]["size"]) * float(layout[ib]["scale"]) / 2.0
			var dx: float = (float(layout[ia]["x"]) - float(layout[ib]["x"])) * screen.x
			var dy: float = (float(layout[ia]["y"]) - float(layout[ib]["y"])) * screen.y
			if sqrt(dx * dx + dy * dy) < (ra + rb) * f:
				pairs.append([ia, ib])
	return pairs

static func preset(d: Dictionary, preset_name: String) -> Dictionary:
	var lay: Dictionary = default_layout(d)
	if preset_name == "left_handed":
		for k in lay:
			lay[k]["x"] = snappedf(1.0 - float(lay[k]["x"]), 0.00001)
	elif preset_name == "compact":
		for k in lay:
			lay[k]["scale"] = snappedf(float(lay[k]["scale"]) * 0.85, 0.0001)
	return lay

static func reset_control(d: Dictionary, layout: Dictionary, cid: String) -> Dictionary:
	var out: Dictionary = layout.duplicate(true)
	var dflt: Dictionary = default_layout(d)
	if dflt.has(cid):
		out[cid] = (dflt[cid] as Dictionary).duplicate()
	return out
