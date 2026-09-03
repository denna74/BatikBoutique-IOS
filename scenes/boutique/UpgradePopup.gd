extends Control

signal upgraded(slot_index: int)
signal cancelled()

const GOLD := preload("res://assets/buttons/gold_medium.png")
const OLD_SEWING_TEX := preload("res://assets/workshop/old_sewing.png")
const MODERN_SEWING_TEX := preload("res://assets/workshop/modern_sewing.png")
const MACHINE_ICONS := {1: OLD_SEWING_TEX, 2: MODERN_SEWING_TEX}

@onready var dim: ColorRect = $Dim
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var current_label: Label = $Panel/Margin/VBox/CurrentLabel
@onready var options_box: VBoxContainer = $Panel/Margin/VBox/Options
@onready var cancel_button: Button = $Panel/Margin/VBox/Buttons/CancelButton

var _slot_index := -1

func _ready():
	visible = false
	TranslationManager.language_changed.connect(_update_texts)
	cancel_button.pressed.connect(_on_cancel_pressed)
	dim.gui_input.connect(_on_dim_input)
	_update_texts()

func open(slot_index: int):
	_slot_index = slot_index
	_rebuild_options()
	_update_texts()
	visible = true

func _rebuild_options():
	for child in options_box.get_children():
		child.queue_free()
	var options := BoutiqueManager.upgrade_options(_slot_index)
	if options.is_empty():
		var max_label := Label.new()
		max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		max_label.add_theme_font_size_override("font_size", 15)
		max_label.add_theme_color_override("font_color", Color.BLACK)
		max_label.text = TranslationManager.t("max_upgrade")
		max_label.set_meta("max", true)
		options_box.add_child(max_label)
		return
	for opt in options:
		var tier := int(opt.tier)
		var btn := _make_option_row(tier, int(opt.cost))
		btn.set_meta("tier", tier)
		btn.set_meta("name_label", btn.get_node("HBox/Info/NameLabel"))
		btn.set_meta("cost_label", btn.get_node("HBox/Info/CostLabel"))
		options_box.add_child(btn)

func _make_option_row(tier: int, cost: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(290, 56)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_option_button(btn)
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)
	var icon := TextureRect.new()
	icon.texture = MACHINE_ICONS.get(tier)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)
	var info := VBoxContainer.new()
	info.name = "Info"
	info.add_theme_constant_override("separation", 2)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info)
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = BoutiqueManager.machine_name(tier)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.BLACK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = _format_cost(cost)
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.4, 0.3, 0.1))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(cost_label)
	btn.disabled = SaveManager.coins < cost
	if btn.disabled:
		hbox.modulate = Color(0.5, 0.5, 0.5, 0.7)
	btn.pressed.connect(_on_option_pressed.bind(tier))
	btn.draw.connect(func():
		hbox.position.x = (btn.size.x - hbox.size.x) / 2.0
		hbox.position.y = (btn.size.y - hbox.size.y) / 2.0
	, CONNECT_ONE_SHOT)
	return btn

func _format_cost(cost: int) -> String:
	return "%d %s" % [cost, TranslationManager.t("coins")]

func _style_option_button(btn: Button):
	var sb := StyleBoxTexture.new()
	sb.texture = GOLD
	sb.content_margin_left = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_color_override("font_focus_color", Color.BLACK)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)

func _on_option_pressed(target_tier: int):
	SfxManager.play_click()
	if BoutiqueManager.upgrade_slot(_slot_index, target_tier):
		upgraded.emit(_slot_index)
		queue_free()

func _on_cancel_pressed():
	SfxManager.play_click()
	cancelled.emit()
	queue_free()

func _on_dim_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_on_cancel_pressed()

func _update_texts(_lang: String = ""):
	title_label.text = TranslationManager.t("upgrade_title")
	current_label.text = TranslationManager.tf("current_machine", [BoutiqueManager.machine_name(BoutiqueManager.slot_upgrade(_slot_index))])
	cancel_button.text = TranslationManager.t("cancel")
	for child in options_box.get_children():
		if child.has_meta("tier"):
			var tier := int(child.get_meta("tier"))
			(child.get_meta("name_label") as Label).text = BoutiqueManager.machine_name(tier)
			(child.get_meta("cost_label") as Label).text = _format_cost(BoutiqueManager.UPGRADE_COSTS[tier])
		elif child.has_meta("max"):
			(child as Label).text = TranslationManager.t("max_upgrade")

func _notification(what: int):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_cancel_pressed()
