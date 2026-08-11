extends Node

# Tuân thủ DoD: Biến debug_mode để in log kiểm soát
@export var debug_mode: bool = true

enum GameState {
	MAIN_MENU,
	SHOP,
	BATTLE,
	REWARD,
	GAME_OVER
}

var current_state: GameState = GameState.MAIN_MENU

func _ready() -> void:
	if debug_mode:
		print("[GameManager] Initialized. Current State: ", GameState.keys()[current_state])

func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
		
	var old_state: GameState = current_state
	current_state = new_state
	
	if debug_mode:
		print("[GameManager] State transition: ", GameState.keys()[old_state], " -> ", GameState.keys()[new_state])
		
	# Báo hiệu cho các hệ thống khác (UI, Audio, Scene Transition)
	EventBus.game_state_changed.emit(new_state, old_state)
