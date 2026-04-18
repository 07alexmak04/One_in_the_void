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

var cfg: Dictionary
var spawn_remaining: float = 0.0
var spawning_done: bool = false
var grace_timer: float = 0.0
var finished: bool = false

func _ready() -> void:
	randomize()
	cfg = GameState.get_config()
	spawn_remaining = cfg["survival_time"]
	level_label.text = "Level: %s" % cfg["name"]

	player.configure(int(cfg["max_hits"]), 1)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
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

func _process(delta: float) -> void:
	if finished:
		return
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
		return

	if not spawning_done:
		spawn_remaining = max(spawn_remaining - delta, 0.0)
		survival_label.text = "%0.0fs" % spawn_remaining
		if spawn_remaining <= 0.0:
			spawning_done = true
			spawn_timer.stop()
			grace_timer = 3.0  # short grace period to clear remaining rocks
	else:
		grace_timer = max(grace_timer - delta, 0.0)
		survival_label.text = ""
		if grace_timer <= 0.0:
			# Clear any remaining rocks and end the level.
			for m in get_tree().get_nodes_in_group("meteorite"):
				m.queue_free()
			_on_level_cleared()

func _spawn_meteorite() -> void:
	if finished or spawning_done:
		return
	var m := MeteoriteScene.instantiate()
	add_child(m)

	var speed := float(cfg["meteor_speed"]) * randf_range(0.85, 1.2)
	var hp := 2 + (GameState.current_difficulty)
	var roll := randf()

	var start := Vector3.ZERO
	var target := Vector3.ZERO
	var player_pos := player.global_position
	var player_vel := player.velocity if player.velocity.length() > 0.5 else Vector3.ZERO

	if roll < 0.35:
		# --- Front approach: from deep z, aimed at player with lead prediction ---
		start = Vector3(randf_range(-13.0, 13.0), randf_range(-7.0, 7.0), -35.0)
		# Predict where player will be when the rock arrives.
		var travel_time: float = 35.0 / maxf(speed, 1.0)
		var predicted := player_pos + player_vel * travel_time * randf_range(0.3, 0.8)
		target = Vector3(
			predicted.x + randf_range(-2.0, 2.0),
			predicted.y + randf_range(-1.5, 1.5),
			0.0
		)
	elif roll < 0.55:
		# --- Side spawn: from left or right edge ---
		var from_left := randf() > 0.5
		var side_x := -16.0 if from_left else 16.0
		start = Vector3(side_x, randf_range(-7.0, 7.0), randf_range(-8.0, 2.0))
		target = Vector3(
			player_pos.x + randf_range(-3.0, 3.0),
			player_pos.y + randf_range(-2.0, 2.0),
			0.0
		)
	elif roll < 0.7:
		# --- Top/bottom spawn ---
		var from_top := randf() > 0.5
		var side_y := 10.0 if from_top else -10.0
		start = Vector3(randf_range(-12.0, 12.0), side_y, randf_range(-8.0, 2.0))
		target = Vector3(
			player_pos.x + randf_range(-3.0, 3.0),
			player_pos.y + randf_range(-2.0, 2.0),
			0.0
		)
	elif roll < 0.85:
		# --- Close fast: spawns closer, less reaction time ---
		start = Vector3(
			randf_range(-12.0, 12.0),
			randf_range(-6.0, 6.0),
			randf_range(-18.0, -10.0)
		)
		target = Vector3(
			player_pos.x + randf_range(-1.5, 1.5),
			player_pos.y + randf_range(-1.0, 1.0),
			0.0
		)
		speed *= 1.3
	else:
		# --- Random cross: not aimed at player, crosses the play area ---
		start = Vector3(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0), -30.0)
		target = Vector3(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0), 10.0)

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
