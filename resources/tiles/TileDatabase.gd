class_name TileDatabase

static var _entries: Array = _load()

static func _load() -> Array:
	var file = FileAccess.open("res://resources/tiles/batik_tiles.json", FileAccess.READ)
	if not file:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Array else []

static func get_count() -> int:
	return _entries.size()

static func get_entry(index: int) -> Dictionary:
	return _entries[index] if index >= 0 and index < _entries.size() else {}

static func get_batik_name(index: int, lang: String = "en") -> String:
	var e = get_entry(index)
	if e.is_empty():
		return "Batik %d" % index
	if lang == "id":
		return e.get("name_id", e.get("name_en", "Batik %d" % index))
	return e.get("name_en", "Batik %d" % index)

static func get_catalog_name(index: int, lang: String = "en") -> String:
	var e = get_entry(index)
	if e.is_empty():
		return "Batik %d" % index
	if lang == "id":
		return e.get("catalog_id", e.get("catalog_en", "Batik %d" % index))
	return e.get("catalog_en", "Batik %d" % index)

static func get_texture_path(index: int) -> String:
	return "res://assets/tiles/tile_%02d.png" % index
