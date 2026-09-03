extends Node

const MAIN_BGM := preload("res://assets/audio/bgm_main.mp3")
const GAMEPLAY_BGM := preload("res://assets/audio/bgm_gameplay.mp3")
const GALLERY_BGM := preload("res://assets/audio/bgm_gallery.mp3")
const BOUTIQUE_BGM := preload("res://assets/audio/bgm_boutique.mp3")

const FADE_DURATION := 0.5
const MAX_LEVEL := 4

signal bgm_changed

var bgm_level: int = MAX_LEVEL

var _main_player: AudioStreamPlayer
var _gameplay_player: AudioStreamPlayer
var _gallery_player: AudioStreamPlayer
var _boutique_player: AudioStreamPlayer
var _active: AudioStreamPlayer
var _fade_tween: Tween

func _ready():
	load_bgm_setting()
	_apply_bgm_level()
	_main_player = _make_player(MAIN_BGM, _loop_main)
	_gameplay_player = _make_player(GAMEPLAY_BGM, _loop_gameplay)
	_gallery_player = _make_player(GALLERY_BGM, _loop_gallery)
	_boutique_player = _make_player(BOUTIQUE_BGM, _loop_boutique)

func _make_player(stream: AudioStream, loop_fn: Callable) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Music"
	player.finished.connect(loop_fn)
	add_child(player)
	return player

func _apply_bgm_level():
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, bgm_level <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(float(bgm_level) / float(MAX_LEVEL)))

func _crossfade(new_track: AudioStreamPlayer):
	if _active == new_track:
		return
	var old_track := _active
	_active = new_track
	if bgm_level <= 0:
		if old_track:
			old_track.stop()
		return
	new_track.volume_db = -40.0
	new_track.play()
	_fade_tween = create_tween().set_parallel(true)
	if old_track and old_track.playing:
		_fade_tween.tween_property(old_track, "volume_db", -40.0, FADE_DURATION)
	_fade_tween.tween_property(new_track, "volume_db", 0.0, FADE_DURATION)
	await _fade_tween.finished
	if old_track and old_track.playing:
		old_track.stop()

func play_main():
	_crossfade(_main_player)

func play_gameplay():
	_active = _gameplay_player
	if bgm_level <= 0:
		_gameplay_player.stop()
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_main_player.stop()
	_gallery_player.stop()
	_boutique_player.stop()
	_gameplay_player.volume_db = 0.0
	_gameplay_player.play()

func play_gallery():
	_crossfade(_gallery_player)

func play_boutique():
	_crossfade(_boutique_player)

func stop():
	_main_player.stop()
	_gameplay_player.stop()
	_gallery_player.stop()
	_boutique_player.stop()

func _loop_main():
	if bgm_level <= 0:
		return
	_main_player.play()

func _loop_gameplay():
	if bgm_level <= 0:
		return
	_gameplay_player.play()

func _loop_gallery():
	if bgm_level <= 0:
		return
	_gallery_player.play()

func _loop_boutique():
	if bgm_level <= 0:
		return
	_boutique_player.play()

func load_bgm_setting():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		if config.has_section_key("settings", "bgm_level"):
			bgm_level = clampi(config.get_value("settings", "bgm_level", MAX_LEVEL), 0, MAX_LEVEL)
		else:
			var legacy_enabled: bool = config.get_value("settings", "bgm_enabled", true)
			bgm_level = MAX_LEVEL if legacy_enabled else 0

func save_bgm_setting():
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("settings", "bgm_level", bgm_level)
	config.save("user://settings.cfg")

func set_bgm_level(level: int):
	level = clampi(level, 0, MAX_LEVEL)
	if bgm_level == level:
		return
	bgm_level = level
	_apply_bgm_level()
	save_bgm_setting()
	if bgm_level > 0:
		if _active and not _active.playing:
			_active.play()
	else:
		stop()
	bgm_changed.emit()
