extends Control

@onready var beginner_button: Button = $CenterContainer/VBoxContainer/BeginnerButton
@onready var intermediate_button: Button = $CenterContainer/VBoxContainer/IntermediateButton
@onready var hard_button: Button = $CenterContainer/VBoxContainer/HardButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	beginner_button.pressed.connect(func(): _start(GameState.Difficulty.BEGINNER))
	intermediate_button.pressed.connect(func(): _start(GameState.Difficulty.INTERMEDIATE))
	hard_button.pressed.connect(func(): _start(GameState.Difficulty.HARD))
	back_button.pressed.connect(_on_back_pressed)

func _start(diff: int) -> void:
	GameState.set_difficulty(diff)
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
