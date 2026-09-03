class_name ClothDatabase

const CATALOG_PATH := "res://assets/clothing/clothing_catalog.json"
const ICON_BASE := "res://assets/icons_cloth/"
const CLOTHING_BASE := "res://assets/clothing/"

static var _types: Array = [
	{"id": 0, "key": "dress", "name_en": "Dress", "name_id": "Gaun", "fabric": 35, "seconds": 105, "icon": "icon_dress.png"},
	{"id": 1, "key": "pants", "name_en": "Pants", "name_id": "Celana", "fabric": 15, "seconds": 45, "icon": "icon_pants.png"},
	{"id": 2, "key": "shawl", "name_en": "Shawl", "name_id": "Selendang", "fabric": 20, "seconds": 60, "icon": "icon_shawl.png"},
	{"id": 3, "key": "shirt_long", "name_en": "Man Long Shirt", "name_id": "Baju Panjang Pria", "fabric": 22, "seconds": 66, "icon": "icon_shirt_man_long.png"},
	{"id": 4, "key": "shirt_short", "name_en": "Man Short Shirt", "name_id": "Baju Pendek Pria", "fabric": 17, "seconds": 51, "icon": "icon_shirt_man_short.png"},
	{"id": 5, "key": "shirt_woman", "name_en": "Woman Shirt", "name_id": "Baju Wanita", "fabric": 21, "seconds": 63, "icon": "icon_shirt_woman.png"},
	{"id": 6, "key": "skirt", "name_en": "Skirt", "name_id": "Rok", "fabric": 16, "seconds": 48, "icon": "icon_skirt.png"},
]

static var _catalog: Dictionary = _load_catalog()

static func _load_catalog() -> Dictionary:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("ClothDatabase: cannot open catalog %s" % CATALOG_PATH)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	var out := {}
	for type_key in parsed:
		var section = parsed[type_key]
		if section is Dictionary and section.get("entries", {}) is Dictionary:
			var entries := {}
			for tile_str in section["entries"]:
				if tile_str.is_valid_int():
					entries[tile_str.to_int()] = section["entries"][tile_str]
			out[type_key] = entries
	return out

static func get_type_count() -> int:
	return _types.size()

static func get_type(type_id: int) -> Dictionary:
	for t in _types:
		if t.id == type_id:
			return t
	return {}

static func get_type_by_key(key: String) -> Dictionary:
	for t in _types:
		if t.key == key:
			return t
	return {}

static func type_name(type_id: int, lang: String = "en") -> String:
	var t := get_type(type_id)
	if t.is_empty():
		return ""
	return t.name_id if lang == "id" else t.name_en

static func type_icon(type_id: int) -> Texture2D:
	var t := get_type(type_id)
	if t.is_empty():
		return null
	return load(ICON_BASE + t.icon)

static func type_fabric(type_id: int) -> int:
	return get_type(type_id).get("fabric", 0)

static func type_seconds(type_id: int) -> int:
	return get_type(type_id).get("seconds", 0)

static func clothing_filename(type_id: int, tile_id: int) -> String:
	var t := get_type(type_id)
	if t.is_empty():
		return ""
	return _catalog.get(t.key, {}).get(tile_id, "")

static func has_clothing(type_id: int, tile_id: int) -> bool:
	return not clothing_filename(type_id, tile_id).is_empty()

static func clothing_texture(type_id: int, tile_id: int) -> Texture2D:
	var t := get_type(type_id)
	if t.is_empty():
		return null
	var fname := clothing_filename(type_id, tile_id)
	if fname.is_empty():
		return null
	return load(CLOTHING_BASE + t.key + "/" + fname)

static func motives_for_type(type_id: int) -> Array:
	var t := get_type(type_id)
	if t.is_empty():
		return []
	var out := []
	for tile_id in _catalog.get(t.key, {}).keys():
		out.append(int(tile_id))
	out.sort()
	return out
