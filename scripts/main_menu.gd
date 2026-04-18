extends Node3D

@onready var start_button: Button = $CanvasLayer/UI/MenuContainer/StartButton
@onready var custom_ship_button: Button = $CanvasLayer/UI/MenuContainer/CustomShipButton
@onready var quit_button: Button = $CanvasLayer/UI/MenuContainer/QuitButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var viewport: SubViewport = $SubViewport
@onready var viewport_texture_rect: TextureRect = $CanvasLayer/UI/MainViewportTexture
@onready var ship_placeholder: Node3D = $SubViewport/PreviewScene/ShipPreviewPivot/ShipPlaceholder
@onready var ship_pivot: Node3D = $SubViewport/PreviewScene/ShipPreviewPivot
@onready var planet_pivot: Node3D = $SubViewport/PreviewScene/PlanetPivot
@onready var planet_placeholder: Node3D = $SubViewport/PreviewScene/PlanetPivot/PlanetPlaceholder

var _time: float = 0.0

func _ready() -> void:
	# Link the viewport to the texture rect
	viewport_texture_rect.texture = viewport.get_texture()
	
	start_button.pressed.connect(_on_start_pressed)
	custom_ship_button.pressed.connect(_on_custom_ship_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	music_player.finished.connect(music_player.play)
	
	# Connect hover animations for all buttons in the container
	for btn in $CanvasLayer/UI/MenuContainer.get_children():
		if btn is Button:
			btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
			btn.mouse_exited.connect(_on_button_hover.bind(btn, false))
			btn.pivot_offset = btn.size / 2.0 # Ensure scale happens from center
	
	_load_ship_preview()
	_create_menu_starfield()
	_load_planet_background()

func _on_button_hover(btn: Button, hovered: bool) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_scale := Vector2(1.05, 1.05) if hovered else Vector2(1.0, 1.0)
	tw.tween_property(btn, "scale", target_scale, 0.2)

func _process(delta: float) -> void:
	_time += delta
	# Subtle drifting rotation for the ship
	ship_pivot.rotation.y += delta * 0.4
	ship_pivot.rotation.x = sin(_time * 0.5) * 0.1
	ship_pivot.position.y = sin(_time * 0.8) * 0.15
	
	# Rotate the entire planet system slowly
	if planet_pivot:
		planet_pivot.rotation.y += delta * 0.015
		planet_pivot.rotation.z = sin(_time * 0.2) * 0.03

func _load_ship_preview() -> void:
	var skin_data: Dictionary = GameState.get_selected_skin_data()
	var model_scene = load(skin_data["model"])
	if model_scene:
		var instance: Node3D = model_scene.instantiate()
		var s: float = skin_data["scale"] * 1.3
		instance.transform = Transform3D(
			Vector3(0, 0, s), Vector3(0, s, 0), Vector3(-s, 0, 0),
			Vector3.ZERO
		)
		
		var tex = load(skin_data["texture"])
		if tex:
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.metallic = 0.5
			mat.roughness = 0.2
			mat.emission_enabled = true
			mat.emission = skin_data["emission_color"]
			mat.emission_energy_multiplier = skin_data["emission_energy"] * 2.0
			_apply_material_recursive(instance, mat)
			
		ship_placeholder.add_child(instance)

func _load_planet_background() -> void:
	# Define a small "Solar System" for the menu
	var planets := [
		{
			"scene": "res://addons/naejimer_3d_planet_generator/scenes/planet_terrestrial.tscn",
			"pos": Vector3(-8, 2, -15),
			"scale": 5.5
		},
		{
			"scene": "res://addons/naejimer_3d_planet_generator/scenes/planet_gaseous.tscn",
			"pos": Vector3(12, -5, -35),
			"scale": 12.0
		},
		{
			"scene": "res://addons/naejimer_3d_planet_generator/scenes/planet_ice.tscn",
			"pos": Vector3(4, 8, -25),
			"scale": 3.0
		},
		{
			"scene": "res://addons/naejimer_3d_planet_generator/scenes/planet_lava.tscn",
			"pos": Vector3(-15, -6, -20),
			"scale": 2.5
		}
	]
	
	for p_info in planets:
		var planet_scene = load(p_info["scene"])
		if planet_scene:
			var instance: Node3D = planet_scene.instantiate()
			instance.position = p_info["pos"]
			var s: float = p_info["scale"]
			instance.scale = Vector3(s, s, s)
			# Add a random initial rotation for variety
			instance.rotation = Vector3(randf(), randf(), randf())
			planet_placeholder.add_child(instance)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _create_menu_starfield() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 200
	particles.lifetime = 4.0
	particles.preprocess = 4.0
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(20, 20, 20)
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 10.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.1
	mat.scale_max = 0.4
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad_mat.albedo_color = Color(1, 1, 1, 0.8)
	quad.material = quad_mat
	
	particles.process_material = mat
	particles.draw_pass_1 = quad
	add_child(particles)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_custom_ship_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/custom_ship.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
