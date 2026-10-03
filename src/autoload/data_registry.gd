extends Node
## Loads every data/*.json once. All content and balance numbers are looked up here by id.
## bundle() returns the pure-logic view (rules, tables) consumed by src/core and src/combat modules.

const FILES := ["characters", "skills", "pets", "weapons", "throwables", "melee", "presets", "loot", "modes", "maps",
	"balance", "armor", "hud_default"]
const LIST_KEYS := {"characters": "characters", "skills": "skills", "pets": "pets", "weapons": "weapons",
	"throwables": "throwables", "melee": "melee", "presets": "presets", "modes": "modes", "maps": "maps"}

var tables: Dictionary = {}   # name -> {id -> entry}
var raw: Dictionary = {}      # name -> parsed JSON
var load_errors: PackedStringArray = []
var _bundle: Dictionary = {}

func _ready() -> void:
	reload_all()

func reload_all() -> void:
	tables.clear()
	raw.clear()
	load_errors.clear()
	_bundle = {}
	for file_name in FILES:
		var path := "res://data/%s.json" % file_name
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			load_errors.append("cannot open " + path)
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if not (parsed is Dictionary):
			load_errors.append("invalid JSON in " + path)
			continue
		raw[file_name] = parsed
		if LIST_KEYS.has(file_name):
			var by_id := {}
			for e in parsed.get(LIST_KEYS[file_name], []):
				by_id[e.get("id", "")] = e
			tables[file_name] = by_id

func get_entry(table: String, id: String) -> Dictionary:
	return tables.get(table, {}).get(id, {})

func count(table: String) -> int:
	return tables.get(table, {}).size()

func bundle() -> Dictionary:
	if _bundle.is_empty() and load_errors.is_empty():
		_bundle = {
			"rules": raw["balance"], "armor": raw["armor"],
			"skills": tables["skills"], "pets": tables["pets"], "characters": tables["characters"],
			"weapons": tables["weapons"], "melee": tables["melee"], "throwables": tables["throwables"],
			"presets": raw["presets"]["presets"], "hud": raw["hud_default"]["controls"],
		}
	return _bundle
