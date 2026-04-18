extends Control

@onready var ship_name_label: Label = $Content/InfoPanel/VBox/ShipNameLabel
@onready var ship_desc_label: Label = $Content/InfoPanel/VBox/DescLabel
@onready var unlock_label: Label = $Content/InfoPanel/VBox/UnlockLabel
@onready var select_button: Button = $Content/InfoPanel/VBox/SelectButton
@onready var back_button: Button = $BackButton
@onready var grid: GridContainer = $Content/ScrollContainer/Grid
@onready var preview_viewport: SubViewport = $Content/PreviewPanel/SubViewportContainer/SubViewport
@onready var preview_model_root: Node3D = $Content/PreviewPanel/SubViewportContainer/SubViewport/PreviewScene/ModelRoot

var current_skin_index: int = 0
var _preview_instance: Node3D = null
var _spin_time: float = 0.0

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	select_button.pressed.connect(_on_select)
	_build_grid()
	# Find the currently selected skin index.
	for i in GameState.SHIP_SKINS.size():
		if GameState.SHIP_SKINS[i]["id"] == GameState.selected_skin:
			current_skin_index = i
			break
	_show_skin(current_skin_index)

func _process(delta: float) -> void:
	_spin_time += delta
	if is_instance_valid(_preview_instance):
		_preview_instance.rotation.y = _spin_time * 0.8

func _build_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	for i in GameState.SHIP_SKINS.size():
		var skin: Dictionary = GameState.SHIP_SKINS[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 52)
		var unlocked := GameState.is_skin_unlocked(skin["id"])
		if unlocked:
			btn.text = skin["name"]
		else:
			btn.text = "??? LOCKED ???"
		btn.add_theme_font_size_override("font_size", 16)
		if skin["id"] == GameState.selected_skin:
			btn.text += "  [EQUIPPED]"
		var idx := i
		btn.pressed.connect(func(): _show_skin(idx))
		grid.add_child(btn)

func _show_skin(index: int) -> void:
	current_skin_index = index
	var skin: Dictionary = GameState.SHIP_SKINS[index]
	var unlocked := GameState.is_skin_unlocked(skin["id"])

	if unlocked:
		ship_name_label.text = skin["name"]
		ship_desc_label.text = skin["description"]
		unlock_label.text = ""
		if skin["id"] == GameState.selected_skin:
			select_button.text = "Equipped"
			select_button.disabled = true
		else:
			select_button.text = "Equip"
			select_button.disabled = false
		_load_preview(skin)
	else:
		ship_name_label.text = "??? LOCKED ???"
		var hint := ""
		match skin["unlock"]:
			"beginner": hint = "Clear Beginner to unlock"
			"intermediate": hint = "Clear Intermediate to unlock"
			"hard": hint = "Clear Hard to unlock"
		ship_desc_label.text = ""
		unlock_label.text = hint
		select_button.text = "Locked"
		select_button.disabled = true
		_clear_preview()

func _load_preview(skin: Dictionary) -> void:
	_clear_preview()
	var model_scene := load(skin["model"])
	if model_scene == null:
		return
	_preview_instance = model_scene.instantiate()
	var s: float = skin.get("scale", 0.1) * 1.5  # slightly bigger for preview
	_preview_instance.scale = Vector3(s, s, s)
	# Apply original texture with subtle emission accent.
	var tex := load(skin["texture"])
	if tex:
		var emission_col: Color = skin.get("emission_color", Color.BLACK)
		var emission_str: float = skin.get("emission_energy", 0.3)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.metallic = 0.4
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = emission_col
		mat.emission_energy_multiplier = emission_str
		_apply_material_recursive(_preview_instance, mat)
	preview_model_root.add_child(_preview_instance)
	_spin_time = 0.0

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _clear_preview() -> void:
	if is_instance_valid(_preview_instance):
		_preview_instance.queue_free()
		_preview_instance = null

func _on_select() -> void:
	var skin: Dictionary = GameState.SHIP_SKINS[current_skin_index]
	if GameState.is_skin_unlocked(skin["id"]):
		GameState.selected_skin = skin["id"]
		_build_grid()
		_show_skin(current_skin_index)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
