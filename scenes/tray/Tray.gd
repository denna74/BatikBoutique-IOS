extends Control
class_name TileTray

signal tray_changed()
signal matched(type: int)
signal returned_tile()

const SLOT_SIZE := 52.0
const SLOT_GAP := 8.0
const SLOT_Y := 20.0
const MAX_SLOTS := 8
const TRAY_TILE_SIZE := 48.0

var capacity := 7
var pending_match := false
var slots: Array = []

var _last_placed := -1
var _last_action_was_match := false
var _pending_matches := 0
var _slot_cells: Array = []


func setup():
	for s in slots:
		if s != null and is_instance_valid(s.node):
			s.node.queue_free()
	slots.clear()
	_pending_matches = 0
	pending_match = false
	for i in range(capacity):
		slots.append(null)
	_build_cells()

func _build_cells():
	for c in _slot_cells:
		if is_instance_valid(c):
			c.queue_free()
	_slot_cells.clear()
	for i in range(capacity):
		var cell := ColorRect.new()
		cell.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		cell.position = _slot_local_pos(i)
		cell.color = Color(0, 0, 0, 0.18)
		add_child(cell)
		_slot_cells.append(cell)

func _slot_local_pos(index: int) -> Vector2:
	var x := (size.x - (capacity * SLOT_SIZE + (capacity - 1) * SLOT_GAP)) / 2.0
	return Vector2(x + index * (SLOT_SIZE + SLOT_GAP), SLOT_Y)

func _slot_global_center(index: int) -> Vector2:
	return _slot_local_pos(index) + global_position + Vector2(SLOT_SIZE, SLOT_SIZE) * 0.5

func _non_matched_count(type: int) -> int:
	var c := 0
	for s in slots:
		if s != null and s.type == type:
			c += 1
	return c

func _first_free() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1

func can_add(type: int) -> bool:
	if _non_matched_count(type) >= 2:
		return true
	return _first_free() >= 0

func _target_slot_for(type: int) -> int:
	for i in range(slots.size()):
		if slots[i] != null and slots[i].type == type:
			if i + 1 < slots.size() and slots[i + 1] == null:
				return i + 1
			if i - 1 >= 0 and slots[i - 1] == null:
				return i - 1
	return _first_free()

func get_placement_global(type: int) -> Vector2:
	var idx := _target_slot_for(type)
	if idx == -1:
		return global_position + size * 0.5
	return _slot_global_center(idx)

func fly_and_place(entry: Dictionary, board_ref: Node) -> Tween:
	if not can_add(entry.type):
		return null
	var target := _target_slot_for(entry.type)
	if target == -1:
		return null

	_kill_orphaned_nodes()

	var node: BatikTile = entry.node
	board_ref.mark_tile_taken(entry)
	slots[target] = {
		"type": entry.type,
		"node": node,
		"board_pos": entry.pos,
		"board_ref": board_ref,
		"board_entry": entry,
	}

	if node.get_parent() != self:
		node.reparent(self, true)
	node.z_index = 1000
	node.scale = Vector2.ONE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "global_position", _slot_global_center(target) - Vector2(TRAY_TILE_SIZE, TRAY_TILE_SIZE) * 0.5, 0.18)
	tw.tween_property(node, "custom_minimum_size", Vector2(TRAY_TILE_SIZE, TRAY_TILE_SIZE), 0.18)
	tw.tween_property(node, "size", Vector2(TRAY_TILE_SIZE, TRAY_TILE_SIZE), 0.18)
	tw.chain().tween_callback(_finish_place.bind(target))
	return tw

func add_tile(entry: Dictionary, board_ref: Node) -> bool:
	if not can_add(entry.type):
		return false
	var target := _target_slot_for(entry.type)
	if target == -1:
		return false

	_kill_orphaned_nodes()

	var node: BatikTile = entry.node
	board_ref.mark_tile_taken(entry)
	slots[target] = {
		"type": entry.type,
		"node": node,
		"board_pos": entry.pos,
		"board_ref": board_ref,
		"board_entry": entry,
	}

	if node.get_parent() != self:
		node.reparent(self, true)
	node.z_index = 1000
	node.scale = Vector2.ONE
	node.custom_minimum_size = Vector2(TRAY_TILE_SIZE, TRAY_TILE_SIZE)
	node.size = Vector2(TRAY_TILE_SIZE, TRAY_TILE_SIZE)
	node.global_position = _slot_global_center(target) - Vector2(TRAY_TILE_SIZE, TRAY_TILE_SIZE) * 0.5
	_finish_place(target)
	return true

func _kill_orphaned_nodes():
	for child in get_children():
		if child is BatikTile:
			var is_active := false
			for s in slots:
				if s != null and s.node == child:
					is_active = true
					break
			if not is_active:
				child.queue_free()

func _finish_place(target: int):
	if target >= slots.size() or slots[target] == null:
		return
	_last_placed = target
	_last_action_was_match = false
	_check_match(slots[target].type)
	tray_changed.emit()

func _check_match(type: int):
	var matching := []
	for i in range(slots.size()):
		if slots[i] != null and slots[i].type == type:
			matching.append(i)
	if matching.size() >= 3:
		_pending_matches += 1
		pending_match = true
		_last_action_was_match = true
		_last_placed = -1
		var info := {"type": type, "indices": [matching[0], matching[1], matching[2]]}
		get_tree().create_timer(0.25).timeout.connect(_do_match.bind(info))

func _do_match(info: Dictionary):
	_pending_matches -= 1
	pending_match = _pending_matches > 0
	var nodes_to_free := []
	for i in info.indices:
		if i >= slots.size() or slots[i] == null or slots[i].type != info.type:
			continue
		var s = slots[i]
		var node: BatikTile = s.node
		if node != null and is_instance_valid(node):
			nodes_to_free.append(node)
			var tw := create_tween().set_parallel()
			tw.tween_property(node, "scale", Vector2(1.25, 1.25), 0.15)
			tw.tween_property(node, "modulate:a", 0.0, 0.3)
			tw.tween_property(node, "position", node.position + Vector2(0, -30), 0.3)
	for i in info.indices:
		if i < slots.size() and slots[i] != null and slots[i].type == info.type:
			slots[i] = null
	if nodes_to_free.size() < 3:
		return
	tray_changed.emit()
	matched.emit(info.type)
	await get_tree().create_timer(0.35).timeout
	for node in nodes_to_free:
		if is_instance_valid(node):
			node.queue_free()

func undo_last() -> bool:
	if _last_action_was_match or _last_placed < 0:
		return false
	var i := _last_placed
	if i >= slots.size() or slots[i] == null:
		_last_placed = -1
		return false
	var s: Dictionary = slots[i]
	var board: Node = s.board_ref
	board.return_tile(s.board_entry)
	slots[i] = null
	_last_placed = -1
	tray_changed.emit()
	returned_tile.emit()
	return true

func expand_capacity():
	if capacity >= MAX_SLOTS:
		return
	capacity += 1
	slots.append(null)
	var cell := ColorRect.new()
	cell.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	cell.color = Color(0, 0, 0, 0.18)
	add_child(cell)
	_slot_cells.append(cell)
	for i in range(_slot_cells.size()):
		_slot_cells[i].position = _slot_local_pos(i)
	for i in range(slots.size() - 1):
		if slots[i] != null and is_instance_valid(slots[i].node):
			slots[i].node.position = _slot_local_pos(i) + (Vector2(SLOT_SIZE, SLOT_SIZE) - slots[i].node.size) / 2.0
	tray_changed.emit()

func unmatched_count() -> int:
	var c := 0
	for s in slots:
		if s != null:
			c += 1
	return c

func is_full() -> bool:
	return _first_free() == -1 and not pending_match
