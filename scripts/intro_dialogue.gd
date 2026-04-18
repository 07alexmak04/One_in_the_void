extends Control

# Each dialogue escalates HARD — calm commanders don't exist here.
const DIALOGUES := [
	{
		"speaker": "COMMANDER YAO",
		"text": "PILOT! WAKE UP! DO YOU COPY?!\nThe spaceship has deviated from its course! Navigation is DEAD!\nWe've lost ALL control! Engines are firing on their own! We are DRIFTING INTO THE VOID!",
		"rate": 1.2,
		"pitch": 0.72,
		"volume": 75,
		"shake_burst": 8.0,
		"rumble": 1.5,
		"typewriter_speed": 0.028,
		"flash_alpha": 0.15,
		"flash_pulse": false,
		"warning_color": Color(1, 0.35, 0.25, 1),
		"bubble_border_color": Color(0.29, 0.76, 1, 0.6),
		"bg_darkness": 0.4,
	},
	{
		"speaker": "COMMANDER YAO  [PRIORITY: MAXIMUM]",
		"text": "OH GOD... METEORITES! HUNDREDS OF THEM! DEAD AHEAD!\nTHEY'RE EVERYWHERE! THE HULL CAN'T TAKE THIS!\nIMPACT IN SECONDS! WE ARE GOING TO CRASH! I REPEAT... WE! ARE! GOING! TO! CRASH!",
		"rate": 1.5,
		"pitch": 0.85,
		"volume": 90,
		"shake_burst": 10.0,
		"rumble": 2.0,
		"typewriter_speed": 0.018,
		"flash_alpha": 0.5,
		"flash_pulse": true,
		"warning_color": Color(1, 0.15, 0.1, 1),
		"bubble_border_color": Color(1, 0.4, 0.2, 0.8),
		"bg_darkness": 0.55,
	},
	{
		"speaker": "COMMANDER YAO  [FINAL TRANSMISSION]",
		"text": "LISTEN TO ME! YOU ARE THE ONLY ONE WHO CAN FLY THIS SHIP!\nGET ON THE CONTROLS RIGHT NOW! SHOOT THEM DOWN! DODGE EVERYTHING!\nIF YOU DON'T... WE ALL DIE OUT HERE. EVERYONE. IS. COUNTING. ON. YOU.\nBRACE!!! FOR!!! IMPACT!!!",
		"rate": 1.7,
		"pitch": 0.92,
		"volume": 100,
		"shake_burst": 12.0,
		"rumble": 2.5,
		"typewriter_speed": 0.014,
		"flash_alpha": 0.7,
		"flash_pulse": true,
		"warning_color": Color(1, 0.05, 0.02, 1),
		"bubble_border_color": Color(1, 0.15, 0.1, 0.9),
		"bg_darkness": 0.7,
	},
]

const PREFERRED_MALE_VOICES := [
	"daniel", "alex", "tom", "fred", "lee", "ralph",
	"rishi", "oliver", "aaron", "arthur",
]

@onready var speaker_label: Label = $DialogueArea/BubblePanel/MarginContainer/VBox/SpeakerLabel
@onready var text_label: RichTextLabel = $DialogueArea/BubblePanel/MarginContainer/VBox/TextLabel
@onready var hint_label: Label = $HintArea/HintLabel
@onready var portrait_texture: TextureRect = $DialogueArea/PortraitFrame/PortraitTexture
@onready var portrait_frame: PanelContainer = $DialogueArea/PortraitFrame
@onready var bubble_panel: PanelContainer = $DialogueArea/BubblePanel
@onready var warning_label: Label = $TopBar/HBox/WarningLabel
@onready var alert_overlay: ColorRect = $AlertFlash
@onready var scanline_rect: ColorRect = $Scanlines
@onready var page_indicator: Label = $DialogueArea/BubblePanel/MarginContainer/VBox/PageIndicator
@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var status_label: Label = $StatusLabel
@onready var top_bar: PanelContainer = $TopBar
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var alarm_sfx: AudioStreamPlayer = $AlarmSFX

var tts_voice_id: String = ""
var current_index: int = 0
var is_typing: bool = false
var full_text: String = ""
var visible_chars: int = 0
var type_timer: float = 0.0
var current_typewriter_speed: float = 0.028
var waiting_for_input: bool = false
var _warning_flash_time: float = 0.0
var _alert_flash_alpha: float = 0.0
var _alert_pulsing: bool = false
var _hint_blink_time: float = 0.0
var _shake_intensity: float = 0.0
var _original_position: Vector2 = Vector2.ZERO
var _continuous_shake: float = 0.0
var _time: float = 0.0
var _portrait_shake: float = 0.0
var _portrait_original_pos: Vector2 = Vector2.ZERO
var _status_texts := [
	"COMMS CHANNEL OPEN  |  PRIORITY: CRITICAL  |  SIGNAL: UNSTABLE",
	"WARNING: HULL INTEGRITY COMPROMISED  |  SHIELDS: OFFLINE",
	"MAYDAY MAYDAY MAYDAY  |  ALL SYSTEMS FAILING  |  ABANDON HOPE",
]

func _ready() -> void:
	_original_position = position
	_find_male_voice()
	hint_label.visible = false
	alert_overlay.color = Color(1, 0.15, 0.1, 0)
	_portrait_original_pos = portrait_frame.position
	_show_dialogue(0)
	_trigger_shake(8.0)

func _find_male_voice() -> void:
	var en_voices := DisplayServer.tts_get_voices_for_language("en")
	if en_voices.size() == 0:
		return
	var all_voices := DisplayServer.tts_get_voices()
	for preferred in PREFERRED_MALE_VOICES:
		for v in all_voices:
			var vid: String = v.get("id", "")
			var vname: String = v.get("name", "")
			var vlang: String = v.get("language", "")
			if vlang.begins_with("en") and vname.to_lower().find(preferred) >= 0:
				tts_voice_id = vid
				return
	tts_voice_id = en_voices[0]

func _process(delta: float) -> void:
	_time += delta

	# --- WARNING LABEL: pulsing red, faster each dialogue ---
	var flash_speed := 4.0 + current_index * 3.0
	_warning_flash_time += delta * flash_speed
	var w_alpha := (sin(_warning_flash_time) + 1.0) / 2.0
	var w_color: Color = DIALOGUES[current_index]["warning_color"]
	warning_label.modulate = Color(w_color.r, w_color.g, w_color.b, 0.4 + w_alpha * 0.6)
	# Scale warning text slightly on pulse.
	var w_scale := 1.0 + w_alpha * 0.03 * (1 + current_index)
	warning_label.scale = Vector2(w_scale, w_scale)

	# --- RED ALERT OVERLAY ---
	if _alert_pulsing:
		# Continuous pulsing red — like emergency lights.
		var pulse_speed := 5.0 + current_index * 2.0
		var pulse := (sin(_time * pulse_speed) + 1.0) / 2.0
		var base_alpha := 0.05 + current_index * 0.06
		var pulse_alpha := base_alpha + pulse * (0.12 + current_index * 0.08)
		alert_overlay.color = Color(1, 0.08, 0.05, max(pulse_alpha, _alert_flash_alpha))
		if _alert_flash_alpha > 0:
			_alert_flash_alpha = max(_alert_flash_alpha - delta * 1.2, 0.0)
	elif _alert_flash_alpha > 0:
		_alert_flash_alpha = max(_alert_flash_alpha - delta * 1.5, 0.0)
		alert_overlay.color = Color(1, 0.15, 0.1, _alert_flash_alpha)
	else:
		alert_overlay.color = Color(1, 0.15, 0.1, 0)

	# --- HINT BLINK ---
	if hint_label.visible:
		_hint_blink_time += delta * 3.0
		hint_label.modulate = Color(1, 1, 1, 0.35 + (sin(_hint_blink_time) + 1.0) * 0.32)

	# --- SCREEN SHAKE: burst + persistent rumble ---
	var total_shake := _shake_intensity + _continuous_shake
	if total_shake > 0.1:
		if _shake_intensity > 0:
			_shake_intensity = max(_shake_intensity - delta * 5.0, 0.0)
		position = _original_position + Vector2(
			randf_range(-total_shake, total_shake),
			randf_range(-total_shake, total_shake)
		)
	else:
		position = _original_position

	# --- PORTRAIT SHAKE (independent from screen) ---
	if _portrait_shake > 0:
		_portrait_shake = max(_portrait_shake - delta * 4.0, 0.0)
		portrait_frame.position = _portrait_original_pos + Vector2(
			randf_range(-_portrait_shake, _portrait_shake),
			randf_range(-_portrait_shake, _portrait_shake)
		)
	# Portrait border color pulse — red on later dialogues.
	if current_index >= 1:
		var p_pulse := (sin(_time * 6.0) + 1.0) / 2.0
		var border_style: StyleBoxFlat = portrait_frame.get_theme_stylebox("panel").duplicate()
		var base_c := Color(0.29, 0.76, 1, 0.7)
		var alarm_c := Color(1, 0.2, 0.1, 0.9)
		border_style.border_color = base_c.lerp(alarm_c, p_pulse * (current_index * 0.5))
		portrait_frame.add_theme_stylebox_override("panel", border_style)

	# --- STATUS LABEL GLITCH ---
	if current_index >= 1 and fmod(_time, 0.15) < delta:
		if randf() < 0.3:
			var glitch_chars := "!@#$%^&*><{}|/"
			var glitched := ""
			var base_text: String = _status_texts[min(current_index, _status_texts.size() - 1)]
			for i in base_text.length():
				if randf() < 0.15 * current_index:
					glitched += glitch_chars[randi() % glitch_chars.length()]
				else:
					glitched += base_text[i]
			status_label.text = glitched
		else:
			status_label.text = _status_texts[min(current_index, _status_texts.size() - 1)]

	# --- MUSIC VOLUME ESCALATION ---
	var target_vol := -10.0 + current_index * 4.0
	music_player.volume_db = lerp(music_player.volume_db, target_vol, delta * 2.0)

	# --- TYPEWRITER ---
	if is_typing:
		type_timer += delta
		while type_timer >= current_typewriter_speed and visible_chars < full_text.length():
			type_timer -= current_typewriter_speed
			visible_chars += 1
			text_label.visible_characters = visible_chars
			# On exclamation marks / periods — micro-shake.
			if visible_chars > 0:
				var ch := full_text[visible_chars - 1]
				if ch == "!" or ch == "?":
					_trigger_shake(1.5 + current_index * 0.5)
		if visible_chars >= full_text.length():
			_finish_typing()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if is_typing:
		visible_chars = full_text.length()
		text_label.visible_characters = visible_chars
		_finish_typing()
	elif waiting_for_input:
		waiting_for_input = false
		hint_label.visible = false
		DisplayServer.tts_stop()
		current_index += 1
		if current_index < DIALOGUES.size():
			_show_dialogue(current_index)
		else:
			_start_gameplay()

func _finish_typing() -> void:
	is_typing = false
	waiting_for_input = true
	hint_label.visible = true
	_hint_blink_time = 0.0
	# Big shake when dialogue finishes to punctuate.
	_trigger_shake(4.0 + current_index * 3.0)
	if current_index < DIALOGUES.size() - 1:
		hint_label.text = "[ Press SPACE or ENTER to continue ]"
	else:
		hint_label.text = "[ ! ! !  PRESS SPACE OR ENTER TO LAUNCH  ! ! ! ]"

func _show_dialogue(index: int) -> void:
	var d: Dictionary = DIALOGUES[index]
	speaker_label.text = d["speaker"]
	full_text = d["text"]
	text_label.text = full_text
	text_label.visible_characters = 0
	visible_chars = 0
	type_timer = 0.0
	current_typewriter_speed = d["typewriter_speed"]
	is_typing = true
	waiting_for_input = false
	page_indicator.text = "%d / %d" % [index + 1, DIALOGUES.size()]

	# Update status bar text.
	status_label.text = _status_texts[min(index, _status_texts.size() - 1)]

	# Escalating continuous rumble.
	_continuous_shake = d["rumble"]

	# Burst shake.
	_trigger_shake(d["shake_burst"])

	# Portrait shake.
	_portrait_shake = d["shake_burst"] * 0.6

	# Red alert flash + pulse mode.
	_alert_flash_alpha = d["flash_alpha"]
	_alert_pulsing = d["flash_pulse"]

	# Darken background progressively — tunnel vision.
	if dark_overlay:
		var tween := create_tween()
		tween.tween_property(dark_overlay, "color", Color(0, 0, 0, d["bg_darkness"]), 0.5)

	# Bubble border color shift — from calm blue to alarm red.
	var bubble_style: StyleBoxFlat = bubble_panel.get_theme_stylebox("panel").duplicate()
	bubble_style.border_color = d["bubble_border_color"]
	bubble_panel.add_theme_stylebox_override("panel", bubble_style)

	# Speaker label turns red on last dialogue.
	if index == DIALOGUES.size() - 1:
		speaker_label.add_theme_color_override("font_color", Color(1, 0.25, 0.15, 1))

	# Speak with escalating intensity.
	_speak(full_text, int(d["volume"]), d["pitch"], d["rate"])

func _speak(text: String, volume: int, pitch: float, rate: float) -> void:
	DisplayServer.tts_stop()
	if tts_voice_id == "":
		return
	var clean := text.replace("\n", " ")
	DisplayServer.tts_speak(clean, tts_voice_id, volume, pitch, rate)

func _trigger_shake(intensity: float) -> void:
	_shake_intensity = max(_shake_intensity, intensity)

func _start_gameplay() -> void:
	DisplayServer.tts_stop()
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")

func _exit_tree() -> void:
	DisplayServer.tts_stop()
