class_name BoardGenerator
extends RefCounted

const TILE_SIZE := 64.0
const ROW_STEP := 64.0
const LAYER_OFFSET := Vector2(8, 8)
const COVER_TOL := 8.0
const DEFAULT_RECT := Rect2(16, 16, 448, 560)
const MAX_COLS := 8
const MAX_ROWS := 10
const FIELD_COLS := 7
const FIELD_ROWS := 8
const CASCADE_STEP := 52.0
const CELL_STRIDE := FIELD_COLS * FIELD_ROWS

const SHAPE_ORDER := [
	"square", "diamond", "circle", "heart", "triangle", "hexagon", "star", "cross",
	"crescent", "clover", "hourglass", "arrow", "shield", "flower", "butterfly",
	"crown", "spade", "ring", "teardrop", "rhombus",
]
const SHAPE_ASPECT := {
	"square": 1.0, "diamond": 1.0, "circle": 1.0, "heart": 1.0, "triangle": 1.0,
	"hexagon": 1.0, "star": 1.0, "cross": 1.0, "crescent": 1.15, "clover": 1.1,
	"hourglass": 0.8, "arrow": 0.75, "shield": 0.75, "flower": 1.1, "butterfly": 1.3,
	"crown": 1.2, "spade": 0.85, "ring": 1.0, "teardrop": 0.8, "rhombus": 0.9,
}

static var _poly_cache: Dictionary = {}

static func generate(level: int, combination: Array) -> Dictionary:
	var depth_cap := LevelData.max_pile_depth(level)
	var total := combination.size() * 3
	var last := {}
	for attempt in range(40):
		var layout := _try_shape_layout(total, level, depth_cap, combination, true, randi())
		if layout.is_empty():
			break
		last = layout
		if _is_solvable(layout):
			return layout
	if last.is_empty():
		return _generate_pile_layout(combination, depth_cap)
	return last

static func shuffle_remaining(remaining_types: Array, level: int) -> Dictionary:
	var depth_cap := LevelData.max_pile_depth(level)
	var total := remaining_types.size()
	if total <= 0:
		return {"tiles": [], "max_depth": depth_cap}
	var last := {}
	for attempt in range(20):
		var layout := _try_shape_layout(total, level, depth_cap, remaining_types, false, randi())
		if layout.is_empty():
			break
		last = layout
		if _is_solvable(layout):
			return layout
	return _generate_pile_layout(remaining_types, depth_cap)

# ---------------------------------------------------------------------------
# Shaped, layered formation (mirrors board-preview-shapes.html)
# ---------------------------------------------------------------------------

static func _shape_pool_for_level(level: int) -> Array:
	var n := mini(SHAPE_ORDER.size(), 1 + (level - 1) / 10)
	return SHAPE_ORDER.slice(0, n)

static func _shape_for_level(level: int) -> String:
	var pool := _shape_pool_for_level(level)
	return pool[(level - 1) % pool.size()]

static func _try_shape_layout(total: int, level: int, depth_cap: int, type_pool: Array, grouped: bool, seed: int) -> Dictionary:
	if total <= 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var shape := _build_shape(total, level, depth_cap)
	var cells: Array = shape.cells
	if cells.size() > total:
		return {}
	var depths := _relief_depths(cells, total, depth_cap)
	var sum := 0
	for d in depths.values():
		sum += int(d)
	if sum != total:
		return {}
	return _build_layout(cells, depths, type_pool, grouped, rng, level)

static func _build_shape(total: int, level: int, depth_cap: int) -> Dictionary:
	var name := _shape_for_level(level)
	var need := ceili(float(total) / float(depth_cap))
	var target_area := maxi(need, mini(total, int(round(total / 2.2))))
	var candidates := []
	for w in range(2, FIELD_COLS + 1):
		var h := clampi(int(round(w * 4.0 / (3.0 * SHAPE_ASPECT[name]))), 2, FIELD_ROWS)
		candidates.append({"w": w, "h": h, "cells": _rasterize(name, w, h)})
	var pool := []
	for c in candidates:
		if int(c.cells.size()) >= need and int(c.cells.size()) <= total:
			pool.append(c)
	if pool.is_empty():
		for c in candidates:
			if int(c.cells.size()) <= total:
				pool.append(c)
	if pool.is_empty():
		pool = candidates
	var best: Dictionary = pool[0]
	for c in pool:
		if abs(int(c.cells.size()) - target_area) < abs(int(best.cells.size()) - target_area):
			best = c
	if int(best.cells.size()) < need:
		best["cells"] = _grow_mask(best.cells, mini(maxi(need, target_area), mini(total, FIELD_COLS * FIELD_ROWS)))
	return {"name": name, "cells": best.cells}

static func _rasterize(name: String, w: int, h: int) -> Array:
	var cells := []
	for c in range(w):
		for r in range(h):
			var u := (c + 0.5) / w * 2.0 - 1.0
			var v := (r + 0.5) / h * 2.0 - 1.0
			if _shape_test(name, u, v):
				cells.append(Vector2i(c, r))
	return cells

static func _grow_mask(cells: Array, need: int) -> Array:
	var set := {}
	for c in cells:
		set[c] = true
	var frontier: Array = cells.duplicate()
	while set.size() < need and set.size() < FIELD_COLS * FIELD_ROWS:
		var next := []
		for c in frontier:
			for nb in _neighbors(c):
				if nb.x < 0 or nb.x >= FIELD_COLS or nb.y < 0 or nb.y >= FIELD_ROWS:
					continue
				if set.has(nb):
					continue
				set[nb] = true
				next.append(nb)
		frontier = next
		if next.is_empty():
			break
	return set.keys()

static func _neighbors(cell: Vector2i) -> Array:
	return [
		Vector2i(cell.x, cell.y - 1), Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x - 1, cell.y), Vector2i(cell.x + 1, cell.y),
	]

static func _compute_rings(cells: Array) -> Dictionary:
	var set := {}
	for c in cells:
		set[c] = true
	var dist := {}
	var queue := []
	for c in cells:
		var edge := false
		for nb in _neighbors(c):
			if not set.has(nb):
				edge = true
				break
		if edge:
			dist[c] = 0
			queue.append(c)
	var qi := 0
	while qi < queue.size():
		var cur: Vector2i = queue[qi]
		qi += 1
		var d: int = dist[cur]
		for nb in _neighbors(cur):
			if set.has(nb) and not dist.has(nb):
				dist[nb] = d + 1
				queue.append(nb)
	return dist

static func _relief_depths(cells: Array, total: int, depth_cap: int) -> Dictionary:
	var dist := _compute_rings(cells)
	var min_r: int = cells[0].y
	var max_r: int = cells[0].y
	var min_c: int = cells[0].x
	var max_c: int = cells[0].x
	for c in cells:
		min_r = mini(min_r, c.y)
		max_r = maxi(max_r, c.y)
		min_c = mini(min_c, c.x)
		max_c = maxi(max_c, c.x)
	var order: Array = cells.duplicate()
	order.sort_custom(func(a: Vector2i, b: Vector2i):
		var da: int = dist[a]
		var db: int = dist[b]
		if db != da:
			return db < da
		return _snake_index(a, min_r, min_c, max_c) < _snake_index(b, min_r, min_c, max_c))
	var depths := {}
	for c in cells:
		depths[c] = 1
	var remaining := total - cells.size()
	for c in order:
		if remaining <= 0:
			break
		var add := mini(remaining, depth_cap - 1)
		depths[c] += add
		remaining -= add
	return depths

static func _snake_index(cell: Vector2i, min_r: int, min_c: int, max_c: int) -> int:
	var off := cell.y - min_r
	var idx := off * FIELD_COLS
	var local := cell.x - min_c
	if off % 2 == 0:
		idx += local
	else:
		idx += max_c - min_c - local
	return idx

static func _build_layout(cells: Array, depths: Dictionary, type_pool: Array, grouped: bool, rng: RandomNumberGenerator, level: int) -> Dictionary:
	var min_r: int = cells[0].y
	var max_r: int = cells[0].y
	var min_c: int = cells[0].x
	var max_c: int = cells[0].x
	for c in cells:
		min_r = mini(min_r, c.y)
		max_r = maxi(max_r, c.y)
		min_c = mini(min_c, c.x)
		max_c = maxi(max_c, c.x)
	var ox := DEFAULT_RECT.position.x + maxf((DEFAULT_RECT.size.x - ((max_c - min_c) * TILE_SIZE + TILE_SIZE)) / 2.0, 0.0) - min_c * TILE_SIZE
	var oy := DEFAULT_RECT.position.y + maxf((DEFAULT_RECT.size.y - ((max_r - min_r) * ROW_STEP + TILE_SIZE)) / 2.0, 0.0) - min_r * ROW_STEP
	var items := []
	for c in cells:
		var d: int = depths[c]
		var sn := _snake_index(c, min_r, min_c, max_c)
		for l0 in range(d):
			items.append({"cell": c, "l0": l0, "sn": sn})
	items.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.l0) != int(b.l0):
			return int(a.l0) < int(b.l0)
		return int(a.sn) < int(b.sn))
	var pool: Array = type_pool.duplicate()
	_shuffle_array(pool, rng)
	var tiles := []
	var max_depth := 0
	for d in depths.values():
		max_depth = maxi(max_depth, int(d))
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var cell: Vector2i = it.cell
		var l0: int = it.l0
		var assigned: int = pool[i % pool.size()] if grouped else pool[i]
		var base := Vector2(ox + cell.x * TILE_SIZE, oy + cell.y * ROW_STEP) + Vector2(l0, l0) * LAYER_OFFSET
		var cell_index := cell.y * FIELD_COLS + cell.x
		tiles.append({
			"type": assigned,
			"pos": base,
			"z": l0 * CELL_STRIDE + cell_index,
			"layer": l0,
			"depth": depths[cell],
			"cell": cell,
		})
	if grouped:
		_apply_solvable_construction(tiles, pool, LevelData.spread(level), rng)
	return {"tiles": tiles, "max_depth": max_depth}

# ---------------------------------------------------------------------------
# Solvable-by-construction type assignment
# ---------------------------------------------------------------------------
# Assigns each type to 3 tiles that are consecutive in a clearing order, which
# provably keeps the tray peak <= 3 (winnable at any level). The clearing order
# is built greedily so consecutive tiles (same type) land far apart visually.
# ---------------------------------------------------------------------------

static func _covering_for(pos: Array, layer: Array) -> Array:
	var n := pos.size()
	var covering := []
	for i in range(n):
		var r := Rect2(pos[i] + Vector2(COVER_TOL, COVER_TOL), Vector2(TILE_SIZE - 2.0 * COVER_TOL, TILE_SIZE - 2.0 * COVER_TOL))
		var cov := []
		for j in range(n):
			if int(layer[j]) > int(layer[i]):
				if r.intersects(Rect2(pos[j], Vector2(TILE_SIZE, TILE_SIZE))):
					cov.append(j)
		covering.append(cov)
	return covering

static func _greedy_clear_order(cells: Array, covering: Array, covered_by: Array) -> Array:
	var n := cells.size()
	var removed := []
	for i in range(n):
		removed.append(false)
	var cover_count := []
	var below := []
	for i in range(n):
		cover_count.append(covering[i].size())
		below.append(covered_by[i].size())
	var order := []
	var triple := []
	var last_cell: Vector2i = Vector2i(-999, -999)
	while order.size() < n:
		var k := order.size()
		var forbid := {}
		for c in triple:
			forbid[c] = true
		var best: int = -1
		var best_score := -1
		for i in range(n):
			if removed[i]:
				continue
			if cover_count[i] > 0:
				continue
			var c: Vector2i = cells[i]
			if forbid.has(c):
				continue
			var dscore := 0
			if k % 3 == 0:
				dscore = absi(c.x - last_cell.x) + absi(c.y - last_cell.y)
			elif k % 3 == 1:
				dscore = absi(c.x - triple[0].x) + absi(c.y - triple[0].y)
			else:
				var p0: Vector2i = triple[0]
				var p1: Vector2i = triple[1]
				dscore = mini(absi(c.x - p0.x) + absi(c.y - p0.y), absi(c.x - p1.x) + absi(c.y - p1.y))
			var score: int = dscore * 4 + below[i] * 8
			if score > best_score:
				best_score = score
				best = i
		if best < 0:
			for i in range(n):
				if removed[i]:
					continue
				if cover_count[i] > 0:
					continue
				best = i
				break
			if best < 0:
				return []
		order.append(best)
		removed[best] = true
		for j in covered_by[best]:
			cover_count[j] -= 1
		last_cell = cells[best]
		triple.append(last_cell)
		if triple.size() == 3:
			triple = []
	return order

static func _permutations_of(k: int) -> Array:
	var result := []
	var current := []
	var used := []
	for i in range(k):
		used.append(false)
	_permute(result, current, used, k)
	return result

static func _permute(result: Array, current: Array, used: Array, k: int):
	if current.size() == k:
		result.append(current.duplicate())
		return
	for i in range(k):
		if used[i]:
			continue
		used[i] = true
		current.append(i)
		_permute(result, current, used, k)
		current.pop_back()
		used[i] = false

# Finds permutations p0,p1,p2 (slot of each type per third) so that every type's
# 3 copies land on 3 distinct cells, preferring copies spread across as many
# distinct stack layers as possible. Empty if no cell-distinct assignment exists.
static func _distinct_third_assignment(cells0: Array, cells1: Array, cells2: Array, layers0: Array, layers1: Array, layers2: Array, jittered: bool, rng: RandomNumberGenerator) -> Array:
	var perms := _permutations_of(cells0.size())
	if jittered:
		_shuffle_array(perms, rng)
	var best_score := -1
	var best_assign := []
	for p0 in perms:
		for p1 in perms:
			for p2 in perms:
				var ok := true
				for t in range(cells0.size()):
					if cells0[p0[t]] == cells1[p1[t]] or cells0[p0[t]] == cells2[p2[t]] or cells1[p1[t]] == cells2[p2[t]]:
						ok = false
						break
				if not ok:
					continue
				var score := 0
				for t in range(cells0.size()):
					var s := {}
					s[layers0[p0[t]]] = true
					s[layers1[p1[t]]] = true
					s[layers2[p2[t]]] = true
					score += 3 if s.size() == 3 else (s.size() - 1)
				if score > best_score:
					best_score = score
					best_assign = [p0, p1, p2]
	return best_assign

# Assigns a type id to each order position. Types are grouped into chunks of
# `spread`; within a chunk of k types, each type gets exactly one copy in each of
# the 3 chunk-thirds, on 3 distinct cells. Peak tray along the order is provably
# 2 * k <= 2 * spread (winnable at cap 7).
static func _assign_chunk_spread(order_size: int, type_count: int, spread: int, cells_at_position: Array, layers_at_position: Array, rng: RandomNumberGenerator, jittered: bool) -> Array:
	var out := []
	for i in range(order_size):
		out.append(-1)
	var pos := 0
	var type_index := 0
	while pos < order_size:
		var k := mini(spread, type_count - type_index)
		var cells0 := []
		var cells1 := []
		var cells2 := []
		var layers0 := []
		var layers1 := []
		var layers2 := []
		for s in range(k):
			cells0.append(cells_at_position[pos + s])
			cells1.append(cells_at_position[pos + k + s])
			cells2.append(cells_at_position[pos + 2 * k + s])
			layers0.append(layers_at_position[pos + s])
			layers1.append(layers_at_position[pos + k + s])
			layers2.append(layers_at_position[pos + 2 * k + s])
		var assign := _distinct_third_assignment(cells0, cells1, cells2, layers0, layers1, layers2, jittered, rng)
		if assign.is_empty():
			var p := []
			for s in range(k):
				p.append(s)
			assign = [p, p.duplicate(), p.duplicate()]
		for t in range(k):
			out[pos + assign[0][t]] = type_index + t
			out[pos + k + assign[1][t]] = type_index + t
			out[pos + 2 * k + assign[2][t]] = type_index + t
		pos += 3 * k
		type_index += k
	return out

# ---------------------------------------------------------------------------
# Spatial refinement: swap types between tiles so no two copies of the same
# type share a cell or sit on adjacent cells, while keeping the greedy-order
# tray peak within the construction cap (2 * spread), so the difficulty ramp
# and solvability are preserved.
# ---------------------------------------------------------------------------

static func _pair_penalty(a: Vector2i, b: Vector2i, a_layer: int, b_layer: int) -> int:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	if dx == 0 and dy == 0:
		return 100
	if a_layer == b_layer:
		return 50
	return 1 if maxi(dx, dy) <= 2 else 0

static func _pairs_involving(types: Array, cells_at_position: Array, layers_at_position: Array, a: int) -> int:
	var count := 0
	for x in range(types.size()):
		if x == a:
			continue
		if types[x] == types[a]:
			count += _pair_penalty(cells_at_position[x], cells_at_position[a], layers_at_position[x], layers_at_position[a])
	return count

static func _distinct_layers_in(positions: Array, layers_at_position: Array) -> int:
	var s := {}
	for i in positions:
		s[int(layers_at_position[i])] = true
	return s.size()

static func _layers_after_swap(positions: Array, exclude: int, added_layer: int, layers_at_position: Array) -> int:
	var s := {}
	for i in positions:
		if i == exclude:
			continue
		s[int(layers_at_position[i])] = true
	s[added_layer] = true
	return s.size()

static func _pairs_of(types: Array, cells_at_position: Array, layers_at_position: Array, tpos: Dictionary, i: int) -> int:
	var total := 0
	var tp: int = types[i]
	for j in tpos[tp]:
		if j != i:
			total += _pair_penalty(cells_at_position[i], cells_at_position[j], layers_at_position[i], layers_at_position[j])
	return total

static func _pair_key(t1: int, t2: int) -> int:
	return mini(t1, t2) * 1024 + maxi(t1, t2)

static func _build_pair_window(types: Array, total_k: Array, tpos: Dictionary, t1: int, t2: int) -> Dictionary:
	var P := []
	P.append_array(tpos[t1])
	P.append_array(tpos[t2])
	P.sort()
	var slot_of := {}
	for s in range(P.size()):
		slot_of[P[s]] = s
	var c1 := []
	var c2 := []
	var n1 := 0
	var n2 := 0
	for s in range(P.size()):
		if types[P[s]] == t1:
			n1 += 1
		else:
			n2 += 1
		c1.append(n1)
		c2.append(n2)
	var segmax := []
	for p in range(P.size() - 1):
		var mx := -1
		for k in range(P[p], P[p + 1]):
			mx = maxi(mx, total_k[k])
		segmax.append(mx)
	return {"P": P, "slot_of": slot_of, "c1": c1, "c2": c2, "segmax": segmax, "t1": t1, "t2": t2}

static func _build_peak_data(types: Array, tpos: Dictionary) -> Dictionary:
	var total_k := []
	var held := {}
	var total := 0
	for k in range(types.size()):
		var tp: int = types[k]
		held[tp] = int(held.get(tp, 0)) + 1
		total += 1
		if held[tp] >= 3:
			total -= 3
			held[tp] -= 3
		total_k.append(total)
	var pairs := {}
	var tl: Array = tpos.keys()
	for i in range(tl.size()):
		for j in range(i + 1, tl.size()):
			var t1: int = tl[i]
			var t2: int = tl[j]
			pairs[_pair_key(t1, t2)] = _build_pair_window(types, total_k, tpos, t1, t2)
	return {"total_k": total_k, "pairs": pairs}

static func _window_pass(types: Array, pd: Dictionary, cap: int, lo: int, hi: int) -> bool:
	var lo_type: int = types[lo]
	var hi_type: int = types[hi]
	var pair: Dictionary = pd.pairs[_pair_key(lo_type, hi_type)]
	var sa: int = pair.slot_of[lo]
	var sb: int = pair.slot_of[hi]
	var c_lo: Array
	var c_hi: Array
	if pair.t1 == lo_type:
		c_lo = pair.c1
		c_hi = pair.c2
	else:
		c_lo = pair.c2
		c_hi = pair.c1
	for p in range(sa, sb):
		var clo: int = c_lo[p]
		var chi: int = c_hi[p]
		var d: int = (1 if chi >= 2 else 0) - (1 if clo == 3 else 0) - (1 if chi == 3 else 0)
		if pair.segmax[p] - 3 * d > cap:
			return false
	return true

static func _try_refine_swap(types: Array, cells_at_position: Array, layers_at_position: Array, tpos: Dictionary, pairs: Array, pd: Dictionary, peak_cap: int, a: int, b: int) -> bool:
	var ta: int = types[a]
	var tb: int = types[b]
	var lo: int = a if a < b else b
	var hi: int = b if a < b else a
	if not _window_pass(types, pd, peak_cap, lo, hi):
		return false
	var before: int = pairs[a] + pairs[b]
	var da_before := _distinct_layers_in(tpos[ta], layers_at_position)
	var db_before := _distinct_layers_in(tpos[tb], layers_at_position)
	var na: int = 0
	for j in tpos[tb]:
		if j != b:
			na += _pair_penalty(cells_at_position[a], cells_at_position[j], layers_at_position[a], layers_at_position[j])
	var nb: int = 0
	for j in tpos[ta]:
		if j != a:
			nb += _pair_penalty(cells_at_position[b], cells_at_position[j], layers_at_position[b], layers_at_position[j])
	var after: int = na + nb
	var pen_ok: bool = after < before
	var neutral: bool = after == before
	var div_gain: int = (_layers_after_swap(tpos[tb], b, int(layers_at_position[a]), layers_at_position) + _layers_after_swap(tpos[ta], a, int(layers_at_position[b]), layers_at_position)) - (da_before + db_before)
	if not ((pen_ok and div_gain >= 0) or (neutral and div_gain > 0)):
		return false
	types[a] = tb
	types[b] = ta
	tpos[ta].erase(a)
	tpos[ta].append(b)
	tpos[tb].erase(b)
	tpos[tb].append(a)
	for j in tpos[ta]:
		pairs[j] = _pairs_of(types, cells_at_position, layers_at_position, tpos, j)
	for j in tpos[tb]:
		pairs[j] = _pairs_of(types, cells_at_position, layers_at_position, tpos, j)
	return true

static func _refine_spatial(types: Array, cells_at_position: Array, layers_at_position: Array, peak_cap: int) -> void:
	var n := types.size()
	var tpos := {}
	for i in range(n):
		var tp: int = types[i]
		if not tpos.has(tp):
			tpos[tp] = []
		tpos[tp].append(i)
	var pairs := []
	for i in range(n):
		pairs.append(_pairs_involving(types, cells_at_position, layers_at_position, i))
	var pd := _build_peak_data(types, tpos)
	var guard := 0
	var changed := true
	while changed and guard < 100:
		guard += 1
		changed = false
		var adj := []
		for i in range(n):
			for j in range(i + 1, n):
				if types[i] == types[j] and _pair_penalty(cells_at_position[i], cells_at_position[j], layers_at_position[i], layers_at_position[j]) > 0:
					adj.append([i, j])
		if adj.is_empty():
			return
		for pair in adj:
			var accepted := false
			for endpoint in [pair[0], pair[1]]:
				if accepted:
					break
				for c in range(n):
					if c == pair[0] or c == pair[1]:
						continue
					if types[c] == types[endpoint]:
						continue
					if _try_refine_swap(types, cells_at_position, layers_at_position, tpos, pairs, pd, peak_cap, endpoint, c):
						accepted = true
						changed = true
						pd = _build_peak_data(types, tpos)
						break
			if accepted:
				break


static func _apply_solvable_construction(tiles: Array, type_pool: Array, spread: int, rng: RandomNumberGenerator) -> void:
	var n := tiles.size()
	if n == 0 or n % 3 != 0:
		return
	var pos := []
	var layer := []
	var cells := []
	for t in tiles:
		pos.append(t.pos)
		layer.append(int(t.layer))
		cells.append(t.cell)
	var covering := _covering_for(pos, layer)
	var covered_by := []
	for i in range(n):
		covered_by.append([])
	for i in range(n):
		for j in covering[i]:
			covered_by[j].append(i)
	var order := _greedy_clear_order(cells, covering, covered_by)
	if order.size() != n:
		return
	var cells_at_position := []
	var layers_at_position := []
	for k in range(n):
		cells_at_position.append(cells[order[k]])
		layers_at_position.append(layer[order[k]])
	var capacity := 7
	var types: Array = _assign_chunk_spread(n, type_pool.size(), spread, cells_at_position, layers_at_position, rng, true)
	var ok := _tray_peak(types) <= capacity
	var attempt := 0
	while not ok and attempt < 4:
		types = _assign_chunk_spread(n, type_pool.size(), spread, cells_at_position, layers_at_position, rng, true)
		ok = _tray_peak(types) <= capacity
		attempt += 1
	if not ok:
		types = _assign_chunk_spread(n, type_pool.size(), spread, cells_at_position, layers_at_position, rng, false)
	_refine_spatial(types, cells_at_position, layers_at_position, 2 * spread)
	for k in range(n):
		tiles[order[k]]["type"] = type_pool[types[k]]

# ---------------------------------------------------------------------------
# Shape geometry
# ---------------------------------------------------------------------------

static func _shape_test(name: String, u: float, v: float) -> bool:
	match name:
		"square":
			return true
		"diamond":
			return abs(u) + abs(v) <= 1.0
		"circle":
			return u * u + v * v <= 1.0
		"crescent":
			return (u * u + v * v <= 1.0) and ((u - 0.65) * (u - 0.65) + (v - 0.1) * (v - 0.1) >= 0.75 * 0.75)
		"clover":
			for cx in [-0.5, 0.5]:
				for cy in [-0.5, 0.5]:
					if (u - cx) * (u - cx) + (v - cy) * (v - cy) <= 0.55 * 0.55:
						return true
			if u * u + v * v <= 0.28 * 0.28:
				return true
			return abs(u) <= 0.12 and v >= 0.55
		"hourglass":
			return abs(u) <= 0.2 + 0.8 * abs(v)
		"flower":
			for k in range(6):
				var a := -PI / 2.0 + k * PI / 3.0
				var cx := 0.5 * cos(a)
				var cy := 0.5 * sin(a)
				if (u - cx) * (u - cx) + (v - cy) * (v - cy) <= 0.45 * 0.45:
					return true
			return u * u + v * v <= 0.32 * 0.32
		"butterfly":
			var le := (u + 0.55) * (u + 0.55) / (0.85 * 0.85) + (v - 0.1) * (v - 0.1) / (0.95 * 0.95) <= 1.0
			var re := (u - 0.55) * (u - 0.55) / (0.85 * 0.85) + (v - 0.1) * (v - 0.1) / (0.95 * 0.95) <= 1.0
			return le or re or (abs(u) <= 0.1 and abs(v) <= 0.7)
		"ring":
			var r := sqrt(u * u + v * v)
			return r >= 0.45 and r <= 1.0
		"arrow":
			return _pip(u, v, _polygon("arrow")) or _pip(u, v, _polygon("arrowShaft"))
		_:
			return _pip(u, v, _polygon(name))

static func _pip(u: float, v: float, pts: Array) -> bool:
	var inside := false
	var j := pts.size() - 1
	for i in range(pts.size()):
		var pi: Vector2 = pts[i]
		var pj: Vector2 = pts[j]
		if ((pi.y > v) != (pj.y > v)) and u < (pj.x - pi.x) * (v - pi.y) / (pj.y - pi.y) + pi.x:
			inside = not inside
		j = i
	return inside

static func _star_poly(outer: float, inner: float, points: int) -> Array:
	var pts := []
	for i in range(points * 2):
		var r := inner if i % 2 == 1 else outer
		var a := -PI / 2.0 + i * PI / points
		pts.append(Vector2(r * cos(a), r * sin(a)))
	return pts

static func _polygon(name: String) -> Array:
	if _poly_cache.has(name):
		return _poly_cache[name]
	var pts := []
	match name:
		"heart":
			for i in range(73):
				var a := i / 72.0 * TAU
				var x := 16.0 * pow(sin(a), 3)
				var y := 13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a)
				pts.append(Vector2(x / 16.0, -(y + 2.5) / 14.5))
		"triangle":
			pts = [Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1)]
		"hexagon":
			pts = [Vector2(0, -1), Vector2(0.866, -0.5), Vector2(0.866, 0.5), Vector2(0, 1), Vector2(-0.866, 0.5), Vector2(-0.866, -0.5)]
		"star":
			pts = _star_poly(1.0, 0.45, 5)
		"cross":
			pts = [Vector2(-0.34, -1), Vector2(0.34, -1), Vector2(0.34, -0.34), Vector2(1, -0.34), Vector2(1, 0.34), Vector2(0.34, 0.34), Vector2(0.34, 1), Vector2(-0.34, 1), Vector2(-0.34, 0.34), Vector2(-1, 0.34), Vector2(-1, -0.34), Vector2(-0.34, -0.34)]
		"arrow":
			pts = [Vector2(0, -1), Vector2(1, 0.2), Vector2(-1, 0.2)]
		"arrowShaft":
			pts = [Vector2(-0.32, 0.2), Vector2(0.32, 0.2), Vector2(0.32, 1), Vector2(-0.32, 1)]
		"shield":
			pts = [Vector2(-0.7, -1), Vector2(0.7, -1), Vector2(1, -0.15), Vector2(0, 1), Vector2(-1, -0.15)]
		"crown":
			pts = [Vector2(-1, 0.4), Vector2(-1, -0.9), Vector2(-0.62, -0.55), Vector2(-0.4, -1), Vector2(-0.15, -0.55), Vector2(0, -0.9), Vector2(0.15, -0.55), Vector2(0.4, -1), Vector2(0.62, -0.55), Vector2(1, -0.9), Vector2(1, 0.4)]
		"spade":
			pts = [Vector2(-0.6, -0.75), Vector2(-0.95, -0.15), Vector2(-0.7, 0.45), Vector2(-0.12, 0.5), Vector2(-0.1, 1), Vector2(0.1, 1), Vector2(0.12, 0.5), Vector2(0.7, 0.45), Vector2(0.95, -0.15), Vector2(0.6, -0.75), Vector2(0, -1)]
		"teardrop":
			pts = [Vector2(0, -1), Vector2(0.62, -0.15), Vector2(0.62, 0.35), Vector2(0, 1), Vector2(-0.62, 0.35), Vector2(-0.62, -0.15)]
		"rhombus":
			pts = [Vector2(0, -1), Vector2(1, 0.35), Vector2(0, 1), Vector2(-1, 0.35)]
		_:
			return []
	_poly_cache[name] = pts
	return pts

# ---------------------------------------------------------------------------
# Accessibility / solvability
# ---------------------------------------------------------------------------

static func _layer_of(t: Dictionary) -> int:
	if t.has("layer"):
		return int(t["layer"])
	return int(int(t.get("z", 0)) / CELL_STRIDE)

static func is_tile_accessible(tile: Dictionary, all_tiles: Array) -> bool:
	var t_layer := _layer_of(tile)
	var r := Rect2(tile.pos + Vector2(COVER_TOL, COVER_TOL), Vector2(TILE_SIZE - 2.0 * COVER_TOL, TILE_SIZE - 2.0 * COVER_TOL))
	for other in all_tiles:
		if other.removed:
			continue
		if _layer_of(other) > t_layer:
			if r.intersects(Rect2(other.pos, Vector2(TILE_SIZE, TILE_SIZE))):
				return false
	return true

static func choose_remove_type(entries: Array) -> int:
	var counts := {}
	var has_accessible := {}
	for e in entries:
		if e.removed:
			continue
		counts[e.type] = int(counts.get(e.type, 0)) + 1
		if is_tile_accessible(e, entries):
			has_accessible[e.type] = true
	var exact := []
	for t in counts.keys():
		if has_accessible.get(t, false) and counts[t] == 3:
			exact.append(t)
	if not exact.is_empty():
		return exact[randi() % exact.size()]
	var chosen := -1
	var best := 2
	for t in counts.keys():
		if has_accessible.get(t, false) and counts[t] > best:
			best = counts[t]
			chosen = t
	return chosen

static func _is_solvable(layout: Dictionary) -> bool:
	var n: int = layout.tiles.size()
	var types := []
	var pos := []
	var layer := []
	var cells := []
	for t in layout.tiles:
		types.append(t.type)
		pos.append(t.pos)
		layer.append(int(t.get("layer", 0)))
		cells.append(t.cell)
	if _construction_solvable(types, cells, pos, layer, 7):
		return true
	var covering := _covering_for(pos, layer)
	var rng := RandomNumberGenerator.new()
	for run in range(8):
		rng.seed = 0x5EED + run * 7919
		if _greedy_run(types, covering, 7, rng):
			return true
	return false

# A board is winnable when the tray, simulated along a valid clearing order, never
# exceeds capacity. Works for consecutive-triple and spread constructions alike.
static func _construction_solvable(types: Array, cells: Array, pos: Array, layer: Array, capacity: int) -> bool:
	var n := types.size()
	if n == 0 or n % 3 != 0:
		return false
	var covering := _covering_for(pos, layer)
	var covered_by := []
	for i in range(n):
		covered_by.append([])
	for i in range(n):
		for j in covering[i]:
			covered_by[j].append(i)
	var order := _greedy_clear_order(cells, covering, covered_by)
	if order.size() != n:
		return false
	var ordered_types := []
	for k in range(n):
		ordered_types.append(types[order[k]])
	return _tray_peak(ordered_types) <= capacity

# Simulates the tray along a clearing order (types_at_position[k] = type at order
# position k); returns the max number of tiles held at once. Match clears at 3.
static func _tray_peak(types_at_position: Array) -> int:
	var held := {}
	var total := 0
	var peak := 0
	for k in range(types_at_position.size()):
		var tp: int = types_at_position[k]
		held[tp] = int(held.get(tp, 0)) + 1
		total += 1
		if held[tp] >= 3:
			total -= 3
			held[tp] -= 3
		peak = maxi(peak, total)
	return peak

static func _greedy_run(types: Array, covering: Array, capacity: int, rng: RandomNumberGenerator) -> bool:
	var n := types.size()
	var removed := []
	for i in range(n):
		removed.append(false)
	var remaining := n
	var tray := {}
	var tray_total := 0

	while remaining > 0:
		var candidates := []
		for i in range(n):
			if removed[i]:
				continue
			var acc := true
			for j in covering[i]:
				if not removed[j]:
					acc = false
					break
			if acc:
				candidates.append(i)
		if candidates.is_empty():
			return false
		for i in range(candidates.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = candidates[i]
			candidates[i] = candidates[j]
			candidates[j] = tmp

		var chosen_index: int = candidates[0]
		for ci in candidates:
			if tray.get(types[ci], 0) == 2:
				chosen_index = ci
				break
		if chosen_index == candidates[0]:
			for ci in candidates:
				if tray.get(types[ci], 0) == 1:
					chosen_index = ci
					break

		var chosen_type: int = types[chosen_index]
		var t: int = tray.get(chosen_type, 0)
		var visible: int = 0
		for ci in candidates:
			if types[ci] == chosen_type:
				visible += 1

		var slot_increases: int
		match t:
			2:
				slot_increases = -2
			1:
				slot_increases = -1 if visible == 2 else 1
			_:
				slot_increases = 0 if visible == 3 else (2 if visible == 2 else 1)
		if tray_total + slot_increases > capacity:
			return false

		match t:
			2:
				tray.erase(chosen_type)
				tray_total -= 2
			1:
				if visible == 2:
					tray.erase(chosen_type)
					tray_total -= 1
				else:
					tray[chosen_type] = 2
					tray_total += 1
			_:
				if visible == 3:
					tray_total += 0
				elif visible == 2:
					tray[chosen_type] = 2
					tray_total += 2
				else:
					tray[chosen_type] = 1
					tray_total += 1

		for ci in candidates:
			if types[ci] == chosen_type:
				removed[ci] = true
				remaining -= 1

	return true

# ---------------------------------------------------------------------------
# Fallback: pile layout (used when the shaped formation is infeasible/unsolvable)
# ---------------------------------------------------------------------------

static func _generate_pile_layout(multiset: Array, max_depth: int) -> Dictionary:
	var last := {}
	for attempt in range(40):
		var layout := _layout_piles(multiset, max_depth)
		last = layout
		if _is_solvable(layout):
			return layout
	return last

static func _layout_piles(multiset: Array, max_depth: int) -> Dictionary:
	var piles := _plan_piles(multiset, max_depth, 56)
	piles.shuffle()

	var deck_by_type := {}
	for t in multiset:
		if not deck_by_type.has(t):
			deck_by_type[t] = []
		deck_by_type[t].append(t)

	var pile_anchors := _cluster_anchors(piles.size())
	var tiles := []
	var pos_min := DEFAULT_RECT.position
	var pos_max := DEFAULT_RECT.position + DEFAULT_RECT.size - Vector2(TILE_SIZE, TILE_SIZE)
	for pile_index in range(piles.size()):
		var pile: Dictionary = piles[pile_index]
		var depth: int = pile.depth
		var anchor: Vector2 = pile_anchors[pile_index].clamp(pos_min, pos_max)
		var type_queue: Array = deck_by_type[pile.type]
		for layer in range(depth):
			tiles.append({
				"type": pile.type,
				"pos": anchor + Vector2(layer, layer) * LAYER_OFFSET,
				"z": layer * CELL_STRIDE + pile_index,
				"layer": layer,
				"depth": depth,
				"cell": Vector2i(-1, -1),
			})
			type_queue.pop_back()

	return {"tiles": tiles, "max_depth": max_depth}

static func _cluster_anchors(pile_count: int) -> Array:
	var cols := _grid_cols(pile_count)
	var rows := _grid_rows(pile_count, cols)
	var origin := _slab_origin(cols, rows)
	var anchors := []
	for k in range(pile_count):
		anchors.append(_cell_pos(k % cols, k / cols, origin, CASCADE_STEP))
	return anchors

static func _grid_cols(pile_count: int) -> int:
	var aspect := DEFAULT_RECT.size.x / float(DEFAULT_RECT.size.y) * 1.1
	return clampi(int(ceil(sqrt(pile_count * aspect))), 2, MAX_COLS)

static func _grid_rows(pile_count: int, cols: int) -> int:
	return clampi(int(ceil(pile_count / float(cols))), 2, MAX_ROWS)

static func _slab_origin(cols: int, rows: int) -> Vector2:
	var slab_w := (cols - 1) * CASCADE_STEP + TILE_SIZE
	var slab_h := (rows - 1) * CASCADE_STEP + TILE_SIZE
	var margin_x := maxf((DEFAULT_RECT.size.x - slab_w) / 2.0, 0.0)
	var margin_y := maxf((DEFAULT_RECT.size.y - slab_h) / 2.0, 0.0)
	return DEFAULT_RECT.position + Vector2(margin_x, margin_y)

static func _cell_pos(col: int, row: int, origin: Vector2, step: float) -> Vector2:
	return origin + Vector2(col * step, row * step)

static func _plan_piles(multiset: Array, max_depth: int, max_anchors: int) -> Array:
	var counts := {}
	for t in multiset:
		counts[t] = counts.get(t, 0) + 1
	var type_list: Array = counts.keys()
	type_list.shuffle()
	var total: int = multiset.size()

	var piles_per_type := ceili(3.0 / float(max_depth))
	var min_piles := type_list.size() * piles_per_type
	var max_piles := mini(total, max_anchors)
	var n_piles := randi_range(mini(min_piles, max_piles), max_piles)
	var n_extra := n_piles - min_piles

	var splits := {}
	for tp in type_list:
		splits[tp] = piles_per_type
	var extra_pool := []
	for tp in type_list:
		for i in range(counts[tp] - piles_per_type):
			extra_pool.append(tp)
	extra_pool.shuffle()
	for i in range(maxi(0, mini(n_extra, extra_pool.size()))):
		splits[extra_pool[i]] += 1

	var piles := []
	for tp in type_list:
		var k: int = splits[tp]
		var depths := _split_copies(counts[tp], k, max_depth)
		for d in depths:
			piles.append({"type": tp, "depth": d})
	return piles

static func _split_copies(copies: int, k: int, max_depth: int) -> Array:
	var depths := []
	for i in range(k):
		depths.append(1)
	var remaining := copies - k
	var idx := randi() % k
	while remaining > 0:
		var tries := 0
		while depths[idx] >= max_depth and tries < k * 2:
			idx = (idx + 1) % k
			tries += 1
		if depths[idx] >= max_depth:
			return depths
		depths[idx] += 1
		remaining -= 1
		idx = (idx + 1) % k
	return depths

static func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr
