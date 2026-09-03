class_name GalleryDescriptions

const DESCRIPTIONS_PATH := "res://resources/gallery/batik_descriptions.json"

static var _descriptions: Dictionary = _load()

static func _load() -> Dictionary:
	var file := FileAccess.open(DESCRIPTIONS_PATH, FileAccess.READ)
	if file == null:
		push_error("GalleryDescriptions: cannot open %s" % DESCRIPTIONS_PATH)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	var out := {}
	for tile_str in parsed:
		if tile_str.is_valid_int() and parsed[tile_str] is Dictionary:
			out[tile_str.to_int()] = parsed[tile_str]
	return out

static func has_description(tile_id: int) -> bool:
	return _descriptions.has(tile_id)

static func get_description(tile_id: int, lang: String = "en") -> String:
	if not _descriptions.has(tile_id):
		return ""
	return _descriptions[tile_id].get("id", "") if lang == "id" else _descriptions[tile_id].get("en", "")
