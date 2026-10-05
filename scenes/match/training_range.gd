extends Node2D
## TRAINING RANGE (Phase 2 slice): walk, jump, crouch and jetpack over a tile map with the player's baked commando,
## touch controls from the saved HUD layout, a hitscan weapon, and dummies that run the REAL damage pipeline.
## Movement = MoveSim (verified by vectors). Weapons are simplified (hitscan, ammo, reload); full weapon system comes in Phase 3.

const MoveSim := preload("res://src/player/move_sim.gd")
const TileGrid := preload("res://src/player/tile_grid.gd")
const DamagePipeline := preload("res://src/combat/damage_pipeline.gd")
const Vitals := preload("res://src/combat/vitals.gd")
const SkillExec := preload("res://src/combat/skill_exec.gd")
const Combatant := preload("res://src/combat/combatant.gd")
const StatResolver := preload("res://src/combat/stat_resolver.gd")
const CommandoRig := preload("res://src/ui/commando_rig.gd")
const TouchControls := preload("res://src/ui/touch_controls.gd")
const DummyView := preload("res://src/player/dummy_view.gd")
const UITheme := preload("res://src/ui/ui_theme.gd")
const UIKit := preload("res://src/ui/ui_kit.gd")
const MAP_PATH := "res://data/maps/training.json"
const DT := 1.0 / 60.0
const DUMMY_LEVELS := [0, 1, 2, 3, 1]

var _d: Dictionary
var _mp: Dictionary
var _lo: Dictionary
var _grid: Dictionary
var _map_px: Vector2 = Vector2.ZERO
var _spawn: Vector2 = Vector2.ZERO
var _marks: Array = []
var _sim: Dictionary = {}
var _combat: Dictionary = {}
var _now: float = 0.0
var _facing: int = 1
var _world: Node2D
var _rig = null            # untyped: custom script methods
var _cam: Camera2D
var _touch = null          # untyped: custom script methods
var _dummies: Array = []
var _weapon: Dictionary = {}
var _melee: Dictionary = {}
var _mag: int = 0
var _fire_cd: float = 0.0
var _melee_cd: float = 0.0
var _reload_left: float = 0.0
var _recoil: float = 0.0
var _haptic_cd: float = 0.0
var _toast: Label
var _toast_t: float = 0.0
var _hp_bar: ProgressBar
var _ep_bar: ProgressBar
var _fuel_bar: ProgressBar
var _info: Label

func _ready() -> void:
	_d = DataRegistry.bundle()
	_mp = _d["move"]
	_lo = SaveManager.loadout()
	InputRouter.set_mode(InputRouter.Mode.GAMEPLAY)
	GameState.set_state(GameState.AppState.MATCH)
	if not _load_map():
		push_error("training map failed to load")
		SceneRouter.go(SceneRouter.MAIN_MENU)
		return
	_weapon = _d["weapons"][String(_lo["primary"])]
	_melee = _d["melee"][String(_lo["melee"])]
	_mag = int(_weapon["mag"])
	_build_world()
	_build_player()
	_build_ui()
	_say("Training Range. Jetpack, jump, shoot the dummies.")

func _load_map() -> bool:
	var f := FileAccess.open(MAP_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return false
	var rows: Array = []
	var raw_rows: Array = parsed["rows"]
	for r in raw_rows.size():
		var line: String = String(raw_rows[r])
		var clean: String = ""
		for c in line.length():
			var ch: String = line.substr(c, 1)
			if ch == "S":
				_spawn = Vector2(float(c) * 32.0 + 16.0, float(r + 1) * 32.0)
				ch = "."
			elif ch == "D":
				_marks.append(Vector2(float(c) * 32.0 + 16.0, float(r + 1) * 32.0))
				ch = "."
			clean += ch
		rows.append(clean)
	_grid = TileGrid.make(rows)
	_map_px = Vector2(float(_grid["w"]) * 32.0, float(_grid["h"]) * 32.0)
	return _spawn != Vector2.ZERO

func _build_world() -> void:
	_world = Node2D.new()
	add_child(_world)
	_world.draw.connect(_draw_world)
	_world.queue_redraw()
	_cam = Camera2D.new()
	_cam.zoom = Vector2(1.2, 1.2)
	_cam.limit_left = 0
	_cam.limit_right = int(_map_px.x)
	_cam.limit_bottom = int(_map_px.y)
	_cam.limit_top = -500
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 7.0
	add_child(_cam)
	for i in _marks.size():
		var dv = DummyView.new()
		dv.d = _d
		var lvl: int = int(DUMMY_LEVELS[i % DUMMY_LEVELS.size()])
		dv.state = Combatant.make(_d, {"helmet": [lvl], "vest": [lvl]})
		dv.position = _marks[i]
		dv.set_meta("level", lvl)
		dv.set_meta("respawn", 0.0)
		_world.add_child(dv)
		_dummies.append(dv)

func _draw_world() -> void:
	var sky_top: Color = Color("#0f1a16")
	var sky_bot: Color = Color("#1d3328")
	for i in 8:
		var t: float = float(i) / 7.0
		_world.draw_rect(Rect2(-800.0, -1400.0 + float(i) * 400.0, _map_px.x + 1600.0, 410.0), sky_top.lerp(sky_bot, t))
	var rows: Array = _grid["rows"]
	for r in rows.size():
		var line: String = String(rows[r])
		var c: int = 0
		while c < line.length():
			var ch: String = line.substr(c, 1)
			if ch == "#" or ch == "=":
				var c2: int = c
				while c2 + 1 < line.length() and line.substr(c2 + 1, 1) == ch:
					c2 += 1
				var rect := Rect2(float(c) * 32.0, float(r) * 32.0, float(c2 - c + 1) * 32.0, 32.0)
				if ch == "#":
					_world.draw_rect(rect, Color("#2c3d33"))
					_world.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), Color("#4a6a52"))
				else:
					_world.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 9.0)), Color("#7FB069"))
				c = c2 + 1
			else:
				c += 1

func _build_player() -> void:
	_sim = MoveSim.make(_mp, {"x": _spawn.x, "y": _spawn.y})
	_combat = Combatant.from_loadout(_d, _lo)
	_rig = CommandoRig.new()
	_world.add_child(_rig)
	if not _rig.setup(String(_lo["character"])):
		push_error("rig failed to load")
	_rig.position = Vector2(float(_sim["x"]), float(_sim["y"]))
	_cam.position = Vector2(float(_sim["x"]), float(_sim["y"]) - 80.0)

func _bar(color: Color, w: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, 22)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(6)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.theme = UITheme.make()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scr: Vector2 = get_viewport_rect().size
	_touch = TouchControls.new()
	root.add_child(_touch)
	_touch.setup(_d, scr)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(32, 20)
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	_hp_bar = _bar(Color("#5BD66F"), 520)
	_ep_bar = _bar(Color("#4FD1C5"), 420)
	_fuel_bar = _bar(Color("#FF9A3C"), 320)
	box.add_child(_hp_bar)
	box.add_child(_ep_bar)
	box.add_child(_fuel_bar)
	_info = UIKit.label("", 24, UITheme.C_TEXT)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_info)
	_toast = UIKit.label("", 34, UITheme.C_PRIMARY)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.position = Vector2(scr.x * 0.5 - 380.0, 24.0)
	_toast.custom_minimum_size = Vector2(760, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_toast)
	var ex: Button = UIKit.button("EXIT", _exit, 150, "back")
	ex.position = Vector2(scr.x - 190.0, 20.0)
	ex.custom_minimum_size = Vector2(150, 80)
	root.add_child(ex)

func _exit() -> void:
	SceneRouter.go(SceneRouter.MAIN_MENU)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_exit()

func _say(text: String) -> void:
	if _toast != null:
		_toast.text = text
		_toast_t = 2.2

# ------------------------------------------------------------------ simulation
func _physics_process(_delta: float) -> void:
	if _sim.is_empty():
		return
	var ts: Dictionary = _touch.state
	var inp: Dictionary = {"move": float(ts["move"]), "jump": _touch.consume("jump"), "jet": bool(ts["jet"]), "crouch": bool(ts["crouch"])}
	_sim = MoveSim.step(_mp, _grid, _sim, inp, DT)
	var aim: Vector2 = ts["aim"]
	if bool(ts["aim_active"]) and absf(aim.x) > 0.1:
		_facing = 1 if aim.x > 0.0 else -1
	elif absf(float(ts["move"])) > 0.1:
		_facing = 1 if float(ts["move"]) > 0.0 else -1
	_now += DT
	_combat = Vitals.tick(_d, _combat, DT, _now)
	_fire_cd = maxf(0.0, _fire_cd - DT)
	_melee_cd = maxf(0.0, _melee_cd - DT)
	_haptic_cd = maxf(0.0, _haptic_cd - DT)
	_recoil = maxf(0.0, _recoil - DT * 6.0)
	if _reload_left > 0.0:
		_reload_left -= DT
		if _reload_left <= 0.0:
			_mag = int(_weapon["mag"])
			_say("Reloaded")
	_actions(ts)
	for dv in _dummies:
		if not bool(dv.state["alive"]):
			dv.set_meta("respawn", float(dv.get_meta("respawn")) - DT)
			if float(dv.get_meta("respawn")) <= 0.0:
				var lvl: int = int(dv.get_meta("level"))
				dv.state = Combatant.make(_d, {"helmet": [lvl], "vest": [lvl]})
				dv.queue_redraw()
		else:
			dv.state = Vitals.tick(_d, dv.state, DT, _now)

func _actions(ts: Dictionary) -> void:
	var aim: Vector2 = ts["aim"]
	var fire_mode_drag: bool = int(Settings.get_value("aim_mode")) == 0
	var wants_fire: bool = bool(ts["fire_held"]) or (fire_mode_drag and bool(ts["aim_active"]) and aim.length() > 0.45)
	if wants_fire:
		_try_fire()
	if _touch.consume("reload"):
		_start_reload()
	if _touch.consume("melee"):
		_do_melee()
	if _touch.consume("skill"):
		_use_skill(String(_lo.get("active", "")))
	if _touch.consume("pet"):
		_use_skill(String(_d["pets"].get(String(_lo.get("pet", "")), {}).get("skill", "")))
	if _touch.consume("heal"):
		_use_item("health_kit" if float(_combat["hp"]) < 125.0 else "bandage")
	if _touch.consume("ep_item"):
		_use_item("ep_cell")
	for k in ["swap", "grenade", "interact"]:
		if _touch.consume(k):
			_say("%s is not available in training yet" % k.capitalize())

func _shoulder() -> Vector2:
	return Vector2(float(_sim["x"]), float(_sim["y"]) - (50.0 if bool(_sim["crouching"]) else 80.0))

func _aim_dir() -> Vector2:
	var ts: Dictionary = _touch.state
	var aim: Vector2 = ts["aim"]
	if bool(ts["aim_active"]):
		return aim.normalized()
	return Vector2(float(_facing), 0.0)

func _start_reload() -> void:
	if _reload_left > 0.0 or _mag >= int(_weapon["mag"]):
		return
	var stats: Dictionary = StatResolver.of(_d["rules"], _combat, _now)
	_reload_left = float(_weapon["reload"]) * float(stats["reload_time_mult"])
	_say("Reloading...")

func _try_fire() -> void:
	if _reload_left > 0.0 or _fire_cd > 0.0:
		return
	if _mag <= 0:
		_start_reload()
		return
	var dir: Vector2 = _aim_dir()
	var origin: Vector2 = _shoulder() + dir * 72.0
	var pellets: int = int(_weapon.get("pellets", 1))
	var spread: float = deg_to_rad(float(_weapon["spread"]))
	for i in pellets:
		var jitter: float = randf_range(-spread, spread) * 0.5
		_shoot_ray(origin, dir.rotated(jitter))
	_mag -= 1
	_fire_cd = 60.0 / float(_weapon["rpm"])
	_recoil = 1.0
	if _haptic_cd <= 0.0:
		Haptics.pulse("fire")
		_haptic_cd = 0.12

func _shoot_ray(origin: Vector2, dir: Vector2) -> void:
	var reach: float = minf(float(_weapon["range"]), 1600.0)
	var p: Vector2 = origin
	var travelled: float = 0.0
	var end: Vector2 = origin + dir * reach
	var hit_dummy = null
	while travelled < reach:
		p += dir * 8.0
		travelled += 8.0
		if TileGrid.tile(_grid, floori(p.x / 32.0), floori(p.y / 32.0)) == "#":
			end = p
			break
		for dv in _dummies:
			if bool(dv.state["alive"]) and absf(p.x - dv.position.x) <= 18.0 and p.y <= dv.position.y and p.y >= dv.position.y - 92.0:
				hit_dummy = dv
				break
		if hit_dummy != null:
			end = p
			break
	_tracer(origin, end)
	if hit_dummy != null:
		var zone: String = "head" if p.y < hit_dummy.position.y - 70.0 else "body"
		_damage_dummy(hit_dummy, {"damage": float(_weapon["dmg"]), "zone": zone, "head_mult": float(_weapon["head_mult"]), "armor_pen": float(_weapon["armor_pen"])}, p)

func _damage_dummy(dv, hit: Dictionary, at: Vector2) -> void:
	var r: Dictionary = DamagePipeline.apply_hit(_d, dv.state, hit, _now)
	dv.state = r["state"]
	dv.flash = 1.0
	dv.queue_redraw()
	var rep: Dictionary = r["report"]
	var txt: String = UIKit.num(snappedf(float(rep["hp_damage"]), 0.1))
	if bool(rep["piece_broken"]):
		txt += " BREAK"
	_float_text(at, txt, Color("#FF5A4F") if hit["zone"] == "head" else Color("#FFE27A"))
	if bool(rep["killed"]):
		dv.set_meta("respawn", 3.0)
		_say("Dummy down")

func _tracer(a: Vector2, b: Vector2) -> void:
	var ln := Line2D.new()
	ln.width = 3.0
	ln.default_color = Color("#FFE27A")
	ln.points = PackedVector2Array([a, b])
	_world.add_child(ln)
	var tw := create_tween()
	tw.tween_property(ln, "modulate:a", 0.0, 0.10)
	tw.tween_callback(ln.queue_free)

func _float_text(at: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = at - Vector2(20, 30)
	l.z_index = 50
	_world.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)

func _do_melee() -> void:
	if _melee_cd > 0.0:
		return
	_melee_cd = float(_melee["rate"])
	var reach: Vector2 = Vector2(float(_sim["x"]) + float(_facing) * 52.0, float(_sim["y"]) - 46.0)
	for dv in _dummies:
		if bool(dv.state["alive"]) and absf(dv.position.x - reach.x) <= 46.0 and absf((dv.position.y - 46.0) - reach.y) <= 56.0:
			_damage_dummy(dv, {"damage": float(_melee["dmg"]), "zone": "body", "armor_break": float(_melee["armor_break"])}, reach)
			return
	_say("Swing")

func _use_skill(skill_id: String) -> void:
	if skill_id == "":
		_say("Nothing equipped in that slot")
		return
	var r: Dictionary = SkillExec.activate(_d, _combat, skill_id, _now)
	_combat = r["state"]
	var nm: String = String(_d["skills"][skill_id]["name"])
	_say(nm if String(r["err"]) == "" else "%s: %s" % [nm, String(r["err"]).capitalize()])

func _use_item(item_id: String) -> void:
	var r: Dictionary = Vitals.item_start(_d, _combat, item_id, _now)
	_combat = r["state"]
	_say(item_id.replace("_", " ").capitalize() + (" ..." if String(r["err"]) == "" else ": " + String(r["err"]).capitalize()))

# ------------------------------------------------------------------ presentation
func _process(delta: float) -> void:
	if _sim.is_empty():
		return
	_rig.position = Vector2(float(_sim["x"]), float(_sim["y"]))
	var ts: Dictionary = _touch.state
	var aim: Vector2 = ts["aim"] if bool(ts["aim_active"]) else Vector2.ZERO
	_rig.pose(delta, _sim, _facing, aim, _recoil)
	_cam.position = Vector2(float(_sim["x"]), float(_sim["y"]) - 90.0)
	_hp_bar.max_value = float(_combat["max_hp"])
	_hp_bar.value = float(_combat["hp"])
	_ep_bar.max_value = Vitals.max_ep(_d, _combat, _now)
	_ep_bar.value = float(_combat["ep"])
	_fuel_bar.max_value = float(_mp["jet_fuel_max"])
	_fuel_bar.value = float(_sim["fuel"])
	var lock: String = "  JET COOLING" if float(_sim["jet_lock"]) > 0.0 else ""
	_info.text = "%s  %d/%d%s   HP %s  EP %s%s" % [String(_weapon["name"]), _mag, int(_weapon["mag"]), "  RELOADING" if _reload_left > 0.0 else "", UIKit.num(snappedf(float(_combat["hp"]), 1.0)), UIKit.num(snappedf(float(_combat["ep"]), 1.0)), lock]
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)
