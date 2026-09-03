extends Control

const MAIN_SCENE := "res://scenes/main/Main.tscn"

@onready var label: Label = $Center/VBox/Label
@onready var progress: ProgressBar = $Center/VBox/ProgressBar

func _ready():
	MusicManager.stop()
	var types: Array = SceneManager.active_tiles.duplicate()
	if types.is_empty():
		types = SceneManager.default_combination(SceneManager.target_level)
	label.text = TranslationManager.t("loading")
	progress.max_value = maxi(types.size(), 1)
	var done := 0
	var start_time := Time.get_ticks_msec()
	for t in types:
		TileArt.get_texture(int(t))
		done += 1
		progress.value = done
		await get_tree().process_frame
	var elapsed := Time.get_ticks_msec() - start_time
	var remaining := maxi(1000 - int(elapsed), 0)
	if remaining > 0:
		await get_tree().create_timer(remaining / 1000.0).timeout
	get_tree().change_scene_to_file(MAIN_SCENE)
