extends Node3D

const MeteoriteScene := preload("res://scenes/meteorite.tscn")
const ChaosBuddyScene := preload("res://scenes/chaos_buddy.tscn")

@onready var player: CharacterBody3D = $World/Player
@onready var camera: Camera3D = $Camera3D
@onready var spawn_timer: Timer = $World/SpawnTimer
@onready var world: Node3D = $World
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
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var minimap: Control = $HUD/Minimap
@onready var waypoint_marker: Node3D = $WaypointMarker
@onready var skill_name_label: Label = $HUD/SkillPanel/VBox/SkillName
@onready var skill_cd_bar: ProgressBar = $HUD/SkillPanel/VBox/CooldownBar
@onready var skill_ready_label: Label = $HUD/SkillPanel/VBox/ReadyLabel
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var menu_button: Button = $HUD/TopPanel/MenuButton

var cfg: Dictionary
var meteors_to_spawn: int = 0
var rocks_avoided: int = 0
var time_used: float = 0.0
var finished: bool = false

# Internal FX and UI state
var _hit_flash: ColorRect = null
var _vignette: ColorRect = null
var _camera_origin: Vector3 = Vector3.ZERO
var _health_fill_style: StyleBoxFlat = null
var _env: Environment = null
var _base_ambient_energy: float = 0.55
var _base_glow: float = 0.4
var _health_pulse_tween: Tween = null
var rock_speed_multiplier: float = 1.0

# Course logic
var waypoints: Array[Vector2] = []
var current_wp_idx: int = 0
var wp_radius: float = 3.5
var course_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	cfg = GameState.get_config()
	level_label.text = "Level: %s" % cfg["name"]
	meteors_to_spawn = int(cfg.get("meteor_count", 0))
	_camera_origin = camera.position
	
	_env = world_env.environment
	_base_ambient_energy = _env.ambient_light_energy
	_base_glow = 0.4 + GameState.current_difficulty * 0.12
	_env.glow_intensity = _base_glow
	
	_build_vignette()
	_build_hit_flash()
	_build_health_style()
	_build_starfield()
	_setup_course()
	
	player.configure(int(cfg["max_hits"]), 1)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.got_hit.connect(_on_player_got_hit)
	_on_player_health_changed(int(cfg["max_hits"]), int(cfg["max_hits"]))
	
	spawn_timer.wait_time = float(cfg["meteor_spawn_interval"])
	spawn_timer.timeout.connect(_spawn_meteorite)
	spawn_timer.start()
	
	# Spawn chaos buddy companion drone.
	_spawn_chaos_buddy()

	game_over_panel.visible = false
	pause_panel.visible = false
	retry_button.pressed.connect(_on_retry)
	go_quit_button.pressed.connect(_on_quit_to_menu)
	resume_button.pressed.connect(_on_resume)
	pause_quit_button.pressed.connect(_on_quit_to_menu)
	menu_button.pressed.connect(_toggle_pause)
	music_player.finished.connect(music_player.play)

func _setup_course() -> void:
	wp_radius = float(cfg.get("waypoint_radius", 3.5))
	var course_dist: float = cfg.get("course_distance", 50.0)
	var angle := randf() * TAU
	course_origin = Vector2(cos(angle), sin(angle)) * course_dist
	
	waypoints.clear()
	var course_pts: Array = cfg.get("course_points", [])
	var course_dir := course_origin.normalized()
	var perp := Vector2(-course_dir.y, course_dir.x)
	for pt: Vector2 in course_pts:
		var world_pt: Vector2 = course_origin + course_dir * pt.x + perp * pt.y
		waypoints.append(world_pt)
	
	minimap.waypoints = waypoints
	_update_waypoint_marker()

func _build_health_style() -> void:
	_health_fill_style = StyleBoxFlat.new()
	_health_fill_style.bg_color = Color(0.2, 0.9, 0.2)
	health_bar.add_theme_stylebox_override("fill", _health_fill_style)

func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.color = Color(0.5, 0.0, 0.0, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_hit_flash() -> void:
	_hit_flash = ColorRect.new()
	_hit_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_hit_flash)
	_hit_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_starfield() -> void:
	var speed_mult := 1.0 + GameState.current_difficulty * 0.4
	var particles := GPUParticles3D.new()
	particles.amount = 320
	particles.lifetime = 2.2
	particles.preprocess = 2.2
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(18.0, 11.0, 24.0)
	mat.direction = Vector3(0.0, 0.0, 1.0)
	mat.spread = 1.5
	mat.initial_velocity_min = 22.0 * speed_mult
	mat.initial_velocity_max = 44.0 * speed_mult
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.4
	mat.scale_max = 1.3
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.08, 0.82, 1.0])
	grad.colors = PackedColorArray([Color(0.8, 0.9, 1.0, 0.0), Color(0.9, 0.95, 1.0, 1.0), Color(0.9, 0.95, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	particles.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	var star_mat := StandardMaterial3D.new()
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.85, 0.92, 1.0)
	star_mat.emission_energy_multiplier = 5.0
	star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, star_mat)
	particles.draw_pass_1 = mesh
	particles.position = Vector3(0.0, 0.0, -20.0)
	add_child(particles)

func _on_player_got_hit() -> void:
	_do_hit_flash()
	_do_camera_shake()

func _do_hit_flash() -> void:
	if _hit_flash:
		_hit_flash.color.a = 0.55
		var tw := create_tween()
		tw.tween_property(_hit_flash, "color:a", 0.0, 0.35)

func _do_camera_shake() -> void:
	var tw := create_tween()
	tw.set_loops(6)
	tw.tween_method(func(t: float) -> void:
		camera.position = _camera_origin + Vector3(sin(t * 40.0) * 0.18, cos(t * 37.0) * 0.14, 0.0)
	, 0.0, 1.0, 0.05)
	tw.tween_callback(func() -> void: camera.position = _camera_origin)

func _on_explosion(_pos: Vector3) -> void:
	_do_explosion_camera_shake()
	_do_explosion_ambient_pulse()

func _do_explosion_camera_shake() -> void:
	var tw := create_tween()
	tw.set_loops(3)
	tw.tween_method(func(t: float) -> void:
		camera.position = _camera_origin + Vector3(sin(t * 30.0) * 0.10, cos(t * 28.0) * 0.08, 0.0)
	, 0.0, 1.0, 0.04)
	tw.tween_callback(func() -> void: camera.position = _camera_origin)

func _do_explosion_ambient_pulse() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_env, "ambient_light_energy", _base_ambient_energy * 3.5, 0.07)
	tw.tween_property(_env, "glow_intensity", _base_glow * 2.2, 0.07)
	tw.chain().set_parallel(true)
	tw.tween_property(_env, "ambient_light_energy", _base_ambient_energy, 0.5)
	tw.tween_property(_env, "glow_intensity", _base_glow, 0.5)

func _process(delta: float) -> void:
	_update_skill_ui(delta)
	if finished:
		return
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
		return
		
	# Camera follows player smoothly
	var target_cam := Vector3(player.global_position.x, player.global_position.y, camera.global_position.z)
	camera.global_position = camera.global_position.lerp(target_cam, 5.0 * delta)
	
	# Timer
	time_used += delta
	var mins := int(time_used) / 60
	var secs := int(time_used) % 60
	time_label.text = "%d:%02d" % [mins, secs]
	
	# Course tracking
	if current_wp_idx < waypoints.size():
		var wp: Vector2 = waypoints[current_wp_idx]
		var player_2d := Vector2(player.global_position.x, player.global_position.y)
		var dist := player_2d.distance_to(wp)
		if dist <= wp_radius:
			current_wp_idx += 1
			if current_wp_idx >= waypoints.size():
				_on_level_victory()
				return
			_update_waypoint_marker()
			
	waypoint_label.text = "%d / %d" % [current_wp_idx, waypoints.size()]
	
	# Update minimap
	minimap.update_state(Vector2(player.global_position.x, player.global_position.y), current_wp_idx)

func _update_waypoint_marker() -> void:
	if current_wp_idx < waypoints.size():
		var wp: Vector2 = waypoints[current_wp_idx]
		waypoint_marker.global_position = Vector3(wp.x, wp.y, 0.0)
		waypoint_marker.visible = true
	else:
		waypoint_marker.visible = false

func _update_skill_ui(_delta: float) -> void:
	if not is_instance_valid(player) or player.skill_info.is_empty():
		return
	var cd: float = player.skill_cooldown_timer
	var total_cd: float = player.skill_info["cooldown"]
	skill_name_label.text = "Skill: " + player.skill_info["name"] + " (Q)"
	if cd > 0:
		skill_cd_bar.value = (1.0 - (cd / total_cd)) * 100.0
		skill_ready_label.visible = false
	else:
		skill_cd_bar.value = 100.0
		skill_ready_label.visible = true

func _spawn_meteorite() -> void:
	if finished:
		return
	
	var m := MeteoriteScene.instantiate()
	world.add_child(m)
	m.exploded.connect(_on_explosion)
	
	var pp := player.global_position
	var pv := player.velocity
	var speed := float(cfg["meteor_speed"]) * randf_range(0.85, 1.2) * rock_speed_multiplier
	
	var start := Vector3.ZERO
	var target := Vector3.ZERO
	var roll := randf()
	
	if roll < 0.7:
		# Front approach with prediction
		start = pp + Vector3(randf_range(-15.0, 15.0), randf_range(-9.0, 9.0), -38.0)
		var travel_time: float = 38.0 / maxf(speed, 1.0)
		var predicted := pp + pv * travel_time * randf_range(0.4, 0.8)
		target = Vector3(predicted.x + randf_range(-2.5, 2.5), predicted.y + randf_range(-2.0, 2.0), pp.z + 5.0)
	else:
		# Side/Ambush approach
		var side_x := 18.0 if randf() > 0.5 else -18.0
		start = pp + Vector3(side_x, randf_range(-8.0, 8.0), randf_range(-10.0, 10.0))
		target = pp + Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), pp.z)
	
	var dir := (target - start).normalized()
	var hp := 2 + (GameState.current_difficulty)
	m.configure(start, dir * speed, hp)

func _spawn_chaos_buddy() -> void:
	var buddy := ChaosBuddyScene.instantiate()
	world.add_child(buddy)
	buddy.global_position = player.global_position + Vector3(3, 1, 0)
	# Harder difficulties: shoots faster and more likely to hit the player.
	var shoot_interval := 2.5 - GameState.current_difficulty * 0.5  # 2.5 / 2.0 / 1.5
	var aim_chance := 0.1 + GameState.current_difficulty * 0.05     # 10% / 15% / 20%
	buddy.configure(shoot_interval, aim_chance)

func trigger_slow_motion(multiplier: float, duration: float) -> void:
	rock_speed_multiplier = multiplier
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(self, "rock_speed_multiplier", 1.0, 0.5)

func _on_player_health_changed(current: int, max_hp: int) -> void:
	if max_hp <= 0:
		health_bar.value = 0
		return
	health_bar.max_value = max_hp
	health_bar.value = current
	var pct := float(current) / float(max_hp)
	if _health_fill_style:
		var c: Color
		if pct > 0.5:
			c = Color(0.2, 0.9, 0.2).lerp(Color(1.0, 0.85, 0.0), (1.0 - pct) * 2.0)
		else:
			c = Color(1.0, 0.85, 0.0).lerp(Color(0.9, 0.1, 0.1), (0.5 - pct) * 2.0)
		_health_fill_style.bg_color = c
	var danger := 1.0 - pct
	if _vignette:
		_vignette.color.a = danger * 0.32
	if _env:
		_env.ambient_light_color = Color(0.72, 0.68, 0.62).lerp(Color(0.85, 0.18, 0.12), danger * 0.65)
	if pct <= 0.25:
		if _health_pulse_tween == null or not _health_pulse_tween.is_running():
			_health_pulse_tween = create_tween().set_loops()
			_health_pulse_tween.tween_property(health_bar, "modulate:a", 0.3, 0.35)
			_health_pulse_tween.tween_property(health_bar, "modulate:a", 1.0, 0.35)
	else:
		if _health_pulse_tween:
			_health_pulse_tween.kill()
			_health_pulse_tween = null
			health_bar.modulate.a = 1.0

func _on_player_died() -> void:
	finished = true
	spawn_timer.stop()
	game_over_label.text = "You lost control.\nThe void claims another."
	retry_button.visible = true
	game_over_panel.visible = true

func _on_level_victory() -> void:
	finished = true
	spawn_timer.stop()
	
	# Record results
	GameState.last_time_used = time_used
	var stars := 3
	if time_used > 180.0: stars = 1
	elif time_used > 90.0: stars = 2
	GameState.last_stars = stars
	
	for m in get_tree().get_nodes_in_group("meteorite"):
		m.queue_free()
	get_tree().change_scene_to_file("res://scenes/victory.tscn")

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
