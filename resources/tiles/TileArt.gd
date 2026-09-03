class_name TileArt

const BAKE_SIZE := 128
const BORDER := 6
const RADIUS := 14
const INNER_SIZE := BAKE_SIZE - 2 * BORDER

static var _cache: Dictionary = {}
static var _mask := PackedByteArray()
static var _mask_built := false

static func raw_path(index: int) -> String:
	return "res://assets/tiles/raw/tile_%02d.png" % index

static func _ensure_mask() -> PackedByteArray:
	if not _mask_built:
		_mask = _build_mask()
		_mask_built = true
	return _mask

static func _build_mask() -> PackedByteArray:
	var alpha := PackedByteArray()
	alpha.resize(BAKE_SIZE * BAKE_SIZE)
	var half := BAKE_SIZE * 0.5
	var inner := half - float(RADIUS)
	var r := float(RADIUS)
	for y in range(BAKE_SIZE):
		for x in range(BAKE_SIZE):
			var px := x + 0.5 - half
			var py := y + 0.5 - half
			var qx := absf(px) - inner
			var qy := absf(py) - inner
			var ox := maxf(qx, 0.0)
			var oy := maxf(qy, 0.0)
			var dist := sqrt(ox * ox + oy * oy) + mini(maxf(qx, qy), 0.0) - r
			alpha[y * BAKE_SIZE + x] = int(clampf(0.5 - dist, 0.0, 1.0) * 255.0)
	return alpha

static func get_texture(index: int) -> Texture2D:
	if _cache.has(index):
		return _cache[index]
	var img := _build_styled(index)
	if img == null:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[index] = tex
	return tex

static func is_cached(index: int) -> bool:
	return _cache.has(index)

static func generate(types: Array) -> void:
	for t in types:
		get_texture(int(t))

static func _build_styled(index: int) -> Image:
	var tex: Texture2D = load(raw_path(index))
	if tex == null:
		return null
	var src: Image = tex.get_image()
	if src == null:
		return null
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var side := mini(src.get_width(), src.get_height())
	var region := Rect2i((src.get_width() - side) / 2, (src.get_height() - side) / 2, side, side)
	var pattern := src.get_region(region)
	pattern.resize(INNER_SIZE, INNER_SIZE, Image.INTERPOLATE_LANCZOS)

	var out := Image.create(BAKE_SIZE, BAKE_SIZE, false, Image.FORMAT_RGBA8)
	out.fill(Color.WHITE)
	var data := out.get_data()
	var pat := pattern.get_data()
	for y in range(INNER_SIZE):
		var dst_base := (y + BORDER) * BAKE_SIZE + BORDER
		for x in range(INNER_SIZE):
			var src_idx := (y * INNER_SIZE + x) * 4
			var dst_idx := (dst_base + x) * 4
			data[dst_idx] = pat[src_idx]
			data[dst_idx + 1] = pat[src_idx + 1]
			data[dst_idx + 2] = pat[src_idx + 2]
			data[dst_idx + 3] = pat[src_idx + 3]
	var mask := _ensure_mask()
	for y in range(BAKE_SIZE):
		var base := y * BAKE_SIZE
		for x in range(BAKE_SIZE):
			var idx := (base + x) * 4
			data[idx + 3] = mini(int(data[idx + 3]), int(mask[base + x]))
	out.set_data(BAKE_SIZE, BAKE_SIZE, false, Image.FORMAT_RGBA8, data)
	return out
