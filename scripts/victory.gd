extends Control

@onready var message_label: Label = $CenterContainer/VBox/MessageLabel
@onready var next_button: Button = $CenterContainer/VBox/HBox/NextButton
@onready var quit_button: Button = $CenterContainer/VBox/HBox/QuitButton

func _ready() -> void:
	var cleared_name: String = GameState.get_config()["name"]
	message_label.text = "Congratulations!\nYou cleared %s." % cleared_name
	next_button.pressed.connect(_on_next_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	if not GameState.has_next_level():
		next_button.disabled = true

func _on_next_pressed() -> void:
	GameState.advance_level()
	get_tree().change_scene_to_file("res://scenes/intro_dialogue.tscn")

func _on_quit_pressed() -> void:
	GameState.reset_progression()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
