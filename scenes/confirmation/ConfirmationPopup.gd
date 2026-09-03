extends Control

signal confirmed(level: int, combination: Array)
signal cancelled()

const TileScene := preload("res://scenes/board/Tile.tscn")

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var hint_label: Label = $Panel/Margin/VBox/Hint
@onready var preview_grid: GridContainer = $Panel/Margin/VBox/PreviewScroll/PreviewCenter/PreviewGrid
@onready var ok_button: Button = $Panel/Margin/VBox/Buttons/OkButton
@onready var cancel_button: Button = $Panel/Margin/VBox/Buttons/CancelButton

var _current_level: int = 1
var _preview_tiles: Array = []

func _ready():
	visible = false
	TranslationManager.language_changed.connect(_update_texts)
	ok_button.pressed.connect(_on_ok_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	for btn in [ok_button, cancel_button]:
		_add_click_behavior(btn)

func _add_click_behavior(btn: Button) -> void:
	btn.pressed.connect(SfxManager.play_click)
	btn.button_down.connect(_on_button_down.bind(btn))
	btn.button_up.connect(_on_button_up.bind(btn))

func _on_button_down(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.scale = Vector2(0.95, 0.95)

func _on_button_up(btn: Button) -> void:
	btn.scale = Vector2.ONE

func open(level: int):
	_current_level = level
	_preview_tiles = SceneManager.default_combination(level)
	_build_preview()
	_update_texts()
	visible = true

func _build_preview():
	for child in preview_grid.get_children():
		child.queue_free()
	for type in _preview_tiles:
		var tile: BatikTile = TileScene.instantiate()
		preview_grid.add_child(tile)
		tile.setup(type, 56.0)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_ok_pressed():
	confirmed.emit(_current_level, _preview_tiles)

func _on_cancel_pressed():
	cancelled.emit()

func _update_texts(_lang: String = ""):
	title_label.text = TranslationManager.tf("play_level", [_current_level])
	hint_label.text = TranslationManager.t("combination_hint")
	ok_button.text = TranslationManager.t("ok")
	cancel_button.text = TranslationManager.t("cancel")
