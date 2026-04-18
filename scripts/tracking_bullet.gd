extends Area3D

@export var speed: float = 35.0 # Slower than rifle bullet to allow for turning
@export var life_time: float = 4.0
@export var damage: int = 2 # Skills should be powerful
@export var turn_speed: float = 8.0 # How fast it curves

var direction: Vector3 = Vector3(0, 0, -1)
var _target: Node3D = null
var _life: float = 0.0

func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 1 << 2
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Visual flare
	var glow := OmniLight3D.new()
	glow.omni_range = 4.0
	glow.light_energy = 8.0
	glow.light_color = Color(0.2, 0.6, 1.0) # Blue for tracking
	add_child(glow)
	
	_apply_missile_material(self)
	_find_target()

func _find_target() -> void:
	var potential_targets = get_tree().get_nodes_in_group("meteorite")
	var closest_dist := 1000.0
	for t in potential_targets:
		if is_instance_valid(t) and t.global_position.z < global_position.z: # Only target things in front
			var d = global_position.distance_to(t.global_position)
			if d < closest_dist:
				closest_dist = d
				_target = t

func _apply_missile_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		# Blue texture for tracking missile
		mat.albedo_color = Color(0.2, 0.4, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.3, 0.8)
		mat.emission_energy_multiplier = 2.0
		mat.metallic = 0.6
		mat.roughness = 0.2
		node.material_override = mat
	for child in node.get_children():
		_apply_missile_material(child)

func _physics_process(delta: float) -> void:
	if is_instance_valid(_target):
		var target_dir = ((_target.global_position + Vector3(0,0,-1)) - global_position).normalized()
		# Smoothly rotate direction
		direction = direction.lerp(target_dir, turn_speed * delta).normalized()
		# Update rotation to match direction
		if direction.length() > 0.1:
			look_at(global_position + direction, Vector3.UP)
	
	global_position += direction * speed * delta
	_life += delta
	if _life > life_time:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	queue_free()
