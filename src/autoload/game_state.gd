extends Node
## Coarse app state + current selections. Match state itself arrives with the sim (Phase 2+).

enum AppState { BOOT, MENU, LOBBY, MATCH, RESULTS }
signal state_changed(state: int)

var state: int = AppState.BOOT
var selected_map: String = "verdant_outpost"
var selected_mode: String = "training"

func set_state(s: int) -> void:
	if s == state:
		return
	state = s
	state_changed.emit(s)
