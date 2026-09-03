extends Control

signal ok_pressed()

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var tile_image: TextureRect = $Panel/Margin/VBox/TileImage
@onready var body_label: Label = $Panel/Margin/VBox/Body
@onready var motif_name_label: Label = $Panel/Margin/VBox/MotifName
@onready var ok_button: Button = $Panel/Margin/VBox/OkButton

func _ready():
	visible = false
	TranslationManager.language_changed.connect(_on_language_changed)
	_update_texts()
	ok_button.pressed.connect(SfxManager.play_click)
	ok_button.pressed.connect(func(): ok_pressed.emit())

func _on_language_changed(_lang: String):
	_update_texts()

func _update_texts():
	title_label.text = TranslationManager.t("new_batik_title")
	body_label.text = TranslationManager.t("new_batik_body")
	ok_button.text = TranslationManager.t("ok")

func show_unlock(tile_id: int):
	tile_image.texture = TileArt.get_texture(tile_id)
	motif_name_label.text = TileDatabase.get_catalog_name(tile_id, TranslationManager.current_language)
	visible = true
