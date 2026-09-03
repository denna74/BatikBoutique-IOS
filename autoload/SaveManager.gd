extends Node

var save_file_path := "user://batik_boutique.save"
const SAVE_PASSPHRASE := "BatikBoutique_S3cure_S4ve_2026"
const BLOCK_SIZE := 16

const SKILL_CONFIG := {
	"undo": {"price": 10000, "stock_granted": 3, "icon": "res://assets/skills/skill_undo.png"},
	"shuffle": {"price": 20000, "stock_granted": 3, "icon": "res://assets/skills/skill_reshuffle.png"},
	"remove3": {"price": 30000, "stock_granted": 3, "icon": "res://assets/skills/skill_remove_3.png"},
	"extra": {"price": 40000, "stock_granted": 3, "icon": "res://assets/skills/skill_add_tray.png"},
}

var max_level: int = 1
var stars: Dictionary = {}
var coins: int = 0
var skills: Dictionary = {"undo": 0, "shuffle": 0, "remove3": 0, "extra": 0}
var fabric: int = 0
var tile_fabrics: Dictionary = {}
var boutique: Dictionary = {}
var mood_level: int = 3
var last_failure_time: int = 0
var accumulated_gameplay_sec: float = 0.0
var processed_purchases: Dictionary = {}

var _session_start_time: int = 0

signal stars_changed(level: int, new_stars: int)
signal coins_changed(value: int)
signal mood_changed(new_mood: int)
signal skill_stock_changed(skill: String, new_stock: int)

func _ready():
	load_game()

func reset_to_defaults():
	max_level = 1
	stars = {}
	coins = 0
	skills = {"undo": 0, "shuffle": 0, "remove3": 0, "extra": 0}
	fabric = 0
	tile_fabrics = {}
	boutique = _default_boutique()
	mood_level = 3
	last_failure_time = 0
	accumulated_gameplay_sec = 0.0
	processed_purchases = {}

func _default_boutique() -> Dictionary:
	var slots := []
	for i in range(3):
		slots.append({"state": "idle", "type": 0, "motive": 0, "finish_at": 0.0, "upgrade": 0})
	return {"unlocked_slots": [], "requests": [], "slots": slots}

func add_coins(amount: int):
	coins += amount
	coins_changed.emit(coins)
	save_game()

func add_tile_fabric(type: int, amount: int):
	tile_fabrics[type] = int(tile_fabrics.get(type, 0)) + amount
	fabric += amount
	save_game()

func get_tile_fabric(type: int) -> int:
	return int(tile_fabrics.get(type, 0))

func get_stars(level: int) -> int:
	return stars.get(level, 0)

func complete_level(level: int, star_count: int):
	if level + 1 > max_level:
		max_level = level + 1
	if stars.get(level, 0) < star_count:
		stars[level] = star_count
		stars_changed.emit(level, star_count)
	save_game()

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		coins_changed.emit(coins)
		save_game()
		return true
	return false

func calculate_recovered_mood() -> int:
	if last_failure_time == 0:
		return 0
	var now = Time.get_unix_time_from_system()
	var elapsed = now - last_failure_time - accumulated_gameplay_sec
	return max(0, int(elapsed / 3600))

func apply_mood_recovery():
	var recovered = calculate_recovered_mood()
	if recovered > 0:
		mood_level = clampi(mood_level + recovered, 0, 3)
		mood_changed.emit(mood_level)
		if mood_level >= 3:
			last_failure_time = 0
			accumulated_gameplay_sec = 0.0
		save_game()

func get_seconds_until_next_mood() -> int:
	if last_failure_time == 0 or mood_level >= 3:
		return 0
	var now = Time.get_unix_time_from_system()
	var elapsed = now - last_failure_time - accumulated_gameplay_sec
	return max(0, 3600 - int(elapsed) % 3600)

func lose_mood():
	mood_level = max(0, mood_level - 1)
	last_failure_time = int(Time.get_unix_time_from_system())
	accumulated_gameplay_sec = 0.0
	mood_changed.emit(mood_level)
	save_game()

func on_gameplay_start():
	_session_start_time = int(Time.get_unix_time_from_system())

func on_gameplay_end():
	if _session_start_time > 0:
		var now = Time.get_unix_time_from_system()
		accumulated_gameplay_sec += now - _session_start_time
		_session_start_time = 0

func show_empty_mood_popup(parent: Control) -> ColorRect:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.anchor_left = 0
	overlay.anchor_top = 0
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var popup = Panel.new()
	var popup_bg := StyleBoxFlat.new()
	popup_bg.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	popup_bg.set_corner_radius_all(12)
	popup.add_theme_stylebox_override("panel", popup_bg)
	popup.anchor_left = 0.5
	popup.anchor_top = 0.5
	popup.anchor_right = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -130
	popup.offset_top = -85
	popup.offset_right = 130
	popup.offset_bottom = 85
	overlay.add_child(popup)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.anchor_left = 0
	vbox.anchor_top = 0
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.offset_left = 15
	vbox.offset_top = 12
	vbox.offset_right = -15
	vbox.offset_bottom = -12
	popup.add_child(vbox)

	var tm := get_node("/root/TranslationManager")
	var label1 = Label.new()
	label1.text = tm.t("mood_empty_title")
	label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label1.add_theme_font_size_override("font_size", 14)
	vbox.add_child(label1)

	var label2 = Label.new()
	label2.text = tm.t("mood_empty_desc")
	label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label2.add_theme_font_size_override("font_size", 11)
	vbox.add_child(label2)

	var label3 = Label.new()
	label3.text = tm.t("mood_empty_countdown")
	label3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label3.add_theme_font_size_override("font_size", 11)
	vbox.add_child(label3)

	var time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(time_label)

	var btn_w = 76
	var btn_h = 26
	var ok_btn = Button.new()
	ok_btn.text = tm.t("ok")
	ok_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	ok_btn.add_theme_font_size_override("font_size", 16)
	for color_name in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		ok_btn.add_theme_color_override(color_name, Color(0, 0, 0, 1))
	var gold_style := StyleBoxTexture.new()
	gold_style.texture = load("res://assets/buttons/gold_small.png")
	gold_style.content_margin_left = 16
	gold_style.content_margin_top = 8
	gold_style.content_margin_right = 16
	gold_style.content_margin_bottom = 8
	ok_btn.add_theme_stylebox_override("normal", gold_style)
	ok_btn.add_theme_stylebox_override("pressed", gold_style)
	ok_btn.add_theme_stylebox_override("hover", gold_style)
	ok_btn.pressed.connect(func():
		get_node("/root/SfxManager").play_click()
		overlay.queue_free()
	)

	var btn_center = CenterContainer.new()
	btn_center.add_child(ok_btn)
	vbox.add_child(btn_center)

	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = false
	popup.add_child(timer)

	var update_time = func():
		var secs = get_seconds_until_next_mood()
		var m = secs / 60
		var s = secs % 60
		time_label.text = "%02d:%02d" % [m, s]
		if secs <= 0:
			timer.stop()

	timer.timeout.connect(update_time)
	update_time.call()
	timer.start()

	overlay.tree_exiting.connect(timer.stop)
	return overlay

func add_skill_stock(skill: String, amount: int):
	if skills.has(skill):
		skills[skill] += amount
		skill_stock_changed.emit(skill, skills[skill])
		save_game()

func use_skill(skill: String) -> bool:
	if skills.has(skill) and skills[skill] > 0:
		skills[skill] -= 1
		skill_stock_changed.emit(skill, skills[skill])
		save_game()
		return true
	return false

func get_skill_stock(skill: String) -> int:
	return skills.get(skill, 0)

func is_purchase_processed(token: String) -> bool:
	return processed_purchases.has(token)

func mark_purchase_processed(token: String, sku: String):
	processed_purchases[token] = {
		"sku": sku,
		"timestamp": Time.get_unix_time_from_system()
	}
	save_game()

func _derive_key() -> PackedByteArray:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(SAVE_PASSPHRASE.to_utf8_buffer())
	return ctx.finish()

func _pkcs7_pad(data: PackedByteArray) -> PackedByteArray:
	var pad_len = BLOCK_SIZE - (data.size() % BLOCK_SIZE)
	var padded = data.duplicate()
	for i in range(pad_len):
		padded.append(pad_len)
	return padded

func _pkcs7_unpad(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return data
	var pad_len = data[data.size() - 1]
	if pad_len < 1 or pad_len > BLOCK_SIZE:
		return data
	return data.slice(0, data.size() - pad_len)

func save_game():
	var data = {
		"max_level": max_level,
		"stars": stars,
		"coins": coins,
		"skills": skills,
		"fabric": fabric,
		"tile_fabrics": tile_fabrics,
		"boutique": boutique,
		"mood_level": mood_level,
		"last_failure_time": last_failure_time,
		"accumulated_gameplay_sec": accumulated_gameplay_sec,
		"processed_purchases": processed_purchases,
	}
	var json_str = JSON.stringify(data)
	var plaintext = json_str.to_utf8_buffer()

	var padded = _pkcs7_pad(plaintext)

	var iv = PackedByteArray()
	for i in range(BLOCK_SIZE):
		iv.append(randi() % 256)

	var key = _derive_key()
	var aes = AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv)
	var ciphertext = aes.update(padded)
	aes.finish()

	var hash_ctx = HashingContext.new()
	hash_ctx.start(HashingContext.HASH_SHA256)
	hash_ctx.update(iv)
	hash_ctx.update(ciphertext)
	var hash = hash_ctx.finish()

	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		file.store_buffer(iv)
		file.store_buffer(ciphertext)
		file.store_buffer(hash)
	else:
		push_error("SaveManager: Could not open save file for writing")

func load_game() -> bool:
	if not FileAccess.file_exists(save_file_path):
		reset_to_defaults()
		return false

	var file = FileAccess.open(save_file_path, FileAccess.READ)
	if not file:
		reset_to_defaults()
		return false

	var all_data = file.get_buffer(file.get_length())
	if all_data.size() < BLOCK_SIZE + 32:
		reset_to_defaults()
		return false

	var iv = all_data.slice(0, BLOCK_SIZE)
	var hash = all_data.slice(all_data.size() - 32, all_data.size())
	var ciphertext = all_data.slice(BLOCK_SIZE, all_data.size() - 32)

	var hash_ctx = HashingContext.new()
	hash_ctx.start(HashingContext.HASH_SHA256)
	hash_ctx.update(iv)
	hash_ctx.update(ciphertext)
	var computed_hash = hash_ctx.finish()
	if computed_hash != hash:
		reset_to_defaults()
		return false

	var key = _derive_key()
	var aes = AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, key, iv)
	var padded = aes.update(ciphertext)
	aes.finish()

	var plaintext = _pkcs7_unpad(padded)
	var json_str = plaintext.get_string_from_utf8()
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		reset_to_defaults()
		return false

	_apply_save_data(parsed)
	return true

func _apply_save_data(parsed: Dictionary):
	max_level = parsed.get("max_level", 1)
	stars = {}
	var loaded_stars = parsed.get("stars", {})
	if loaded_stars is Dictionary:
		for lvl_key in loaded_stars.keys():
			if lvl_key is String and lvl_key.is_valid_int():
				stars[lvl_key.to_int()] = loaded_stars[lvl_key]
			else:
				stars[lvl_key] = loaded_stars[lvl_key]
	coins = parsed.get("coins", 0)
	skills = {"undo": 0, "shuffle": 0, "remove3": 0, "extra": 0}
	var loaded_skills = parsed.get("skills", {})
	if loaded_skills is Dictionary:
		for key in loaded_skills:
			skills[key] = loaded_skills[key]
	fabric = parsed.get("fabric", 0)
	tile_fabrics = {}
	var loaded_tile_fabrics = parsed.get("tile_fabrics", {})
	if loaded_tile_fabrics is Dictionary:
		for key in loaded_tile_fabrics:
			if key is String and key.is_valid_int():
				tile_fabrics[key.to_int()] = loaded_tile_fabrics[key]
			else:
				tile_fabrics[key] = loaded_tile_fabrics[key]
	var loaded_boutique = parsed.get("boutique", {})
	if loaded_boutique is Dictionary and not loaded_boutique.is_empty():
		boutique = loaded_boutique
	else:
		boutique = _default_boutique()
	mood_level = clampi(parsed.get("mood_level", 3), 0, 3)
	last_failure_time = int(parsed.get("last_failure_time", 0))
	accumulated_gameplay_sec = float(parsed.get("accumulated_gameplay_sec", 0.0))
	var loaded_purchases = parsed.get("processed_purchases", {})
	if loaded_purchases is Dictionary:
		processed_purchases = loaded_purchases
	else:
		processed_purchases = {}
	apply_mood_recovery()
	if boutique.get("unlocked_slots") is Array:
		var norm := []
		for s in boutique["unlocked_slots"]:
			norm.append(int(s))
		boutique["unlocked_slots"] = norm
