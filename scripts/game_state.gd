extends Node

# Autoload: persists selected difficulty and progression between scenes.

enum Difficulty { BEGINNER, INTERMEDIATE, HARD }

var current_difficulty: int = Difficulty.BEGINNER

# Per-difficulty tuning.
# max_hits: how many meteorite hits the ship can take before dying (life bar at 100%).
# survival_time: seconds the player must survive to clear the level.
# meteor_spawn_interval: seconds between meteorite spawns.
# meteor_speed: base meteorite speed.
const LEVEL_CONFIG := {
	Difficulty.BEGINNER: {
		"name": "Beginner",
		"max_hits": 5,
		"survival_time": 15.0,
		"meteor_spawn_interval": 0.9,
		"meteor_speed": 12.0,
	},
	Difficulty.INTERMEDIATE: {
		"name": "Intermediate",
		"max_hits": 3,
		"survival_time": 30.0,
		"meteor_spawn_interval": 0.55,
		"meteor_speed": 16.0,
	},
	Difficulty.HARD: {
		"name": "Hard",
		"max_hits": 1,
		"survival_time": 60.0,
		"meteor_spawn_interval": 0.35,
		"meteor_speed": 22.0,
	},
}

func get_config() -> Dictionary:
	return LEVEL_CONFIG[current_difficulty]

func set_difficulty(d: int) -> void:
	current_difficulty = d

func has_next_level() -> bool:
	return current_difficulty < Difficulty.HARD

func advance_level() -> void:
	if has_next_level():
		current_difficulty += 1

func reset_progression() -> void:
	current_difficulty = Difficulty.BEGINNER
