extends Control

const WorkshopPopupScene := preload("res://scenes/boutique/WorkshopPopup.tscn")
const UpgradePopupScene := preload("res://scenes/boutique/UpgradePopup.tscn")
const CharacterScene := preload("res://scenes/character/Character.tscn")
const COIN_TEX := preload("res://assets/buttons/coin.png")
const LOCK_TEX := preload("res://assets/buttons/cute_lock_small.png")
const GOLD_MEDIUM := preload("res://assets/buttons/gold_medium.png")
const DARK_MEDIUM := preload("res://assets/buttons/dark_medium.png")
const SEWING_FRAME_FORMATS := {
	0: "res://assets/workshop/sewing_manual/frame_%03d.png",
	1: "res://assets/workshop/sewing_machine_old/frame_%03d.png",
	2: "res://assets/workshop/sewing_machine_modern/frame_%03d.png",
}
const SEWING_FRAME_COUNT := 30
const SEWING_FPS := 12.0
const SEWING_DISPLAY_SIZE := 140.0
const OLD_SEWING_TEX := preload("res://assets/workshop/old_sewing.png")
const OLD_SEWING_SIZE := Vector2(96, 73)
const MODERN_SEWING_TEX := preload("res://assets/workshop/modern_sewing.png")
const MODERN_SEWING_SIZE := Vector2(62, 73)
const MODERN_IDLE_Y_OFFSET := 17.0
const CHARACTER_GAP := 6.0
const FLASH_SALE_TEX := preload("res://assets/buttons/flashsale_shop.png")
const FLASH_SALE_IMG_SIZE := Vector2(150, 121)

const REQUEST_ROW_HEIGHT := 84.0
const WORKSHOP_PANEL_WIDTH := 232.0
const WORKSHOP_PANEL_HEIGHT := 248.0
const WORKSHOP_AREA_TOP := 340.0
const CONTENT_TOP := 66.0

var _coin_label: Label
var _exit_button: Button
var _instant_coins_btn: TextureButton
var _request_container: VBoxContainer
var _workshop_panels: Array = []
var _flash_box: Panel
var _flash_label: Label
var _slot_states: Array = []
var _popup: Control
var _confirm_popup: Control
var _upgrade_popup: Control
var _coin_popup: Control
var _iap_status: Label

func _ready():
	MusicManager.play_boutique()
	UiTransition.fade_in(0.2)
	BoutiqueManager.ensure_state()
	_build_header()
	_build_requests_area()
	_build_workshop_area()
	TranslationManager.language_changed.connect(_on_language_changed)
	SaveManager.coins_changed.connect(_on_coins_changed)
	IAPManager.billing_ready.connect(_on_billing_ready)
	IAPManager.purchases_restored.connect(_on_purchases_restored)
	_on_purchases_restored()
	_refresh_all()
	_animate_initial_requests()

func _process(_delta: float):
	BoutiqueManager.reconcile()
	var slots := BoutiqueManager.workshop_slots()
	for i in range(slots.size()):
		var state: String = slots[i].state
		if i >= _slot_states.size():
			_slot_states.append("")
		if _slot_states[i] != state:
			_slot_states[i] = state
			_refresh_workshop(i)
		if state == "working":
			_update_workshop_progress(i)

func _build_header():
	var header := Control.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(480, 60)
	add_child(header)

	var coin_icon := TextureRect.new()
	coin_icon.texture = COIN_TEX
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.position = Vector2(10, 12)
	coin_icon.size = Vector2(32, 32)
	header.add_child(coin_icon)

	_coin_label = Label.new()
	_coin_label.position = Vector2(50, 20)
	_coin_label.size = Vector2(100, 32)
	_coin_label.add_theme_font_size_override("font_size", 20)
	_coin_label.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(_coin_label)

	_instant_coins_btn = TextureButton.new()
	_instant_coins_btn.ignore_texture_size = true
	_instant_coins_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_instant_coins_btn.position = Vector2(270, 2)
	_instant_coins_btn.size = Vector2(82, 60)
	_instant_coins_btn.pressed.connect(_on_instant_coins_pressed)
	header.add_child(_instant_coins_btn)

	_exit_button = _make_button(DARK_MEDIUM)
	_exit_button.position = Vector2(392, 8)
	_exit_button.size = Vector2(80, 44)
	_exit_button.pressed.connect(_on_exit_pressed)
	header.add_child(_exit_button)

func _build_requests_area():
	_request_container = VBoxContainer.new()
	_request_container.position = Vector2(0, CONTENT_TOP)
	_request_container.size = Vector2(480, 0)
	_request_container.add_theme_constant_override("separation", 4)
	add_child(_request_container)

func _build_workshop_area():
	var left_col := Control.new()
	left_col.position = Vector2(4, WORKSHOP_AREA_TOP)
	left_col.size = Vector2(WORKSHOP_PANEL_WIDTH, WORKSHOP_PANEL_HEIGHT * 2 + 8)
	add_child(left_col)

	var right_col := Control.new()
	right_col.position = Vector2(244, WORKSHOP_AREA_TOP)
	right_col.size = Vector2(WORKSHOP_PANEL_WIDTH, WORKSHOP_PANEL_HEIGHT * 2 + 8)
	add_child(right_col)

	var w1 := _make_workshop_panel(0)
	w1.position = Vector2(0, 0)
	w1.size = Vector2(WORKSHOP_PANEL_WIDTH, WORKSHOP_PANEL_HEIGHT)
	left_col.add_child(w1)

	_flash_box = Panel.new()
	_flash_box.position = Vector2(0, WORKSHOP_PANEL_HEIGHT + 8)
	_flash_box.size = Vector2(WORKSHOP_PANEL_WIDTH, WORKSHOP_PANEL_HEIGHT)
	_flash_box.add_theme_stylebox_override("panel", _panel_style(Color(0.9, 0.8, 0.6, 0.85)))
	left_col.add_child(_flash_box)
	var flash_img := TextureRect.new()
	flash_img.texture = FLASH_SALE_TEX
	flash_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flash_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flash_img.size = FLASH_SALE_IMG_SIZE
	flash_img.position = (_flash_box.size - FLASH_SALE_IMG_SIZE) / 2.0
	flash_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_box.add_child(flash_img)
	_flash_label = Label.new()
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.position = Vector2(0, 6)
	_flash_label.size = Vector2(WORKSHOP_PANEL_WIDTH, 26)
	_flash_label.add_theme_font_size_override("font_size", 16)
	_flash_label.add_theme_color_override("font_color", Color.BLACK)
	_flash_box.add_child(_flash_label)

	var w2 := _make_workshop_panel(1)
	w2.position = Vector2(0, 0)
	w2.size = Vector2(WORKSHOP_PANEL_WIDTH, WORKSHOP_PANEL_HEIGHT)
	right_col.add_child(w2)

	var w3 := _make_workshop_panel(2)
	w3.position = Vector2(0, WORKSHOP_PANEL_HEIGHT + 8)
	w3.size = Vector2(WORKSHOP_PANEL_WIDTH, WORKSHOP_PANEL_HEIGHT)
	right_col.add_child(w3)

	_workshop_panels = [w1, w2, w3]

func _make_workshop_panel(index: int) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.97, 0.9, 0.78, 0.92)))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel

func _panel_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	return sb

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

func _start_breath(btn: Button) -> Tween:
	var tween := btn.create_tween().set_loops()
	tween.tween_property(btn, "scale", Vector2(1.06, 1.06), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

func _refresh_all():
	_refresh_header()
	_rebuild_requests()
	for i in range(_workshop_panels.size()):
		_refresh_workshop(i)

func _refresh_header():
	_coin_label.text = str(SaveManager.coins)
	_exit_button.text = TranslationManager.t("exit")
	_flash_label.text = TranslationManager.t("flash_sale")
	if _instant_coins_btn and is_instance_valid(_instant_coins_btn):
		_instant_coins_btn.texture_normal = _instant_coins_texture()

func _instant_coins_texture() -> Texture2D:
	if TranslationManager.current_language == "id":
		return load("res://assets/instant/instant_coins_id.png")
	return load("res://assets/instant/instant_coins_en.png")

func _on_coins_changed(_value: int):
	_coin_label.text = str(SaveManager.coins)
	for i in range(_workshop_panels.size()):
		if not BoutiqueManager.slot_unlocked(i):
			_refresh_workshop(i)

func _rebuild_requests():
	for child in _request_container.get_children():
		child.queue_free()
	var requests := BoutiqueManager.request_slots()
	for i in range(requests.size()):
		var row := _make_request_row(requests[i])
		_request_container.add_child(row)

func _make_request_row(req: Dictionary) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(480, REQUEST_ROW_HEIGHT)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", _panel_style(Color(0.95, 0.87, 0.74, 0.75)))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(bg)

	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/npc/%s" % req.npc)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.position = Vector2(6, 4)
	portrait.size = Vector2(70, REQUEST_ROW_HEIGHT - 8)
	row.add_child(portrait)

	var type_label := Label.new()
	type_label.text = TranslationManager.tf("cloth_type", [ClothDatabase.type_name(int(req.type), TranslationManager.current_language)])
	type_label.position = Vector2(82, 8)
	type_label.size = Vector2(290, 26)
	type_label.add_theme_font_size_override("font_size", 16)
	type_label.add_theme_color_override("font_color", Color.BLACK)
	row.add_child(type_label)

	var thumb := TextureRect.new()
	thumb.texture = TileArt.get_texture(int(req.motive))
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.position = Vector2(82, 36)
	thumb.size = Vector2(38, 38)
	row.add_child(thumb)

	var motive_label := Label.new()
	motive_label.text = TileDatabase.get_catalog_name(int(req.motive), TranslationManager.current_language)
	motive_label.position = Vector2(126, 42)
	motive_label.size = Vector2(346, 32)
	motive_label.add_theme_font_size_override("font_size", 14)
	motive_label.add_theme_color_override("font_color", Color.BLACK)
	row.add_child(motive_label)

	var reward := ClothDatabase.type_fabric(int(req.type)) * BoutiqueManager.batik_value(int(req.motive))
	var reward_icon := TextureRect.new()
	reward_icon.texture = COIN_TEX
	reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reward_icon.position = Vector2(418, 2)
	reward_icon.size = Vector2(26, 26)
	reward_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(reward_icon)

	var reward_label := Label.new()
	reward_label.text = str(reward)
	reward_label.position = Vector2(444, 8)
	reward_label.size = Vector2(60, 26)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reward_label.add_theme_font_size_override("font_size", 16)
	reward_label.add_theme_color_override("font_color", Color.BLACK)
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(reward_label)
	return row

func _animate_initial_requests():
	for child in _request_container.get_children():
		_animate_row_in(child)

func _animate_row_in(row: Control):
	row.position = Vector2(-300, 0)
	var tw := create_tween()
	tw.tween_property(row, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _refresh_workshop(index: int):
	var panel: Panel = _workshop_panels[index]
	for child in panel.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = TranslationManager.tf("workshop", [index + 1])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(WORKSHOP_PANEL_WIDTH, 26)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.BLACK)
	panel.add_child(title)

	var unlocked := BoutiqueManager.slot_unlocked(index)
	if not unlocked:
		_add_locked_content(panel, index)
		return

	var slots := BoutiqueManager.workshop_slots()
	var slot: Dictionary = slots[index]
	if slot.state == "idle":
		var tier := BoutiqueManager.slot_upgrade(index)
		var y_offset := MODERN_IDLE_Y_OFFSET if tier == 2 else 0.0
		var character := _add_character(panel, y_offset)
		_add_idle_content(panel, index, y_offset)
		if tier == 1:
			_center_character_with_machine(panel, character, OLD_SEWING_TEX, OLD_SEWING_SIZE, y_offset)
		elif tier == 2:
			_center_character_with_machine(panel, character, MODERN_SEWING_TEX, MODERN_SEWING_SIZE, y_offset)
	elif slot.state == "working":
		_add_working_content(panel, index)
	else:
		_add_ready_content(panel, index)

func _add_character(panel: Panel, y_offset := 0.0) -> Node2D:
	var character := CharacterScene.instantiate()
	panel.add_child(character)
	character.position = Vector2(WORKSHOP_PANEL_WIDTH / 2.0, 144.0 - y_offset)
	character.scale = Vector2(0.24, 0.24)
	character.sprite.play("idle")
	return character

func _center_character_with_machine(panel: Panel, character: Node2D, machine_tex: Texture2D, machine_size: Vector2, y_offset := 0.0):
	var sprite: AnimatedSprite2D = character.get_node("Sprite")
	var char_w := sprite.sprite_frames.get_frame_texture("idle", 0).get_size().x * character.scale.x
	var combo_w := machine_size.x + CHARACTER_GAP + char_w
	var left := (WORKSHOP_PANEL_WIDTH - combo_w) / 2.0
	var machine := TextureRect.new()
	machine.texture = machine_tex
	machine.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	machine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	machine.position = Vector2(left, 144.0 - y_offset - machine_size.y / 2.0)
	machine.size = machine_size
	machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(machine)
	character.position.x = left + machine_size.x + CHARACTER_GAP + char_w / 2.0

func _add_idle_content(panel: Panel, index: int, y_offset := 0.0):
	var machine_label := Label.new()
	machine_label.text = BoutiqueManager.machine_name(BoutiqueManager.slot_upgrade(index))
	machine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine_label.position = Vector2(0, 35)
	machine_label.size = Vector2(WORKSHOP_PANEL_WIDTH, 22)
	machine_label.add_theme_font_size_override("font_size", 13)
	machine_label.add_theme_color_override("font_color", Color(0.35, 0.25, 0.1))
	panel.add_child(machine_label)

	if BoutiqueManager.slot_upgrade(index) < 2:
		var up_btn := _make_button(GOLD_MEDIUM)
		up_btn.text = TranslationManager.t("upgrade")
		up_btn.size = Vector2(140, 40)
		up_btn.position = Vector2((WORKSHOP_PANEL_WIDTH - 140) / 2.0, 53)
		up_btn.pressed.connect(_on_upgrade_pressed.bind(index))
		panel.add_child(up_btn)

	var work_btn := _make_button(GOLD_MEDIUM)
	work_btn.text = TranslationManager.t("work")
	work_btn.size = Vector2(140, 44)
	work_btn.position = Vector2((WORKSHOP_PANEL_WIDTH - 140) / 2.0, 190.0 - y_offset)
	work_btn.pivot_offset = work_btn.size / 2.0
	work_btn.pressed.connect(_on_work_pressed.bind(index))
	panel.add_child(work_btn)
	var breath := _start_breath(work_btn)
	work_btn.button_down.connect(func(): breath.kill())
	work_btn.button_up.connect(func(): breath = _start_breath(work_btn))

func _add_working_content(panel: Panel, index: int):
	var slots := BoutiqueManager.workshop_slots()
	var slot: Dictionary = slots[index]
	var type_id: int = slot.type
	var total := float(ClothDatabase.type_seconds(type_id)) * BoutiqueManager.time_multiplier(index)
	_add_sewing_sprite(panel, BoutiqueManager.slot_upgrade(index))
	var bar := ProgressBar.new()
	bar.size = Vector2(190, 22)
	bar.position = Vector2((WORKSHOP_PANEL_WIDTH - 190) / 2.0, 190)
	bar.min_value = 0.0
	bar.max_value = total
	bar.value = total - BoutiqueManager.seconds_left(index)
	panel.add_child(bar)
	var time_label := Label.new()
	time_label.text = TranslationManager.tf("seconds_short", [int(ceil(BoutiqueManager.seconds_left(index)))])
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.position = Vector2(0, 222)
	time_label.size = Vector2(WORKSHOP_PANEL_WIDTH, 24)
	time_label.add_theme_color_override("font_color", Color.BLACK)
	panel.add_child(time_label)
	panel.set_meta("progress_bar", bar)
	panel.set_meta("time_label", time_label)
	panel.set_meta("work_total", total)

func _add_sewing_sprite(panel: Panel, tier: int):
	var frame_format: String = SEWING_FRAME_FORMATS[tier]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("sew")
	frames.set_animation_loop("sew", false)
	frames.set_animation_speed("sew", SEWING_FPS)
	frames.add_animation("sew_back")
	frames.set_animation_loop("sew_back", false)
	frames.set_animation_speed("sew_back", SEWING_FPS)
	for i in range(1, SEWING_FRAME_COUNT + 1):
		frames.add_frame("sew", load(frame_format % i))
	for i in range(SEWING_FRAME_COUNT, 0, -1):
		frames.add_frame("sew_back", load(frame_format % i))
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.scale = Vector2(SEWING_DISPLAY_SIZE / 256.0, SEWING_DISPLAY_SIZE / 256.0)
	anim.position = Vector2(WORKSHOP_PANEL_WIDTH / 2.0, 112.0)
	anim.animation_finished.connect(_on_sewing_cycle_finished.bind(anim))
	anim.play("sew")
	panel.add_child(anim)

func _on_sewing_cycle_finished(anim: AnimatedSprite2D):
	anim.play("sew" if anim.animation == "sew_back" else "sew_back")

func _add_ready_content(panel: Panel, index: int):
	var slots := BoutiqueManager.workshop_slots()
	var slot: Dictionary = slots[index]
	var cloth := TextureRect.new()
	cloth.texture = ClothDatabase.clothing_texture(int(slot.type), int(slot.motive))
	cloth.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cloth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cloth.position = Vector2((WORKSHOP_PANEL_WIDTH - 80) / 2.0, 56)
	cloth.size = Vector2(80, 96)
	panel.add_child(cloth)
	var serve_btn := _make_button(GOLD_MEDIUM)
	serve_btn.text = TranslationManager.t("serve")
	serve_btn.size = Vector2(120, 40)
	serve_btn.position = Vector2((WORKSHOP_PANEL_WIDTH - 120) / 2.0, 182)
	serve_btn.pressed.connect(_on_serve_pressed.bind(index))
	panel.add_child(serve_btn)

func _add_locked_content(panel: Panel, index: int):
	var lock := TextureRect.new()
	lock.texture = LOCK_TEX
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.position = Vector2((WORKSHOP_PANEL_WIDTH - 48) / 2.0, 90)
	lock.size = Vector2(48, 48)
	panel.add_child(lock)
	var buy_btn := _make_button(GOLD_MEDIUM)
	buy_btn.text = TranslationManager.tf("buy_workshop", [BoutiqueManager.EXTENDED_COST])
	buy_btn.size = Vector2(170, 44)
	buy_btn.position = Vector2((WORKSHOP_PANEL_WIDTH - 170) / 2.0, 160)
	buy_btn.disabled = SaveManager.coins < BoutiqueManager.EXTENDED_COST
	buy_btn.pressed.connect(_on_buy_pressed.bind(index))
	panel.add_child(buy_btn)
	if SaveManager.coins < BoutiqueManager.EXTENDED_COST:
		var need_label := Label.new()
		need_label.text = TranslationManager.t("insufficient_coins")
		need_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		need_label.position = Vector2(0, 210)
		need_label.size = Vector2(WORKSHOP_PANEL_WIDTH, 24)
		need_label.add_theme_font_size_override("font_size", 13)
		need_label.add_theme_color_override("font_color", Color(0.7, 0.15, 0.15))
		panel.add_child(need_label)

func _update_workshop_progress(index: int):
	var panel: Panel = _workshop_panels[index]
	if not panel.has_meta("progress_bar"):
		return
	var total := float(panel.get_meta("work_total"))
	var bar: ProgressBar = panel.get_meta("progress_bar")
	bar.value = total - BoutiqueManager.seconds_left(index)
	var time_label: Label = panel.get_meta("time_label")
	time_label.text = TranslationManager.tf("seconds_short", [int(ceil(BoutiqueManager.seconds_left(index)))])

func _on_work_pressed(slot_index: int):
	_open_workshop_popup(slot_index)

func _on_upgrade_pressed(slot_index: int):
	if is_instance_valid(_upgrade_popup):
		_upgrade_popup.queue_free()
	_upgrade_popup = UpgradePopupScene.instantiate()
	_upgrade_popup.z_index = 1100
	add_child(_upgrade_popup)
	_upgrade_popup.upgraded.connect(_on_upgraded)
	_upgrade_popup.cancelled.connect(func():
		if is_instance_valid(_upgrade_popup):
			_upgrade_popup.queue_free()
			_upgrade_popup = null
	)
	_upgrade_popup.open(slot_index)

func _on_upgraded(slot_index: int):
	_refresh_header()
	_refresh_workshop(slot_index)
	_slot_states[slot_index] = BoutiqueManager.workshop_slots()[slot_index].state
	if is_instance_valid(_upgrade_popup):
		_upgrade_popup.queue_free()
		_upgrade_popup = null

func _open_workshop_popup(slot_index: int):
	if is_instance_valid(_popup):
		_popup.queue_free()
	_popup = WorkshopPopupScene.instantiate()
	_popup.z_index = 1000
	add_child(_popup)
	_popup.work_started.connect(_on_work_started)
	_popup.cancelled.connect(func():
		if is_instance_valid(_popup):
			_popup.queue_free()
			_popup = null
	)
	_popup.open(slot_index)

func _on_work_started(_slot_index: int):
	_refresh_header()
	_refresh_workshop(_slot_index)
	_slot_states[_slot_index] = "working"
	if is_instance_valid(_popup):
		_popup.queue_free()
		_popup = null

func _on_serve_pressed(slot_index: int):
	var slots := BoutiqueManager.workshop_slots()
	var slot: Dictionary = slots[slot_index]
	var type_id: int = slot.type
	var motive: int = slot.motive
	var result: Dictionary = BoutiqueManager.serve(slot_index)
	if result.is_empty():
		return
	var from_rect := Rect2(_workshop_panels[slot_index].global_position, Vector2(80, 96))
	from_rect.position += Vector2((WORKSHOP_PANEL_WIDTH - 80) / 2.0, 100)
	if result.matched:
		var row_index := int(result.request_index)
		var portrait_pos := _request_portrait_center(row_index)
		await _animate_cloth_arc(from_rect, type_id, motive, portrait_pos)
		await _animate_coins(portrait_pos, int(result.price))
		var row := _request_container.get_child(row_index) if row_index < _request_container.get_child_count() else null
		if row:
			await _animate_row_out(row)
		_rebuild_requests()
		_animate_row_in_at_index(row_index)
	else:
		var target := _flash_box.global_position + _flash_box.size / 2.0
		await _animate_cloth_straight(from_rect, type_id, motive, target)
		_animate_price_label(target, int(result.price))
		await _animate_coins(target, int(result.price))
		_rebuild_requests()
	_refresh_workshop(slot_index)
	_slot_states[slot_index] = "idle"

func _request_portrait_center(row_index: int) -> Vector2:
	var children := _request_container.get_children()
	if row_index < 0 or row_index >= children.size():
		return Vector2(240, 300)
	var row: Control = children[row_index]
	return row.global_position + Vector2(41, 42)

func _animate_cloth_arc(from_rect: Rect2, type_id: int, motive: int, target: Vector2) -> void:
	var cloth := TextureRect.new()
	cloth.texture = ClothDatabase.clothing_texture(type_id, motive)
	cloth.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cloth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cloth.position = from_rect.position
	cloth.size = Vector2(80, 96)
	cloth.z_index = 1500
	add_child(cloth)
	var start_pos := cloth.position
	var mid_x := (start_pos.x + target.x) / 2.0
	var arc_height := -60.0
	var tw := create_tween()
	tw.tween_property(cloth, "position", Vector2(mid_x, start_pos.y + arc_height), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cloth, "position", target - Vector2(41, 42), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(cloth.queue_free)
	await tw.finished

func _animate_cloth_straight(from_rect: Rect2, type_id: int, motive: int, target: Vector2) -> void:
	var cloth := TextureRect.new()
	cloth.texture = ClothDatabase.clothing_texture(type_id, motive)
	cloth.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cloth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cloth.position = from_rect.position
	cloth.size = Vector2(80, 96)
	cloth.z_index = 1500
	add_child(cloth)
	var tw := create_tween()
	tw.tween_property(cloth, "position", target - Vector2(40, 48), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(cloth.queue_free)
	await tw.finished

func _animate_coins(from_pos: Vector2, price: int) -> void:
	var coin_icon := TextureRect.new()
	coin_icon.texture = COIN_TEX
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.position = from_pos - Vector2(16, 16)
	coin_icon.size = Vector2(32, 32)
	coin_icon.z_index = 1500
	add_child(coin_icon)
	var target_pos := _coin_label.global_position + Vector2(0, 16)
	var tw := create_tween()
	tw.tween_property(coin_icon, "position", target_pos - Vector2(8, 8), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(coin_icon, "scale", Vector2(0.3, 0.3), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(SfxManager.play_coin)
	tw.tween_callback(coin_icon.queue_free)
	await tw.finished

func _animate_price_label(from_pos: Vector2, price: int) -> void:
	var coin_label := Label.new()
	coin_label.text = "+%d" % price
	coin_label.add_theme_font_size_override("font_size", 20)
	coin_label.add_theme_color_override("font_color", Color.BLACK)
	coin_label.position = from_pos
	coin_label.z_index = 1600
	add_child(coin_label)
	var tw := create_tween()
	tw.tween_property(coin_label, "position:y", from_pos.y - 40, 0.7)
	tw.parallel().tween_property(coin_label, "modulate:a", 0.0, 0.7)
	tw.tween_callback(coin_label.queue_free)
	await tw.finished

func _animate_row_out(row: Control) -> void:
	var tw := create_tween()
	tw.tween_property(row, "position:x", 500.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

func _animate_row_in_at_index(row_index: int) -> void:
	var children := _request_container.get_children()
	if row_index < 0 or row_index >= children.size():
		return
	var row: Control = children[row_index]
	_animate_row_in(row)

func _on_buy_pressed(slot_index: int):
	if SaveManager.coins < BoutiqueManager.EXTENDED_COST:
		return
	_show_buy_confirm(slot_index)

func _show_buy_confirm(slot_index: int):
	if is_instance_valid(_confirm_popup):
		_confirm_popup.queue_free()
	var popup := Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.z_index = 1200
	_confirm_popup = popup
	add_child(popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dim)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.98, 0.93, 0.83, 1.0)))
	panel.position = Vector2(60, 350)
	panel.size = Vector2(360, 160)
	popup.add_child(panel)
	var label := Label.new()
	label.text = TranslationManager.tf("confirm_buy", [BoutiqueManager.EXTENDED_COST])
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(20, 20)
	label.size = Vector2(320, 60)
	label.add_theme_color_override("font_color", Color.BLACK)
	panel.add_child(label)
	var yes_btn := _make_button(GOLD_MEDIUM)
	yes_btn.text = TranslationManager.t("ok")
	yes_btn.size = Vector2(140, 44)
	yes_btn.position = Vector2(20, 96)
	panel.add_child(yes_btn)
	yes_btn.pressed.connect(_on_buy_confirmed.bind(slot_index, popup))
	var no_btn := _make_button(DARK_MEDIUM)
	no_btn.text = TranslationManager.t("cancel")
	no_btn.size = Vector2(140, 44)
	no_btn.position = Vector2(200, 96)
	panel.add_child(no_btn)
	no_btn.pressed.connect(func():
		if is_instance_valid(popup):
			popup.queue_free()
	)

func _on_buy_confirmed(slot_index: int, popup: Control):
	if BoutiqueManager.buy_slot(slot_index):
		if is_instance_valid(popup):
			popup.queue_free()
		_refresh_all()
		_refresh_workshop(slot_index)
		_slot_states[slot_index] = BoutiqueManager.workshop_slots()[slot_index].state
	else:
		if is_instance_valid(popup):
			popup.queue_free()

func _on_instant_coins_pressed():
	SfxManager.play_click()
	_show_instant_coins_popup()

func _show_instant_coins_popup():
	if is_instance_valid(_coin_popup):
		_coin_popup.queue_free()
	var popup := Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.z_index = 1200
	_coin_popup = popup
	add_child(popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dim)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.98, 0.93, 0.83, 1.0)))
	panel.position = Vector2(60, 200)
	panel.size = Vector2(360, 460)
	popup.add_child(panel)

	var title := Label.new()
	title.text = TranslationManager.t("instant_coins_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 14)
	title.size = Vector2(360, 30)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.BLACK)
	panel.add_child(title)

	var sku_keys := ["instant_coins_1", "instant_coins_2", "instant_coins_3"]
	var y := 56
	for i in range(sku_keys.size()):
		var btn := TextureButton.new()
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.texture_normal = load("res://assets/buttons/purchase_coins_%d.png" % (i + 1))
		btn.position = Vector2(40, y)
		btn.size = Vector2(280, 52)
		btn.pressed.connect(_on_coin_pack_pressed.bind(sku_keys[i], btn))
		panel.add_child(btn)
		if not IAPManager.is_products_ready():
			btn.disabled = true
		y += 60

	_iap_status = Label.new()
	_iap_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_iap_status.position = Vector2(0, y + 6)
	_iap_status.size = Vector2(360, 30)
	_iap_status.add_theme_font_size_override("font_size", 14)
	_iap_status.add_theme_color_override("font_color", Color(0.6, 0.1, 0.1))
	panel.add_child(_iap_status)
	if not IAPManager.is_products_ready():
		_iap_status.text = TranslationManager.t("iap_not_ready")

	var cancel_btn := _make_button(DARK_MEDIUM)
	cancel_btn.text = TranslationManager.t("cancel")
	cancel_btn.size = Vector2(160, 44)
	cancel_btn.position = Vector2((360 - 160) / 2.0, y + 46)
	cancel_btn.pressed.connect(_close_instant_coins_popup)
	panel.add_child(cancel_btn)

func _close_instant_coins_popup():
	if is_instance_valid(_coin_popup):
		_coin_popup.queue_free()
	_coin_popup = null
	_iap_status = null

func _on_billing_ready():
	if is_instance_valid(_iap_status):
		_iap_status.text = ""
	for child in _coin_popup.get_children() if is_instance_valid(_coin_popup) else []:
		if child is TextureButton:
			child.disabled = false

func _on_purchases_restored():
	var pending = IAPManager.get_pending_restorations()
	for p in pending:
		var sku = p["sku"]
		var token = p["token"]
		if SaveManager.is_purchase_processed(token):
			continue
		var reward = IAPConfig.get_coin_reward(sku)
		if reward > 0:
			SaveManager.add_coins(reward)
			SaveManager.mark_purchase_processed(token, sku)
			IAPManager.finalize_purchase(token, sku)

func _on_coin_pack_pressed(sku_key: String, btn: TextureButton):
	SfxManager.play_click()
	btn.disabled = true
	var sku = IAPConfig.get_sku(sku_key)
	var result = IAPManager.purchase(sku)
	match result:
		IAPManager.PurchaseResult.OK:
			if is_instance_valid(_iap_status):
				_iap_status.text = TranslationManager.t("iap_purchasing")
		IAPManager.PurchaseResult.NOT_INITIALIZED:
			if is_instance_valid(_iap_status):
				_iap_status.text = TranslationManager.t("iap_not_ready")
			btn.disabled = false
		_:
			if is_instance_valid(_iap_status):
				_iap_status.text = TranslationManager.t("iap_unavailable")
			btn.disabled = false
	IAPManager.purchase_successful.connect(_on_coin_purchase_success.bind(sku_key, btn), CONNECT_ONE_SHOT)
	IAPManager.purchase_failed.connect(_on_coin_purchase_failed.bind(btn), CONNECT_ONE_SHOT)

func _on_coin_purchase_success(sku: String, token: String, expected_sku_key: String, btn: TextureButton):
	if sku != IAPConfig.get_sku(expected_sku_key):
		return
	var reward = IAPConfig.get_coin_reward(sku)
	if reward > 0:
		SaveManager.add_coins(reward)
		SaveManager.mark_purchase_processed(token, sku)
	IAPManager.finalize_purchase(token, sku)
	if is_instance_valid(btn):
		btn.disabled = false
	_close_instant_coins_popup()

func _on_coin_purchase_failed(_sku: String, btn: TextureButton):
	if is_instance_valid(_iap_status):
		_iap_status.text = TranslationManager.t("iap_purchase_failed")
	if is_instance_valid(btn):
		btn.disabled = false

func _on_language_changed(_lang: String):
	_refresh_header()
	_rebuild_requests()
	for i in range(_workshop_panels.size()):
		_refresh_workshop(i)

func _notification(what: int):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_exit_pressed()

func _on_exit_pressed():
	await UiTransition.fade_out(0.2)
	SceneManager.fade_in_menu = true
	SceneManager.go_to_level_track()
