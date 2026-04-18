extends Node3D

const MeteoriteScene := preload("res://scenes/meteorite.tscn")

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Camera3D
@onready var spawn_timer: Timer = $SpawnTimer
@onready var time_label: Label = $HUD/TopPanel/TimeLabel
@onready var level_label: Label = $HUD/TopPanel/LevelLabel
@onready var health_bar: ProgressBar = $HUD/TopPanel/HealthBar
@onready var waypoint_label: Label = $HUD/TopPanel/WaypointLabel
@onready var game_over_panel: Control = $HUD/GameOverPanel
@onready var game_over_label: Label = $HUD/GameOverPanel/VBox/Label
@onready var retry_button: Button = $HUD/GameOverPanel/VBox/HBox/RetryButton
@onready var go_quit_button: Button = $HUD/GameOverPanel/VBox/HBox/QuitButton
@onready var pause_panel: Control = $HUD/PausePanel
@onready var resume_button: Button = $HUD/PausePanel/VBox/ResumeButton
@onready var pause_quit_button: Button = $HUD/PausePanel/VBox/QuitButton
@onready var minimap: Control = $HUD/Minimap
@onready var waypoint_marker: Node3D = $WaypointMarker

var cfg: Dictionary
var time_used: float = 0.0
var finished: bool = false

# Course: world-space waypoints generated from config.
var waypoints: Array[Vector2] = []
var current_wp_idx: int = 0
var wp_radius: float = 3.0
var course_origin: Vector2 = Vector2.ZERO  # where the course starts in world

func _ready() -> void:
	randomize()
	cfg = GameState.get_config()
	level_label.text = cfg["name"]
	wp_radius = float(cfg["waypoint_radius"])

	# Place the course at a random direction, at the configured distance.
	var course_dist: float = cfg["course_distance"]
	var angle := randf() * TAU
	course_origin = Vector2(cos(angle), sin(angle)) * course_dist

	# Build world-space waypoints from course_origin + relative points.
	waypoints.clear()
	var course_pts: Array = cfg["course_points"]
	# Rotate course points to align with the direction from origin to course.
	var course_dir := course_origin.normalized()
	var perp := Vector2(-course_dir.y, course_dir.x)
	for pt: Vector2 in course_pts:
		var world_pt: Vector2 = course_origin + course_dir * pt.x + perp * pt.y
		waypoints.append(world_pt)

	player.configure(int(cfg["max_hits"]), 1)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	_on_player_health_changed(int(cfg["max_hits"]), int(cfg["max_hits"]))

	spawn_timer.wait_time = float(cfg["meteor_spawn_interval"])
	spawn_timer.timeout.connect(_spawn_meteorite)
	spawn_timer.start()

	minimap.waypoints = waypoints
	_update_waypoint_marker()

	game_over_panel.visible = false
	pause_panel.visible = false
	retry_button.pressed.connect(_on_retry)
	go_quit_button.pressed.connect(_on_quit_to_menu)
	resume_button.pressed.connect(_on_resume)
	pause_quit_button.pressed.connect(_on_quit_to_menu)

func _process(delta: float) -> void:
	if finished:
		return
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
		return

	# Camera follows player smoothly.
	var target_cam := Vector3(player.global_position.x, player.global_position.y, camera.global_position.z)
	camera.global_position = camera.global_position.lerp(target_cam, 5.0 * delta)

	# Timer.
	time_used += delta
	var mins := int(time_used) / 60
	var secs := int(time_used) % 60
	time_label.text = "%d:%02d" % [mins, secs]

	# Course tracking.
	if current_wp_idx < waypoints.size():
		var wp: Vector2 = waypoints[current_wp_idx]
		var player_2d := Vector2(player.global_position.x, player.global_position.y)
		var dist := player_2d.distance_to(wp)
		if dist <= wp_radius:
			current_wp_idx += 1
			if current_wp_idx >= waypoints.size():
				_on_level_cleared()
				return
			_update_waypoint_marker()

	waypoint_label.text = "%d / %d" % [current_wp_idx, waypoints.size()]

	# Update minimap.
	minimap.update_state(
		Vector2(player.global_position.x, player.global_position.y),
		current_wp_idx
	)

func _update_waypoint_marker() -> void:
	if current_wp_idx < waypoints.size():
		var wp: Vector2 = waypoints[current_wp_idx]
		waypoint_marker.global_position = Vector3(wp.x, wp.y, 0.0)
		waypoint_marker.visible = true
	else:
		waypoint_marker.visible = false

func _spawn_meteorite() -> void:
	if finished:
		return
	var m := MeteoriteScene.instantiate()
	add_child(m)

	var speed := float(cfg["meteor_speed"]) * randf_range(0.85, 1.2)
	var hp := 2 + (GameState.current_difficulty)
	var pp := player.global_position  # spawn relative to player
	var pv := player.velocity if player.velocity.length() > 0.5 else Vector3.ZERO
	var roll := randf()

	var start := Vector3.ZERO
	var target := Vector3.ZERO

	if roll < 0.4:
		# Front approach with prediction.
		start = pp + Vector3(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0), -35.0)
		var travel_time: float = 35.0 / maxf(speed, 1.0)
		var predicted := pp + pv * travel_time * randf_range(0.3, 0.7)
		target = Vector3(predicted.x + randf_range(-2.0, 2.0), predicted.y + randf_range(-1.5, 1.5), 0.0)
	elif roll < 0.6:
		# Side spawn.
		var side_x: float = pp.x + (16.0 if randf() > 0.5 else -16.0)
		start = Vector3(side_x, pp.y + randf_range(-8.0, 8.0), randf_range(-6.0, 2.0))
		target = Vector3(pp.x + randf_range(-3.0, 3.0), pp.y + randf_range(-2.0, 2.0), 0.0)
	elif roll < 0.75:
		# Top/bottom.
		var side_y: float = pp.y + (10.0 if randf() > 0.5 else -10.0)
		start = Vector3(pp.x + randf_range(-12.0, 12.0), side_y, randf_range(-6.0, 2.0))
		target = Vector3(pp.x + randf_range(-3.0, 3.0), pp.y + randf_range(-2.0, 2.0), 0.0)
	elif roll < 0.9:
		# Close fast.
		start = pp + Vector3(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0), randf_range(-16.0, -8.0))
		target = Vector3(pp.x + randf_range(-1.5, 1.5), pp.y + randf_range(-1.0, 1.0), 0.0)
		speed *= 1.3
	else:
		# Random cross.
		start = pp + Vector3(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0), -28.0)
		target = pp + Vector3(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0), 10.0)

	var dir := (target - start).normalized()
	m.configure(start, dir * speed, hp)

func _on_player_health_changed(current: int, max_hp: int) -> void:
	if max_hp <= 0:
		health_bar.value = 0
		return
	health_bar.max_value = max_hp
	health_bar.value = current

func _on_player_died() -> void:
	finished = true
	spawn_timer.stop()
	game_over_label.text = "You lost control.\nThe void claims another."
	retry_button.visible = true
	game_over_panel.visible = true

func _on_level_cleared() -> void:
	finished = true
	spawn_timer.stop()
	for m in get_tree().get_nodes_in_group("meteorite"):
		m.queue_free()
	GameState.last_time_used = time_used
	GameState.last_stars = GameState.calculate_stars(GameState.current_difficulty, time_used)
	if GameState.has_next_level():
		get_tree().change_scene_to_file("res://scenes/victory.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/final_victory.tscn")

func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_panel.visible = paused

func _on_resume() -> void:
	get_tree().paused = false
	pause_panel.visible = false

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_to_menu() -> void:
	get_tree().paused = false
	GameState.reset_progression()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
