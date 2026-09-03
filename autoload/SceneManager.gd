extends Node

var target_level: int = 1
var active_tiles: Array = []
var cold_start: bool = true
var return_to_track: bool = false
var fade_in_menu: bool = false

func go_to_gameplay(level: int):
	target_level = level
	get_tree().change_scene_to_file("res://scenes/main/Loading.tscn")

func go_to_level_track():
	get_tree().change_scene_to_file("res://scenes/menu/MenuLevelSelect.tscn")

func go_to_boutique():
	get_tree().change_scene_to_file("res://scenes/boutique/Boutique.tscn")

func go_to_gallery():
	get_tree().change_scene_to_file("res://scenes/gallery/Gallery.tscn")

func default_combination(level: int) -> Array:
	return LevelData.default_types(level)

func set_combination_for_level(level: int, combination: Array):
	target_level = level
	active_tiles = combination
