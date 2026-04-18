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

var cfg: Dictionary
var meteors_to_spawn: int = 0
var finished: bool = false

func _ready() -> void:
	randomize()
	cfg = GameState.get_config()
	meteors_to_spawn = int(cfg["meteor_count"])
	level_label.text = "Level: %s" % cfg["name"]
	_update_rock_label()

	player.configure(int(cfg["max_hits"]))
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
	music_player.finished.connect(music_player.play)

func _process(_delta: float) -> void:
	if finished:
		return
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
		return

	# Win once all rocks are spawned and none remain in the scene.
	if meteors_to_spawn == 0 and get_tree().get_nodes_in_group("meteorite").is_empty():
		_on_level_cleared()

func _spawn_meteorite() -> void:
	if finished or meteors_to_spawn <= 0:
		return
	meteors_to_spawn -= 1
	_update_rock_label()

	var m := MeteoriteScene.instantiate()
	add_child(m)
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

func _update_rock_label() -> void:
	if meteors_to_spawn > 0:
		survival_label.text = "Rocks: %d" % meteors_to_spawn
	else:
		survival_label.text = "Hold on!"

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
