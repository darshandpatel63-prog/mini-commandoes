extends RefCounted
## Deterministic kinematic movement (walk, jump, crouch, jetpack) over a tile grid. Pure logic, fixed step.
## Identical for every commando. Mirrors tools/ref_model.py move_step; verified by tests/vectors/cases.json "moves".

const TileGrid := preload("res://src/player/tile_grid.gd")
const EPS := 0.000001

static func make(_p: Dictionary, spec: Dictionary) -> Dictionary:
	return {"x": float(spec["x"]), "y": float(spec["y"]), "vx": 0.0, "vy": 0.0, "on_ground": bool(spec.get("on_ground", false)),
		"crouching": bool(spec.get("crouching", false)), "fuel": float(spec.get("fuel", _p["jet_fuel_max"])),
		"jet_lock": 0.0, "jetting": false}

static func _approach(a: float, target: float, d: float) -> float:
	return minf(a + d, target) if a < target else maxf(a - d, target)

static func _any_solid_col(g: Dictionary, col: int, r0: int, r1: int) -> bool:
	for r in range(r0, r1 + 1):
		if TileGrid.tile(g, col, r) == "#":
			return true
	return false

## inp: {move: -1..1, jump: bool (edge), jet: bool (held), crouch: bool (held)}. Returns the new state (input not mutated).
static func step(p: Dictionary, g: Dictionary, st: Dictionary, inp: Dictionary, dt: float) -> Dictionary:
	var s: Dictionary = st.duplicate()
	var t: float = float(p["tile"])
	var hw: float = float(p["hw"])
	var want_crouch: bool = bool(inp.get("crouch", false))
	if want_crouch and bool(s["on_ground"]):
		s["crouching"] = true
	elif bool(s["crouching"]) and not want_crouch:
		if not TileGrid.blocked(p, g, float(s["x"]), float(s["y"]), float(p["h_stand"])):
			s["crouching"] = false
	var h: float = float(p["h_crouch"]) if bool(s["crouching"]) else float(p["h_stand"])
	var mv: float = clampf(float(inp.get("move", 0.0)), -1.0, 1.0)
	var speed: float = float(p["air_speed"])
	if bool(s["on_ground"]):
		speed = float(p["walk_speed"]) * float(p["crouch_mult"]) if bool(s["crouching"]) else float(p["walk_speed"])
	var acc: float = float(p["ground_accel"]) if bool(s["on_ground"]) else float(p["air_accel"])
	s["vx"] = _approach(float(s["vx"]), mv * speed, acc * dt)
	if bool(inp.get("jump", false)) and bool(s["on_ground"]) and not bool(s["crouching"]):
		s["vy"] = -float(p["jump_speed"])
		s["on_ground"] = false
	var jetting: bool = false
	if bool(inp.get("jet", false)) and float(s["fuel"]) > 0.0 and float(s["jet_lock"]) <= 0.0:
		if float(s["vy"]) > -float(p["jet_max_rise"]):
			s["vy"] = maxf(float(s["vy"]) - float(p["jet_accel"]) * dt, -float(p["jet_max_rise"]))
		s["fuel"] = maxf(0.0, float(s["fuel"]) - float(p["jet_drain"]) * dt)
		jetting = true
		s["on_ground"] = false
		if float(s["fuel"]) <= 0.0:
			s["jet_lock"] = float(p["jet_lock"])
	s["jetting"] = jetting
	s["vy"] = minf(float(s["vy"]) + float(p["gravity"]) * dt, float(p["max_fall"]))
	if not jetting:
		if float(s["jet_lock"]) > 0.0:
			s["jet_lock"] = maxf(0.0, float(s["jet_lock"]) - dt)
		else:
			var regen: float = float(p["jet_regen_ground"]) if bool(s["on_ground"]) else float(p["jet_regen_air"])
			s["fuel"] = minf(float(p["jet_fuel_max"]), float(s["fuel"]) + regen * dt)
	# horizontal
	var nx: float = float(s["x"]) + float(s["vx"]) * dt
	var r0: int = floori((float(s["y"]) - h) / t)
	var r1: int = floori((float(s["y"]) - EPS) / t)
	if float(s["vx"]) > 0.0:
		var col: int = floori((nx + hw - EPS) / t)
		if _any_solid_col(g, col, r0, r1):
			nx = float(col) * t - hw
			s["vx"] = 0.0
	elif float(s["vx"]) < 0.0:
		var col2: int = floori((nx - hw) / t)
		if _any_solid_col(g, col2, r0, r1):
			nx = float(col2 + 1) * t + hw
			s["vx"] = 0.0
	s["x"] = nx
	# vertical
	var ny: float = float(s["y"]) + float(s["vy"]) * dt
	var old_bottom: float = float(s["y"])
	var old_top: float = float(s["y"]) - h
	var c0: int = floori((float(s["x"]) - hw) / t)
	var c1: int = floori((float(s["x"]) + hw - EPS) / t)
	var landed: bool = false
	if float(s["vy"]) >= 0.0:
		var r: int = floori(ny / t)
		var b: float = float(r) * t
		if old_bottom <= b + EPS:
			for c in range(c0, c1 + 1):
				var tc: String = TileGrid.tile(g, c, r)
				if tc == "#" or tc == "=":
					ny = b
					s["vy"] = 0.0
					landed = true
					break
	else:
		var r2: int = floori((ny - h) / t)
		var edge: float = float(r2 + 1) * t
		if old_top >= edge - EPS:
			for c in range(c0, c1 + 1):
				if TileGrid.tile(g, c, r2) == "#":
					ny = edge + h
					s["vy"] = 0.0
					break
	s["y"] = ny
	s["on_ground"] = landed
	return s
