extends Node

# Autoload: persists selected difficulty, progression, and ship skins between scenes.

enum Difficulty { BEGINNER, INTERMEDIATE, HARD }

var current_difficulty: int = Difficulty.BEGINNER

# Per-difficulty tuning.
const LEVEL_CONFIG := {
	Difficulty.BEGINNER: {
		"name": "Beginner",
		"max_hits": 5,
		"meteor_spawn_interval": 0.9,
		"meteor_speed": 12.0,
		# The original course is placed this far from the player's start (0,0).
		# Beginner: close enough to see on minimap immediately.
		"course_distance": 25.0,
		# The course itself: waypoints relative to course start, spaced apart.
		"course_points": [
			Vector2(0, 0), Vector2(8, 4), Vector2(18, -2), Vector2(28, 3),
		],
		"waypoint_radius": 3.0,
		"star_times": [30.0, 45.0, 60.0, 80.0],
	},
	Difficulty.INTERMEDIATE: {
		"name": "Intermediate",
		"max_hits": 3,
		"meteor_spawn_interval": 0.55,
		"meteor_speed": 16.0,
		# Further away — player needs to navigate to find it.
		"course_distance": 60.0,
		"course_points": [
			Vector2(0, 0), Vector2(10, -5), Vector2(22, 3), Vector2(35, -4),
			Vector2(48, 2),
		],
		"waypoint_radius": 2.8,
		"star_times": [50.0, 70.0, 95.0, 120.0],
	},
	Difficulty.HARD: {
		"name": "Hard",
		"max_hits": 1,
		"meteor_spawn_interval": 0.35,
		"meteor_speed": 22.0,
		# Very far — must search through the void.
		"course_distance": 120.0,
		"course_points": [
			Vector2(0, 0), Vector2(8, 6), Vector2(20, -5), Vector2(32, 4),
			Vector2(45, -3), Vector2(58, 5),
		],
		"waypoint_radius": 2.5,
		"star_times": [80.0, 110.0, 140.0, 180.0],
	},
}

# Last completed level result.
var last_time_used: float = 0.0
var last_stars: int = 0

func calculate_stars(difficulty: int, time_used: float) -> int:
	var thresholds: Array = LEVEL_CONFIG[difficulty]["star_times"]
	if time_used <= thresholds[0]:
		return 5
	elif time_used <= thresholds[1]:
		return 4
	elif time_used <= thresholds[2]:
		return 3
	elif time_used <= thresholds[3]:
		return 2
	else:
		return 1

# --- Ship skins ---
# Each skin: id, display name, model path, texture path, unlock condition.
const SHIP_SKINS := [
	{
		"id": "light_cruiser_01",
		"name": "Light Cruiser I",
		"description": "Standard issue vessel. Nothing fancy, but she flies.",
		"model": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Light cruiser_01.fbx",
		"texture": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Texture/T_Spase_blue.png",
		"unlock": "default",
		"emission_color": Color(0.15, 0.35, 0.8),
		"emission_energy": 0.3,
		"scale": 0.08,
		"trail_color": Color(0.4, 0.65, 1.0),
	},
	{
		"id": "destroyer_01",
		"name": "Destroyer I - Iron Fang",
		"description": "Heavier hull, meaner silhouette.\nAwarded for surviving Beginner.",
		"model": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Destroyer_01.fbx",
		"texture": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Texture/T_Spase_blue.png",
		"unlock": "beginner",
		"emission_color": Color(0.8, 0.2, 0.1),
		"emission_energy": 0.35,
		"scale": 0.1,
		"trail_color": Color(1.0, 0.35, 0.15),
	},
	{
		"id": "light_cruiser_03",
		"name": "Phantom III",
		"description": "Sleek interceptor frame with a different hull shape.\nEarned by clearing Intermediate.",
		"model": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Light cruiser_03.fbx",
		"texture": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Texture/T_Spase_64.png",
		"unlock": "intermediate",
		"emission_color": Color(0.1, 0.75, 0.35),
		"emission_energy": 0.35,
		"scale": 0.09,
		"trail_color": Color(0.2, 0.9, 0.4),
	},
	{
		"id": "destroyer_05",
		"name": "Void Breaker V",
		"description": "The flagship. Largest hull in the fleet.\nOnly pilots who conquered Hard earn this legend.",
		"model": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Destroyer_05.fbx",
		"texture": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Texture/T_Spase_64.png",
		"unlock": "hard",
		"emission_color": Color(0.85, 0.6, 0.1),
		"emission_energy": 0.4,
		"scale": 0.12,
		"trail_color": Color(1.0, 0.75, 0.2),
	},
]

var unlocked_skins: Array[String] = ["light_cruiser_01"]
var selected_skin: String = "light_cruiser_01"

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

# --- Skin helpers ---

func unlock_skin_for_level(difficulty: int) -> String:
	var unlock_key := ""
	match difficulty:
		Difficulty.BEGINNER: unlock_key = "beginner"
		Difficulty.INTERMEDIATE: unlock_key = "intermediate"
		Difficulty.HARD: unlock_key = "hard"
	var newly_unlocked := ""
	for skin in SHIP_SKINS:
		if skin["unlock"] == unlock_key and skin["id"] not in unlocked_skins:
			unlocked_skins.append(skin["id"])
			newly_unlocked = skin["name"]
	return newly_unlocked

func is_skin_unlocked(skin_id: String) -> bool:
	return skin_id in unlocked_skins

func get_skin_data(skin_id: String) -> Dictionary:
	for skin in SHIP_SKINS:
		if skin["id"] == skin_id:
			return skin
	return SHIP_SKINS[0]

func get_selected_skin_data() -> Dictionary:
	return get_skin_data(selected_skin)
