extends Node
## Switches input interpretation between menu and gameplay (virtual controls arrive in Phase 2).

enum Mode { MENU, GAMEPLAY }
signal mode_changed(mode: int)

var mode: int = Mode.MENU

func set_mode(m: int) -> void:
	if m == mode:
		return
	mode = m
	mode_changed.emit(m)
