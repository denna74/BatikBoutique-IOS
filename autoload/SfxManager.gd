extends Node

signal click_finished
signal sfx_changed

const CLICK := preload("res://assets/audio/click_001.ogg")
const COIN := preload("res://assets/audio/coin.wav")

const MAX_LEVEL := 4

var sfx_level: int = MAX_LEVEL

var _click_player: AudioStreamPlayer
var _coin_player: AudioStreamPlayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = CLICK
	_click_player.bus = &"SFX"
	_click_player.finished.connect(func(): click_finished.emit())
	add_child(_click_player)
	_coin_player = AudioStreamPlayer.new()
	_coin_player.stream = COIN
	_coin_player.bus = &"SFX"
	add_child(_coin_player)
	load_sfx_setting()
	_apply_sfx_level()

func _apply_sfx_level():
	var idx := AudioServer.get_bus_index("SFX")
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, sfx_level <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(float(sfx_level) / float(MAX_LEVEL)))

func load_sfx_setting():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		sfx_level = clampi(config.get_value("settings", "sfx_level", MAX_LEVEL), 0, MAX_LEVEL)

func save_sfx_setting():
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("settings", "sfx_level", sfx_level)
	config.save("user://settings.cfg")

func set_sfx_level(level: int):
	level = clampi(level, 0, MAX_LEVEL)
	if sfx_level == level:
		return
	sfx_level = level
	_apply_sfx_level()
	save_sfx_setting()
	sfx_changed.emit()

func play_click():
	if _click_player:
		_click_player.play()

func play_coin():
	if _coin_player:
		_coin_player.play()
