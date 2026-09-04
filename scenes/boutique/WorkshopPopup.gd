extends Control

signal work_started(slot_index: int)
signal cancelled()

@onready var dim: ColorRect = $Dim
@onready var cloth_type_label: Label = $Panel/Margin/VBox/TypeGrid/ClothTypeLabel
@onready var fabric_header_label: Label = $Panel/Margin/VBox/TypeGrid/FabricHeaderLabel
@onready var type_dropdown: OptionButton = $Panel/Margin/VBox/TypeGrid/TypeDropdown
@onready var fabric_label: Label = $Panel/Margin/VBox/TypeGrid/FabricLabel
@onready var motive_label: Label = $Panel/Margin/VBox/MotiveLabel
@onready var motive_grid: GridContainer = $Panel/Margin/VBox/MotiveScroll/MotiveGrid
@onready var work_button: Button = $Panel/Margin/VBox/Buttons/WorkButton
@onready var cancel_button: Button = $Panel/Margin/VBox/Buttons/CancelButton

var _slot_index := -1
var _selected_type := -1
var _selected_motive := -1
var _cells: Array = []

const ICON_HEIGHT := 18.0

func _ready():
	visible = false
	TranslationManager.language_changed.connect(_update_texts)
	type_dropdown.item_selected.connect(_on_type_selected)
	work_button.pressed.connect(_on_work_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	dim.gui_input.connect(_on_dim_input)
	_style_popup()
	_update_texts()

func _style_popup():
	var popup := type_dropdown.get_popup()
	var empty := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	popup.add_theme_icon_override("check", empty)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(1, 1, 1, 1)
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_right = 8
	panel.corner_radius_bottom_left = 8
	panel.content_margin_top = 6
	panel.content_margin_bottom = 6
	popup.add_theme_stylebox_override("panel", panel)
	popup.add_theme_constant_override("v_separation", 8)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.9, 0.85, 0.75, 1)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_color_override("font_color", Color.BLACK)
	popup.add_theme_color_override("font_hover_color", Color.BLACK)

func open(slot_index: int):
	_slot_index = slot_index
	_selected_type = 0
	_selected_motive = -1
	_populate_types()
	type_dropdown.select(0)
	_build_motive_grid()
	_update_cells()
	_refresh()
	_update_fabric_label()
	visible = true

func _populate_types():
	type_dropdown.clear()
	for i in range(ClothDatabase.get_type_count()):
		type_dropdown.add_icon_item(_scaled_icon(ClothDatabase.type_icon(i)), ClothDatabase.type_name(i, TranslationManager.current_language), i)

func _scaled_icon(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	var scale := ICON_HEIGHT / float(img.get_height())
	var w := maxi(1, int(round(img.get_width() * scale)))
	img.resize(w, int(round(ICON_HEIGHT)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

func _is_tile_locked(tile_id: int) -> bool:
	var loop := Engine.get_main_loop()
	var sm: Node = null
	if loop is SceneTree:
		sm = (loop as SceneTree).root.get_node_or_null("SaveManager")
	var max_level: int = sm.max_level if sm != null else 1
	return tile_id >= LevelData.types_in_play(max_level)

func _build_motive_grid():
	for child in motive_grid.get_children():
		child.queue_free()
	_cells = []
	for tile_id in range(TileDatabase.get_count()):
		var cell := _make_motive_cell(tile_id)
		_cells.append(cell)
		motive_grid.add_child(cell)

func _make_motive_cell(tile_id: int) -> Control:
	var locked := _is_tile_locked(tile_id)
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(48, 62)
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", 0)
	cell.set_meta("tile_id", tile_id)
	cell.set_meta("locked", locked)
	var tile_box := Control.new()
	tile_box.custom_minimum_size = Vector2(48, 48)
	tile_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(tile_box)
	var thumb := TextureRect.new()
	thumb.texture = TileArt.get_texture(tile_id)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb.modulate = Color(0.15, 0.15, 0.15, 1) if locked else Color.WHITE
	tile_box.add_child(thumb)
	var border := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0)
	sb.border_color = Color(0.9, 0.6, 0.1, 1) if tile_id == _selected_motive else Color(0, 0, 0, 0)
	sb.set_border_width_all(3)
	border.add_theme_stylebox_override("panel", sb)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_box.add_child(border)
	cell.set_meta("border", border)
	var amount := Label.new()
	amount.name = "Amount"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override("font_size", 12)
	amount.add_theme_color_override("font_color", Color.BLACK)
	amount.custom_minimum_size = Vector2(48, 14)
	cell.add_child(amount)
	cell.gui_input.connect(_on_motive_input.bind(tile_id))
	return cell

func _on_type_selected(index: int):
	_selected_type = type_dropdown.get_item_id(index)
	_selected_motive = -1
	_update_cells()
	_refresh()
	_update_fabric_label()

func _on_motive_input(event: InputEvent, tile_id: int):
	if _selected_type < 0:
		return
	if _is_tile_locked(tile_id):
		return
	if not BoutiqueManager.can_afford(_selected_type, tile_id):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_selected_motive = tile_id
		_update_cells()
		_refresh()

func _update_cells():
	for cell in _cells:
		var tile_id := int(cell.get_meta("tile_id"))
		var locked := bool(cell.get_meta("locked"))
		var enabled := not locked and _selected_type >= 0 and BoutiqueManager.can_afford(_selected_type, tile_id)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		var amount: Label = cell.get_node("Amount")
		if locked:
			amount.text = "?"
		else:
			amount.text = str(BoutiqueManager.tile_fabric(tile_id))
		var border: Panel = cell.get_meta("border")
		var sb: StyleBoxFlat = border.get_theme_stylebox("panel") as StyleBoxFlat
		sb.border_color = Color(0.9, 0.6, 0.1, 1) if tile_id == _selected_motive else Color(0, 0, 0, 0)

func _refresh():
	var has_choice := _selected_type >= 0 and _selected_motive >= 0
	work_button.disabled = not (has_choice and BoutiqueManager.can_afford(_selected_type, _selected_motive))

func _update_fabric_label():
	if _selected_type < 0:
		fabric_label.text = ""
	else:
		fabric_label.text = str(ClothDatabase.type_fabric(_selected_type))

func _on_work_pressed():
	SfxManager.play_click()
	if BoutiqueManager.start_work(_slot_index, _selected_type, _selected_motive):
		work_started.emit(_slot_index)
		queue_free()

func _on_cancel_pressed():
	SfxManager.play_click()
	cancelled.emit()
	queue_free()

func _on_dim_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_on_cancel_pressed()

func _update_texts(_lang: String = ""):
	cloth_type_label.text = TranslationManager.t("cloth_type_label")
	fabric_header_label.text = TranslationManager.t("fabric")
	motive_label.text = TranslationManager.t("motive_label")
	work_button.text = TranslationManager.t("work")
	cancel_button.text = TranslationManager.t("cancel")
	_populate_types()
	if _selected_type >= 0:
		type_dropdown.select(_selected_type)
	_update_cells()
	_refresh()
	_update_fabric_label()

func _notification(what: int):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_cancel_pressed()
