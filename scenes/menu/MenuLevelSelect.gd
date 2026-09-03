extends Control

const ConfirmationPopupScene := preload("res://scenes/confirmation/ConfirmationPopup.tscn")
const SettingsPopupScene := preload("res://scenes/menu/SettingsPopup.tscn")
const _SQUARE_TEX := preload("res://assets/buttons/square_large.png")
const _STAR_TEX := preload("res://assets/buttons/cute-star-small.png")
const _LOCK_TEX := preload("res://assets/buttons/cute_lock_small.png")
const _LEVEL_NUM_COLOR := Color(0.25, 0.16, 0.05)
const _LEVEL_GAP := 2.0
const _LEVEL_ALIGNMENT := BoxContainer.ALIGNMENT_CENTER
const _PLAYABLE_CONTENT_Y := 9.0
const _LATEST_CONTENT_Y := 0.0
const _LOCKED_CONTENT_Y := 6.0
const GOLD_SMALL := preload("res://assets/buttons/gold_small.png")

@onready var main_menu_view: Control = $MainMenuView
@onready var level_track_view: Control = $LevelTrackView
@onready var logo: TextureRect = $MainMenuView/Logo
@onready var settings_btn: Button = $MainMenuView/SettingsButton
@onready var settings_label: Label = $MainMenuView/SettingsButton/HBox/Label
@onready var boutique_btn: Button = $MainMenuView/BoutiqueButton
@onready var factory_btn: Button = $MainMenuView/FactoryButton
@onready var gallery_btn: Button = $MainMenuView/GalleryButton
@onready var back_btn: Button = $LevelTrackView/BackButton
@onready var level_scroll: ScrollContainer = $LevelTrackView/LevelScroll
@onready var level_grid: VBoxContainer = $LevelTrackView/LevelScroll/LevelGrid
@onready var track_bottom_hint: Label = $LevelTrackView/BottomHint
@onready var character: Node2D = $MainMenuView/Character

var _confirmation_popup: Control
var _settings_popup: Control
var _fade_rect: ColorRect
var _fading := false
var _track_hud_built := false
var _coin_label: Label
var _mood_hearts: Array = []
var _instant_mood_btn: TextureButton
var _instant_popup: Control
var _instant_watch_btn: TextureButton
var _buy_popup: Control
var _skill_buttons: Dictionary = {}

const _SKILL_ORDER := ["undo", "shuffle", "remove3", "extra"]
const _SKILL_NAME_KEYS := {"undo": "undo", "shuffle": "shuffle", "remove3": "remove_3", "extra": "extra_slot"}

func _ready():
	MusicManager.play_main()
	TranslationManager.language_changed.connect(_update_ui_texts)
	boutique_btn.pressed.connect(_on_boutique_pressed)
	factory_btn.pressed.connect(_on_factory_pressed)
	gallery_btn.pressed.connect(_on_gallery_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	SaveManager.coins_changed.connect(func(_v): _refresh_track_hud())
	SaveManager.mood_changed.connect(func(_m): _refresh_mood_display())
	SaveManager.skill_stock_changed.connect(func(_s, _n): _refresh_skill_buttons())
	AdsManager.mood_reward_earned.connect(_on_mood_reward_earned)
	AdsManager.mood_reward_failed.connect(_on_mood_reward_failed)
	for btn in [settings_btn, boutique_btn, factory_btn, gallery_btn, back_btn]:
		_add_click_behavior(btn)
	_setup_fade_overlay()
	if SceneManager.fade_in_menu:
		SceneManager.fade_in_menu = false
		if SceneManager.return_to_track:
			SceneManager.return_to_track = false
			show_level_track(false)
		else:
			show_main_menu(false)
		UiTransition.fade_in(0.2)
	elif SceneManager.return_to_track:
		SceneManager.return_to_track = false
		show_level_track()
	else:
		show_main_menu()

func _add_click_behavior(btn: BaseButton) -> void:
	btn.pressed.connect(SfxManager.play_click)
	btn.button_down.connect(_on_button_down.bind(btn))
	btn.button_up.connect(_on_button_up.bind(btn))

func _on_button_down(btn: BaseButton) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.scale = Vector2(0.95, 0.95)

func _on_button_up(btn: BaseButton) -> void:
	btn.scale = Vector2.ONE

func show_main_menu(fade := true):
	if not fade:
		level_track_view.visible = false
		main_menu_view.visible = true
		character.walk_in()
		_update_ui_texts()
		return
	_play_fade(func():
		level_track_view.visible = false
		main_menu_view.visible = true
		character.walk_in()
		_update_ui_texts()
	)

func show_level_track(fade := true):
	if not fade:
		main_menu_view.visible = false
		level_track_view.visible = true
		_update_ui_texts()
		_build_level_grid()
		_ensure_track_hud()
		_refresh_track_hud()
		return
	_play_fade(func():
		main_menu_view.visible = false
		level_track_view.visible = true
		_update_ui_texts()
		_build_level_grid()
		_ensure_track_hud()
		_refresh_track_hud()
	)

func _setup_fade_overlay():
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.visible = false
	add_child(_fade_rect)

func _play_fade(callback: Callable) -> void:
	if _fading:
		return
	_fading = true
	_fade_rect.visible = true
	_fade_rect.color = Color(0, 0, 0, 0)
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.18)
	tw.tween_callback(callback)
	tw.tween_property(_fade_rect, "color:a", 0.0, 0.25)
	tw.tween_callback(_finish_fade)

func _finish_fade():
	_fading = false
	_fade_rect.visible = false

func _on_factory_pressed():
	show_level_track()

func _on_boutique_pressed():
	await UiTransition.fade_out(0.2)
	if is_inside_tree():
		SceneManager.go_to_boutique()

func _on_gallery_pressed():
	await UiTransition.fade_out(0.2)
	if is_inside_tree():
		SceneManager.go_to_gallery()

func _on_back_pressed():
	show_main_menu()

func _on_settings_pressed():
	_close_settings_popup()
	var popup: Control = SettingsPopupScene.instantiate()
	add_child(popup)
	_settings_popup = popup

func _close_settings_popup():
	if is_instance_valid(_settings_popup):
		_settings_popup.queue_free()
	_settings_popup = null

func _update_ui_texts(_lang: String = ""):
	var t := TranslationManager
	settings_label.text = t.t("settings")
	boutique_btn.text = t.t("boutique")
	factory_btn.text = t.t("factory")
	gallery_btn.text = t.t("gallery")
	track_bottom_hint.text = t.t("menu_hint")
	back_btn.text = t.t("back")
	if _track_hud_built:
		_refresh_skill_buttons()
		if _instant_mood_btn and is_instance_valid(_instant_mood_btn):
			_instant_mood_btn.texture_normal = _instant_mood_texture()
		if _coin_label and is_instance_valid(_coin_label):
			_coin_label.text = str(SaveManager.coins)

func _instant_mood_texture() -> Texture2D:
	if TranslationManager.current_language == "id":
		return load("res://assets/instant/instant_mood_id.png")
	return load("res://assets/instant/instant_mood_en.png")

func _ensure_track_hud():
	if _track_hud_built:
		return
	level_scroll.offset_top = 90
	level_scroll.offset_bottom = -162

	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://assets/buttons/coin.png")
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.custom_minimum_size = Vector2(30, 30)
	coin_icon.position = Vector2(12, 2)
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_track_view.add_child(coin_icon)

	_coin_label = Label.new()
	_coin_label.position = Vector2(46, 10)
	_coin_label.add_theme_font_size_override("font_size", 20)
	_coin_label.text = str(SaveManager.coins)
	level_track_view.add_child(_coin_label)

	var hearts_row := HBoxContainer.new()
	hearts_row.position = Vector2(35, 40)
	hearts_row.add_theme_constant_override("separation", 4)
	hearts_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_track_view.add_child(hearts_row)
	var heart_tex := load("res://assets/buttons/heart.png")
	for i in range(3):
		var heart := TextureRect.new()
		heart.texture = heart_tex
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.custom_minimum_size = Vector2(32, 32)
		heart.name = "TrackHeart" + str(i)
		hearts_row.add_child(heart)
		_mood_hearts.append(heart)

	_instant_mood_btn = TextureButton.new()
	_instant_mood_btn.ignore_texture_size = true
	_instant_mood_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_instant_mood_btn.texture_normal = _instant_mood_texture()
	_instant_mood_btn.position = Vector2(200, 5)
	_instant_mood_btn.size = Vector2(80, 80)
	_instant_mood_btn.pressed.connect(_on_instant_mood_pressed)
	level_track_view.add_child(_instant_mood_btn)

	var skill_row := HBoxContainer.new()
	skill_row.position = Vector2(8, 723)
	skill_row.size = Vector2(464, 76)
	skill_row.add_theme_constant_override("separation", 0)
	level_track_view.add_child(skill_row)
	var square_tex := preload("res://assets/buttons/square_small.png")
	for skill in _SKILL_ORDER:
		var btn := TextureButton.new()
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.texture_normal = square_tex
		btn.custom_minimum_size = Vector2(58, 58)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_skill_buy.bind(skill))
		skill_row.add_child(btn)
		var icon_tex := load(SaveManager.SKILL_CONFIG[skill]["icon"])
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.offset_left = -20
		icon.offset_top = -20
		icon.offset_right = 20
		icon.offset_bottom = 20
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		var stock_label := Label.new()
		stock_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stock_label.offset_left = 2
		stock_label.offset_top = 0
		stock_label.offset_right = 30
		stock_label.offset_bottom = 16
		stock_label.add_theme_font_size_override("font_size", 11)
		stock_label.add_theme_color_override("font_color", Color.WHITE)
		stock_label.add_theme_color_override("font_outline_color", Color.BLACK)
		stock_label.add_theme_constant_override("outline_size", 3)
		stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(stock_label)
		_skill_buttons[skill] = {"button": btn, "stock_label": stock_label}

	_track_hud_built = true

func _refresh_track_hud():
	if not _track_hud_built:
		return
	if _coin_label and is_instance_valid(_coin_label):
		_coin_label.text = str(SaveManager.coins)
	_refresh_mood_display()
	_refresh_skill_buttons()

func _refresh_mood_display():
	if not _track_hud_built:
		return
	var heart_tex := load("res://assets/buttons/heart.png")
	var heart_lost_tex := load("res://assets/buttons/heart_lost.png")
	for i in range(_mood_hearts.size()):
		var heart: TextureRect = _mood_hearts[i]
		heart.texture = heart_tex if i < SaveManager.mood_level else heart_lost_tex
	if _instant_mood_btn and is_instance_valid(_instant_mood_btn):
		_instant_mood_btn.modulate = Color(0.5, 0.5, 0.5, 1) if SaveManager.mood_level >= 3 else Color.WHITE

func _refresh_skill_buttons():
	if not _track_hud_built:
		return
	for skill in _SKILL_ORDER:
		var refs: Dictionary = _skill_buttons[skill]
		var stock_label: Label = refs["stock_label"]
		stock_label.text = str(SaveManager.get_skill_stock(skill))

func _on_instant_mood_pressed():
	SfxManager.play_click()
	if SaveManager.mood_level >= 3:
		return
	_show_instant_mood_popup()

func _show_instant_mood_popup():
	_close_instant_popup()
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_instant_popup = overlay

	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(80, 300)
	panel.size = Vector2(320, 254)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(15, 14)
	vbox.size = Vector2(290, 226)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = TranslationManager.t("instant_moods_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = TranslationManager.t("instant_moods_desc")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	vbox.add_child(desc)

	var body_label := Label.new()
	body_label.text = ""
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(body_label)

	var watch_btn := TextureButton.new()
	watch_btn.ignore_texture_size = true
	watch_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	watch_btn.texture_normal = load("res://assets/buttons/watch_ads_id.png") if TranslationManager.current_language == "id" else load("res://assets/buttons/watch_ads_en.png")
	watch_btn.custom_minimum_size = Vector2(130, 40)
	watch_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_instant_watch_btn = watch_btn
	var watch_center := CenterContainer.new()
	watch_center.add_child(watch_btn)
	vbox.add_child(watch_center)

	var cancel_btn := Button.new()
	cancel_btn.text = TranslationManager.t("cancel")
	cancel_btn.custom_minimum_size = Vector2(100, 40)
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.add_theme_color_override("font_color", Color.BLACK)
	cancel_btn.add_theme_color_override("font_focus_color", Color.BLACK)
	cancel_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	cancel_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	var cancel_sb := StyleBoxTexture.new()
	cancel_sb.texture = GOLD_SMALL
	cancel_sb.content_margin_left = 2.0
	cancel_sb.content_margin_top = 2.0
	cancel_sb.content_margin_right = 2.0
	cancel_sb.content_margin_bottom = 2.0
	cancel_btn.add_theme_stylebox_override("normal", cancel_sb)
	cancel_btn.add_theme_stylebox_override("hover", cancel_sb)
	cancel_btn.add_theme_stylebox_override("pressed", cancel_sb)
	var cancel_center := CenterContainer.new()
	cancel_center.add_child(cancel_btn)
	vbox.add_child(cancel_center)

	cancel_btn.pressed.connect(func():
		SfxManager.play_click()
		_close_instant_popup()
	)
	watch_btn.pressed.connect(func():
		SfxManager.play_click()
		watch_btn.disabled = true
		AdsManager.start_mood_reward_flow(body_label)
	)

func _close_instant_popup():
	if is_instance_valid(_instant_popup):
		_instant_popup.queue_free()
	_instant_popup = null
	_instant_watch_btn = null

func _on_mood_reward_earned():
	_close_instant_popup()
	SaveManager.mood_level = clampi(SaveManager.mood_level + 1, 0, 3)
	SaveManager.mood_changed.emit(SaveManager.mood_level)
	SaveManager.save_game()
	_refresh_mood_display()

func _on_mood_reward_failed():
	if is_instance_valid(_instant_watch_btn):
		_instant_watch_btn.disabled = false

func _on_skill_buy(skill: String):
	SfxManager.play_click()
	_show_skill_buy_popup(skill)

func _show_skill_buy_popup(skill: String):
	_close_buy_popup()
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_buy_popup = overlay

	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(90, 300)
	panel.size = Vector2(300, 282)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(15, 14)
	vbox.size = Vector2(270, 254)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = TranslationManager.t("skill_buy_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var name_label := Label.new()
	name_label.text = TranslationManager.t(_SKILL_NAME_KEYS[skill])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	var price_label := Label.new()
	var price: int = SaveManager.SKILL_CONFIG[skill]["price"]
	var stock_granted: int = SaveManager.SKILL_CONFIG[skill]["stock_granted"]
	price_label.text = TranslationManager.tf("skill_buy_price", [price, stock_granted])
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(price_label)

	var stock_label := Label.new()
	stock_label.text = TranslationManager.tf("skill_current_stock", [SaveManager.get_skill_stock(skill)])
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(stock_label)

	var confirm_btn := Button.new()
	confirm_btn.text = TranslationManager.t("ok")
	confirm_btn.custom_minimum_size = Vector2(120, 40)
	confirm_btn.add_theme_font_size_override("font_size", 16)
	confirm_btn.add_theme_color_override("font_color", Color.BLACK)
	confirm_btn.add_theme_color_override("font_focus_color", Color.BLACK)
	confirm_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	confirm_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	var confirm_sb := StyleBoxTexture.new()
	confirm_sb.texture = GOLD_SMALL
	confirm_sb.content_margin_left = 16.0
	confirm_sb.content_margin_top = 8.0
	confirm_sb.content_margin_right = 16.0
	confirm_sb.content_margin_bottom = 8.0
	confirm_btn.add_theme_stylebox_override("normal", confirm_sb)
	confirm_btn.add_theme_stylebox_override("hover", confirm_sb)
	confirm_btn.add_theme_stylebox_override("pressed", confirm_sb)
	var confirm_center := CenterContainer.new()
	confirm_center.add_child(confirm_btn)
	vbox.add_child(confirm_center)

	var cancel_btn := Button.new()
	cancel_btn.text = TranslationManager.t("cancel")
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.add_theme_color_override("font_color", Color.BLACK)
	cancel_btn.add_theme_color_override("font_focus_color", Color.BLACK)
	cancel_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	cancel_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	var cancel_sb := StyleBoxTexture.new()
	cancel_sb.texture = GOLD_SMALL
	cancel_sb.content_margin_left = 16.0
	cancel_sb.content_margin_top = 8.0
	cancel_sb.content_margin_right = 16.0
	cancel_sb.content_margin_bottom = 8.0
	cancel_btn.add_theme_stylebox_override("normal", cancel_sb)
	cancel_btn.add_theme_stylebox_override("hover", cancel_sb)
	cancel_btn.add_theme_stylebox_override("pressed", cancel_sb)
	var cancel_center := CenterContainer.new()
	cancel_center.add_child(cancel_btn)
	vbox.add_child(cancel_center)

	var warn_label: Label = null
	if SaveManager.coins < price:
		confirm_btn.disabled = true
		warn_label = _make_warn_label()
		vbox.add_child(warn_label)
		vbox.move_child(warn_label, confirm_center.get_index())

	cancel_btn.pressed.connect(func():
		SfxManager.play_click()
		_close_buy_popup()
	)
	confirm_btn.pressed.connect(func():
		SfxManager.play_click()
		if SaveManager.spend_coins(price):
			SaveManager.add_skill_stock(skill, stock_granted)
			_close_buy_popup()
			_refresh_track_hud()
		else:
			if not is_instance_valid(warn_label):
				warn_label = _make_warn_label()
				vbox.add_child(warn_label)
				vbox.move_child(warn_label, confirm_center.get_index())
	)

func _close_buy_popup():
	if is_instance_valid(_buy_popup):
		_buy_popup.queue_free()
	_buy_popup = null

func _make_warn_label() -> Label:
	var warn := Label.new()
	warn.text = TranslationManager.t("insufficient_coins")
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_font_size_override("font_size", 12)
	warn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	return warn

func _build_level_grid():
	for child in level_grid.get_children():
		child.queue_free()
	var max_reached: int = SaveManager.max_level
	var total_to_show := max_reached + 5
	for lvl in range(total_to_show, 0, -1):
		if lvl == max_reached:
			_latest_level_node(lvl)
		elif lvl < max_reached:
			_playable_level_node(lvl)
		else:
			_locked_level_node(lvl)

func _level_node(size: Vector2, bg_modulate: Color = Color.WHITE) -> Control:
	var node := Control.new()
	node.custom_minimum_size = size
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.texture = _SQUARE_TEX
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.modulate = bg_modulate
	node.add_child(bg)
	return node

func _node_content(node: Control, offset_y: float = 0.0) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top += offset_y
	content.offset_bottom += offset_y
	content.alignment = _LEVEL_ALIGNMENT
	content.add_theme_constant_override("separation", _LEVEL_GAP)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(content)
	return content

func _level_number_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _stars_row(earned: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	for i in 3:
		var star := TextureRect.new()
		star.texture = _STAR_TEX
		star.custom_minimum_size = Vector2(16, 16)
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.modulate = Color(1, 1, 1, 1) if i < earned else Color(1, 1, 1, 0.25)
		row.add_child(star)
	return row

func _latest_level_node(lvl: int):
	var node := _level_node(Vector2(140, 100))
	var content := _node_content(node, _LATEST_CONTENT_Y)
	content.add_child(_level_number_label(str(lvl), 30, _LEVEL_NUM_COLOR))
	node.gui_input.connect(_on_latest_node_input.bind(lvl))
	level_grid.add_child(node)
	_breathe(node)

func _playable_level_node(lvl: int):
	var node := _level_node(Vector2(80, 56))
	var content := _node_content(node, _PLAYABLE_CONTENT_Y)
	content.add_child(_level_number_label(str(lvl), 20, _LEVEL_NUM_COLOR))
	content.add_child(_stars_row(SaveManager.get_stars(lvl)))
	node.gui_input.connect(_on_level_node_input.bind(node, lvl))
	level_grid.add_child(node)

func _locked_level_node(lvl: int):
	var node := _level_node(Vector2(60, 60), Color(0.6, 0.6, 0.6))
	var content := _node_content(node, _LOCKED_CONTENT_Y)
	var lock_rect := TextureRect.new()
	lock_rect.texture = _LOCK_TEX
	lock_rect.custom_minimum_size = Vector2(34, 34)
	lock_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	content.add_child(lock_rect)
	content.add_child(_level_number_label(str(lvl), 14, Color(0.4, 0.4, 0.4)))
	level_grid.add_child(node)

func _breathe(node: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2(1.06, 1.06), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_level_node_input(event: InputEvent, node: Control, lvl: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			SfxManager.play_click()
			node.pivot_offset = node.size / 2.0
			node.scale = Vector2(0.95, 0.95)
		else:
			node.scale = Vector2.ONE
			_on_level_selected(lvl)

func _on_latest_node_input(event: InputEvent, lvl: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			SfxManager.play_click()
		else:
			_on_level_selected(lvl)

func _on_level_selected(level: int):
	if SaveManager.mood_level <= 0:
		SaveManager.show_empty_mood_popup(self)
		return
	_show_confirmation(level)

func _show_confirmation(level: int):
	_close_confirmation()
	var popup: Control = ConfirmationPopupScene.instantiate()
	add_child(popup)
	_confirmation_popup = popup
	popup.confirmed.connect(_on_confirmation_confirmed)
	popup.cancelled.connect(_on_confirmation_cancelled)
	popup.open(level)

func _on_confirmation_confirmed(level: int, combination: Array):
	SceneManager.set_combination_for_level(level, combination)
	SceneManager.active_tiles = combination.duplicate()
	SceneManager.go_to_gameplay(level)

func _on_confirmation_cancelled():
	_close_confirmation()

func _close_confirmation():
	if is_instance_valid(_confirmation_popup):
		_confirmation_popup.queue_free()
	_confirmation_popup = null

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(_confirmation_popup):
			_close_confirmation()
		elif is_instance_valid(_settings_popup):
			_close_settings_popup()
		elif level_track_view.visible:
			show_main_menu()
