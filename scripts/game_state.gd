extends Node

# Global state for the whole game.
# Handles ship unlocks, selected skin, difficulty, etc.

enum Difficulty { BEGINNER, INTERMEDIATE, HARD }

var current_difficulty: Difficulty = Difficulty.BEGINNER
var selected_skin: String = "light_cruiser_01"

# Persisted unlocks
var unlocked_skins: Array = ["light_cruiser_01"]

# Post-game results from latest session
var last_time_used: float = 0.0
var last_stars: int = 0


# --- Ship skins ---
# Each skin: id, display name, model path, texture path, unlock condition.
const SHIP_SKINS := [
	{
		"id": "light_cruiser_01",
		"name": "Light Cruiser I",
		"description": "Standard issue vessel.\nNothing fancy, but she flies.",
		"model": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Light cruiser_01.fbx",
		"texture": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Texture/T_Spase_blue.png",
		"unlock": "default",
		"emission_color": Color(0.15, 0.35, 0.8),
		"emission_energy": 0.3,
		"scale": 0.08,
		"trail_color": Color(0.4, 0.65, 1.0),
		"skill": {
			"type": "slow",
			"name": "Stasis Burst",
			"cooldown": 15.0,
			"duration": 3.0,
			"skill_desc": "Twists space-time to slow all meteorites to 30% speed for 3 seconds."
		}
	},
	{
		"id": "destroyer_01",
		"name": "Iron Fang",
		"description": "Heavier hull, meaner silhouette.\nUnlocked by surviving Beginner.",
		"model": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Destroyer_01.fbx",
		"texture": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Texture/T_Spase_blue.png",
		"unlock": "beginner",
		"emission_color": Color(0.8, 0.2, 0.1),
		"emission_energy": 0.35,
		"scale": 0.1,
		"trail_color": Color(1.0, 0.35, 0.15),
		"skill": {
			"type": "tracking",
			"name": "Seeker Protocol",
			"cooldown": 12.0,
			"count": 3,
			"skill_desc": "Calibrates advanced AI. The next 3 shots will curve towards the nearest target."
		}
	},
	{
		"id": "light_cruiser_03",
		"name": "Phantom III",
		"description": "Sleek interceptor frame.\nUnlocked by clearing Intermediate.",
		"model": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Light cruiser_03.fbx",
		"texture": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Texture/T_Spase_64.png",
		"unlock": "intermediate",
		"emission_color": Color(0.1, 0.75, 0.35),
		"emission_energy": 0.35,
		"scale": 0.09,
		"trail_color": Color(0.2, 0.9, 0.4),
		"skill": {
			"type": "blink",
			"name": "Quantum Blink",
			"cooldown": 8.0,
			"distance": 18.0,
			"skill_desc": "A short-range hyper-space jump in your current direction. Grants brief invincibility."
		}
	},
	{
		"id": "destroyer_05",
		"name": "Void Breaker V",
		"description": "The flagship. Largest hull in the fleet.\nOnly Hard conquerors fly this.",
		"model": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Destroyer_05.fbx",
		"texture": "res://reference/Battle-SpaceShip-Free-3D-Low-Poly-Models/Texture/T_Spase_64.png",
		"unlock": "hard",
		"emission_color": Color(0.85, 0.6, 0.1),
		"emission_energy": 0.4,
		"scale": 0.12,
		"trail_color": Color(1.0, 0.75, 0.2),
		"skill": {
			"type": "nova",
			"name": "Void Pulse",
			"cooldown": 20.0,
			"radius": 15.0,
			"skill_desc": "Releases a devastating shockwave that vaporizes all meteorites in a 15m radius."
		}
	},
]

const DIFFICULTY_CONFIGS := {
	Difficulty.BEGINNER: {
		"name": "Beginner",
		"meteor_count": 15,
		"meteor_spawn_interval": 1.1,
		"max_hits": 5,
		"meteor_speed": 11.0,
		"waypoint_radius": 3.5,
		"course_distance": 50.0,
		"course_points": [
			Vector2(0, 0), Vector2(10, 20), Vector2(-10, 40), Vector2(10, 60), Vector2(0, 80)
		]
	},
	Difficulty.INTERMEDIATE: {
		"name": "Intermediate",
		"meteor_count": 35,
		"meteor_spawn_interval": 0.65,
		"max_hits": 3,
		"meteor_speed": 17.0,
		"waypoint_radius": 3.0,
		"course_distance": 80.0,
		"course_points": [
			Vector2(0, 0), Vector2(20, 30), Vector2(-20, 60), Vector2(20, 90), 
			Vector2(-20, 120), Vector2(20, 150), Vector2(0, 180)
		]
	},
	Difficulty.HARD: {
		"name": "Hard",
		"meteor_count": 90,
		"meteor_spawn_interval": 0.4,
		"max_hits": 1,
		"meteor_speed": 24.0,
		"waypoint_radius": 2.5,
		"course_distance": 120.0,
		"course_points": [
			Vector2(0, 0), Vector2(30, 40), Vector2(-30, 80), Vector2(30, 120),
			Vector2(-30, 160), Vector2(30, 200), Vector2(-30, 240), Vector2(30, 280), Vector2(0, 320)
		]
	},
}

func _ready() -> void:
	load_prefs()

func get_config() -> Dictionary:
	return DIFFICULTY_CONFIGS[current_difficulty]

func set_difficulty(diff: Difficulty) -> void:
	current_difficulty = diff

func get_selected_skin_data() -> Dictionary:
	for skin in SHIP_SKINS:
		if skin["id"] == selected_skin:
			return skin
	return SHIP_SKINS[0]

func is_skin_unlocked(skin_id: String) -> bool:
	return skin_id in unlocked_skins

func unlock_skin_for_difficulty(diff: Difficulty) -> String:
	var unlock_key := ""
	match diff:
		Difficulty.BEGINNER:	unlock_key = "beginner"
		Difficulty.INTERMEDIATE: unlock_key = "intermediate"
		Difficulty.HARD:		unlock_key = "hard"
	
	if unlock_key == "": return ""
	
	var newly_unlocked := ""
	for skin in SHIP_SKINS:
		if skin["unlock"] == unlock_key:
			if not is_skin_unlocked(skin["id"]):
				unlocked_skins.append(skin["id"])
				newly_unlocked = skin["name"]
	save_prefs()
	return newly_unlocked

func has_next_level() -> bool:
	return current_difficulty < Difficulty.HARD

func advance_level() -> void:
	if has_next_level():
		current_difficulty = (current_difficulty + 1) as Difficulty

func reset_progression() -> void:
	current_difficulty = Difficulty.BEGINNER

func save_prefs() -> void:
	var f = FileAccess.open("user://prefs.save", FileAccess.WRITE)
	var data = {
		"unlocked_skins": unlocked_skins,
		"selected_skin": selected_skin
	}
	f.store_var(data)

func load_prefs() -> void:
	if not FileAccess.file_exists("user://prefs.save"):
		return
	var f = FileAccess.open("user://prefs.save", FileAccess.READ)
	var data = f.get_var()
	if data.has("unlocked_skins"):
		unlocked_skins = data["unlocked_skins"]
	if data.has("selected_skin"):
		selected_skin = data["selected_skin"]
