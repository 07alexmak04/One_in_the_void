extends Area3D

signal passed
signal exploded(pos: Vector3)

const _STONE_MESH := preload("res://reference/Stones/STONE#1/STONE#1.obj")
const _STONE_COLOR := preload("res://reference/Stones/STONE#1/STONE#1_Textures/STONE#1_color.png")
const _STONE_NORMAL := preload("res://reference/Stones/STONE#1/STONE#1_Textures/STONE#1_normal.png")
const _STONE_ROUGH := preload("res://reference/Stones/STONE#1/STONE#1_Textures/STONE#1_roughness.png")

@export var speed: float = 12.0
@export var hp: int = 3
@export var explosion_radius: float = 5.0
@export var explosion_damage: int = 2

var velocity: Vector3 = Vector3.ZERO
var spin_axis: Vector3 = Vector3(1, 1, 0).normalized()
var spin_speed: float = 1.5
var _exploding: bool = false

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	add_to_group("meteorite")
	collision_layer = 1 << 2
	collision_mask = (1 << 1) | (1 << 3)
	body_entered.connect(_on_body_entered)
	spin_axis = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	spin_speed = randf_range(0.6, 2.2)

func configure(start_pos: Vector3, vel: Vector3, meteor_hp: int = 3) -> void:
	global_position = start_pos
	velocity = vel
	speed = vel.length()
	hp = meteor_hp

func _physics_process(delta: float) -> void:
	var multiplier: float = 1.0
	var parent = get_parent() # This is the 'World' node
	if parent and parent.get_parent() and "rock_speed_multiplier" in parent.get_parent():
		multiplier = parent.get_parent().rock_speed_multiplier
		
	global_position += velocity * delta * multiplier
	if is_instance_valid(mesh):
		mesh.rotate(spin_axis, spin_speed * delta * multiplier)
	if global_position.z > 18.0:
		emit_signal("passed")
		queue_free()

func take_damage(dmg: int) -> void:
	hp -= dmg
	if hp <= 0:
		_explode()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_hit"):
		body.take_hit()
	_explode()

func _explode() -> void:
	if _exploding:
		return
	_exploding = true

	var pos := global_position
	var tree := get_tree()
	if tree:
		for m in tree.get_nodes_in_group("meteorite"):
			if is_instance_valid(m) and m != self:
				if m.global_position.distance_to(pos) <= explosion_radius:
					m.take_damage(explosion_damage)
		for p in tree.get_nodes_in_group("player"):
			if is_instance_valid(p) and p.global_position.distance_to(pos) <= explosion_radius:
				p.take_hit()

	emit_signal("exploded", pos)
	_spawn_explosion_vfx(pos)
	queue_free()

func _spawn_explosion_vfx(pos: Vector3) -> void:
	var scene_root := get_tree().current_scene

	# Central fireball flash — add_child FIRST, then set position
	var flash := Node3D.new()
	scene_root.add_child(flash)
	flash.global_position = pos

	var flash_mi := MeshInstance3D.new()
	var flash_sphere := SphereMesh.new()
	flash_sphere.radius = 0.5
	flash_sphere.height = 1.0
	flash_mi.mesh = flash_sphere
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.8, 0.3, 1.0)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.5, 0.1, 1.0)
	flash_mat.emission_energy_multiplier = 8.0
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mi.set_surface_override_material(0, flash_mat)
	flash.add_child(flash_mi)

	var flash_light := OmniLight3D.new()
	flash_light.omni_range = 12.0
	flash_light.light_energy = 14.0
	flash_light.light_color = Color(1.0, 0.6, 0.2)
	flash.add_child(flash_light)

	var flash_tween := flash.create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector3(5.0, 5.0, 5.0), 0.35)
	flash_tween.tween_property(flash_light, "light_energy", 0.0, 0.35)
	flash_tween.tween_method(func(a: float) -> void: flash_mat.albedo_color.a = a, 1.0, 0.0, 0.35)
	flash_tween.chain().tween_callback(flash.queue_free)

	# Flying debris pieces — Area3D so they can hit rocks and player
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(14):
		var debris := Area3D.new()
		debris.collision_layer = 1 << 3
		debris.collision_mask = (1 << 1) | (1 << 2)
		debris.monitoring = false
		scene_root.add_child(debris)
		debris.global_position = pos
		debris.set_deferred("monitoring", true)

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.35
		col.shape = shape
		debris.add_child(col)

		var mi := MeshInstance3D.new()
		mi.mesh = _STONE_MESH
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _STONE_COLOR
		mat.normal_enabled = true
		mat.normal_texture = _STONE_NORMAL
		mat.roughness_texture = _STONE_ROUGH
		mat.roughness_texture_channel = 0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.set_surface_override_material(0, mat)
		var sz := rng.randf_range(0.18, 0.42)
		mi.scale = Vector3(sz, sz * rng.randf_range(0.6, 1.4), sz * rng.randf_range(0.6, 1.4))
		debris.add_child(mi)

		debris.area_entered.connect(func(area: Area3D) -> void:
			if not is_instance_valid(debris):
				return
			if area.has_method("take_damage"):
				area.take_damage(2)
			debris.set_deferred("monitoring", false)
		)
		debris.body_entered.connect(func(body: Node3D) -> void:
			if not is_instance_valid(debris):
				return
			if body.has_method("take_hit"):
				body.take_hit()
			debris.set_deferred("monitoring", false)
		)

		var dir := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-0.6, 0.6)
		).normalized()
		var dist := rng.randf_range(5.0, 12.0)
		var duration := rng.randf_range(0.7, 1.2)
		var end_pos := pos + dir * dist

		var rot_end := Vector3(
			rng.randf_range(-TAU, TAU),
			rng.randf_range(-TAU, TAU),
			rng.randf_range(-TAU, TAU)
		)

		var dtween := debris.create_tween()
		dtween.set_parallel(true)
		dtween.tween_property(debris, "global_position", end_pos, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		dtween.tween_property(mi, "scale", Vector3.ZERO, duration).set_trans(Tween.TRANS_QUAD)
		dtween.tween_property(debris, "rotation", rot_end, duration)
		dtween.chain().tween_callback(debris.queue_free)
