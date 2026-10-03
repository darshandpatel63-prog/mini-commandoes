extends RefCounted
## Atomic, integrity-checked JSON saves with .bak recovery. Pure logic, unit-testable headless.
## File format: {"v": schema, "body": "<json string of data>", "sig": sha256(body)}.
## NOTE: JSON parsing turns ints into floats; callers must int() numeric fields.

static func write(path: String, data: Dictionary, schema: int) -> bool:
	var body: String = JSON.stringify(data, "", true)
	var payload := {"v": schema, "body": body, "sig": body.sha256_text()}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "", true))
	f.close()
	var abs_main := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(abs_main, ProjectSettings.globalize_path(path + ".bak"))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_main) == OK

static func _try_read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false}
	var txt: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return {"ok": false}
	var body: Variant = parsed.get("body", null)
	var sig: Variant = parsed.get("sig", null)
	if not (body is String) or not (sig is String):
		return {"ok": false}
	if (body as String).sha256_text() != (sig as String):
		return {"ok": false}
	var data: Variant = JSON.parse_string(body)
	if not (data is Dictionary):
		return {"ok": false}
	return {"ok": true, "version": int(parsed.get("v", 0)), "data": data}

## Returns {"source": "main"|"backup"|"none", "version": int, "data": Dictionary}
static func read(path: String) -> Dictionary:
	var r: Dictionary = _try_read(path)
	if r.get("ok", false):
		return {"source": "main", "version": r["version"], "data": r["data"]}
	r = _try_read(path + ".bak")
	if r.get("ok", false):
		return {"source": "backup", "version": r["version"], "data": r["data"]}
	return {"source": "none", "version": 0, "data": {}}

static func remove_all(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var p: String = path + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
