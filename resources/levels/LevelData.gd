class_name LevelData

static func types_in_play(level: int) -> int:
	return mini(6 + int((level - 1) / 10), 56)

static func tile_count(level: int) -> int:
	return 3 * types_in_play(level)

static func max_pile_depth(level: int) -> int:
	if level <= 4:
		return 2
	if level <= 24:
		return 3
	return 4

static func spread(level: int) -> int:
	if level <= 9:
		return 1
	if level <= 19:
		return 2
	return 3

static func seconds_per_tile(level: int) -> float:
	if level <= 10:
		return 2.0
	if level <= 20:
		return 1.9
	return 1.8

static func time_limit(level: int) -> float:
	return maxf(seconds_per_tile(level) * tile_count(level) - 10.0, 1.0)

static func default_types(level: int) -> Array:
	var out := []
	var n := types_in_play(level)
	for i in range(n):
		out.append(i)
	return out

static func unlocked_types(max_level: int) -> Array:
	var out := []
	var n := types_in_play(max_level)
	for i in range(n):
		out.append(i)
	return out

static func star_3_time(tile_count_value: int) -> float:
	return 2.5 * tile_count_value

static func star_2_time(tile_count_value: int) -> float:
	return 4.0 * tile_count_value
