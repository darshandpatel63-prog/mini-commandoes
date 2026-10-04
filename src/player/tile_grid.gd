extends RefCounted
## Tile map queries. rows = Array of Strings: '#' solid, '=' one-way platform, '.' empty (S spawn, D dummy are empty).
## Outside the map: left/right/bottom are solid walls, above the top is open sky. Mirrors tools/ref_model.py.

static func make(rows: Array) -> Dictionary:
	var w: int = 0
	for r in rows:
		w = maxi(w, String(r).length())
	return {"rows": rows, "w": w, "h": rows.size()}

static func tile(g: Dictionary, cx: int, cy: int) -> String:
	if cx < 0 or cx >= int(g["w"]) or cy >= int(g["h"]):
		return "#"
	if cy < 0:
		return "."
	var row: String = String(g["rows"][cy])
	if cx >= row.length():
		return "."
	return row.substr(cx, 1)

static func blocked(p: Dictionary, g: Dictionary, x: float, y: float, h: float) -> bool:
	var t: float = float(p["tile"])
	var hw: float = float(p["hw"])
	var eps: float = 0.000001
	for cy in range(floori((y - h) / t), floori((y - eps) / t) + 1):
		for cx in range(floori((x - hw) / t), floori((x + hw - eps) / t) + 1):
			if tile(g, cx, cy) == "#":
				return true
	return false
