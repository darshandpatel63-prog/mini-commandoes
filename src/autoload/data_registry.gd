extends Node
## Loads every data/*.json once. All content (characters, weapons, ...) is looked up here by id.
## Adding content = editing JSON, not code (blueprint §Content structure).

const FILES := ["characters", "skills", "pets", "weapons", "throwables", "loot", "modes", "maps"]
const LIST_KEYS := {"characters": "characters", "skills": "skills", "pets": "pets",
	"weapons": "weapons", "throwables": "throwables", "modes": "modes", "maps": "maps"}

var tables: Dictionary = {}   # name -> {id -> entry}
var raw: Dictionary = {}      # name -> parsed JSON
var load_errors: PackedStringArray = []

func _ready() -> void:
	reload_all()

func reload_all() -> void:
	tables.clear(); raw.clear(); load_errors.clear()
	for name in FILES:
		var path := "res://data/%s.json" % name
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			load_errors.append("cannot open " + path); continue
		var parsed = JSON.parse_string(f.get_as_text())
		if not (parsed is Dictionary):
			load_errors.append("invalid JSON in " + path); continue
		raw[name] = parsed
		if LIST_KEYS.has(name):
			var by_id := {}
			for e in parsed.get(LIST_KEYS[name], []):
				by_id[e.get("id", "")] = e
			tables[name] = by_id

func get_entry(table: String, id: String) -> Dictionary:
	return tables.get(table, {}).get(id, {})

func count(table: String) -> int:
	return tables.get(table, {}).size()
