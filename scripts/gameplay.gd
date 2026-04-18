extends Node3D

const MeteoriteScene := preload("res://scenes/meteorite.tscn")

@onready var player: CharacterBody3D = $Player
@onready var spawn_timer: Timer = $SpawnTimer
@onready var survival_label: Label = $HUD/TopPanel/SurvivalLabel
@onready var level_label: Label = $HUD/TopPanel/LevelLabel
@onready var health_bar: ProgressBar = $HUD/TopPanel/HealthBar
@onready var game_over_panel: Control = $HUD/GameOverPanel
@onready var game_over_label: Label = $HUD/GameOverPanel/VBox/Label
@onready var retry_button: Button = $HUD/GameOverPanel/VBox/HBox/RetryButton
@onready var go_quit_button: Button = $HUD/GameOverPanel/VBox/HBox/QuitButton
@onready var pause_panel: Control = $HUD/PausePanel
@onready var resume_button: Button = $HUD/PausePanel/VBox/ResumeButton
@onready var pause_quit_button: Button = $HUD/PausePanel/VBox/QuitButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var camera: Camera3D = $Camera3D
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var background: MeshInstance3D = $Background

var cfg: Dictionary
var meteors_to_spawn: int = 0
var rocks_avoided: int = 0
var finished: bool = false

var _hit_flash: ColorRect = null
var _vignette: ColorRect = null
var _camera_origin: Vector3 = Vector3.ZERO
var _health_fill_style: StyleBoxFlat = null
var _env: Environment = null
var _base_ambient_energy: float = 0.55
var _base_glow: float = 0.4
var _health_pulse_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	cfg = GameState.get_config()
	meteors_to_spawn = int(cfg["meteor_count"])
	level_label.text = "Level: %s" % cfg["name"]
	_update_rock_label()
	_camera_origin = camera.position

	_env = world_env.environment
	_base_ambient_energy = _env.ambient_light_energy
	_base_glow = 0.4 + GameState.current_difficulty * 0.12
	_env.glow_intensity = _base_glow

	_build_vignette()
	_build_hit_flash()
	_build_health_style()
	_build_starfield()

	player.configure(int(cfg["max_hits"]), int(cfg["hit_damage"]))
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.got_hit.connect(_on_player_got_hit)
	_on_player_health_changed(int(cfg["max_hits"]), int(cfg["max_hits"]))

	spawn_timer.wait_time = float(cfg["meteor_spawn_interval"])
	spawn_timer.timeout.connect(_spawn_meteorite)
	spawn_timer.start()

	game_over_panel.visible = false
	pause_panel.visible = false
	retry_button.pressed.connect(_on_retry)
	go_quit_button.pressed.connect(_on_quit_to_menu)
	resume_button.pressed.connect(_on_resume)
	pause_quit_button.pressed.connect(_on_quit_to_menu)
	music_player.finished.connect(music_player.play)

func _build_health_style() -> void:
	_health_fill_style = StyleBoxFlat.new()
	_health_fill_style.bg_color = Color(0.2, 0.9, 0.2)
	health_bar.add_theme_stylebox_override("fill", _health_fill_style)

func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.color = Color(0.5, 0.0, 0.0, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud: CanvasLayer = $HUD
	hud.add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_hit_flash() -> void:
	_hit_flash = ColorRect.new()
	_hit_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud: CanvasLayer = $HUD
	hud.add_child(_hit_flash)
	_hit_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_starfield() -> void:
	var speed_mult := 1.0 + GameState.current_difficulty * 0.4
	var particles := GPUParticles3D.new()
	particles.amount = 320
	particles.lifetime = 2.2
	particles.preprocess = 2.2
	particles.randomness = 0.5
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
	grad.colors = PackedColorArray([
		Color(0.8, 0.9, 1.0, 0.0),
		Color(0.9, 0.95, 1.0, 1.0),
		Color(0.9, 0.95, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	particles.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 4
	mesh.rings = 2
	var star_mat := StandardMaterial3D.new()
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.85, 0.92, 1.0)
	star_mat.emission_energy_multiplier = 5.0
	star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh.surface_set_material(0, star_mat)
	particles.draw_pass_1 = mesh
	particles.position = Vector3(0.0, 0.0, -20.0)
	add_child(particles)

func _on_player_got_hit() -> void:
	_do_hit_flash()
	_do_camera_shake()

func _do_hit_flash() -> void:
	_hit_flash.color.a = 0.55
	var tw := create_tween()
	tw.tween_property(_hit_flash, "color:a", 0.0, 0.35)

func _do_camera_shake() -> void:
	var tw := create_tween()
	tw.set_loops(6)
	tw.tween_method(func(t: float) -> void:
		camera.position = _camera_origin + Vector3(
			sin(t * 40.0) * 0.18,
			cos(t * 37.0) * 0.14,
			0.0
		)
	, 0.0, 1.0, 0.05)
	tw.tween_callback(func() -> void: camera.position = _camera_origin)

func _on_explosion(_pos: Vector3) -> void:
	_do_explosion_camera_shake()
	_do_explosion_ambient_pulse()

func _do_explosion_camera_shake() -> void:
	var tw := create_tween()
	tw.set_loops(3)
	tw.tween_method(func(t: float) -> void:
		camera.position = _camera_origin + Vector3(
			sin(t * 30.0) * 0.10,
			cos(t * 28.0) * 0.08,
			0.0
		)
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

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not finished:
		_toggle_pause()
		return
	if finished or get_tree().paused:
		return
	if meteors_to_spawn == 0 and get_tree().get_nodes_in_group("meteorite").is_empty():
		_on_level_cleared()
	background.position.x = -player.global_position.x * 0.08
	background.position.y = -player.global_position.y * 0.06

func _spawn_meteorite() -> void:
	if finished or meteors_to_spawn <= 0:
		return
	meteors_to_spawn -= 1
	var m := MeteoriteScene.instantiate()
	add_child(m)
	m.passed.connect(_on_rock_passed)
	m.exploded.connect(_on_explosion)
	var x := randf_range(-13.0, 13.0)
	var y := randf_range(-7.0, 7.0)
	var start := Vector3(x, y, -40.0)
	var target := Vector3(
		player.global_position.x + randf_range(-8.0, 8.0),
		player.global_position.y + randf_range(-6.0, 6.0),
		0.0
	)
	var dir := (target - start).normalized()
	var speed := float(cfg["meteor_speed"]) * randf_range(0.85, 1.2)
	var hp := 2 + GameState.current_difficulty
	m.configure(start, dir * speed, hp)
	if meteors_to_spawn == 0:
		spawn_timer.stop()

func _on_rock_passed() -> void:
	rocks_avoided += 1
	_update_rock_label()

func _update_rock_label() -> void:
	survival_label.text = "Avoided: %d" % rocks_avoided

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

func _on_level_cleared() -> void:
	finished = true
	spawn_timer.stop()
	var newly: String = GameState.unlock_skin_for_difficulty(GameState.current_difficulty)
	GameState.save_prefs()
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
