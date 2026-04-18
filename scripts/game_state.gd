extends Node

enum Difficulty { BEGINNER, INTERMEDIATE, HARD }

var current_difficulty: int = Difficulty.BEGINNER

const LEVEL_CONFIG := {
	Difficulty.BEGINNER: {
		"name": "Beginner",
		"max_hits": 5,
		"hit_damage": 1,
		"meteor_count": 15,
		"meteor_spawn_interval": 0.9,
		"meteor_speed": 12.0,
	},
	Difficulty.INTERMEDIATE: {
		"name": "Intermediate",
		"max_hits": 5,
		"hit_damage": 2,
		"meteor_count": 35,
		"meteor_spawn_interval": 0.55,
		"meteor_speed": 16.0,
	},
	Difficulty.HARD: {
		"name": "Hard",
		"max_hits": 5,
		"hit_damage": 4,
		"meteor_count": 60,
		"meteor_spawn_interval": 0.35,
		"meteor_speed": 22.0,
	},
}

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
	},
]

var unlocked_skins: Array[String] = ["light_cruiser_01"]
var selected_skin: String = "light_cruiser_01"

func _ready() -> void:
	load_prefs()

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

func get_skin_data(skin_id: String) -> Dictionary:
	for skin in SHIP_SKINS:
		if skin["id"] == skin_id:
			return skin
	return SHIP_SKINS[0]

func get_selected_skin_data() -> Dictionary:
	return get_skin_data(selected_skin)

func is_skin_unlocked(skin_id: String) -> bool:
	return skin_id in unlocked_skins

func unlock_skin_for_difficulty(difficulty: int) -> String:
	var unlock_key := ""
	match difficulty:
		Difficulty.BEGINNER:    unlock_key = "beginner"
		Difficulty.INTERMEDIATE: unlock_key = "intermediate"
		Difficulty.HARD:        unlock_key = "hard"
	var newly_unlocked := ""
	for skin in SHIP_SKINS:
		if skin["unlock"] == unlock_key and skin["id"] not in unlocked_skins:
			unlocked_skins.append(skin["id"])
			newly_unlocked = skin["name"]
	return newly_unlocked

func save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ship", "selected", selected_skin)
	cfg.set_value("ship", "unlocked", unlocked_skins)
	cfg.save("user://prefs.cfg")

func load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://prefs.cfg") != OK:
		return
	selected_skin = cfg.get_value("ship", "selected", "light_cruiser_01")
	var loaded: Array = cfg.get_value("ship", "unlocked", ["light_cruiser_01"])
	unlocked_skins.clear()
	for s in loaded:
		unlocked_skins.append(str(s))
