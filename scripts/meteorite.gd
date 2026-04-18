extends Area3D

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
	global_position += velocity * delta
	if is_instance_valid(mesh):
		mesh.rotate(spin_axis, spin_speed * delta)
	if global_position.z > 18.0:
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

	_spawn_explosion_vfx(pos)
	queue_free()

func _spawn_explosion_vfx(pos: Vector3) -> void:
	var scene_root := get_tree().current_scene
	var vfx := Node3D.new()
	vfx.global_position = pos
	scene_root.add_child(vfx)

	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.1, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0, 1.0)
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.set_surface_override_material(0, mat)
	vfx.add_child(mi)

	var light := OmniLight3D.new()
	light.omni_range = 8.0
	light.light_energy = 10.0
	light.light_color = Color(1.0, 0.6, 0.2)
	vfx.add_child(light)

	var tween := vfx.create_tween()
	tween.set_parallel(true)
	tween.tween_property(vfx, "scale", Vector3(6.0, 6.0, 6.0), 0.45)
	tween.tween_property(light, "light_energy", 0.0, 0.45)
	tween.tween_method(func(a: float) -> void: mat.albedo_color.a = a, 1.0, 0.0, 0.45)
	tween.chain().tween_callback(vfx.queue_free)
