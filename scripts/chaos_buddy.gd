extends Node3D

## Chaos Buddy — a small malfunctioning drone that follows the player's spaceship.
## It shoots randomly in all directions. Bullets can hit meteorites (splitting them)
## or accidentally hit the player ship (dealing damage). Part of the "losing control" theme.

const BuddyBulletScene := preload("res://scenes/buddy_bullet.tscn")

@export var orbit_radius: float = 3.5
@export var orbit_speed: float = 1.8
@export var shoot_interval_min: float = 0.8
@export var shoot_interval_max: float = 2.5
@export var bullet_speed: float = 20.0
@export var aim_at_player_chance: float = 0.15  # 15% chance to shoot toward player

var _orbit_angle: float = 0.0
var _shoot_timer: float = 0.0
var _time: float = 0.0
var _bob_phase: float = 0.0

var _model: Node3D = null

func _ready() -> void:
	_orbit_angle = randf() * TAU
	_bob_phase = randf() * TAU
	_shoot_timer = randf_range(1.0, shoot_interval_max)
	_load_ship_model()

func _load_ship_model() -> void:
	var skin_data: Dictionary = GameState.get_selected_skin_data()
	var model_scene = load(skin_data["model"])
	if model_scene == null:
		return
	_model = Node3D.new()
	_model.name = "BuddyModel"
	add_child(_model)
	var instance: Node3D = model_scene.instantiate()
	# Same orientation as the player ship but ~40% the size.
	var s: float = skin_data["scale"] * 0.4
	instance.transform = Transform3D(
		Vector3(0, 0, s), Vector3(0, s, 0), Vector3(-s, 0, 0),
		Vector3.ZERO
	)
	var tex = load(skin_data["texture"])
	if tex:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.metallic = 0.4
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = skin_data["emission_color"]
		mat.emission_energy_multiplier = skin_data["emission_energy"]
		_apply_mat(instance, mat)
	_model.add_child(instance)

func _apply_mat(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_mat(child, mat)

func _process(delta: float) -> void:
	_time += delta
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0 or not is_instance_valid(players[0]):
		return
	var player_node: Node3D = players[0]

	# Orbit around the player ship.
	_orbit_angle += orbit_speed * delta
	var offset := Vector3(
		cos(_orbit_angle) * orbit_radius,
		sin(_orbit_angle) * orbit_radius * 0.5 + sin(_time * 3.0 + _bob_phase) * 0.4,
		sin(_orbit_angle * 0.6) * 1.5
	)
	global_position = global_position.lerp(player_node.global_position + offset, 6.0 * delta)

	# Tilt model slightly as it orbits.
	if _model:
		_model.rotation.z = sin(_time * 2.0) * 0.2
		_model.rotation.x = cos(_time * 1.5) * 0.15

	# Shoot timer.
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = randf_range(shoot_interval_min, shoot_interval_max)
		_fire(player_node)

func _fire(player_node: Node3D) -> void:
	var dir := Vector3.ZERO
	var roll := randf()

	if roll < aim_at_player_chance:
		# Accidentally shoot toward the player.
		dir = (player_node.global_position - global_position).normalized()
		dir += Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.1, 0.1))
		dir = dir.normalized()
	else:
		# Shoot in a random forward-ish direction (where meteorites come from).
		dir = Vector3(
			randf_range(-0.8, 0.8),
			randf_range(-0.6, 0.6),
			randf_range(-1.0, -0.2)
		).normalized()

	var bullet := BuddyBulletScene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.speed = bullet_speed

func configure(cfg_shoot_interval: float, cfg_aim_chance: float) -> void:
	shoot_interval_min = cfg_shoot_interval * 0.6
	shoot_interval_max = cfg_shoot_interval
	aim_at_player_chance = cfg_aim_chance
