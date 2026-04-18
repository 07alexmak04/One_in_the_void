extends Area3D

@export var speed: float = 32.0
@export var accel: float = 40.0
@export var life_time: float = 1.2
@export var damage: int = 5
@export var splash_radius: float = 4.0

var direction: Vector3 = Vector3(0, 0, -1)
var _life: float = 0.0
var _current_speed: float = 12.0

func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 1 << 2
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	_current_speed = min(_current_speed + accel * delta, speed)
	global_position += direction * _current_speed * delta
	_life += delta
	if _life > life_time:
		_explode()

func _on_body_entered(_body: Node) -> void:
	_explode()

func _on_area_entered(_area: Area3D) -> void:
	_explode()

func _explode() -> void:
	# Safety check: Don't explode if too close to player to avoid self-damage.
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		if global_position.distance_to(players[0].global_position) < 5.0:
			queue_free()
			return

	# Splash damage: affect all meteorites inside splash_radius.
	var tree := get_tree()
	if tree:
		for m in tree.get_nodes_in_group("meteorite"):
			if is_instance_valid(m) and m.global_position.distance_to(global_position) <= splash_radius:
				if m.has_method("take_damage"):
					m.take_damage(damage)
	queue_free()
