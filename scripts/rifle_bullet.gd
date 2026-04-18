extends Area3D

@export var speed: float = 50.0
@export var life_time: float = 2.5
@export var damage: int = 1

var direction: Vector3 = Vector3(0, 0, -1)
var _life: float = 0.0

func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 1 << 2
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	var glow := OmniLight3D.new()
	glow.omni_range = 3.5
	glow.light_energy = 5.0
	glow.light_color = Color(1.0, 0.75, 0.2)
	add_child(glow)
	_apply_missile_material(self)

func _apply_missile_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://reference/Rockets Missiles and Bombs - AurynSky/Textures/Red.png")
		mat.metallic = 0.4
		mat.roughness = 0.35
		node.material_override = mat
	for child in node.get_children():
		_apply_missile_material(child)

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
