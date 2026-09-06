class_name BoutiqueManager

const REQUEST_COUNT := 3
const SLOT_COUNT := 3
const EXTENDED_COST := 50000
const MAX_EXTENDED := 2
const UPGRADE_COSTS := {1: 50000, 2: 100000}
const TIME_MULTIPLIERS := {0: 1.0, 1: 0.5, 2: 0.1}

static func batik_value(tile_id: int) -> int:
	if tile_id <= 5:   return 5
	if tile_id <= 14:  return 7
	if tile_id <= 23:  return 9
	if tile_id <= 31:  return 10
	if tile_id <= 40:  return 12
	if tile_id <= 49:  return 13
	return 15

static func _save() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("SaveManager")
	return null

static func _translation() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("TranslationManager")
	return null

static func ensure_state():
	var sm := _save()
	if sm == null:
		return
	var b: Dictionary = sm.boutique
	var raw_unlocked: Array = b.get("unlocked_slots") if b.get("unlocked_slots") is Array else []
	var unlocked := []
	for s in raw_unlocked:
		unlocked.append(int(s))
	if unlocked.is_empty() and b.has("extended_workshops"):
		var count := int(b.get("extended_workshops", 0))
		for i in range(1, count + 1):
			unlocked.append(i)
	b["unlocked_slots"] = unlocked
	b.erase("extended_workshops")
	if not b.has("requests") or not (b["requests"] is Array):
		b["requests"] = []
	if not b.has("slots") or not (b["slots"] is Array):
		b["slots"] = []
	while b["slots"].size() < SLOT_COUNT:
		b["slots"].append({"state": "idle", "type": 0, "motive": 0, "finish_at": 0.0})
	for slot in b["slots"]:
		if not slot.has("state"):
			slot["state"] = "idle"
		if not slot.has("type"):
			slot["type"] = 0
		if not slot.has("motive"):
			slot["motive"] = 0
		if not slot.has("finish_at"):
			slot["finish_at"] = 0.0
		if not slot.has("upgrade"):
			slot["upgrade"] = 0

static func request_slots() -> Array:
	ensure_state()
	var sm := _save()
	if sm == null:
		return []
	fill_requests()
	return sm.boutique["requests"]

static func workshop_slots() -> Array:
	ensure_state()
	var sm := _save()
	return sm.boutique["slots"] if sm != null else []

static func extended_workshops() -> int:
	ensure_state()
	var sm := _save()
	if sm == null:
		return 0
	return (sm.boutique["unlocked_slots"] as Array).size()

static func slot_unlocked(slot_index: int) -> bool:
	ensure_state()
	var sm := _save()
	if sm == null:
		return slot_index == 0
	if slot_index == 0:
		return true
	return slot_index in (sm.boutique["unlocked_slots"] as Array)

static func npc_files() -> Array:
	var out := []
	var i := 1
	while true:
		var filename := "npc_%02d.png" % i
		if not ResourceLoader.exists("res://assets/npc/%s" % filename):
			break
		out.append(filename)
		i += 1
	return out

static func motive_pool(type_id: int) -> Array:
	var sm := _save()
	var unlocked := LevelData.unlocked_types(sm.max_level if sm != null else 1)
	var out := []
	for tile_id in unlocked:
		if ClothDatabase.has_clothing(type_id, int(tile_id)):
			out.append(int(tile_id))
	return out

static func _generate_request(exclude_motives: Array = []) -> Dictionary:
	var sm := _save()
	var npcs := npc_files()
	var used_motives := {}
	var used_npcs := {}
	if sm != null:
		var existing: Array = sm.boutique.get("requests", [])
		for r in existing:
			used_motives[int(r.motive)] = true
			used_npcs[r.npc] = true
	for m in exclude_motives:
		used_motives[int(m)] = true
	for attempt in range(64):
		var type_id := randi() % ClothDatabase.get_type_count()
		var pool := motive_pool(type_id)
		if pool.is_empty():
			continue
		var motive: int = pool[randi() % pool.size()]
		if used_motives.has(motive):
			continue
		var npc_pool := []
		for f in npcs:
			if not used_npcs.has(f):
				npc_pool.append(f)
		if npc_pool.is_empty():
			npc_pool = npcs
		var npc: String = "npc_01.png" if npc_pool.is_empty() else npc_pool[randi() % npc_pool.size()]
		return {"npc": npc, "type": type_id, "motive": motive}
	return {}

static func _generate_teaser() -> Dictionary:
	var sm := _save()
	if sm == null:
		return {}
	var next_motif := LevelData.types_in_play(sm.max_level if sm != null else 1)
	if next_motif >= 56:
		return {}
	var npcs := npc_files()
	var used_npcs := {}
	var existing: Array = sm.boutique.get("requests", [])
	for r in existing:
		used_npcs[r.npc] = true
	var npc_pool := []
	for f in npcs:
		if not used_npcs.has(f):
			npc_pool.append(f)
	if npc_pool.is_empty():
		npc_pool = npcs
	var npc: String = "npc_01.png" if npc_pool.is_empty() else npc_pool[randi() % npc_pool.size()]
	var type_id := randi() % ClothDatabase.get_type_count()
	return {"npc": npc, "type": type_id, "motive": next_motif, "teaser": true}

static func fill_requests(insert_at: int = -1):
	var sm := _save()
	if sm == null:
		return
	var b: Dictionary = sm.boutique
	if not b.has("requests") or not (b["requests"] is Array):
		b["requests"] = []
	var requests: Array = b["requests"]
	var has_teaser := false
	for r in requests:
		if r.get("teaser", false):
			has_teaser = true
			break
	if not has_teaser:
		var teaser := _generate_teaser()
		if not teaser.is_empty():
			if insert_at >= 0 and insert_at <= requests.size():
				requests.insert(insert_at, teaser)
				insert_at += 1
			else:
				requests.append(teaser)
	while requests.size() < REQUEST_COUNT:
		var exclude_motives := []
		for r in requests:
			exclude_motives.append(int(r.motive))
		var generated := _generate_request(exclude_motives)
		if generated.is_empty():
			break
		if insert_at >= 0 and insert_at <= requests.size():
			requests.insert(insert_at, generated)
			insert_at += 1
		else:
			requests.append(generated)
	save()

static func start_work(slot_index: int, type_id: int, motive: int) -> bool:
	ensure_state()
	var sm := _save()
	if sm == null:
		return false
	var slots: Array = sm.boutique["slots"]
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot: Dictionary = slots[slot_index]
	if slot["state"] != "idle":
		return false
	if not slot_unlocked(slot_index):
		return false
	var type_info := ClothDatabase.get_type(type_id)
	if type_info.is_empty():
		return false
	if not ClothDatabase.has_clothing(type_id, motive):
		return false
	if sm.get_tile_fabric(motive) < type_info.fabric:
		return false
	sm.tile_fabrics[motive] = sm.get_tile_fabric(motive) - type_info.fabric
	sm.fabric -= type_info.fabric
	slot["state"] = "working"
	slot["type"] = type_id
	slot["motive"] = motive
	slot["finish_at"] = Time.get_unix_time_from_system() + type_info.seconds * time_multiplier(slot_index)
	save()
	return true

static func reconcile():
	ensure_state()
	var sm := _save()
	if sm == null:
		return
	var changed := false
	var now := Time.get_unix_time_from_system()
	for slot in sm.boutique["slots"]:
		if slot["state"] == "working" and float(slot["finish_at"]) <= now:
			slot["state"] = "ready"
			changed = true
	if changed:
		save()

static func seconds_left(slot_index: int) -> float:
	ensure_state()
	var sm := _save()
	if sm == null:
		return 0.0
	var slots: Array = sm.boutique["slots"]
	if slot_index < 0 or slot_index >= slots.size():
		return 0.0
	var slot: Dictionary = slots[slot_index]
	if slot["state"] != "working":
		return 0.0
	return maxf(float(slot["finish_at"]) - Time.get_unix_time_from_system(), 0.0)

static func can_afford(type_id: int, tile_id: int) -> bool:
	var sm := _save()
	return sm != null and sm.get_tile_fabric(tile_id) >= ClothDatabase.type_fabric(type_id)

static func tile_fabric(tile_id: int) -> int:
	var sm := _save()
	return sm.get_tile_fabric(tile_id) if sm != null else 0

static func serve(slot_index: int) -> Dictionary:
	ensure_state()
	var sm := _save()
	if sm == null:
		return {}
	var slots: Array = sm.boutique["slots"]
	if slot_index < 0 or slot_index >= slots.size():
		return {}
	var slot: Dictionary = slots[slot_index]
	if slot["state"] != "ready":
		return {}
	var type_id: int = slot["type"]
	var motive: int = slot["motive"]
	var requests: Array = sm.boutique["requests"]
	var price := ClothDatabase.type_fabric(type_id) * batik_value(motive)
	var matched := false
	var request_index := -1
	for i in range(requests.size()):
		var req: Dictionary = requests[i]
		if int(req.type) == type_id and int(req.motive) == motive:
			matched = true
			request_index = i
			break
	if matched:
		requests.remove_at(request_index)
	else:
		price = price / 2
	slot["state"] = "idle"
	slot["type"] = 0
	slot["motive"] = 0
	slot["finish_at"] = 0.0
	sm.add_coins(price)
	fill_requests(request_index if matched else -1)
	save()
	return {"matched": matched, "price": price, "request_index": request_index}

static func buy_slot(slot_index: int) -> bool:
	ensure_state()
	var sm := _save()
	if sm == null:
		return false
	if slot_index < 1 or slot_index > MAX_EXTENDED:
		return false
	var unlocked: Array = sm.boutique["unlocked_slots"]
	if slot_index in unlocked:
		return false
	if sm.coins < EXTENDED_COST:
		return false
	unlocked.append(slot_index)
	sm.boutique["unlocked_slots"] = unlocked
	sm.add_coins(-EXTENDED_COST)
	save()
	return true

static func slot_upgrade(slot_index: int) -> int:
	ensure_state()
	var sm := _save()
	if sm == null:
		return 0
	var slots: Array = sm.boutique["slots"]
	if slot_index < 0 or slot_index >= slots.size():
		return 0
	return int(slots[slot_index].get("upgrade", 0))

static func upgrade_options(slot_index: int) -> Array:
	var current := slot_upgrade(slot_index)
	var out := []
	if current == 0:
		out.append({"tier": 1, "cost": 50000})
		out.append({"tier": 2, "cost": 100000})
	elif current == 1:
		out.append({"tier": 2, "cost": 100000})
	return out

static func upgrade_slot(slot_index: int, target_tier: int) -> bool:
	ensure_state()
	var sm := _save()
	if sm == null:
		return false
	var slots: Array = sm.boutique["slots"]
	if slot_index < 0 or slot_index >= slots.size():
		return false
	if not slot_unlocked(slot_index):
		return false
	var slot: Dictionary = slots[slot_index]
	if slot["state"] != "idle":
		return false
	var cost := 0
	var allowed := false
	for opt in upgrade_options(slot_index):
		if int(opt.tier) == target_tier:
			allowed = true
			cost = int(opt.cost)
			break
	if not allowed:
		return false
	if sm.coins < cost:
		return false
	sm.add_coins(-cost)
	slot["upgrade"] = target_tier
	save()
	return true

static func time_multiplier(slot_index: int) -> float:
	return float(TIME_MULTIPLIERS.get(slot_upgrade(slot_index), 1.0))

static func machine_name(tier: int) -> String:
	var tm := _translation()
	var key := ""
	match tier:
		1:
			key = "old_sewing_machine"
		2:
			key = "modern_sewing_machine"
		_:
			key = "manual_sewing"
	if tm != null and tm.has_method("t"):
		return tm.t(key)
	return key

static func save():
	var sm := _save()
	if sm != null:
		sm.save_game()
