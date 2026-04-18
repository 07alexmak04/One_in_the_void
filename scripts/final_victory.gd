extends Control

@onready var quit_button: Button = $CenterContainer/VBox/QuitButton

func _ready() -> void:
	quit_button.pressed.connect(_on_quit_pressed)

func _on_quit_pressed() -> void:
	GameState.reset_progression()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
