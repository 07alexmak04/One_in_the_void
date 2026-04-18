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

var cfg: Dictionary
var meteors_to_spawn: int = 0
var rocks_avoided: int = 0
var finished: bool = false

var _hit_flash: ColorRect = null
var _camera_origin: Vector3 = Vector3.ZERO
var _health_fill_style: StyleBoxFlat = null

func _ready() -> void:
	randomize()
	cfg = GameState.get_config()
	meteors_to_spawn = int(cfg["meteor_count"])
	level_label.text = "Level: %s" % cfg["name"]
	_update_rock_label()
	_camera_origin = camera.position

	_build_hit_flash()
	_build_health_style()

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

func _build_hit_flash() -> void:
	_hit_flash = ColorRect.new()
	_hit_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud: CanvasLayer = $HUD
	hud.add_child(_hit_flash)
	# Stretch to fill screen
	_hit_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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

func _process(_delta: float) -> void:
	if finished:
		return
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
		return
	if meteors_to_spawn == 0 and get_tree().get_nodes_in_group("meteorite").is_empty():
		_on_level_cleared()

func _spawn_meteorite() -> void:
	if finished or meteors_to_spawn <= 0:
		return
	meteors_to_spawn -= 1

	var m := MeteoriteScene.instantiate()
	add_child(m)
	m.passed.connect(_on_rock_passed)
	var x := randf_range(-13.0, 13.0)
	var y := randf_range(-7.0, 7.0)
	var start := Vector3(x, y, -40.0)
	var target := Vector3(
		player.global_position.x + randf_range(-4.0, 4.0),
		player.global_position.y + randf_range(-3.0, 3.0),
		0.0
	)
	var dir := (target - start).normalized()
	var speed := float(cfg["meteor_speed"]) * randf_range(0.85, 1.2)
	var hp := 2 + (GameState.current_difficulty)
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
	if _health_fill_style:
		var pct := float(current) / float(max_hp)
		var c: Color
		if pct > 0.5:
			c = Color(0.2, 0.9, 0.2).lerp(Color(1.0, 0.85, 0.0), (1.0 - pct) * 2.0)
		else:
			c = Color(1.0, 0.85, 0.0).lerp(Color(0.9, 0.1, 0.1), (0.5 - pct) * 2.0)
		_health_fill_style.bg_color = c

func _on_player_died() -> void:
	finished = true
	spawn_timer.stop()
	game_over_label.text = "You lost control.\nThe void claims another."
	retry_button.visible = true
	game_over_panel.visible = true

func _on_level_cleared() -> void:
	finished = true
	spawn_timer.stop()
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
