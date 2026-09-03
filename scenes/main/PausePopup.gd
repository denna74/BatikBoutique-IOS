extends Control

signal continue_pressed()
signal exit_pressed()

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var continue_button: Button = $Panel/Margin/VBox/Buttons/ContinueButton
@onready var exit_button: Button = $Panel/Margin/VBox/Buttons/ExitButton

func _ready():
	visible = false
	TranslationManager.language_changed.connect(_on_language_changed)
	_update_texts()
	continue_button.pressed.connect(SfxManager.play_click)
	continue_button.pressed.connect(func(): continue_pressed.emit())
	exit_button.pressed.connect(SfxManager.play_click)
	exit_button.pressed.connect(func(): exit_pressed.emit())

func _on_language_changed(_lang: String):
	_update_texts()

func _update_texts():
	title_label.text = TranslationManager.t("pause_title")
	continue_button.text = TranslationManager.t("continue_btn")
	exit_button.text = TranslationManager.t("exit_btn")
