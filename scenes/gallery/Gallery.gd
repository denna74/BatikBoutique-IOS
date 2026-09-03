extends Control

const GOLD_MEDIUM := preload("res://assets/buttons/gold_medium.png")
const DARK_MEDIUM := preload("res://assets/buttons/dark_medium.png")

const TILE_DISPLAY_ORDER := [0, 6, 5, 2, 3, 4, 1]
const FADE_SEC := 0.15
const SWIPE_THRESHOLD := 60.0

static func next_tile(tile_id: int) -> int:
	return (tile_id + 1) % TileDatabase.get_count()

static func prev_tile(tile_id: int) -> int:
	return (tile_id - 1 + TileDatabase.get_count()) % TileDatabase.get_count()

static func swipe_target(current: int, delta_x: float) -> int:
	if absf(delta_x) < SWIPE_THRESHOLD:
		return -1
	if delta_x > 0:
		return prev_tile(current)
	return next_tile(current)

static func unlock_level(tile_id: int) -> int:
	if tile_id < 6:
		return 0
	return 10 * (tile_id - 5)

static func is_locked(tile_id: int) -> bool:
	var sm: Node = null
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		sm = (loop as SceneTree).root.get_node_or_null("SaveManager")
	var max_level: int = sm.max_level if sm != null else 1
	return tile_id >= LevelData.types_in_play(max_level)

const CONTENT_TOP := 119.0
const TITLE_POS := Vector2(0, CONTENT_TOP)
const TITLE_SIZE := Vector2(480, 34)
const TOP_IMG_POS := Vector2(0, CONTENT_TOP + 40)
const TOP_IMG_SIZE := Vector2(480, 140)
const NAME_POS := Vector2(0, CONTENT_TOP + 186)
const NAME_SIZE := Vector2(480, 24)
const CLOTH_ROW1_POS := Vector2(0, CONTENT_TOP + 216)
const CLOTH_ROW2_POS := Vector2(0, CONTENT_TOP + 274)
const CLOTH_CELL_SIZE := Vector2(92, 54)
const CLOTH_X_GAP := 8.0
const PRICE_POS := Vector2(0, CONTENT_TOP + 336)
const PRICE_SIZE := Vector2(480, 26)
const DESC_POS := Vector2(24, CONTENT_TOP + 368)
const DESC_SIZE := Vector2(432, 224)
const UNLOCK_POS := Vector2(24, CONTENT_TOP + 597)
const UNLOCK_SIZE := Vector2(432, 24)
const NAV_POS := Vector2(24, CONTENT_TOP + 627)
const NAV_SIZE := Vector2(180, 48)
const BACK_POS := Vector2(388, 10)
const BACK_SIZE := Vector2(80, 40)
const PANEL_POS := Vector2(10, CONTENT_TOP - 12)
const PANEL_SIZE := Vector2(460, 699)

var _current_tile := 0
var _drag_start := Vector2.ZERO
var _drag_index := -1
var _swipe_handled := false

var _top_image: TextureRect
var _question_image: TextureRect
var _name_label: Label
var _cloth_images: Array = []
var _price_label: Label
var _desc_label: Label
var _unlock_label: Label
var _title_label: Label
var _back_button: Button
var _prev_button: Button
var _next_button: Button

func _ready():
	MusicManager.play_gallery()
	UiTransition.fade_in(FADE_SEC)
	_build_background_panel()
	_build_header()
	_build_top()
	_build_cloth_row()
	_build_price()
	_build_description()
	_build_unlock()
	_build_nav()
	TranslationManager.language_changed.connect(_on_language_changed)
	_refresh()

func _build_background_panel():
	var panel := Panel.new()
	panel.position = PANEL_POS
	panel.size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.5)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

func _build_header():
	_title_label = Label.new()
	_title_label.position = TITLE_POS
	_title_label.size = TITLE_SIZE
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	add_child(_title_label)

	_back_button = _make_button(DARK_MEDIUM)
	_back_button.position = BACK_POS
	_back_button.size = BACK_SIZE
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)

func _build_top():
	_top_image = TextureRect.new()
	_top_image.position = TOP_IMG_POS
	_top_image.size = TOP_IMG_SIZE
	_top_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_top_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_top_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_image)

	_name_label = Label.new()
	_name_label.position = NAME_POS
	_name_label.size = NAME_SIZE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_question_image = TextureRect.new()
	_question_image.texture = preload("res://assets/gallery/question.png")
	_question_image.position = Vector2((TOP_IMG_SIZE.x - 64) / 2, TOP_IMG_POS.y + (TOP_IMG_SIZE.y - 64) / 2)
	_question_image.size = Vector2(64, 64)
	_question_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_question_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_question_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_question_image.visible = false
	add_child(_question_image)

func _build_cloth_row():
	_cloth_images = []
	for i in range(7):
		var img := TextureRect.new()
		var row := i / 4
		var col := i % 4
		var row_count := 4 if row == 0 else 3
		var row_width := row_count * CLOTH_CELL_SIZE.x + (row_count - 1) * CLOTH_X_GAP
		var x := (480 - row_width) / 2.0
		img.position = Vector2(x + col * (CLOTH_CELL_SIZE.x + CLOTH_X_GAP), CLOTH_ROW1_POS.y + row * (CLOTH_ROW2_POS.y - CLOTH_ROW1_POS.y))
		img.size = CLOTH_CELL_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(img)
		_cloth_images.append(img)

func _build_price():
	_price_label = Label.new()
	_price_label.position = PRICE_POS
	_price_label.size = PRICE_SIZE
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price_label.add_theme_font_size_override("font_size", 18)
	_price_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	_price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_price_label)

func _build_description():
	_desc_label = Label.new()
	_desc_label.position = DESC_POS
	_desc_label.size = DESC_SIZE
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 18)
	_desc_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05, 0.95))
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc_label)

func _build_unlock():
	_unlock_label = Label.new()
	_unlock_label.position = UNLOCK_POS
	_unlock_label.size = UNLOCK_SIZE
	_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unlock_label.add_theme_font_size_override("font_size", 15)
	_unlock_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	_unlock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_unlock_label)

func _build_nav():
	_prev_button = _make_button(GOLD_MEDIUM)
	_prev_button.position = NAV_POS
	_prev_button.size = NAV_SIZE
	_prev_button.pressed.connect(_on_prev_pressed)
	add_child(_prev_button)

	_next_button = _make_button(GOLD_MEDIUM)
	_next_button.position = Vector2(480 - NAV_POS.x - NAV_SIZE.x, NAV_POS.y)
	_next_button.size = NAV_SIZE
	_next_button.pressed.connect(_on_next_pressed)
	add_child(_next_button)

func _make_button(bg: Texture2D) -> Button:
	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_color_override("font_focus_color", Color.BLACK)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	var sb := StyleBoxTexture.new()
	sb.texture = bg
	sb.content_margin_left = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.pressed.connect(SfxManager.play_click)
	btn.button_down.connect(func(): btn.pivot_offset = btn.size / 2.0; btn.scale = Vector2(0.95, 0.95))
	btn.button_up.connect(func(): btn.scale = Vector2.ONE)
	return btn

func _is_locked(tile_id: int) -> bool:
	return is_locked(tile_id)

func _refresh():
	var lang := TranslationManager.current_language
	var locked := _is_locked(_current_tile)
	if locked:
		_top_image.visible = true
		_top_image.texture = TileArt.get_texture(_current_tile)
		_top_image.modulate = Color(0.15, 0.15, 0.15, 1)
		_name_label.visible = false
		_question_image.visible = true
		for i in range(7):
			(_cloth_images[i] as TextureRect).texture = ClothDatabase.type_icon(TILE_DISPLAY_ORDER[i])
	else:
		_top_image.visible = true
		_top_image.modulate = Color.WHITE
		_top_image.texture = TileArt.get_texture(_current_tile)
		_name_label.visible = true
		_name_label.text = TileDatabase.get_batik_name(_current_tile, lang)
		_question_image.visible = false
		for i in range(7):
			(_cloth_images[i] as TextureRect).texture = ClothDatabase.clothing_texture(TILE_DISPLAY_ORDER[i], _current_tile)
	if locked:
		_price_label.text = "? %s" % TranslationManager.t("coins")
		_desc_label.text = ""
		_unlock_label.text = TranslationManager.tf("unlock_level", [unlock_level(_current_tile)])
	else:
		_price_label.text = "%s : %d %s" % [TranslationManager.t("price"), BoutiqueManager.batik_value(_current_tile), TranslationManager.t("coins")]
		_desc_label.text = GalleryDescriptions.get_description(_current_tile, lang)
		_unlock_label.text = ""
	_update_ui_texts()

func _update_ui_texts():
	_title_label.text = TranslationManager.t("gallery")
	_back_button.text = TranslationManager.t("back")
	_prev_button.text = TranslationManager.t("previous")
	_next_button.text = TranslationManager.t("next")

func _on_language_changed(_lang: String):
	_refresh()

func _on_prev_pressed():
	if _swipe_handled:
		_swipe_handled = false
		return
	_goto(prev_tile(_current_tile))

func _on_next_pressed():
	if _swipe_handled:
		_swipe_handled = false
		return
	_goto(next_tile(_current_tile))

func _goto(tile_id: int):
	if tile_id == _current_tile:
		return
	_current_tile = tile_id
	_refresh()

func _notification(what: int):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _on_back_pressed():
	if _swipe_handled:
		_swipe_handled = false
		return
	await UiTransition.fade_out(0.2)
	if is_inside_tree():
		SceneManager.fade_in_menu = true
		SceneManager.go_to_level_track()

func _input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_start = event.position
			_drag_index = event.index
			_swipe_handled = false
		elif event.index == _drag_index:
			_drag_index = -1
	elif event is InputEventScreenDrag:
		if event.index == _drag_index and not _swipe_handled:
			_check_swipe(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = event.position
				_drag_index = 0
				_swipe_handled = false
			else:
				_drag_index = -1
	elif event is InputEventMouseMotion:
		if _drag_index == 0 and not _swipe_handled:
			_check_swipe(event.position)

func _check_swipe(pos: Vector2):
	var delta := pos - _drag_start
	if absf(delta.y) > absf(delta.x):
		return
	var target := swipe_target(_current_tile, delta.x)
	if target == -1:
		return
	_swipe_handled = true
	_drag_index = -1
	_goto(target)
