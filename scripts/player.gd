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

# Condition state
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

func _physics_process(delta: float) -> void:
	_rifle_timer = max(_rifle_timer - delta, 0.0)
	_rocket_timer = max(_rocket_timer - delta, 0.0)
	_invuln_timer = max(_invuln_timer - delta, 0.0)
	_update_drift_timer(delta)
	_update_stutter_timer(delta)

	var input_vec := Vector3.ZERO

	if not _stutter_blocking:
		if Input.is_action_pressed("move_right"): input_vec.x += 1.0
		if Input.is_action_pressed("move_left"):  input_vec.x -= 1.0
		if Input.is_action_pressed("move_up"):    input_vec.y += 1.0
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

	global_position.x = clamp(global_position.x, -bounds.x, bounds.x)
	global_position.y = clamp(global_position.y, -bounds.y, bounds.y)
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
	var b := RifleBulletScene.instantiate()
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

func take_hit() -> void:
	if _invuln_timer > 0.0:
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

	var was_critical := _has_critical

	_has_drift    = pct < 0.75
	_has_jitter   = pct < 0.50
	_has_stutter  = pct < 0.25
	_has_critical = false  # temporarily disabled

	if _has_drift and _drift_dir == Vector2.ZERO:
		_drift_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		_drift_change_timer = randf_range(1.5, 3.5)
