extends CharacterBody3D

signal health_changed(current: int, max: int)
signal died

@export var move_speed: float = 14.0
@export var bounds: Vector3 = Vector3(14, 8, 0)  # half-extents around origin
@export var rifle_cooldown: float = 0.15
@export var rocket_cooldown: float = 0.9
@export var invuln_time: float = 0.8

var max_hits: int = 5
var hits_taken: int = 0

var _rifle_timer: float = 0.0
var _rocket_timer: float = 0.0
var _invuln_timer: float = 0.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var rifle_muzzle: Marker3D = $RifleMuzzle
@onready var rocket_muzzle: Marker3D = $RocketMuzzle

const RifleBulletScene := preload("res://scenes/rifle_bullet.tscn")
const RocketScene := preload("res://scenes/rocket.tscn")

func configure(cfg_max_hits: int) -> void:
	max_hits = cfg_max_hits
	hits_taken = 0
	emit_signal("health_changed", max_hits - hits_taken, max_hits)

func _ready() -> void:
	# Physics layers: player on layer 2, collides with enemy (3) and enemy projectile (5).
	collision_layer = 1 << 1
	collision_mask = (1 << 2) | (1 << 4)
	_apply_skin()

func _apply_skin() -> void:
	var skin_data: Dictionary = GameState.get_selected_skin_data()
	# Remove existing visual children of Mesh node.
	for child in mesh.get_children():
		child.queue_free()
	# Remove old engine trail if any.
	var old_trail := get_node_or_null("EngineTrail")
	if old_trail:
		old_trail.queue_free()
	# Load the selected ship model.
	var model_scene = load(skin_data["model"])
	if model_scene == null:
		return
	var s: float = skin_data["scale"]
	var instance: Node3D = model_scene.instantiate()
	instance.transform = Transform3D(
		Vector3(0, 0, s), Vector3(0, s, 0), Vector3(-s, 0, 0),
		Vector3.ZERO
	)
	# Apply original texture — keep ship detail clean.
	# Only add a subtle emission glow for differentiation.
	var tex = load(skin_data["texture"])
	if tex:
		var emission_col: Color = skin_data["emission_color"]
		var emission_str: float = skin_data["emission_energy"]
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.metallic = 0.4
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = emission_col
		mat.emission_energy_multiplier = emission_str
		_apply_material_recursive(instance, mat)
	mesh.add_child(instance)
	# Add engine trail with skin-specific color.
	_add_engine_trail(skin_data)

func _add_engine_trail(skin_data: Dictionary) -> void:
	var trail_color: Color = skin_data["trail_color"]
	# OmniLight3D as engine glow behind the ship.
	var glow := OmniLight3D.new()
	glow.name = "EngineTrail"
	glow.light_color = trail_color
	glow.light_energy = 1.5
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0, 1.5)
	add_child(glow)
	# GPUParticles3D for exhaust trail.
	var particles := GPUParticles3D.new()
	particles.name = "ExhaustParticles"
	particles.amount = 30
	particles.lifetime = 0.6
	particles.emitting = true
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, 1)
	pmat.spread = 15.0
	pmat.initial_velocity_min = 4.0
	pmat.initial_velocity_max = 8.0
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.15
	pmat.scale_max = 0.35
	pmat.color = trail_color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(trail_color.r, trail_color.g, trail_color.b, 1.0))
	color_ramp.set_color(1, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
	var tex_grad := GradientTexture1D.new()
	tex_grad.gradient = color_ramp
	pmat.color_ramp = tex_grad
	particles.process_material = pmat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.vertex_color_use_as_albedo = true
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = quad_mat
	particles.draw_pass_1 = quad
	particles.position = Vector3(0, 0, 1.3)
	add_child(particles)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _physics_process(delta: float) -> void:
	_rifle_timer = max(_rifle_timer - delta, 0.0)
	_rocket_timer = max(_rocket_timer - delta, 0.0)
	_invuln_timer = max(_invuln_timer - delta, 0.0)

	var input_vec := Vector3.ZERO
	if Input.is_action_pressed("move_right"): input_vec.x += 1.0
	if Input.is_action_pressed("move_left"): input_vec.x -= 1.0
	if Input.is_action_pressed("move_up"): input_vec.y += 1.0
	if Input.is_action_pressed("move_down"): input_vec.y -= 1.0
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	velocity = input_vec * move_speed
	move_and_slide()

	# Clamp inside bounds.
	global_position.x = clamp(global_position.x, -bounds.x, bounds.x)
	global_position.y = clamp(global_position.y, -bounds.y, bounds.y)
	global_position.z = 0.0

	# Slight tilt based on motion for feedback.
	var target_roll := -input_vec.x * 0.35
	var target_pitch := -input_vec.y * 0.25
	mesh.rotation.z = lerp(mesh.rotation.z, target_roll, 0.15)
	mesh.rotation.x = lerp(mesh.rotation.x, target_pitch, 0.15)

	# Blink while invulnerable.
	if _invuln_timer > 0.0:
		mesh.visible = int(_invuln_timer * 20.0) % 2 == 0
	else:
		mesh.visible = true

	if Input.is_action_pressed("shoot_rifle") and _rifle_timer <= 0.0:
		_fire_rifle()
		_rifle_timer = rifle_cooldown
	if Input.is_action_just_pressed("shoot_rocket") and _rocket_timer <= 0.0:
		_fire_rocket()
		_rocket_timer = rocket_cooldown

func _fire_rifle() -> void:
	var b := RifleBulletScene.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = rifle_muzzle.global_position
	b.direction = Vector3(0, 0, -1)

func _fire_rocket() -> void:
	var r := RocketScene.instantiate()
	get_tree().current_scene.add_child(r)
	r.global_position = rocket_muzzle.global_position
	r.direction = Vector3(0, 0, -1)

func take_hit() -> void:
	if _invuln_timer > 0.0:
		return
	hits_taken += 1
	_invuln_timer = invuln_time
	emit_signal("health_changed", max(max_hits - hits_taken, 0), max_hits)
	if hits_taken >= max_hits:
		emit_signal("died")
