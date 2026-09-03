extends TextureRect
class_name BatikTile

const PALETTE := [
	Color(0.90, 0.30, 0.30),
	Color(0.25, 0.55, 0.90),
	Color(0.30, 0.70, 0.35),
	Color(0.95, 0.70, 0.20),
	Color(0.60, 0.35, 0.85),
	Color(0.20, 0.75, 0.75),
	Color(0.90, 0.45, 0.65),
	Color(0.55, 0.45, 0.30),
	Color(0.75, 0.25, 0.60),
	Color(0.45, 0.65, 0.25),
	Color(0.85, 0.60, 0.45),
	Color(0.35, 0.45, 0.80),
]

var tile_type: int = -1

@onready var number_label: Label = $Center/NumberLabel

func setup(type_index: int, p_size: float):
	tile_type = type_index
	custom_minimum_size = Vector2(p_size, p_size)
	size = Vector2(p_size, p_size)
	var styled: Texture2D = TileArt.get_texture(type_index)
	if styled != null:
		texture = styled
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		number_label.text = ""
	else:
		texture = _make_placeholder(type_index, int(p_size))
		stretch_mode = TextureRect.STRETCH_KEEP
		number_label.text = str(type_index + 1)
		number_label.add_theme_font_size_override("font_size", int(p_size * 0.45))

func _make_placeholder(type_index: int, size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(PALETTE[type_index % PALETTE.size()])
	var border := 3
	for x in range(size):
		for y in range(size):
			if x < border or y < border or x >= size - border or y >= size - border:
				img.set_pixel(x, y, Color(1, 1, 1, 0.75))
	return ImageTexture.create_from_image(img)

func set_accessible(acc: bool):
	modulate = Color(1, 1, 1, 1) if acc else Color(0.55, 0.55, 0.55, 1)
