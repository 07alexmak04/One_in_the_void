extends Area3D

@export var speed: float = 50.0
@export var life_time: float = 2.5
@export var damage: int = 1

var direction: Vector3 = Vector3(0, 0, -1)
var _life: float = 0.0

func _ready() -> void:
	# Player projectile on layer 4, hits enemies on layer 3.
	collision_layer = 1 << 3
	collision_mask = 1 << 2
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
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
