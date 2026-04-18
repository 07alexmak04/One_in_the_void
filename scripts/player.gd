extends CharacterBody3D

signal health_changed(current: int, max: int)
signal died
signal got_hit

@export var move_speed: float = 14.0
@export var bounds: Vector3 = Vector3(11, 6, 0)
@export var rifle_cooldown: float = 0.15
@export var rocket_cooldown: float = 0.9
@export var invuln_time: float = 0.8

var max_hits: int = 5
var hit_damage: int = 1
var hits_taken: int = 0

var _rifle_timer: float = 0.0
var _rocket_timer: float = 0.0
var _invuln_timer: float = 0.0

# Ability state
var skill_info: Dictionary = {}
var skill_cooldown_timer: float = 0.0
var active_skill_duration_timer: float = 0.0
var remaining_tracking_shots: int = 0
var is_invincible: bool = false # Used for Blink dash

signal skill_activated(skill_type: String, cooldown: float)
signal skill_ready

var _has_drift: bool = false
var _has_jitter: bool = false
var _has_stutter: bool = false
var _has_critical: bool = false

var _drift_dir: Vector2 = Vector2.ZERO
var _drift_change_timer: float = 0.0

var _stutter_cycle: float = 0.0
var _stutter_blocking: bool = false

var _critical_invert_x: bool = false
var _critical_invert_y: bool = false

@onready var mesh: MeshInstance3D = $Mesh
@onready var rifle_muzzle: Marker3D = $RifleMuzzle
@onready var rocket_muzzle: Marker3D = $RocketMuzzle

const RifleBulletScene := preload("res://scenes/rifle_bullet.tscn")
const TrackingBulletScene := preload("res://scenes/tracking_bullet.tscn")
const RocketScene := preload("res://scenes/rocket.tscn")

func configure(cfg_max_hits: int, cfg_hit_damage: int) -> void:
	max_hits = cfg_max_hits
	hit_damage = cfg_hit_damage
	hits_taken = 0
	emit_signal("health_changed", max_hits, max_hits)

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1 << 1
	collision_mask = (1 << 2) | (1 << 4)
	
	var skin_data := GameState.get_selected_skin_data()
	if skin_data.has("skill"):
		skill_info = skin_data["skill"]
	
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
	skill_cooldown_timer = max(skill_cooldown_timer - delta, 0.0)
	active_skill_duration_timer = max(active_skill_duration_timer - delta, 0.0)
	
	_update_drift_timer(delta)
	_update_stutter_timer(delta)

	var input_vec := Vector3.ZERO

	if not _stutter_blocking:
		if Input.is_action_pressed("move_right"): input_vec.x += 1.0
		if Input.is_action_pressed("move_left"):  input_vec.x -= 1.0
		if Input.is_action_pressed("move_up"):	input_vec.y += 1.0
		if Input.is_action_pressed("move_down"):  input_vec.y -= 1.0

	if _has_critical:
		if _critical_invert_x: input_vec.x = -input_vec.x
		if _critical_invert_y: input_vec.y = -input_vec.y

	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	if _has_drift:
		input_vec.x += _drift_dir.x * 0.45
		input_vec.y += _drift_dir.y * 0.45

	var effective_speed := move_speed * (0.5 if _has_critical else 1.0)
	velocity = input_vec * effective_speed
	move_and_slide()

	# No bounds — open world, camera follows.
	global_position.z = 0.0

	var target_roll := -input_vec.x * 0.35
	var target_pitch := -input_vec.y * 0.25
	mesh.rotation.z = lerp(mesh.rotation.z, target_roll, 0.15)
	mesh.rotation.x = lerp(mesh.rotation.x, target_pitch, 0.15)

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
	if Input.is_action_just_pressed("skill") and skill_cooldown_timer <= 0.0:
		_use_skill()

func _update_drift_timer(delta: float) -> void:
	if not _has_drift:
		return
	_drift_change_timer -= delta
	if _drift_change_timer <= 0.0:
		_drift_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		_drift_change_timer = randf_range(1.5, 3.5)

func _update_stutter_timer(delta: float) -> void:
	if not _has_stutter:
		_stutter_blocking = false
		return
	_stutter_cycle += delta
	# Every 1.5s: block input for 0.3s
	if _stutter_cycle >= 1.5:
		_stutter_blocking = true
	if _stutter_cycle >= 1.8:
		_stutter_blocking = false
		_stutter_cycle = 0.0

func _fire_rifle() -> void:
	var b: Area3D
	if remaining_tracking_shots > 0:
		b = TrackingBulletScene.instantiate()
		remaining_tracking_shots -= 1
	else:
		b = RifleBulletScene.instantiate()
		
	get_tree().current_scene.add_child(b)
	b.global_position = rifle_muzzle.global_position
	var dir := Vector3(0, 0, -1)
	if _has_jitter:
		var jitter := deg_to_rad(randf_range(-20.0, 20.0))
		dir = Vector3(sin(jitter), sin(jitter * 0.5), -cos(jitter)).normalized()
	b.direction = dir

func _fire_rocket() -> void:
	var r := RocketScene.instantiate()
	get_tree().current_scene.add_child(r)
	r.global_position = rocket_muzzle.global_position
	r.direction = Vector3(0, 0, -1)

func _use_skill() -> void:
	if skill_info.is_empty():
		return
		
	var type: String = skill_info["type"]
	skill_cooldown_timer = skill_info["cooldown"]
	emit_signal("skill_activated", type, skill_cooldown_timer)
	
	match type:
		"slow":
			var duration: float = skill_info.get("duration", 4.0)
			# Find Gameplay node to trigger slow
			var gp = get_tree().current_scene
			if gp.has_method("trigger_slow_motion"):
				gp.trigger_slow_motion(0.3, duration)
				
		"tracking":
			remaining_tracking_shots = skill_info.get("count", 3)
			
		"blink":
			var dist: float = skill_info.get("distance", 15.0)
			# Find current movement direction for dash
			var dash_dir := velocity.normalized()
			if dash_dir.length() < 0.1: # Default forward if not moving
				dash_dir = Vector3(0, 1, 0)
				
			var target_pos = global_position + (dash_dir * dist)
			# Clamp to bounds
			target_pos.x = clamp(target_pos.x, -bounds.x, bounds.x)
			target_pos.y = clamp(target_pos.y, -bounds.y, bounds.y)
			
			var tw := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			is_invincible = true
			_invuln_timer = 0.6
			
			# Visual flash effect
			var flash_col = skill_info.get("color", Color(0.1, 1.0, 0.4))
			_spawn_blink_visual(flash_col)
			
			tw.tween_property(self, "global_position", target_pos, 0.15)
			tw.chain().tween_callback(func(): is_invincible = false)
			
		"nova":
			var radius: float = skill_info.get("radius", 15.0)
			# Spawn a visual shockwave
			_spawn_nova_visual(radius)
			# Damage all meteorites in range
			for m in get_tree().get_nodes_in_group("meteorite"):
				if is_instance_valid(m) and global_position.distance_to(m.global_position) <= radius:
					m.take_damage(10) # Heavy damage

func _spawn_nova_visual(radius: float) -> void:
	var sphere := MeshInstance3D.new()
	var mesh_obj := SphereMesh.new()
	mesh_obj.radius = 1.0
	mesh_obj.height = 2.0
	sphere.mesh = mesh_obj
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.2, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.3, 1.0)
	mat.emission_energy_multiplier = 4.0
	sphere.material_override = mat
	
	get_tree().current_scene.add_child(sphere)
	sphere.global_position = global_position
	
	var tw := sphere.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sphere, "scale", Vector3(radius, radius, radius), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(sphere.queue_free)

func _spawn_blink_visual(color: Color) -> void:
	# Flash light
	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 10.0
	flash.omni_range = 6.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = global_position
	
	# Small sphere flash
	var sphere := MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	sphere.mesh.radius = 0.5
	sphere.mesh.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	sphere.material_override = mat
	get_tree().current_scene.add_child(sphere)
	sphere.global_position = global_position
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "light_energy", 0.0, 0.3)
	tw.tween_property(sphere, "scale", Vector3(2, 2, 2), 0.3)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(flash.queue_free)
	tw.parallel().tween_callback(sphere.queue_free)

func take_hit() -> void:
	if _invuln_timer > 0.0 or is_invincible:
		return
	hits_taken = min(hits_taken + hit_damage, max_hits)
	_invuln_timer = invuln_time
	emit_signal("health_changed", max(max_hits - hits_taken, 0), max_hits)
	emit_signal("got_hit")
	_update_conditions()
	if hits_taken >= max_hits:
		emit_signal("died")

func _update_conditions() -> void:
	var hp_left: int = max_hits - hits_taken
	var pct: float = float(hp_left) / float(max_hits)

	var _was_critical := _has_critical

	_has_drift	= pct < 0.75
	_has_jitter   = pct < 0.50
	_has_stutter  = pct < 0.25
	_has_critical = false  # temporarily disabled

	if _has_drift and _drift_dir == Vector2.ZERO:
		_drift_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		_drift_change_timer = randf_range(1.5, 3.5)
