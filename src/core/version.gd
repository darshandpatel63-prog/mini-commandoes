extends Node
## Single source of version info (blueprint §Versioning). CI injects BUILD_NUMBER/GIT_SHA via
## tools/stamp_version.py, which rewrites data/build_info.json before export.

const GAME_VERSION := "0.0.3"
var build_number := 0
var git_sha := "dev"

func _ready() -> void:
	var f := FileAccess.open("res://data/build_info.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			build_number = int(d.get("build_number", 0))
			git_sha = str(d.get("git_sha", "dev"))

func display_string() -> String:
	var v := Engine.get_version_info()
	return "v%s (build %d, %s) Godot %s" % [GAME_VERSION, build_number, git_sha, v.get("string", "?")]
