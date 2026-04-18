extends CharacterBody3D

signal health_changed(current: int, max: int)
signal died

@export var move_speed: float = 14.0
@export var bounds: Vector3 = Vector3(11, 6, 0)
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
	add_to_group("player")
	collision_layer = 1 << 1
	collision_mask = (1 << 2) | (1 << 4)

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
