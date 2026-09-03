extends Control

const TileScene := preload("res://scenes/board/Tile.tscn")

signal retry_pressed()
signal next_pressed()
signal exit_pressed()

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var info_label: Label = $Panel/Margin/VBox/Info
@onready var stars_label: Label = $Panel/Margin/VBox/Stars
@onready var fabric_label: Label = $Panel/Margin/VBox/FabricLabel
@onready var preview_grid: GridContainer = $Panel/Margin/VBox/PreviewScroll/PreviewCenter/PreviewGrid
@onready var retry_button: Button = $Panel/Margin/VBox/Buttons/RetryButton
@onready var next_button: Button = $Panel/Margin/VBox/Buttons/NextButton
@onready var exit_button: Button = $Panel/Margin/VBox/Buttons/ExitButton

func _ready():
	visible = false
	TranslationManager.language_changed.connect(_on_language_changed)
	_update_texts()
	retry_button.pressed.connect(SfxManager.play_click)
	retry_button.pressed.connect(func(): retry_pressed.emit())
	next_button.pressed.connect(SfxManager.play_click)
	next_button.pressed.connect(func(): next_pressed.emit())
	exit_button.pressed.connect(SfxManager.play_click)
	exit_button.pressed.connect(func(): exit_pressed.emit())

func _on_language_changed(_lang: String):
	_update_texts()

func _update_texts():
	retry_button.text = TranslationManager.t("retry")
	next_button.text = TranslationManager.t("next_level")
	exit_button.text = TranslationManager.t("exit")

func show_win(level: int, stars: int, time_sec: float, fabric_earned: int, matched_types: Dictionary):
	title_label.text = TranslationManager.t("win_title")
	stars_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	var level_text := TranslationManager.tf("level", [level])
	info_label.text = "%s — %s: %.1fs" % [level_text, TranslationManager.t("time_label"), time_sec]
	fabric_label.text = TranslationManager.tf("fabric_earned", [fabric_earned])
	fabric_label.visible = true
	_build_preview(matched_types)
	preview_grid.visible = true
	next_button.visible = true
	retry_button.visible = true
	visible = true

func show_lose(level: int):
	title_label.text = TranslationManager.t("lose_title")
	stars_label.text = ""
	var level_text := TranslationManager.tf("level", [level])
	info_label.text = "%s  •  %s" % [level_text, TranslationManager.t("mood_lost")]
	fabric_label.visible = false
	preview_grid.visible = false
	next_button.visible = false
	retry_button.visible = SaveManager.mood_level > 0
	visible = true

func _build_preview(matched_types: Dictionary):
	for child in preview_grid.get_children():
		child.queue_free()
	for type in matched_types:
		var tile: BatikTile = TileScene.instantiate()
		preview_grid.add_child(tile)
		tile.setup(int(type), 56.0)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
