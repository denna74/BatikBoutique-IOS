extends Control
class_name GameBoard

const TileScene := preload("res://scenes/board/Tile.tscn")

signal tile_tapped(entry: Dictionary)
signal board_cleared()
signal tile_solved(type: int)

var layout: Dictionary = {}
var _entries: Array = []
var blocked_input := false

func setup(level: int, combination: Array):
	clear_board()
	layout = BoardGenerator.generate(level, combination)
	for t in layout.tiles:
		var node: BatikTile = TileScene.instantiate()
		add_child(node)
		node.setup(t.type, BoardGenerator.TILE_SIZE)
		node.position = t.pos
		node.z_index = t.z
		_entries.append({
			"node": node,
			"type": t.type,
			"pos": t.pos,
			"z": t.z,
			"removed": false,
		})
	_update_accessibility()

func clear_board():
	for e in _entries:
		if e.node != null and is_instance_valid(e.node):
			e.node.queue_free()
	_entries = []
	layout = {}

func remaining_count() -> int:
	var n := 0
	for e in _entries:
		if not e.removed:
			n += 1
	return n

func _gui_input(event):
	if blocked_input:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var e: Dictionary = _topmost_at(event.position)
		if e.is_empty():
			return
		if BoardGenerator.is_tile_accessible(e, _entries):
			tile_tapped.emit(e)

func _topmost_at(point: Vector2) -> Dictionary:
	var best := {}
	var best_z := -INF
	for e in _entries:
		if e.removed:
			continue
		if Rect2(e.pos, Vector2(BoardGenerator.TILE_SIZE, BoardGenerator.TILE_SIZE)).has_point(point):
			if e.z > best_z:
				best_z = e.z
				best = e
	return best

func _update_accessibility():
	for e in _entries:
		if not e.removed and e.node != null and is_instance_valid(e.node):
			e.node.set_accessible(BoardGenerator.is_tile_accessible(e, _entries))

func fly_tile_to(entry: Dictionary, target_global: Vector2) -> Tween:
	var node: BatikTile = entry.node
	node.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	var tw := create_tween()
	tw.tween_property(node, "global_position", target_global - node.size * 0.5, 0.22)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	return tw

func return_tile(entry: Dictionary):
	var node: BatikTile = entry.node
	if node.get_parent() != self:
		node.reparent(self, true)
	node.scale = Vector2.ONE
	node.custom_minimum_size = Vector2(BoardGenerator.TILE_SIZE, BoardGenerator.TILE_SIZE)
	node.size = Vector2(BoardGenerator.TILE_SIZE, BoardGenerator.TILE_SIZE)
	node.modulate = Color.WHITE
	node.z_index = entry.z
	node.position = entry.pos
	entry.removed = false
	_update_accessibility()

func mark_tile_taken(entry: Dictionary):
	entry.removed = true
	_update_accessibility()
	if remaining_count() == 0:
		board_cleared.emit()

func do_shuffle(level: int):
	var active := []
	for e in _entries:
		if not e.removed:
			active.append(e)
	if active.is_empty():
		return
	var new_layout := BoardGenerator.shuffle_remaining(_types_of(active), level)
	active.shuffle()
	for k in range(new_layout.tiles.size()):
		var e: Dictionary = active[k]
		var t: Dictionary = new_layout.tiles[k]
		e.pos = t.pos
		e.z = t.z
		var node: BatikTile = e.node
		node.z_index = t.z
		var tw := create_tween()
		tw.tween_property(node, "position", t.pos, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_update_accessibility()

func remove_triple() -> int:
	var chosen := BoardGenerator.choose_remove_type(_entries)
	if chosen == -1:
		return 0
	var removed_entries := []
	var removed := 0
	for e in _entries:
		if not e.removed and e.type == chosen:
			e.removed = true
			var node: BatikTile = e.node
			var tw := create_tween().set_parallel()
			tw.tween_property(node, "scale", Vector2(1.3, 1.3), 0.1)
			tw.tween_property(node, "modulate:a", 0.0, 0.25)
			tw.tween_property(node, "position", node.position + Vector2(0, -40), 0.25)
			removed_entries.append(e)
			removed += 1
	await get_tree().create_timer(0.3).timeout
	for e in removed_entries:
		if e.node != null and is_instance_valid(e.node):
			e.node.queue_free()
			e.node = null
	_update_accessibility()
	tile_solved.emit(chosen)
	if remaining_count() == 0:
		board_cleared.emit()
	return removed

func _types_of(entries: Array) -> Array:
	var out := []
	for e in entries:
		out.append(e.type)
	return out

func set_blocked(b: bool):
	blocked_input = b
