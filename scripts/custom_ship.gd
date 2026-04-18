extends Control

@onready var ship_name_label: Label = $InfoPanel/VBox/ShipNameLabel
@onready var ship_desc_label: Label = $InfoPanel/VBox/DescLabel
@onready var unlock_label: Label = $InfoPanel/VBox/UnlockLabel
@onready var select_button: Button = $InfoPanel/VBox/SelectButton
@onready var back_button: Button = $BackButton
@onready var grid: GridContainer = $SelectionPanel/ScrollContainer/Grid
@onready var preview_viewport: SubViewport = $SubViewport
@onready var preview_model_root: Node3D = $SubViewport/PreviewScene/ModelRoot
@onready var skill_title_label: Label = $InfoPanel/VBox/SkillTitle
@onready var skill_desc_label: Label = $InfoPanel/VBox/SkillDesc
@onready var skill_separator: Control = $InfoPanel/VBox/SkillSeparator
@onready var ship_showcase: TextureRect = $ShipShowcase

var current_skin_index: int = 0
var _preview_instance: Node3D = null
var _spin_time: float = 0.0

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	select_button.pressed.connect(_on_select)
	
	# Manually setup ViewportTexture for absolute reliability
	var tex = preview_viewport.get_texture()
	ship_showcase.texture = tex
	
	_build_grid()
	
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
		var skin = GameState.SHIP_SKINS[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 52)
		
		var unlocked = GameState.is_skin_unlocked(skin["id"])
		if unlocked:
			btn.text = skin["name"]
		else:
			btn.text = "??? LOCKED ???"
		
		btn.add_theme_font_size_override("font_size", 16)
		if skin["id"] == GameState.selected_skin:
			btn.text += " [EQUIPPED]"
			
		var idx = i
		btn.pressed.connect(func(): _show_skin(idx))
		grid.add_child(btn)

func _show_skin(index: int) -> void:
	current_skin_index = index
	var skin = GameState.SHIP_SKINS[index]
	var unlocked = GameState.is_skin_unlocked(skin["id"])
	
	if unlocked:
		ship_name_label.text = skin["name"]
		ship_desc_label.text = skin["description"]
		unlock_label.text = ""
		
		skill_separator.visible = true
		skill_title_label.visible = true
		skill_desc_label.visible = true
		
		var sk = skin["skill"]
		skill_title_label.text = "Ability: " + sk["name"]
		skill_desc_label.text = sk.get("skill_desc", "No description available.")
		
		if skin["id"] == GameState.selected_skin:
			select_button.text = "Equipped"
			select_button.disabled = true
		else:
			select_button.text = "Equip"
			select_button.disabled = false
		_load_preview(skin)
	else:
		ship_name_label.text = "??? LOCKED ???"
		skill_separator.visible = false
		skill_title_label.visible = false
		skill_desc_label.visible = false
		
		var hint = ""
		match skin["unlock"]:
			"beginner": hint = "SURVIVE BEGINNER DIFFICULTY"
			"intermediate": hint = "CLEAR INTERMEDIATE DIFFICULTY"
			"hard": hint = "CONQUER HARD DIFFICULTY"
		
		ship_desc_label.text = "DECRYPTING LOGS...\nREQUIRED: " + hint
		unlock_label.text = "LOCKED"
		select_button.text = "Locked"
		select_button.disabled = true
		_clear_preview()

func _load_preview(skin: Dictionary) -> void:
	_clear_preview()
	var model_scene = load(skin["model"])
	if model_scene:
		_preview_instance = model_scene.instantiate()
		var s: float = skin.get("scale", 0.1) * 0.8
		_preview_instance.scale = Vector3(s, s, s)
		
		var tex = load(skin["texture"])
		if tex:
			var mat = StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.metallic = 0.5
			mat.roughness = 0.3
			mat.emission_enabled = true
			mat.emission = skin.get("emission_color", Color.BLACK)
			mat.emission_energy_multiplier = skin.get("emission_energy", 0.5)
			_apply_mat(_preview_instance, mat)
		
		preview_model_root.add_child(_preview_instance)

func _clear_preview() -> void:
	for child in preview_model_root.get_children():
		child.queue_free()
	_preview_instance = null

func _apply_mat(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_mat(child, mat)

func _on_select() -> void:
	var skin_id = GameState.SHIP_SKINS[current_skin_index]["id"]
	GameState.selected_skin = skin_id
	GameState.save_prefs()
	_build_grid()
	_show_skin(current_skin_index)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
