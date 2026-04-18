extends Area3D

## Projectile fired by Chaos Buddy drones.
## Hits the player (damages ship) and meteorites (causes them to split).

@export var speed: float = 18.0
@export var life_time: float = 4.0
@export var damage_to_player: int = 1

var direction: Vector3 = Vector3(0, 0, -1)
var _life: float = 0.0

func _ready() -> void:
	# Enemy projectile: layer 5, collides with player (layer 2) and meteorites (layer 3).
	collision_layer = 1 << 4   # enemy_projectile
	collision_mask = (1 << 1) | (1 << 2)  # player + enemy(meteorite)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life += delta
	if _life > life_time:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# Hit the player ship.
	if body.has_method("take_hit"):
		body.take_hit()
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	# Hit a meteorite — make it split into fragments.
	if area.is_in_group("meteorite") and area.has_method("split_from_buddy"):
		area.split_from_buddy()
	queue_free()
