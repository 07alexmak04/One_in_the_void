extends Area3D

@export var speed: float = 12.0
@export var hp: int = 3

var velocity: Vector3 = Vector3.ZERO
var spin_axis: Vector3 = Vector3(1, 1, 0).normalized()
var spin_speed: float = 1.5

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	add_to_group("meteorite")
	# Enemy on layer 3, collides with player (2) and player projectiles (4).
	collision_layer = 1 << 2
	collision_mask = (1 << 1) | (1 << 3)
	body_entered.connect(_on_body_entered)
	# Random rotation axis so rocks look different.
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
	# Despawn when well past the player.
	if global_position.z > 18.0:
		queue_free()

func take_damage(dmg: int) -> void:
	hp -= dmg
	if hp <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_hit"):
		body.take_hit()
		queue_free()
