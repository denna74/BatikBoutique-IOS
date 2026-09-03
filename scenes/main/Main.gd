extends Control

const BoardScene := preload("res://scenes/board/Board.tscn")
const TrayScene := preload("res://scenes/tray/Tray.tscn")
const ResultPopupScene := preload("res://scenes/main/ResultPopup.tscn")
const NewBatikPopupScene := preload("res://scenes/main/NewBatikPopup.tscn")
const PausePopupScene := preload("res://scenes/main/PausePopup.tscn")
const ConfirmationPopupScene := preload("res://scenes/confirmation/ConfirmationPopup.tscn")

@onready var board: GameBoard = $Board
@onready var tray: TileTray = $Tray
@onready var level_label: Label = $Header/LevelLabel
@onready var time_label: Label = $Header/TimeLabel
@onready var pause_button: TextureButton = $Header/PauseButton
@onready var undo_button: TextureButton = $HelperBar/HBox/UndoButton
@onready var shuffle_button: TextureButton = $HelperBar/HBox/ShuffleButton
@onready var remove3_button: TextureButton = $HelperBar/HBox/Remove3Button
@onready var extra_button: TextureButton = $HelperBar/HBox/ExtraSlotButton
@onready var undo_count_label: Label = $HelperBar/HBox/UndoButton/StockLabel
@onready var shuffle_count_label: Label = $HelperBar/HBox/ShuffleButton/StockLabel
@onready var remove3_count_label: Label = $HelperBar/HBox/Remove3Button/StockLabel
@onready var extra_count_label: Label = $HelperBar/HBox/ExtraSlotButton/StockLabel

var current_level: int = 1
var time_left := 0.0
var running := false
var result_shown := false
var _board_empty := false
var _matches := 0
var _matched_types: Dictionary = {}
var helpers := {"undo": 0, "shuffle": 0, "remove3": 0, "extra": 0}
var extra_used_this_game := false
var _sfx_players: Node
var _result_popup: Control
var _confirmation_popup: Control
var _mood_hearts: Array = []

func _ready():
	_setup_sfx()
	_setup_mood_hearts()
	_setup_skill_buttons()
	board.tile_tapped.connect(_on_tile_tapped)
	board.board_cleared.connect(_on_board_cleared)
	tray.tray_changed.connect(_on_tray_changed)
	tray.matched.connect(_on_matched)
	pause_button.pressed.connect(_toggle_pause)
	undo_button.pressed.connect(_on_undo_pressed)
	shuffle_button.pressed.connect(_on_shuffle_pressed)
	remove3_button.pressed.connect(_on_remove3_pressed)
	extra_button.pressed.connect(_on_extra_pressed)
	TranslationManager.language_changed.connect(_on_language_changed)
	SaveManager.mood_changed.connect(_refresh_mood_hearts)
	_on_language_changed(TranslationManager.current_language)
	_refresh_mood_hearts()
	start_level(SceneManager.target_level)

func _setup_mood_hearts():
	var hbox := HBoxContainer.new()
	hbox.name = "MoodHearts"
	hbox.offset_left = 280
	hbox.offset_top = 20
	hbox.offset_bottom = 60
	hbox.add_theme_constant_override("separation", 4)
	$Header.add_child(hbox)
	var heart_texture := load("res://assets/buttons/heart.png")
	for i in range(3):
		var heart := TextureRect.new()
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.custom_minimum_size = Vector2(36, 36)
		heart.texture = heart_texture
		heart.name = "Heart" + str(i)
		hbox.add_child(heart)
		_mood_hearts.append(heart)

func _refresh_mood_hearts(_new_mood: int = -1):
	var heart_texture := load("res://assets/buttons/heart.png")
	var heart_lost_texture := load("res://assets/buttons/heart_lost.png")
	for i in range(_mood_hearts.size()):
		var heart: TextureRect = _mood_hearts[i]
		if i < SaveManager.mood_level:
			heart.texture = heart_texture
		else:
			heart.texture = heart_lost_texture

func _setup_skill_buttons():
	var square_tex := preload("res://assets/buttons/square_small.png")
	var buttons := [
		[undo_button, "undo"],
		[shuffle_button, "shuffle"],
		[remove3_button, "remove3"],
		[extra_button, "extra"],
	]
	for pair in buttons:
		var btn: TextureButton = pair[0]
		var skill: String = pair[1]
		btn.texture_normal = square_tex
		var icon := TextureRect.new()
		icon.texture = load(SaveManager.SKILL_CONFIG[skill]["icon"])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.offset_left = -16
		icon.offset_top = -16
		icon.offset_right = 16
		icon.offset_bottom = 16
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)

func _setup_sfx():
	var sounds := {
		"Click": preload("res://assets/audio/choose.ogg"),
		"Error": preload("res://assets/audio/error_001.ogg"),
		"Match": preload("res://assets/audio/match.ogg"),
		"Win": preload("res://assets/audio/win.ogg"),
		"Lose": preload("res://assets/audio/lose.ogg"),
		"Shuffle": preload("res://assets/audio/switch_004.ogg"),
		"Remove": preload("res://assets/audio/select_001.ogg"),
	}
	_sfx_players = Node.new()
	add_child(_sfx_players)
	for name in sounds:
		var player := AudioStreamPlayer.new()
		player.stream = sounds[name]
		player.bus = &"SFX"
		player.name = name + "Sound"
		_sfx_players.add_child(player)

func _play_sfx(sound_name: String) -> void:
	var node := _sfx_players.get_node(sound_name + "Sound") as AudioStreamPlayer
	if node:
		if node.playing:
			node.stop()
		node.play()
		await node.finished

func _on_language_changed(_lang: String):
	level_label.text = TranslationManager.tf("level", [current_level])

func start_level(level: int):
	if _result_popup:
		_result_popup.queue_free()
		_result_popup = null
	current_level = level
	var combination: Array
	if SceneManager.active_tiles.size() == LevelData.types_in_play(level):
		combination = SceneManager.active_tiles.duplicate()
	else:
		combination = SceneManager.default_combination(level)
	SceneManager.active_tiles = combination
	board.setup(level, combination)
	tray.setup()
	helpers = {
		"undo": SaveManager.get_skill_stock("undo"),
		"shuffle": SaveManager.get_skill_stock("shuffle"),
		"remove3": SaveManager.get_skill_stock("remove3"),
		"extra": SaveManager.get_skill_stock("extra"),
	}
	extra_used_this_game = false
	_refresh_helper_counts()
	time_left = LevelData.time_limit(level)
	running = true
	result_shown = false
	_board_empty = false
	_matches = 0
	_matched_types = {}
	board.set_blocked(false)
	SaveManager.on_gameplay_start()
	MusicManager.play_gameplay()
	_on_language_changed(TranslationManager.current_language)

func _process(delta: float):
	if not running or result_shown:
		return
	time_left = maxf(time_left - delta, 0.0)
	time_label.text = "%s: %d" % [TranslationManager.t("time_label"), int(ceil(time_left))]
	if time_left <= 0.0:
		_lose()

func _on_tile_tapped(entry: Dictionary):
	if not running or result_shown:
		return
	if not tray.can_add(entry.type):
		_play_sfx("Error")
		_shake_tray()
		return
	_play_sfx("Click")
	board.set_blocked(true)
	var tw := tray.fly_and_place(entry, board)
	if tw:
		await tw.finished
	board.set_blocked(false)

func _shake_tray():
	var orig := tray.position
	var tw := create_tween()
	tw.tween_property(tray, "position", orig + Vector2(10, 0), 0.05)
	tw.tween_property(tray, "position", orig - Vector2(10, 0), 0.05)
	tw.tween_property(tray, "position", orig + Vector2(6, 0), 0.05)
	tw.tween_property(tray, "position", orig - Vector2(6, 0), 0.05)
	tw.tween_property(tray, "position", orig, 0.05)

func _on_board_cleared():
	_board_empty = true

func _on_matched(type: int):
	_play_sfx("Match")
	_matches += 1
	_matched_types[type] = int(_matched_types.get(type, 0)) + 1
	if _board_empty and not result_shown:
		_win()

func _on_tray_changed():
	if running and not result_shown and tray.is_full() and not tray.pending_match and board.remaining_count() > 0:
		_lose()

func _win():
	running = false
	result_shown = true
	board.set_blocked(true)
	var limit := LevelData.time_limit(current_level)
	var frac := time_left / limit if limit > 0.0 else 0.0
	var stars := 1
	if frac >= 0.5:
		stars = 3
	elif frac >= 0.25:
		stars = 2
	_play_sfx("Win")
	for t in _matched_types:
		SaveManager.add_tile_fabric(int(t), _matched_types[t])
	var old_max := SaveManager.max_level
	SaveManager.complete_level(current_level, stars)
	SaveManager.on_gameplay_end()
	if _unlocks_new_batik(old_max):
		_show_new_batik_popup(stars)
	else:
		_show_result_popup(stars)

func _unlocks_new_batik(old_max: int) -> bool:
	if current_level < old_max:
		return false
	return LevelData.types_in_play(current_level + 1) > LevelData.types_in_play(current_level)

func _show_new_batik_popup(stars: int):
	var popup := NewBatikPopupScene.instantiate()
	popup.z_index = 2000
	add_child(popup)
	popup.show_unlock(LevelData.types_in_play(current_level + 1) - 1)
	popup.ok_pressed.connect(_show_result_popup.bind(stars))
	popup.ok_pressed.connect(popup.queue_free)

func _show_result_popup(stars: int):
	var popup := ResultPopupScene.instantiate()
	popup.z_index = 2000
	add_child(popup)
	_result_popup = popup
	popup.show_win(current_level, stars, time_left, _matches, _matched_types)
	popup.retry_pressed.connect(_on_retry_pressed)
	popup.next_pressed.connect(_on_next_pressed)
	popup.exit_pressed.connect(_on_exit_pressed)

func _lose():
	running = false
	result_shown = true
	board.set_blocked(true)
	MusicManager.stop()
	_play_sfx("Lose")
	SaveManager.on_gameplay_end()
	SaveManager.lose_mood()
	var popup := ResultPopupScene.instantiate()
	popup.z_index = 2000
	add_child(popup)
	_result_popup = popup
	popup.show_lose(current_level)
	popup.retry_pressed.connect(_on_retry_pressed)
	popup.next_pressed.connect(_on_next_pressed)
	popup.exit_pressed.connect(_on_exit_pressed)

func _on_retry_pressed():
	_open_confirmation(current_level)

func _on_next_pressed():
	_open_confirmation(current_level + 1)

func _open_confirmation(level: int):
	if is_instance_valid(_confirmation_popup):
		_confirmation_popup.queue_free()
		_confirmation_popup = null
	if _result_popup:
		_result_popup.queue_free()
		_result_popup = null
	var popup: Control = ConfirmationPopupScene.instantiate()
	popup.z_index = 2000
	add_child(popup)
	_confirmation_popup = popup
	popup.confirmed.connect(_on_confirmation_confirmed)
	popup.cancelled.connect(_on_confirmation_cancelled)
	popup.open(level)

func _on_confirmation_confirmed(level: int, combination: Array):
	if is_instance_valid(_confirmation_popup):
		_confirmation_popup.queue_free()
		_confirmation_popup = null
	SceneManager.set_combination_for_level(level, combination)
	SceneManager.active_tiles = combination.duplicate()
	SceneManager.go_to_gameplay(level)

func _on_confirmation_cancelled():
	if is_instance_valid(_confirmation_popup):
		_confirmation_popup.queue_free()
		_confirmation_popup = null
	SceneManager.active_tiles = []
	SceneManager.return_to_track = true
	SceneManager.go_to_level_track()

func _on_exit_pressed():
	SceneManager.active_tiles = []
	SceneManager.return_to_track = true
	SceneManager.go_to_level_track()

func _on_undo_pressed():
	SfxManager.play_click()
	if not running or result_shown:
		return
	if helpers.undo <= 0:
		_play_sfx("Error")
		return
	if tray.undo_last():
		helpers.undo -= 1
		SaveManager.use_skill("undo")
		_refresh_helper_counts()
		_play_sfx("Click")

func _on_shuffle_pressed():
	SfxManager.play_click()
	if not running or result_shown:
		return
	if helpers.shuffle <= 0:
		_play_sfx("Error")
		return
	helpers.shuffle -= 1
	SaveManager.use_skill("shuffle")
	_refresh_helper_counts()
	_play_sfx("Shuffle")
	board.do_shuffle(current_level)

func _on_remove3_pressed():
	SfxManager.play_click()
	if not running or result_shown:
		return
	if helpers.remove3 <= 0:
		_play_sfx("Error")
		return
	helpers.remove3 -= 1
	SaveManager.use_skill("remove3")
	_refresh_helper_counts()
	_play_sfx("Remove")
	board.set_blocked(true)
	await board.remove_triple()
	board.set_blocked(false)
	if board.remaining_count() == 0 and not result_shown:
		_win()

func _on_extra_pressed():
	SfxManager.play_click()
	if not running or result_shown:
		return
	if helpers.extra <= 0 or extra_used_this_game:
		_play_sfx("Error")
		return
	if tray.capacity >= tray.MAX_SLOTS:
		_play_sfx("Error")
		return
	helpers.extra -= 1
	extra_used_this_game = true
	SaveManager.use_skill("extra")
	_refresh_helper_counts()
	_play_sfx("Click")
	tray.expand_capacity()

func _refresh_helper_counts():
	undo_count_label.text = str(helpers.undo)
	shuffle_count_label.text = str(helpers.shuffle)
	remove3_count_label.text = str(helpers.remove3)
	extra_count_label.text = str(helpers.extra)
	_set_skill_enabled(undo_button, helpers.undo > 0)
	_set_skill_enabled(shuffle_button, helpers.shuffle > 0)
	_set_skill_enabled(remove3_button, helpers.remove3 > 0)
	_set_skill_enabled(extra_button, helpers.extra > 0 and not extra_used_this_game)

func _set_skill_enabled(btn: TextureButton, enabled: bool):
	btn.disabled = not enabled
	btn.modulate.a = 1.0 if enabled else 0.4

func _toggle_pause():
	if result_shown:
		return
	SfxManager.play_click()
	var p := not get_tree().paused
	get_tree().paused = p
	pause_button.disabled = p
	board.set_blocked(p)
	if p:
		var popup := PausePopupScene.instantiate()
		popup.z_index = 2000
		popup.name = "ActivePausePopup"
		add_child(popup)
		popup.visible = true
		popup.continue_pressed.connect(_on_pause_continue)
		popup.exit_pressed.connect(_on_pause_exit)

func _on_pause_continue():
	_toggle_pause()
	var popup := get_node_or_null("ActivePausePopup")
	if popup:
		popup.queue_free()

func _on_pause_exit():
	_toggle_pause()
	if running and not result_shown:
		SaveManager.on_gameplay_end()
		SaveManager.lose_mood()
	SceneManager.active_tiles = []
	SceneManager.return_to_track = true
	SceneManager.go_to_level_track()

func _notification(what: int):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if running and not result_shown:
			SaveManager.on_gameplay_end()
			SaveManager.lose_mood()

var _last_back_ms := -10000

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		_handle_back_request()

func _handle_back_request():
	var now := Time.get_ticks_msec()
	if now - _last_back_ms < 150:
		return
	_last_back_ms = now
	if result_shown:
		return
	if get_tree().paused:
		_on_pause_continue()
	else:
		_toggle_pause()

func _exit_tree():
	if get_tree().paused:
		get_tree().paused = false
