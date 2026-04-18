extends Control

@onready var message_label: Label = $CenterContainer/VBox/MessageLabel
@onready var time_label: Label = $CenterContainer/VBox/TimeLabel
@onready var stars_label: Label = $CenterContainer/VBox/StarsLabel
@onready var unlock_label: Label = $CenterContainer/VBox/UnlockLabel
@onready var unlock_preview: SubViewportContainer = $CenterContainer/VBox/UnlockPreview
@onready var preview_root: Node3D = $CenterContainer/VBox/UnlockPreview/SubViewport/PreviewScene/ModelRoot
@onready var next_button: Button = $CenterContainer/VBox/HBox/NextButton
@onready var quit_button: Button = $CenterContainer/VBox/HBox/QuitButton

var _preview_instance: Node3D = null
var _spin_time: float = 0.0

func _ready() -> void:
	var cleared_name: String = GameState.get_config()["name"]
	message_label.text = "Congratulations!\nYou cleared %s." % cleared_name

	# Show time and stars.
	var t := GameState.last_time_used
	var mins := int(t) / 60
	var secs := int(t) % 60
	time_label.text = "Time: %d:%02d" % [mins, secs]
	var star_count := GameState.last_stars
	stars_label.text = _star_string(star_count)

	# Unlock skin reward.
	var new_skin_name: String = GameState.unlock_skin_for_difficulty(GameState.current_difficulty)
	if new_skin_name != "":
		unlock_label.text = "NEW SHIP UNLOCKED: %s" % new_skin_name
		unlock_label.visible = true
		unlock_preview.visible = true
		_show_unlocked_ship(new_skin_name)
	else:
		unlock_label.visible = false
		unlock_preview.visible = false

	next_button.pressed.connect(_on_next_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	if not GameState.has_next_level():
		next_button.disabled = true

func _process(delta: float) -> void:
	_spin_time += delta
	if is_instance_valid(_preview_instance):
		_preview_instance.rotation.y = _spin_time * 1.2

func _star_string(count: int) -> String:
	var filled := ""
	for i in 5:
		if i < count:
			filled += "★"
		else:
			filled += "☆"
	return filled

func _show_unlocked_ship(skin_name: String) -> void:
	var skin: Dictionary = {}
	for s in GameState.SHIP_SKINS:
		if s["name"] == skin_name:
			skin = s
			break
	if skin.is_empty():
		return
	var model_scene = load(skin["model"])
	if model_scene == null:
		return
	_preview_instance = model_scene.instantiate()
	var s: float = skin.get("scale", 0.1) * 1.5
	_preview_instance.scale = Vector3(s, s, s)
	var tex = load(skin["texture"])
	if tex:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.metallic = 0.4
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = skin.get("emission_color", Color.BLACK)
		mat.emission_energy_multiplier = skin.get("emission_energy", 0.3)
		_apply_mat(_preview_instance, mat)
	preview_root.add_child(_preview_instance)

func _apply_mat(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_mat(child, mat)

func _on_next_pressed() -> void:
	GameState.advance_level()
	get_tree().change_scene_to_file("res://scenes/intro_dialogue.tscn")

func _on_quit_pressed() -> void:
	GameState.reset_progression()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
