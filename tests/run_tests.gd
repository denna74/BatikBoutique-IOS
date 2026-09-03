extends SceneTree

var _fail_count := 0

func _init():
	_run()

func _run():
	await process_frame
	var sm := root.get_node("SaveManager")
	sm.save_file_path = "user://test_batik_boutique.save"
	DirAccess.remove_absolute("user://test_batik_boutique.save")
	await _test_ui_transition_overlay()
	_test_level_data()
	_test_tray_peak()
	_test_chunk_spread()
	_test_spatial_refinement()
	_test_tile_database()
	_test_tile_art()
	_test_scene_manager()
	_test_generator()
	_test_generation_speed()
	_test_difficulty_ramp()
	_test_layer_diversity()
	_test_scene_loads()
	await _test_character()
	await _test_tray_matching()
	await _test_tray_concurrent_matches()
	await _test_tray_reserves_matched_slots()
	await _test_result_popup_closes()
	await _test_pause_resume()
	await _test_pause_covers_board()
	await _test_countdown_timer()
	await _test_win_stars()
	await _test_gameplay_back_button()
	await _test_new_batik_popup_trigger()
	_test_save_system()
	_test_mood_mechanics()
	_test_mood_save_roundtrip()
	_test_skill_stock()
	_test_spend_coins()
	_test_purchase_processed()
	await _test_ads_flow()
	await _test_mood_gate_blocks_level_start()
	await _test_helpers_seeded_from_stock()
	await _test_skill_buttons_disabled()
	await _test_track_hud_built()
	await _test_instant_coins_popup()
	_test_cloth_database()
	await _test_workshop_popup()
	await _test_request_cloth_type_language()
	await _test_menu_click_guard()
	await _test_menu_popup_cancel_clicks()
	await _test_skill_buy_popup_price_shown()
	_test_boutique_requests()
	await _test_request_reward_badge()
	_test_npc_files()
	_test_request_npc_diversity()
	_test_start_work()
	_test_reconcile()
	_test_serve()
	_test_extended_workshops()
	_test_extended_workshops_migration()
	await _test_locked_workshop_ui()
	await _test_gallery_page()
	await _test_gallery_instant_swap()
	await _test_old_sewing_machine()
	_test_slot_upgrade_defaults()
	_test_upgrade_options()
	_test_upgrade_slot()
	_test_start_work_multiplier()
	_test_save_roundtrip_upgrade()
	_test_sewing_frames()
	await _test_sewing_pingpong()
	_test_save_boutique_roundtrip()
	await _test_fabric_banking()
	_test_remove_skill_target()
	await _test_remove3_preserves_tray_tiles()
	await _test_remove3_counts_as_solved()
	await _test_bgm_levels()
	await _test_bgm_restart_after_menu_fade()
	await _test_sfx_levels()
	await _test_loading_stops_music()
	await _test_gameplay_music_after_board_setup()
	DirAccess.remove_absolute("user://test_batik_boutique.save")
	if _fail_count == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("%d TEST(S) FAILED" % _fail_count)
		quit(1)

class StubBoard:
	extends Node
	func mark_tile_taken(_e: Dictionary):
		pass

class MusicSpyBoard:
	extends GameBoard
	var music_node: Node
	var playing_during_setup := false
	func setup(level: int, combination: Array):
		playing_during_setup = music_node._gameplay_player.playing
		super(level, combination)

func _test_tray_matching():
	await process_frame
	var tray = load("res://scenes/tray/Tray.tscn").instantiate()
	root.add_child(tray)
	tray.size = Vector2(480, 120)
	tray.setup()
	var board := StubBoard.new()
	root.add_child(board)
	var matched_count := [0]
	tray.matched.connect(func(_t: int): matched_count[0] += 1)
	for i in range(3):
		var node = load("res://scenes/board/Tile.tscn").instantiate()
		root.add_child(node)
		node.setup(5, BoardGenerator.TILE_SIZE)
		var entry := {"node": node, "type": 5, "pos": Vector2(100, 100)}
		_check(tray.add_tile(entry, board), "tray accepts tile %d of 3" % (i + 1))
		await create_timer(0.4).timeout
		if i == 1:
			_check(tray.unmatched_count() == 2, "identical tiles occupy separate slots (no stacking)")
	await create_timer(0.5).timeout
	_check(matched_count[0] == 1, "3 identical tray tiles auto-match once")
	_check(tray.unmatched_count() == 0, "tray clears matched tiles")

func _test_tray_concurrent_matches():
	await process_frame
	var tray = load("res://scenes/tray/Tray.tscn").instantiate()
	root.add_child(tray)
	tray.size = Vector2(480, 120)
	tray.setup()
	var board := StubBoard.new()
	root.add_child(board)
	var matched_types := []
	tray.matched.connect(func(t: int): matched_types.append(t))
	for i in range(3):
		var node = load("res://scenes/board/Tile.tscn").instantiate()
		root.add_child(node)
		node.setup(0, BoardGenerator.TILE_SIZE)
		tray.add_tile({"node": node, "type": 0, "pos": Vector2(100, 100)}, board)
	for i in range(3):
		var node = load("res://scenes/board/Tile.tscn").instantiate()
		root.add_child(node)
		node.setup(1, BoardGenerator.TILE_SIZE)
		tray.add_tile({"node": node, "type": 1, "pos": Vector2(200, 200)}, board)
	await create_timer(0.9).timeout
	_check(tray.unmatched_count() == 0, "rapid successive matches clear all tray tiles")
	_check(matched_types.size() == 2, "both concurrent matches emit matched")

func _test_tray_reserves_matched_slots():
	await process_frame
	var tray = load("res://scenes/tray/Tray.tscn").instantiate()
	root.add_child(tray)
	tray.size = Vector2(480, 120)
	tray.setup()
	var board := StubBoard.new()
	root.add_child(board)
	for i in range(3):
		var node = load("res://scenes/board/Tile.tscn").instantiate()
		root.add_child(node)
		node.setup(5, BoardGenerator.TILE_SIZE)
		tray.add_tile({"node": node, "type": 5, "pos": Vector2(100, 100)}, board)
	await create_timer(0.5).timeout
	var new_node = load("res://scenes/board/Tile.tscn").instantiate()
	root.add_child(new_node)
	new_node.setup(6, BoardGenerator.TILE_SIZE)
	_check(tray.add_tile({"node": new_node, "type": 6, "pos": Vector2(200, 200)}, board),
		"tray accepts tile while a match is fading out")
	_check(tray.slots[3] != null and tray.slots[3].node == new_node,
		"new tile lands in a fresh slot, not a fading matched slot")
	_check(tray.slots[0] == null and tray.slots[1] == null and tray.slots[2] == null,
		"fading matched slots stay empty")
	await create_timer(0.6).timeout
	_check(tray.unmatched_count() == 1, "exactly the new tile remains after cleanup")
	var tile_children := 0
	for c in tray.get_children():
		if c is BatikTile:
			tile_children += 1
	_check(tile_children == 1, "no ghost tile nodes linger in the tray after cleanup")

func _count_result_popups(main: Node) -> int:
	var n := 0
	for c in main.get_children():
		if c is Control and c.has_method("show_win"):
			n += 1
	return n

func _first_result_popup(main: Node) -> Control:
	for c in main.get_children():
		if c is Control and c.has_method("show_win"):
			return c
	return null

func _count_new_batik_popups(main: Node) -> int:
	var n := 0
	for c in main.get_children():
		if c is Control and c.has_method("show_unlock"):
			n += 1
	return n

func _first_new_batik_popup(main: Node) -> Control:
	for c in main.get_children():
		if c is Control and c.has_method("show_unlock"):
			return c
	return null

func _test_result_popup_closes():
	await process_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._win()
	await process_frame
	_check(_count_result_popups(main) == 1, "win shows a result popup")
	_check(_first_result_popup(main).z_index > 1000, "win popup draws above tray tiles")
	_check(_first_result_popup(main).get_node("Panel/Margin/VBox/Buttons/NextButton").visible,
		"win popup shows next level button")
	main._on_next_pressed()
	await process_frame
	_check(_count_result_popups(main) == 0, "result popup closes after choosing next level")
	main._win()
	await process_frame
	main._on_retry_pressed()
	await process_frame
	_check(_count_result_popups(main) == 0, "result popup closes after retry")
	main._lose()
	await process_frame
	_check(_count_result_popups(main) == 1, "lose shows a result popup")
	_check(_first_result_popup(main).z_index > 1000, "lose popup draws above tray tiles")
	_check(not _first_result_popup(main).get_node("Panel/Margin/VBox/Buttons/NextButton").visible,
		"lose popup hides next level button")
	main.queue_free()

func _test_pause_resume():
	await process_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._toggle_pause()
	await process_frame
	_check(paused, "pause freezes the game")
	var popup: Node = main.get_node_or_null("ActivePausePopup")
	_check(popup != null, "pause shows a popup")
	_check(popup != null and popup.visible, "pause popup is visible (has a continue button)")
	_check(popup != null and popup.process_mode == Node.PROCESS_MODE_WHEN_PAUSED,
		"pause popup keeps processing input while paused")
	_check(not main.pause_button.visible, "pause button hidden while paused")
	main._on_pause_continue()
	await process_frame
	_check(not paused, "continue resumes the game")
	_check(main.get_node_or_null("ActivePausePopup") == null, "continue removes the pause popup")
	_check(main.pause_button.visible, "pause button visible after resume")
	main.queue_free()

func _test_pause_covers_board():
	await process_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._toggle_pause()
	await process_frame
	var popup := main.get_node_or_null("ActivePausePopup") as Control
	var dim := popup.get_node("Dim") as TextureRect
	var dim_rect := dim.get_global_rect()
	_check(dim_rect.encloses(main.board.get_global_rect()), "pause backdrop covers the board area")
	main.queue_free()

func _test_countdown_timer():
	await process_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var limit := LevelData.time_limit(main.current_level)
	_check(main.time_left <= limit and main.time_left > limit - 1.0,
		"countdown starts at the time limit")
	_check(main.time_left > 0.0, "countdown is positive at start")
	var before: float = main.time_left
	await create_timer(0.2).timeout
	_check(main.time_left < before, "countdown decreases over time")
	main.time_left = 0.01
	await create_timer(0.05).timeout
	_check(not main.running, "timeout stops the game")
	_check(_count_result_popups(main) == 1, "timeout shows a lose popup")
	_check(not _first_result_popup(main).get_node("Panel/Margin/VBox/Buttons/NextButton").visible,
		"timeout lose popup hides next level button")
	main.queue_free()

func _test_win_stars():
	await process_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var save_manager := root.get_node("SaveManager")
	save_manager.reset_to_defaults()
	main.start_level(5)
	main.time_left = 0.6 * LevelData.time_limit(5)
	main._win()
	_check(save_manager.get_stars(5) == 3, ">=50%% time left wins 3 stars")
	main.start_level(6)
	main.time_left = 0.3 * LevelData.time_limit(6)
	main._win()
	_check(save_manager.get_stars(6) == 2, ">=25%% time left wins 2 stars")
	main.start_level(7)
	main.time_left = 0.1 * LevelData.time_limit(7)
	main._win()
	_check(save_manager.get_stars(7) == 1, "<25%% time left wins 1 star")
	main.queue_free()

func _test_new_batik_popup_trigger():
	await process_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var save_manager := root.get_node("SaveManager")
	save_manager.reset_to_defaults()
	main.current_level = 9
	_check(not main._unlocks_new_batik(9), "level 9 win unlocks no new batik")
	main.current_level = 10
	_check(main._unlocks_new_batik(10), "first-time level 10 win unlocks a new batik")
	_check(not main._unlocks_new_batik(11), "retry of beaten level 10 unlocks no new batik")
	main.current_level = 12
	_check(not main._unlocks_new_batik(12), "first-time level 12 win unlocks no new batik")
	main.current_level = 500
	_check(main._unlocks_new_batik(500), "first-time level 500 win unlocks a new batik")
	save_manager.reset_to_defaults()
	main.start_level(10)
	main._win()
	await process_frame
	_check(_count_new_batik_popups(main) == 1, "first level 10 win shows the new batik popup")
	_check(_count_result_popups(main) == 0, "new batik popup precedes the result popup")
	var unlock_popup := _first_new_batik_popup(main)
	_check(unlock_popup != null and unlock_popup.z_index > 1000, "new batik popup draws above tray tiles")
	_check(unlock_popup.get_node("Panel/Margin/VBox/MotifName").text ==
		TileDatabase.get_catalog_name(6, root.get_node("TranslationManager").current_language),
		"new batik popup shows tile 6 catalog name")
	unlock_popup.ok_pressed.emit()
	await process_frame
	_check(_count_new_batik_popups(main) == 0, "ok closes the new batik popup")
	_check(_count_result_popups(main) == 1, "result popup appears after ok")
	main.start_level(10)
	await process_frame
	main._win()
	await process_frame
	_check(_count_new_batik_popups(main) == 0, "retry of level 10 skips the new batik popup")
	_check(_count_result_popups(main) == 1, "retry of level 10 shows the result popup directly")
	save_manager.reset_to_defaults()
	main.start_level(12)
	main._win()
	await process_frame
	_check(_count_new_batik_popups(main) == 0, "first level 12 win skips the new batik popup")
	_check(_count_result_popups(main) == 1, "first level 12 win shows the result popup")
	save_manager.reset_to_defaults()
	main.start_level(500)
	main.time_left = LevelData.time_limit(500)
	main._win()
	await process_frame
	_check(_count_new_batik_popups(main) == 1, "first level 500 win shows the new batik popup")
	_check(_first_new_batik_popup(main).get_node("Panel/Margin/VBox/MotifName").text ==
		TileDatabase.get_catalog_name(55, root.get_node("TranslationManager").current_language),
		"new batik popup shows tile 55 catalog name")
	main.queue_free()

func _test_gameplay_back_button():
	await process_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	_check(paused, "system back pauses gameplay")
	_check(main.get_node_or_null("ActivePausePopup") != null, "system back shows the pause popup")
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	_check(paused, "duplicate back request in same frame is ignored (Android double-delivery)")
	_check(main.get_node_or_null("ActivePausePopup") != null, "pause popup survives duplicate back request")
	main._last_back_ms = -10000
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	_check(not paused, "second system back resumes gameplay")
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	main._last_back_ms = -10000
	main._unhandled_input(ev)
	await process_frame
	_check(paused, "ui_cancel pauses gameplay too")
	main._last_back_ms = -10000
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	_check(not paused, "back request resumes from ui_cancel pause as well")
	main.result_shown = true
	main._last_back_ms = -10000
	main._handle_back_request()
	_check(not paused, "back is ignored while a result popup is showing")
	main.queue_free()

func _test_save_system():
	var path := "user://test_save_system.save"
	DirAccess.remove_absolute(path)
	var sm = load("res://autoload/SaveManager.gd").new()
	sm.save_file_path = path
	sm.max_level = 46
	sm.stars = {1: 3, 2: 2}
	sm.coins = 500
	sm.skills = {"undo": 2, "shuffle": 1, "remove3": 0, "extra": 4}
	sm.tile_fabrics = {0: 10, 5: 20}
	sm.save_game()
	var sm2 = load("res://autoload/SaveManager.gd").new()
	sm2.save_file_path = path
	_check(sm2.load_game(), "save file loads")
	_check(sm2.max_level == 46, "round-trip preserves max_level")
	_check(sm2.get_stars(1) == 3 and sm2.get_stars(2) == 2, "round-trip preserves stars")
	_check(sm2.coins == 500, "round-trip preserves coins")
	_check(sm2.tile_fabrics.get(0, 0) == 10 and sm2.tile_fabrics.get(5, 0) == 20, "round-trip preserves per-tile fabric")
	_check(sm2.skills.undo == 2 and sm2.skills.shuffle == 1 and sm2.skills.extra == 4,
		"round-trip preserves skills")
	sm2._apply_save_data({"max_level": 10, "stars": {"1": 2}})
	_check(sm2.max_level == 10, "old-format save loads max_level")
	_check(sm2.get_stars(1) == 2, "old-format save loads stars")
	_check(sm2.coins == 0, "old-format save defaults coins to 0")
	_check(sm2.skills.undo == 0 and sm2.skills.shuffle == 0 and sm2.skills.remove3 == 0 and sm2.skills.extra == 0,
		"old-format save defaults skills to 0")
	DirAccess.remove_absolute(path)

func _check(cond: bool, msg: String):
	if cond:
		print("PASS: ", msg)
	else:
		print("FAIL: ", msg)
		_fail_count += 1

func _test_tray_peak():
	_check(BoardGenerator._tray_peak([]) == 0, "empty tray peak == 0")
	_check(BoardGenerator._tray_peak([0, 0, 0, 1, 1, 1, 2, 2, 2]) == 2, "cycle-1 peak == 2")
	_check(BoardGenerator._tray_peak([0, 1, 0, 1, 0, 1, 2, 3, 2, 3, 2, 3]) == 4, "cycle-2 peak == 4")
	_check(BoardGenerator._tray_peak([0, 1, 2, 0, 1, 2, 0, 1, 2]) == 6, "cycle-3 peak == 6")
	_check(BoardGenerator._tray_peak([0, 1, 0, 1, 0, 1]) == 4, "cycle-2 partial peak == 4")

func _test_chunk_spread():
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var cells := []
	var layers := []
	for i in range(18):
		cells.append(Vector2i(i % 7, i / 7))
		layers.append(i % 3)
	var base: Array = BoardGenerator._assign_chunk_spread(18, 6, 1, cells, layers, rng, false)
	_check(base == [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5],
		"spread 1 base = consecutive triples")
	var jit: Array = BoardGenerator._assign_chunk_spread(18, 6, 3, cells, layers, rng, true)
	_check(jit.size() == 18, "jittered chunk spread covers all positions")
	var counts := {}
	for v in jit:
		counts[v] = counts.get(v, 0) + 1
	var each_three := true
	for c in counts.values():
		if c != 3:
			each_three = false
	_check(each_three, "jittered chunk spread: each type exactly 3 times")
	_check(BoardGenerator._tray_peak(jit) == 6, "jittered spread 3 peak == 6")
	var per_cell := {}
	var same_cell := false
	for i in range(18):
		if per_cell.has(cells[i]) and per_cell[cells[i]] == jit[i]:
			same_cell = true
		per_cell[cells[i]] = jit[i]
	_check(not same_cell, "jittered chunk spread avoids same-cell same-type")
	var per_type := {}
	for k in range(18):
		if not per_type.has(jit[k]):
			per_type[jit[k]] = []
		per_type[jit[k]].append(layers[k])
	var mostly_separated := 0
	for tp in per_type:
		var s := {}
		for ly in per_type[tp]:
			s[ly] = true
		if s.size() >= 2:
			mostly_separated += 1
	_check(mostly_separated >= 4, "jittered spread 3 assignment spreads copies across layers")

func _total_penalty(types: Array, cells: Array, layers: Array) -> int:
	var total := 0
	for i in range(types.size()):
		total += BoardGenerator._pairs_involving(types, cells, layers, i)
	return total / 2

func _same_layer_pairs(types: Array, cells: Array, layers: Array) -> int:
	var count := 0
	for i in range(types.size()):
		for j in range(i + 1, types.size()):
			if types[i] == types[j] and cells[i] == cells[j]:
				continue
			if types[i] == types[j] and layers[i] == layers[j]:
				count += 1
	return count

func _test_spatial_refinement():
	var cells := []
	var layers := []
	for i in range(18):
		cells.append(Vector2i(i % 6, i / 6))
		layers.append(i / 6)
	var types := [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5]
	var before := _total_penalty(types, cells, layers)
	_check(before > 0, "refinement fixture has penalized pairs")
	var same_before := _same_layer_pairs(types, cells, layers)
	_check(same_before > 0, "refinement fixture has same-layer pairs")
	BoardGenerator._refine_spatial(types, cells, layers, 6)
	_check(BoardGenerator._tray_peak(types) <= 6, "refinement keeps tray peak within cap")
	var counts := {}
	for v in types:
		counts[v] = counts.get(v, 0) + 1
	var each_three := true
	for c in counts.values():
		if c != 3:
			each_three = false
	_check(each_three, "refinement preserves type counts")
	_check(_total_penalty(types, cells, layers) < before, "refinement reduces penalized pairs")
	_check(_same_layer_pairs(types, cells, layers) < same_before, "refinement reduces same-layer pairs")

	var types2 := [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5]
	var cells2 := []
	var layers2 := []
	for i in range(18):
		cells2.append(Vector2i(i % 6, i / 6))
		layers2.append(i / 6)
	cells2[1] = cells2[0]
	BoardGenerator._refine_spatial(types2, cells2, layers2, 6)
	var same_cell_left := 0
	for i in range(18):
		for j in range(i + 1, 18):
			if types2[i] == types2[j] and cells2[i] == cells2[j]:
				same_cell_left += 1
	_check(same_cell_left == 0, "refinement removes same-cell penalty")
	_check(BoardGenerator._tray_peak(types2) <= 6, "refinement keeps same-cell fixture within cap")

func _tray_peak_for(layout: Dictionary) -> int:
	var pos := []
	var layer := []
	var cells := []
	for t in layout.tiles:
		pos.append(t.pos)
		layer.append(int(t.layer))
		cells.append(t.cell)
	var covering := BoardGenerator._covering_for(pos, layer)
	var covered_by := []
	for i in range(pos.size()):
		covered_by.append([])
	for i in range(pos.size()):
		for j in covering[i]:
			covered_by[j].append(i)
	var order := BoardGenerator._greedy_clear_order(cells, covering, covered_by)
	if order.size() != layout.tiles.size():
		return 999
	var ordered_types := []
	for k in range(order.size()):
		ordered_types.append(layout.tiles[order[k]].type)
	return BoardGenerator._tray_peak(ordered_types)

func _test_generation_speed():
	seed(9999)
	var level := 500
	var comb := []
	for i in range(LevelData.types_in_play(level)):
		comb.append(i)
	var s := Time.get_ticks_msec()
	var layout: Dictionary = BoardGenerator.generate(level, comb)
	var e := Time.get_ticks_msec()
	var elapsed := e - s
	_check(BoardGenerator._is_solvable(layout), "speed fixture: level 500 layout solvable")
	_check(elapsed < 3000, "level 500 generates in %d ms (< 3000)" % elapsed)

func _test_difficulty_ramp():
	var early_max := 0
	for level in range(1, 10):
		var comb := []
		for i in range(LevelData.types_in_play(level)):
			comb.append(i)
		var layout: Dictionary = BoardGenerator.generate(level, comb)
		early_max = maxi(early_max, _tray_peak_for(layout))
	_check(early_max <= 2, "levels 1-9 tray peak <= 2 (easy)")

	var mid_min := 99
	var mid_max := 0
	for level in range(10, 20):
		var comb := []
		for i in range(LevelData.types_in_play(level)):
			comb.append(i)
		var layout: Dictionary = BoardGenerator.generate(level, comb)
		var pk := _tray_peak_for(layout)
		mid_min = mini(mid_min, pk)
		mid_max = maxi(mid_max, pk)
	_check(mid_min >= 4 and mid_max <= 4, "levels 10-19 tray peak == 4")

	var late_min := 99
	var late_max := 0
	for level in range(20, 41):
		var comb := []
		for i in range(LevelData.types_in_play(level)):
			comb.append(i)
		var layout: Dictionary = BoardGenerator.generate(level, comb)
		var pk := _tray_peak_for(layout)
		late_min = mini(late_min, pk)
		late_max = maxi(late_max, pk)
	_check(late_min >= 5 and late_max <= 7, "levels 20-40 tray peak >= 5 and <= 7")

func _test_layer_diversity():
	var mid_span2 := 0
	var mid_types := 0
	for level in range(10, 25):
		var comb := []
		for i in range(LevelData.types_in_play(level)):
			comb.append(i)
		var layout: Dictionary = BoardGenerator.generate(level, comb)
		var counts := _span_counts(layout)
		mid_types += counts.types
		mid_span2 += counts.span2
	_check(float(mid_span2) / float(maxi(1, mid_types)) >= 0.55, "levels 10-24 most types span >= 2 levels")

	var late_span2 := 0
	var late_types := 0
	var late_span3 := 0
	for level in range(25, 46):
		var comb := []
		for i in range(LevelData.types_in_play(level)):
			comb.append(i)
		var layout: Dictionary = BoardGenerator.generate(level, comb)
		var counts := _span_counts(layout)
		late_types += counts.types
		late_span2 += counts.span2
		late_span3 += counts.span3
	_check(float(late_span2) / float(maxi(1, late_types)) >= 0.6, "levels 25-45 most types span >= 2 levels")
	_check(late_span3 > 0, "levels 25-45 some types span 3 levels")

func _span_counts(layout: Dictionary) -> Dictionary:
	var per_type := {}
	for t in layout.tiles:
		if not per_type.has(t.type):
			per_type[t.type] = []
		per_type[t.type].append(int(t.layer))
	var span2 := 0
	var span3 := 0
	for tp in per_type:
		var s := {}
		for ly in per_type[tp]:
			s[ly] = true
		if s.size() >= 2:
			span2 += 1
		if s.size() >= 3:
			span3 += 1
	return {"span2": span2, "span3": span3, "types": per_type.size()}

func _count_span2(layout: Dictionary) -> int:
	return int(_span_counts(layout).span2)

func _count_span3(layout: Dictionary) -> int:
	return int(_span_counts(layout).span3)

func _test_ui_transition_overlay():
	var ut := root.get_node("UiTransition")
	_check(not ut._overlay.visible, "overlay starts hidden so it cannot block input")
	ut.fade_out(0.02)
	_check(ut._overlay.visible, "overlay shows while fading out")
	await create_timer(0.1).timeout
	ut.fade_in(0.02)
	await create_timer(0.1).timeout
	_check(not ut._overlay.visible, "overlay hides after fade_in completes")

func _test_level_data():
	_check(LevelData.types_in_play(1) == 6, "types_in_play(1) == 6")
	_check(LevelData.types_in_play(10) == 6, "types_in_play(10) == 6")
	_check(LevelData.types_in_play(11) == 7, "types_in_play(11) == 7")
	_check(LevelData.types_in_play(500) == 55, "types_in_play(500) == 55")
	_check(LevelData.types_in_play(510) == 56, "types_in_play(510) == 56")
	_check(LevelData.types_in_play(600) == 56, "types_in_play(600) == 56")
	_check(LevelData.tile_count(1) == 18, "tile_count(1) == 18")
	_check(LevelData.tile_count(500) == 165, "tile_count(500) == 165")
	_check(LevelData.tile_count(510) == 168, "tile_count(510) == 168")
	_check(LevelData.tile_count(600) == 168, "tile_count(600) == 168")
	_check(LevelData.max_pile_depth(4) == 2, "max_pile_depth(4) == 2")
	_check(LevelData.max_pile_depth(5) == 3, "max_pile_depth(5) == 3")
	_check(LevelData.max_pile_depth(24) == 3, "max_pile_depth(24) == 3")
	_check(LevelData.max_pile_depth(25) == 4, "max_pile_depth(25) == 4")
	_check(LevelData.max_pile_depth(120) == 4, "max_pile_depth(120) == 4")
	_check(LevelData.spread(1) == 1, "spread(1) == 1")
	_check(LevelData.spread(9) == 1, "spread(9) == 1")
	_check(LevelData.spread(10) == 2, "spread(10) == 2")
	_check(LevelData.spread(19) == 2, "spread(19) == 2")
	_check(LevelData.spread(20) == 3, "spread(20) == 3")
	_check(LevelData.spread(500) == 3, "spread(500) == 3")
	_check(absf(LevelData.time_limit(1) - 26.0) < 0.001, "time_limit(1) == 26.0")
	_check(absf(LevelData.time_limit(10) - 26.0) < 0.001, "time_limit(10) == 26.0")
	_check(absf(LevelData.time_limit(19) - 29.9) < 0.001, "time_limit(19) == 29.9")
	_check(absf(LevelData.time_limit(20) - 29.9) < 0.001, "time_limit(20) == 29.9")
	_check(LevelData.star_3_time(18) == 45.0, "star_3_time(18) == 45.0")
	_check(LevelData.star_2_time(18) == 72.0, "star_2_time(18) == 72.0")
	_check(LevelData.unlocked_types(1) == [0, 1, 2, 3, 4, 5], "unlocked_types(1) == [0..5]")
	_check(LevelData.unlocked_types(10) == [0, 1, 2, 3, 4, 5], "unlocked_types(10) == [0..5]")
	_check(LevelData.unlocked_types(11) == [0, 1, 2, 3, 4, 5, 6], "unlocked_types(11) == [0..6]")

func _test_tile_database():
	_check(TileDatabase.get_count() == 56, "TileDatabase.get_count() == 56")
	_check(TileDatabase.get_texture_path(0) == "res://assets/tiles/tile_00.png", "texture path zero-padded")
	_check(TileDatabase.get_entry(55).size() > 0, "entry 55 exists")
	_check(TileDatabase.get_entry(56).is_empty(), "entry 56 out of range")
	_check(TileDatabase.get_catalog_name(0) == "Parang Diagonal \u2013 Indigo", "catalog_en for type 0")
	_check(TileDatabase.get_catalog_name(0, "id").length() > 0, "catalog_id for type 0")

func _test_tile_art():
	var tex: Texture2D = TileArt.get_texture(0)
	_check(tex != null, "TileArt texture for type 0 exists")
	if tex != null:
		var img: Image = tex.get_image()
		_check(img != null, "TileArt texture has image")
		if img != null:
			_check(img.get_width() == TileArt.BAKE_SIZE, "TileArt texture baked at BAKE_SIZE")
			var top: Color = img.get_pixel(TileArt.BAKE_SIZE / 2, 1)
			_check(top.a > 0.99 and top.r > 0.95 and top.g > 0.95 and top.b > 0.95, "TileArt white border at top")
			var corner: Color = img.get_pixel(0, 0)
			_check(corner.a < 0.01, "TileArt transparent rounded corner")
	_check(TileArt.get_texture(999) == null, "TileArt missing raw returns null")
	_check(not TileArt.is_cached(3), "TileArt type 3 not cached before generate")
	TileArt.generate([3])
	_check(TileArt.is_cached(3), "TileArt.generate caches type 3")

func _test_scene_manager():
	var sm = load("res://autoload/SceneManager.gd").new()
	var dflt: Array = sm.default_combination(1)
	_check(dflt == [0, 1, 2, 3, 4, 5], "default_combination(1) == [0..5]")
	_check(sm.default_combination(10).size() == 6, "default_combination(10) has 6 types")
	_check(sm.default_combination(11).size() == 7, "default_combination(11) has 7 types")

func _test_generator():
	var comb := [0, 1, 2, 3, 4, 5]
	seed(1234)
	var layout: Dictionary = BoardGenerator.generate(1, comb)
	_check(layout.tiles.size() == 18, "level 1 board has 18 tiles")
	_check(BoardGenerator._is_solvable(layout), "level 1 layout solvable")

	var rect: Rect2 = BoardGenerator.DEFAULT_RECT
	for t in layout.tiles:
		_check(rect.has_point(t.pos), "level 1 tile position inside DEFAULT_RECT")
		_check(rect.grow(64).encloses(Rect2(t.pos, Vector2(BoardGenerator.TILE_SIZE, BoardGenerator.TILE_SIZE))),
			"level 1 tile rect inside grown rect")

	var max_x := -INF
	var min_x := INF
	var max_y := -INF
	var min_y := INF
	for t in layout.tiles:
		max_x = maxf(max_x, t.pos.x)
		min_x = minf(min_x, t.pos.x)
		max_y = maxf(max_y, t.pos.y)
		min_y = minf(min_y, t.pos.y)
	_check(min_x < rect.get_center().x and max_x > rect.get_center().x, "level 1 slab centered across board width")
	_check(min_y < rect.get_center().y and max_y > rect.get_center().y, "level 1 slab centered across board height")

	var entries := []
	for t in layout.tiles:
		entries.append({"type": t.type, "pos": t.pos, "z": t.z, "removed": false})
	var accessible_count := 0
	for e in entries:
		if BoardGenerator.is_tile_accessible(e, entries):
			accessible_count += 1
	_check(accessible_count > 0, "level 1 has accessible tiles")
	_check(accessible_count < entries.size(), "level 1 has blocked (covered) tiles")

	for level in [1, 10, 50, 100, 300, 500]:
		var lvl_comb := []
		for i in range(LevelData.types_in_play(level)):
			lvl_comb.append(i)
		var lvl_layout: Dictionary = BoardGenerator.generate(level, lvl_comb)
		_check(lvl_layout.tiles.size() == LevelData.tile_count(level), "level %d tile count" % level)
		_check(BoardGenerator._is_solvable(lvl_layout), "level %d layout solvable" % level)
		var per_type := {}
		var uniq_pos := {}
		var max_layer := 0
		for t in lvl_layout.tiles:
			per_type[t.type] = per_type.get(t.type, 0) + 1
			uniq_pos[t.pos] = true
			max_layer = maxi(max_layer, int(t.z / BoardGenerator.CELL_STRIDE))
		var all_three := true
		for k in per_type:
			if per_type[k] != 3:
				all_three = false
		_check(all_three, "level %d every type appears exactly 3 times" % level)
		_check(uniq_pos.size() % 3 == 0, "level %d blob cell count multiple of 3" % level)
		_check(max_layer + 1 <= LevelData.max_pile_depth(level), "level %d max depth within limit" % level)

	var remaining_types := []
	for t in layout.tiles:
		remaining_types.append(t.type)
	var shuffled: Dictionary = BoardGenerator.shuffle_remaining(remaining_types, 1)
	_check(shuffled.tiles.size() == 18, "shuffle_remaining preserves tile count")
	_check(BoardGenerator._is_solvable(shuffled), "shuffled layout solvable")

func _test_scene_loads():
	var scenes := [
		"res://scenes/board/Board.tscn",
		"res://scenes/board/Tile.tscn",
		"res://scenes/tray/Tray.tscn",
		"res://scenes/main/Loading.tscn",
		"res://scenes/boutique/Boutique.tscn",
		"res://scenes/boutique/WorkshopPopup.tscn",
		"res://scenes/gallery/Gallery.tscn",
		"res://scenes/menu/MenuLevelSelect.tscn",
	]
	for s in scenes:
		_check(load(s) != null, "scene loads: " + s)

func _test_character():
	await process_frame
	var char_script := preload("res://scenes/character/Character.gd")
	var scene := load("res://scenes/character/Character.tscn")
	_check(scene != null, "character scene loads")
	var character = scene.instantiate()
	root.add_child(character)
	await process_frame
	var frames: SpriteFrames = character.sprite.sprite_frames
	_check(frames.get_animation_names().size() == 2, "character has coming + idle animations")
	_check(frames.get_frame_count("coming") == 13, "coming animation has 13 frames")
	_check(frames.get_frame_count("idle") == 47, "idle animation has 47 frames")
	_check(not frames.get_animation_loop("coming"), "coming does not loop")
	_check(frames.get_animation_loop("idle"), "idle loops")
	character.walk_in()
	_check(character.position == char_script.START_POSITION, "walk_in starts off-screen right")
	_check(character.sprite.animation == "coming", "walk_in plays coming animation")
	character.queue_free()

func _test_remove_skill_target():
	var buried := []
	var exposed := []
	for i in range(3):
		buried.append({"type": 0, "pos": Vector2(100 + i * 64, 100), "z": 0, "removed": false})
		exposed.append({"type": 1, "pos": Vector2(110 + i * 64, 110), "z": BoardGenerator.CELL_STRIDE, "removed": false})
	var buried_accessible := false
	for e in buried:
		if BoardGenerator.is_tile_accessible(e, buried + exposed):
			buried_accessible = true
	_check(not buried_accessible, "remove test: buried type is fully covered")
	var exposed_accessible := false
	for e in exposed:
		if BoardGenerator.is_tile_accessible(e, buried + exposed):
			exposed_accessible = true
	_check(exposed_accessible, "remove test: exposed type has accessible tile")
	_check(BoardGenerator.choose_remove_type(buried + exposed) == 1, "remove skill never picks fully buried type")

	var three := []
	var many := []
	for i in range(3):
		three.append({"type": 2, "pos": Vector2(300 + i * 64, 300), "z": BoardGenerator.CELL_STRIDE, "removed": false})
	for i in range(5):
		many.append({"type": 3, "pos": Vector2(500 + i * 64, 500), "z": BoardGenerator.CELL_STRIDE, "removed": false})
	_check(BoardGenerator.choose_remove_type(many + three) == 2, "remove skill prefers exact 3 over more numerous type")

	var lonely := [{"type": 4, "pos": Vector2(20, 20), "z": BoardGenerator.CELL_STRIDE, "removed": false}]
	_check(BoardGenerator.choose_remove_type(lonely) == -1, "remove skill returns -1 when no type has 2+ tiles")
	var all_gone := [{"type": 5, "pos": Vector2(20, 20), "z": BoardGenerator.CELL_STRIDE, "removed": true}]
	_check(BoardGenerator.choose_remove_type(all_gone) == -1, "remove skill returns -1 when all tiles removed")

func _test_remove3_preserves_tray_tiles():
	await process_frame
	var board = load("res://scenes/board/Board.tscn").instantiate()
	root.add_child(board)
	var tray_node = load("res://scenes/board/Tile.tscn").instantiate()
	root.add_child(tray_node)
	tray_node.setup(2, BoardGenerator.TILE_SIZE)
	var tray_entry := {"node": tray_node, "type": 2, "pos": Vector2(20, 20), "z": 0, "removed": true}
	var type1_nodes := []
	for i in range(3):
		var n = load("res://scenes/board/Tile.tscn").instantiate()
		root.add_child(n)
		n.setup(1, BoardGenerator.TILE_SIZE)
		n.position = Vector2(100 + i * 64, 100)
		type1_nodes.append(n)
	board._entries = [
		{"node": type1_nodes[0], "type": 1, "pos": Vector2(100, 100), "z": BoardGenerator.CELL_STRIDE, "removed": false},
		{"node": type1_nodes[1], "type": 1, "pos": Vector2(164, 100), "z": BoardGenerator.CELL_STRIDE, "removed": false},
		{"node": type1_nodes[2], "type": 1, "pos": Vector2(228, 100), "z": BoardGenerator.CELL_STRIDE, "removed": false},
		tray_entry,
	]
	var removed = await board.remove_triple()
	await process_frame
	_check(removed == 3, "remove3 removes exactly 3 tiles")
	_check(is_instance_valid(tray_node), "remove3 keeps tray tile nodes alive")
	_check(board._entries[3].node != null, "remove3 keeps tray tile node reference")

func _test_remove3_counts_as_solved():
	await process_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	main.start_level(3)
	var solved_types := []
	main.board.tile_solved.connect(func(type: int): solved_types.append(type))
	var entries := []
	for i in range(3):
		var node = load("res://scenes/board/Tile.tscn").instantiate()
		main.add_child(node)
		node.setup(7, BoardGenerator.TILE_SIZE)
		entries.append({
			"node": node,
			"type": 7,
			"pos": Vector2(100 + i * 64, 100),
			"z": BoardGenerator.CELL_STRIDE,
			"removed": false,
		})
	main.board._entries = entries
	main.board._update_accessibility()
	var removed = await main.board.remove_triple()
	_check(removed == 3, "remove3 test removes the solved type")
	_check(solved_types == [7], "remove3 reports the solved tile type")
	main._win()
	_check(sm.tile_fabrics.get(7, 0) == 1, "remove3 solved type earns fabric")
	var popup := _first_result_popup(main)
	var grid: GridContainer = popup.get_node("Panel/Margin/VBox/PreviewScroll/PreviewCenter/PreviewGrid")
	_check(grid.get_child_count() == 1, "remove3 solved type appears in result preview")
	main.queue_free()

func _test_bgm_levels():
	await process_frame
	var music = root.get_node("MusicManager")
	var bus_idx := AudioServer.get_bus_index("Music")
	_check(bus_idx >= 0, "Music bus exists in bus layout")
	music.set_bgm_level(4)
	music.play_gameplay()
	_check(music._gameplay_player.playing, "bgm fixture: gameplay music playing")
	music.set_bgm_level(2)
	_check(not AudioServer.is_bus_mute(bus_idx), "music bus unmuted above level 0")
	_check(absf(AudioServer.get_bus_volume_db(bus_idx) - linear_to_db(0.5)) < 0.01, "bgm level 2 maps to 50% volume")
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	_check(config.get_value("settings", "bgm_level", -1) == 2, "bgm level persists to settings")
	music.set_bgm_level(0)
	_check(AudioServer.is_bus_mute(bus_idx), "bgm level 0 mutes the music bus")
	_check(not music._gameplay_player.playing, "bgm level 0 stops playback")
	music.play_main()
	_check(not music._main_player.playing, "play_main stays silent at bgm level 0")
	music.set_bgm_level(4)
	_check(music._main_player.playing, "raising bgm level resumes the active track")
	config = ConfigFile.new()
	config.load("user://settings.cfg")
	_check(config.get_value("settings", "bgm_level", -1) == 4, "restored bgm level persists")
	var legacy = ConfigFile.new()
	legacy.set_value("settings", "bgm_enabled", false)
	legacy.save("user://settings.cfg")
	music.load_bgm_setting()
	_check(music.bgm_level == 0, "legacy bgm_enabled=false migrates to level 0")
	legacy.set_value("settings", "bgm_enabled", true)
	legacy.save("user://settings.cfg")
	music.load_bgm_setting()
	_check(music.bgm_level == 4, "legacy bgm_enabled=true migrates to level 4")

func _test_bgm_restart_after_menu_fade():
	await process_frame
	var music = root.get_node("MusicManager")
	music.set_bgm_level(4)
	music.play_gameplay()
	_check(music._gameplay_player.playing, "restart fixture: gameplay music playing")
	music.play_main()
	await create_timer(0.7).timeout
	_check(not music._gameplay_player.playing, "gameplay music stopped after menu crossfade")
	music.play_gameplay()
	_check(music._gameplay_player.playing, "gameplay music restarts after replay")
	_check(absf(music._gameplay_player.volume_db) < 0.01, "gameplay music audible after replay (not faded out)")
	music.stop()

func _test_sfx_levels():
	await process_frame
	var sfx = root.get_node("SfxManager")
	var bus_idx := AudioServer.get_bus_index("SFX")
	_check(bus_idx >= 0, "SFX bus exists in bus layout")
	sfx.set_sfx_level(2)
	_check(not AudioServer.is_bus_mute(bus_idx), "sfx bus unmuted above level 0")
	_check(absf(AudioServer.get_bus_volume_db(bus_idx) - linear_to_db(0.5)) < 0.01, "sfx level 2 maps to 50% volume")
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	_check(config.get_value("settings", "sfx_level", -1) == 2, "sfx level persists to settings")
	sfx.set_sfx_level(0)
	_check(AudioServer.is_bus_mute(bus_idx), "sfx level 0 mutes the sfx bus")
	sfx.set_sfx_level(4)
	_check(not AudioServer.is_bus_mute(bus_idx), "sfx level 4 unmutes the sfx bus")

func _test_loading_stops_music():
	await process_frame
	var music = root.get_node("MusicManager")
	music.play_main()
	_check(music._main_player.playing, "menu music playing before loading")
	var loading = load("res://scenes/main/Loading.tscn").instantiate()
	root.add_child(loading)
	await process_frame
	_check(not music._main_player.playing, "menu music stops on the loading page")
	_check(not music._gameplay_player.playing, "gameplay music does not play on the loading page")
	loading.queue_free()

func _test_gameplay_music_after_board_setup():
	await process_frame
	var music = root.get_node("MusicManager")
	music.play_main()
	var main = load("res://scenes/main/Main.tscn").instantiate()
	var spy := MusicSpyBoard.new()
	spy.music_node = music
	var board_node := main.get_node("Board") as Node
	main.remove_child(board_node)
	board_node.queue_free()
	main.add_child(spy)
	spy.name = "Board"
	root.add_child(main)
	await process_frame
	_check(not spy.playing_during_setup, "gameplay music is not playing during board setup")
	_check(music._gameplay_player.playing, "gameplay music starts when the gameplay page is ready")
	_check(not music._main_player.playing, "menu music stops once gameplay starts")
	main.queue_free()

func _test_mood_mechanics():
	var sm = load("res://autoload/SaveManager.gd").new()
	sm.save_file_path = "user://test_mood_save.save"
	DirAccess.remove_absolute(sm.save_file_path)
	sm.reset_to_defaults()
	_check(sm.mood_level == 3, "mood starts at 3")
	var mood_sig := [0]
	sm.mood_changed.connect(func(m: int): mood_sig[0] = m)
	sm.lose_mood()
	_check(sm.mood_level == 2, "lose_mood drops mood to 2")
	_check(mood_sig[0] == 2, "lose_mood emits mood_changed")
	sm.lose_mood()
	sm.lose_mood()
	sm.lose_mood()
	sm.lose_mood()
	_check(sm.mood_level == 0, "lose_mood clamps at 0")
	_check(sm.last_failure_time > 0, "lose_mood records failure time")
	sm._apply_save_data({"mood_level": 3})
	_check(sm.mood_level == 3, "recovered mood can return to 3")
	sm.lose_mood()
	var before: int = sm.get_seconds_until_next_mood()
	_check(before > 0 and before <= 3600, "get_seconds_until_next_mood within an hour")
	sm.last_failure_time = int(Time.get_unix_time_from_system()) - 7200
	sm.accumulated_gameplay_sec = 0.0
	sm.apply_mood_recovery()
	_check(sm.mood_level == 3, "2 hours away recovers mood to full")
	sm.last_failure_time = int(Time.get_unix_time_from_system()) - 3600
	sm.accumulated_gameplay_sec = 0.0
	sm.mood_level = 0
	sm.apply_mood_recovery()
	_check(sm.mood_level == 1, "exactly 1 hour recovers 1 mood")
	sm.last_failure_time = int(Time.get_unix_time_from_system()) - 7200
	sm.mood_level = 0
	sm.apply_mood_recovery()
	_check(sm.mood_level == 2, "2 hours recover 2 mood")
	sm.last_failure_time = int(Time.get_unix_time_from_system()) - 1800
	sm.accumulated_gameplay_sec = 0.0
	sm.mood_level = 0
	sm.apply_mood_recovery()
	_check(sm.mood_level == 0, "half hour recovers nothing")

func _test_mood_save_roundtrip():
	var path := "user://test_mood_save.save"
	DirAccess.remove_absolute(path)
	var sm = load("res://autoload/SaveManager.gd").new()
	sm.save_file_path = path
	sm.mood_level = 1
	var stored_time := int(Time.get_unix_time_from_system()) - 500
	sm.last_failure_time = stored_time
	sm.accumulated_gameplay_sec = 42.5
	sm.save_game()
	var sm2 = load("res://autoload/SaveManager.gd").new()
	sm2.save_file_path = path
	_check(sm2.load_game(), "mood save loads")
	_check(sm2.mood_level == 1, "round-trip preserves mood_level")
	_check(sm2.last_failure_time == stored_time, "round-trip preserves last_failure_time")
	_check(absf(sm2.accumulated_gameplay_sec - 42.5) < 0.001, "round-trip preserves accumulated_gameplay_sec")
	sm2._apply_save_data({"mood_level": 2})
	_check(sm2.mood_level == 2, "old-format save defaults mood to 2 when provided")
	sm2._apply_save_data({})
	_check(sm2.mood_level == 3, "old-format save defaults mood to 3")
	DirAccess.remove_absolute(path)

func _test_skill_stock():
	var sm = load("res://autoload/SaveManager.gd").new()
	sm.save_file_path = "user://test_skill_save.save"
	DirAccess.remove_absolute(sm.save_file_path)
	sm.reset_to_defaults()
	_check(SaveManager.SKILL_CONFIG.undo.price == 10000, "undo costs 10000")
	_check(SaveManager.SKILL_CONFIG.shuffle.price == 20000, "shuffle costs 20000")
	_check(SaveManager.SKILL_CONFIG.remove3.price == 30000, "remove3 costs 30000")
	_check(SaveManager.SKILL_CONFIG.extra.price == 40000, "extra costs 40000")
	_check(SaveManager.SKILL_CONFIG.undo.stock_granted == 3, "purchase grants 3 uses")
	_check(sm.get_skill_stock("undo") == 0, "no free skill stock by default")
	var sig := ["", 0]
	sm.skill_stock_changed.connect(func(s: String, n: int):
		sig[0] = s
		sig[1] = n)
	sm.add_skill_stock("undo", 3)
	_check(sm.get_skill_stock("undo") == 3, "add_skill_stock adds stock")
	_check(sig[0] == "undo" and sig[1] == 3, "add_skill_stock emits skill_stock_changed")
	_check(sm.use_skill("undo"), "use_skill consumes stock")
	_check(sm.get_skill_stock("undo") == 2, "use_skill decrements stock")
	sm.reset_to_defaults()
	_check(not sm.use_skill("undo"), "use_skill fails at 0 stock")

func _test_spend_coins():
	var sm = load("res://autoload/SaveManager.gd").new()
	sm.save_file_path = "user://test_spend_save.save"
	DirAccess.remove_absolute(sm.save_file_path)
	sm.reset_to_defaults()
	sm.coins = 100
	_check(sm.spend_coins(60), "spend_coins succeeds with enough coins")
	_check(sm.coins == 40, "spend_coins deducts coins")
	_check(not sm.spend_coins(50), "spend_coins fails with insufficient coins")
	_check(sm.coins == 40, "failed spend leaves coins unchanged")
	DirAccess.remove_absolute(sm.save_file_path)

func _test_purchase_processed():
	var sm = load("res://autoload/SaveManager.gd").new()
	sm.save_file_path = "user://test_purchase_save.save"
	DirAccess.remove_absolute(sm.save_file_path)
	sm.reset_to_defaults()
	_check(not sm.is_purchase_processed("token_1"), "unprocessed token not processed")
	sm.mark_purchase_processed("token_1", "instant_coins_1")
	_check(sm.is_purchase_processed("token_1"), "processed token recorded")
	var path: String = sm.save_file_path
	sm.save_game()
	var sm2 = load("res://autoload/SaveManager.gd").new()
	sm2.save_file_path = path
	sm2.load_game()
	_check(sm2.is_purchase_processed("token_1"), "processed purchase survives round-trip")
	DirAccess.remove_absolute(path)

var _stub_ads_script = null

func _make_ads_manager() -> Node:
	if _stub_ads_script == null:
		_stub_ads_script = load("res://tests/stub_ads_manager.gd")
	var m: Node = _stub_ads_script.new()
	root.add_child(m)
	return m

func _test_ads_flow():
	await process_frame
	var ua := root.get_node("UnityAds")
	var m := _make_ads_manager()
	var got := {"failed": false}
	m.mood_reward_failed.connect(func(): got["failed"] = true)
	m._kick_off_flow(Label.new())
	_check(m.is_flow_active(), "F1 flow active right after kickoff")
	await create_timer(1.0).timeout
	_check(got["failed"], "F1 load timeout emits mood_reward_failed")
	_check(not m.is_flow_active(), "F1 flow inactive after load timeout")
	m.queue_free()

	await process_frame
	m = _make_ads_manager()
	got = {"failed": false}
	m.mood_reward_failed.connect(func(): got["failed"] = true)
	m._kick_off_flow(Label.new())
	ua.ad_loaded.emit("Rewarded_Android")
	ua.ad_completed.emit("Rewarded_Android", "SKIPPED")
	_check(got["failed"], "F2 skipped ad emits mood_reward_failed")
	_check(not m.is_flow_active(), "F2 flow inactive after skip")
	m.queue_free()

	await process_frame
	m = _make_ads_manager()
	m._sdk_initialized = true
	m._ensure_sdk_initialized()
	_check(m.init_calls == 0, "F3 no initialize() call when already initialized")
	m._sdk_initialized = false
	m._ensure_sdk_initialized()
	_check(m.init_calls == 1, "F3 initialize() called when not yet initialized")
	m.queue_free()

	await process_frame
	m = _make_ads_manager()
	got = {"failed": false}
	m.mood_reward_failed.connect(func(): got["failed"] = true)
	var result: int = m.start_mood_reward_flow(null)
	_check(result == m.StartResult.SDK_NOT_READY, "F4 SDK not ready returns SDK_NOT_READY")
	m._on_init_failed("TEST_ERROR", "init failed")
	_check(got["failed"], "F4 pending flow fails when SDK init fails")
	_check(not m.is_flow_active(), "F4 no flow running after pending init failure")
	m.queue_free()

	await process_frame
	m = _make_ads_manager()
	var earned := {"ok": false}
	m.mood_reward_earned.connect(func(): earned["ok"] = true)
	m._kick_off_flow(Label.new())
	ua.ad_loaded.emit("Rewarded_Android")
	ua.ad_completed.emit("Rewarded_Android", "COMPLETED")
	ua.rewarded.emit("Rewarded_Android")
	_check(m.is_flow_active(), "F2 first COMPLETED ad keeps flow active")
	ua.ad_loaded.emit("Rewarded_Android")
	ua.ad_completed.emit("Rewarded_Android", "COMPLETED")
	ua.rewarded.emit("Rewarded_Android")
	_check(earned["ok"], "F2 normal 2-ad COMPLETED flow still earns reward")
	_check(not m.is_flow_active(), "F2 flow finished after reward")
	m.queue_free()

func _test_mood_gate_blocks_level_start():
	await process_frame
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	var scene_manager := root.get_node("SceneManager")
	scene_manager.return_to_track = true
	var menu = load("res://scenes/menu/MenuLevelSelect.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await create_timer(0.6).timeout
	sm.mood_level = 0
	menu._on_level_selected(1)
	await process_frame
	_check(menu._confirmation_popup == null, "mood 0 blocks the level confirmation popup")
	var has_empty_popup := false
	for child in menu.get_children():
		if child is ColorRect and (child as ColorRect).color.a >= 0.5:
			has_empty_popup = true
	_check(has_empty_popup, "mood 0 shows the empty-mood popup")
	sm.mood_level = 1
	menu._on_level_selected(1)
	await process_frame
	_check(is_instance_valid(menu._confirmation_popup), "mood > 0 opens the level confirmation popup")
	if is_instance_valid(menu._confirmation_popup):
		menu._confirmation_popup.queue_free()
	menu.queue_free()

func _test_helpers_seeded_from_stock():
	await process_frame
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.add_skill_stock("undo", 3)
	sm.add_skill_stock("shuffle", 2)
	sm.add_skill_stock("remove3", 5)
	sm.add_skill_stock("extra", 1)
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start_level(1)
	_check(main.helpers.undo == 3 and main.helpers.shuffle == 2 and main.helpers.remove3 == 5 and main.helpers.extra == 1,
		"helpers seeded from purchased stock (no freebies)")
	main.queue_free()

func _test_skill_buttons_disabled():
	await process_frame
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.add_skill_stock("extra", 2)
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start_level(1)
	_check(main.undo_button.disabled and main.shuffle_button.disabled and main.remove3_button.disabled,
		"skill buttons disabled at zero stock")
	_check(not main.extra_button.disabled, "extra button enabled with stock")
	main._on_extra_pressed()
	_check(main.extra_button.disabled, "extra button disabled after one use per game")
	_check(main.helpers.extra == 1, "extra consumes only one stock on its single use")
	main.start_level(1)
	_check(not main.extra_button.disabled, "extra button re-enabled on new game")
	main.tray.capacity = main.tray.MAX_SLOTS
	var extra_before: int = main.helpers.extra
	main._on_extra_pressed()
	_check(main.helpers.extra == extra_before, "full tray blocks extra without consuming stock")
	_check(not main.extra_button.disabled, "extra button stays enabled when blocked by full tray")
	main.queue_free()

func _test_track_hud_built():
	await process_frame
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	var menu = load("res://scenes/menu/MenuLevelSelect.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._ensure_track_hud()
	await process_frame
	_check(menu._track_hud_built, "track HUD builds")
	_check(menu._mood_hearts.size() == 3, "track HUD shows 3 hearts")
	_check(menu._coin_label != null and menu._coin_label.text == "0", "track HUD shows coins")
	_check(menu._instant_mood_btn != null, "track HUD has the instant mood button")
	_check(menu._skill_buttons.size() == 4, "track HUD has 4 skill shop buttons")
	menu.queue_free()

func _test_instant_coins_popup():
	await process_frame
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	var boutique = load("res://scenes/boutique/Boutique.tscn").instantiate()
	root.add_child(boutique)
	await process_frame
	await process_frame
	boutique._show_instant_coins_popup()
	await process_frame
	_check(is_instance_valid(boutique._coin_popup), "instant coins popup opens")
	_check(boutique._coin_popup != null and boutique._iap_status != null, "instant coins popup has status label")
	boutique._close_instant_coins_popup()
	await process_frame
	_check(not is_instance_valid(boutique._coin_popup), "instant coins popup closes")
	boutique.queue_free()

func _test_cloth_database():
	_check(ClothDatabase.get_type_count() == 7, "cloth database has 7 types")
	_check(ClothDatabase.type_fabric(0) == 35 and ClothDatabase.type_seconds(0) == 105, "dress cost table")
	_check(ClothDatabase.type_fabric(1) == 15 and ClothDatabase.type_seconds(1) == 45, "pants cost table")
	_check(ClothDatabase.type_fabric(2) == 20 and ClothDatabase.type_seconds(2) == 60, "shawl cost table")
	_check(ClothDatabase.type_fabric(3) == 22 and ClothDatabase.type_seconds(3) == 66, "long shirt cost table")
	_check(ClothDatabase.type_fabric(4) == 17 and ClothDatabase.type_seconds(4) == 51, "short shirt cost table")
	_check(ClothDatabase.type_fabric(5) == 21 and ClothDatabase.type_seconds(5) == 63, "woman shirt cost table")
	_check(ClothDatabase.type_fabric(6) == 16 and ClothDatabase.type_seconds(6) == 48, "skirt cost table")
	for type_id in range(7):
		var motives := ClothDatabase.motives_for_type(type_id)
		_check(motives.size() == 56, "cloth type %d maps 56 motives" % type_id)
		_check(motives.has(45), "cloth type %d has a garment for tile 45" % type_id)
		_check(ClothDatabase.type_icon(type_id) != null, "cloth type %d has an icon" % type_id)

func _test_workshop_popup():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.tile_fabrics = {0: 123, 1: 123, 2: 123, 3: 123, 4: 123, 5: 123}
	var popup = load("res://scenes/boutique/WorkshopPopup.tscn").instantiate()
	root.add_child(popup)
	await process_frame
	popup.open(0)
	var grid: GridContainer = popup.get_node("Panel/Margin/VBox/MotiveScroll/MotiveGrid")
	_check(grid.get_child_count() == 56, "workshop popup shows all 56 tiles")
	var dropdown: OptionButton = popup.get_node("Panel/Margin/VBox/TypeGrid/TypeDropdown")
	for i in range(ClothDatabase.get_type_count()):
		_check(dropdown.get_item_icon(i) != null, "dropdown item %d has an icon" % i)
		_check(dropdown.get_item_id(i) == i, "dropdown item %d id matches cloth type" % i)
	var fabric_label: Label = popup.get_node("Panel/Margin/VBox/TypeGrid/FabricLabel")
	_check(fabric_label.text == str(ClothDatabase.type_fabric(0)), "fabric label shows selected type fabric cost")
	popup._on_type_selected(1)
	_check(fabric_label.text == str(ClothDatabase.type_fabric(1)), "fabric label updates on type change")
	popup._on_type_selected(0)
	var amount_color: Color = (grid.get_child(0).get_node("Amount") as Label).get_theme_color("font_color")
	_check(amount_color == Color.BLACK, "amount label font is black")
	var unlocked_count := 0
	var locked_count := 0
	for cell in grid.get_children():
		if cell.get_meta("locked"):
			locked_count += 1
		else:
			unlocked_count += 1
	_check(unlocked_count == 6 and locked_count == 50, "level 1 locks 50 of 56 tiles")
	_check(popup._selected_type == 0, "dress is the default selected cloth type")
	for cell in grid.get_children():
		if cell.get_meta("locked"):
			_check(cell.get_node("Amount").text == "?", "locked tile shows '?'")
			_check(cell.mouse_filter == Control.MOUSE_FILTER_IGNORE, "locked tile not tappable")
		else:
			var tid := int(cell.get_meta("tile_id"))
			_check(cell.get_node("Amount").text == str(sm.tile_fabrics[tid]), "unlocked tile shows its own fabric balance")
			_check(cell.mouse_filter == Control.MOUSE_FILTER_STOP, "unlocked tile tappable with default dress type")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	popup._on_motive_input(ev, 0)
	_check(popup._selected_motive == 0, "motive selectable with default dress type")
	popup._on_motive_input(ev, 6)
	_check(popup._selected_motive == 0, "locked tile cannot change the selection")
	popup._on_type_selected(1)
	_check(popup._selected_motive == -1, "reselecting type clears motive selection")
	popup._on_type_selected(0)
	sm.tile_fabrics[5] = 10
	popup._update_cells()
	var cell5 = grid.get_child(5)
	_check(cell5.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tile without enough fabric not tappable")
	popup._on_motive_input(ev, 5)
	_check(popup._selected_motive == -1, "tile without enough fabric cannot be selected")
	sm.tile_fabrics[5] = 100
	popup._update_cells()
	popup._refresh()
	popup._on_motive_input(ev, 5)
	_check(not popup.work_button.disabled, "work enabled with type + motive + enough tile fabric")
	sm.tile_fabrics[5] = 0
	popup._update_cells()
	popup._refresh()
	_check(popup.work_button.disabled, "work disabled when selected tile lacks fabric")
	var sfx := root.get_node("SfxManager")
	popup.cancel_button.pressed.emit()
	_check(sfx._click_player.playing, "workshop popup cancel button plays the click sound")
	popup.queue_free()

func _test_request_cloth_type_language():
	var tm := root.get_node("TranslationManager")
	var prev = tm.current_language
	tm.current_language = "id"
	tm._load_strings()
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	var boutique = load("res://scenes/boutique/Boutique.tscn").instantiate()
	root.add_child(boutique)
	await process_frame
	await process_frame
	_check(ClothDatabase.type_name(0, "id") == "Gaun", "dress name is Indonesian in the database")
	var row = boutique._make_request_row({"npc": "npc_03.png", "type": 0, "motive": 0})
	var type_label: Label = row.get_child(2)
	_check(type_label.text.contains("Gaun"), "request cloth type uses the Indonesian name")
	_check(not type_label.text.contains("Dress"), "request cloth type is not left in English")
	row.queue_free()
	boutique.queue_free()
	tm.current_language = prev
	tm._load_strings()

func _test_menu_click_guard():
	change_scene_to_file("res://scenes/menu/MenuLevelSelect.tscn")
	await process_frame
	var menu := current_scene
	var btn: Button = menu.get_node("MainMenuView/BoutiqueButton")
	var sfx := root.get_node("SfxManager")
	sfx.play_click()
	_check(sfx._click_player.playing, "click plays from the global SfxManager")
	btn.pressed.emit()
	_check(sfx._click_player.playing, "boutique press starts the click sound")
	await create_timer(0.5).timeout
	var menu_gone := not is_instance_valid(menu) or not menu.is_inside_tree()
	_check(menu_gone, "menu leaves the tree after the fade-out and navigation")
	if is_instance_valid(menu):
		menu.queue_free()

func _test_menu_popup_cancel_clicks():
	change_scene_to_file("res://scenes/menu/MenuLevelSelect.tscn")
	await create_timer(0.1).timeout
	await process_frame
	var menu := current_scene
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.mood_level = 1
	var sfx := root.get_node("SfxManager")
	menu._on_instant_mood_pressed()
	_check(is_instance_valid(menu._instant_popup), "instant mood popup opens")
	var cancel_btn := _find_cancel_texture_button(menu._instant_popup)
	_check(cancel_btn != null, "instant mood popup has a cancel button")
	if cancel_btn != null:
		cancel_btn.pressed.emit()
		_check(sfx._click_player.playing, "instant mood popup cancel plays the click sound")
	await process_frame
	_check(not is_instance_valid(menu._instant_popup), "instant mood popup closes on cancel")
	menu._on_skill_buy("undo")
	_check(is_instance_valid(menu._buy_popup), "skill buy popup opens")
	var cancel_tex := _find_cancel_texture_button(menu._buy_popup)
	_check(cancel_tex != null, "skill buy popup has a cancel button")
	if cancel_tex != null:
		cancel_tex.pressed.emit()
		_check(sfx._click_player.playing, "skill buy popup cancel plays the click sound")
	await process_frame
	_check(not is_instance_valid(menu._buy_popup), "skill buy popup closes on cancel")
	if is_instance_valid(menu):
		menu.queue_free()

func _test_skill_buy_popup_price_shown():
	change_scene_to_file("res://scenes/menu/MenuLevelSelect.tscn")
	await create_timer(0.1).timeout
	await process_frame
	var menu := current_scene
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.mood_level = 1
	var tm := root.get_node("TranslationManager")
	var price: int = sm.SKILL_CONFIG["undo"]["price"]
	var stock_granted: int = sm.SKILL_CONFIG["undo"]["stock_granted"]
	var price_text: String = tm.tf("skill_buy_price", [price, stock_granted])
	var insufficient_text: String = tm.t("insufficient_coins")

	sm.coins = price - 1
	menu._on_skill_buy("undo")
	_check(is_instance_valid(menu._buy_popup), "skill buy popup opens with insufficient coins")
	_check(_find_label_containing(menu._buy_popup, price_text) != null, "price label shown when coins insufficient")
	_check(_find_label_containing(menu._buy_popup, insufficient_text) != null, "insufficient-coins label shown when coins insufficient")
	var ok_btn := _find_button_by_text(menu._buy_popup, tm.t("ok"))
	_check(ok_btn != null and ok_btn.disabled, "ok button disabled when coins insufficient")
	menu._close_buy_popup()

	sm.coins = 999999
	menu._on_skill_buy("undo")
	_check(is_instance_valid(menu._buy_popup), "skill buy popup opens with sufficient coins")
	_check(_find_label_containing(menu._buy_popup, price_text) != null, "price label shown when coins sufficient")
	_check(_find_label_containing(menu._buy_popup, insufficient_text) == null, "no insufficient-coins label when coins sufficient")
	ok_btn = _find_button_by_text(menu._buy_popup, tm.t("ok"))
	_check(ok_btn != null and not ok_btn.disabled, "ok button enabled when coins sufficient")
	await process_frame
	if is_instance_valid(menu):
		menu.queue_free()

func _test_boutique_requests():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	var requests := BoutiqueManager.request_slots()
	_check(requests.size() == 3, "boutique fills 3 request slots")
	var seen := {}
	var ok := true
	var unlocked := LevelData.unlocked_types(sm.max_level)
	for r in requests:
		var key := [int(r.type), int(r.motive)]
		if seen.has(key):
			ok = false
		seen[key] = true
		if not unlocked.has(int(r.motive)):
			ok = false
		if not ClothDatabase.has_clothing(int(r.type), int(r.motive)):
			ok = false
		if not ResourceLoader.exists("res://assets/npc/%s" % r.npc):
			ok = false
	_check(ok, "requests unique on (type, motive) with unlocked craftable motives and existing NPCs")

func _find_numeric_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label and (child as Label).text.is_valid_int():
			return child
	return null

func _test_request_reward_badge():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	_check(BoutiqueManager.request_slots().size() == 3, "requests ready for reward badge check")
	var boutique = load("res://scenes/boutique/Boutique.tscn").instantiate()
	root.add_child(boutique)
	await process_frame
	await process_frame
	var rows: Array = boutique._request_container.get_children()
	_check(rows.size() == 3, "request area renders 3 rows")
	var all_ok := true
	for i in range(mini(rows.size(), BoutiqueManager.request_slots().size())):
		var req: Dictionary = BoutiqueManager.request_slots()[i]
		var expected := ClothDatabase.type_fabric(int(req.type)) * BoutiqueManager.batik_value(int(req.motive))
		var label := _find_numeric_label(rows[i])
		if label == null or label.text != str(expected):
			all_ok = false
	_check(all_ok, "every request row shows its coin reward")
	boutique.queue_free()

func _test_npc_files():
	var files := BoutiqueManager.npc_files()
	_check(files.size() == 18, "npc_files lists all 18 NPCs")

func _test_request_npc_diversity():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.boutique["requests"] = []
	seed(5)
	var npcs := {}
	var all_distinct := true
	for i in range(3):
		var req := BoutiqueManager._generate_request()
		if req.is_empty():
			_check(false, "request generated")
			return
		if npcs.has(req.npc):
			all_distinct = false
		npcs[req.npc] = true
		sm.boutique["requests"].append(req)
	_check(all_distinct, "3 request slots use different NPCs")

func _test_start_work():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	sm.tile_fabrics = {11: 100}
	var slots := BoutiqueManager.workshop_slots()
	_check(slots[0].state == "idle", "workshop slot 0 starts idle")
	_check(BoutiqueManager.start_work(0, 0, 11), "start_work accepts dress motive 11 with fabric")
	var after: Dictionary = BoutiqueManager.workshop_slots()[0]
	_check(after.state == "working", "slot becomes working")
	_check(float(after.finish_at) > Time.get_unix_time_from_system(), "finish_at is in the future")
	_check(sm.tile_fabrics[11] == 65, "start_work deducts dress fabric cost from the motive tile")
	_check(not BoutiqueManager.start_work(0, 1, 6), "start_work rejects a busy slot")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	sm.tile_fabrics = {11: 5}
	_check(not BoutiqueManager.start_work(0, 0, 11), "start_work rejects insufficient fabric")

func _test_reconcile():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	sm.tile_fabrics = {4: 100}
	_check(BoutiqueManager.start_work(0, 2, 4), "reconcile fixture starts work")
	var slot: Dictionary = BoutiqueManager.workshop_slots()[0]
	slot.finish_at = Time.get_unix_time_from_system() - 5.0
	BoutiqueManager.reconcile()
	_check(BoutiqueManager.workshop_slots()[0].state == "ready", "reconcile turns finished work ready")

func _test_serve():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	for i in range(56):
		sm.tile_fabrics[i] = 100
	var requests := BoutiqueManager.request_slots()
	var req: Dictionary = requests[0]
	var type_id: int = req.type
	var motive: int = req.motive
	var price := ClothDatabase.type_fabric(type_id) * BoutiqueManager.batik_value(motive)
	_check(BoutiqueManager.start_work(0, type_id, motive), "serve fixture starts work")
	var slot: Dictionary = BoutiqueManager.workshop_slots()[0]
	slot.finish_at = Time.get_unix_time_from_system() - 1.0
	BoutiqueManager.reconcile()
	var before_requests := BoutiqueManager.request_slots().size()
	var result := BoutiqueManager.serve(0)
	_check(result.matched, "serve on matching request reports match")
	_check(sm.coins == price, "matching serve grants full price")
	_check(BoutiqueManager.workshop_slots()[0].state == "idle", "slot returns to idle after serve")
	_check(BoutiqueManager.request_slots().size() == before_requests, "served request is replaced")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	for i in range(56):
		sm.tile_fabrics[i] = 100
	var requests2 := BoutiqueManager.request_slots()
	var wanted := {}
	for r in requests2:
		wanted[[int(r.type), int(r.motive)]] = true
	var type_id2 := -1
	var motive2 := -1
	for tid in range(7):
		for mid in ClothDatabase.motives_for_type(tid):
			if not wanted.has([tid, mid]):
				type_id2 = tid
				motive2 = mid
				break
		if type_id2 >= 0:
			break
	_check(BoutiqueManager.start_work(0, type_id2, motive2), "flash sale fixture starts work")
	var slot2: Dictionary = BoutiqueManager.workshop_slots()[0]
	slot2.finish_at = Time.get_unix_time_from_system() - 1.0
	BoutiqueManager.reconcile()
	var coins_before: int = sm.coins
	var result2 := BoutiqueManager.serve(0)
	_check(not result2.matched, "unmatched craft triggers flash sale")
	_check(sm.coins - coins_before == ClothDatabase.type_fabric(type_id2) * BoutiqueManager.batik_value(motive2) / 2, "flash sale pays half price (floored)")

func _test_extended_workshops():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	_check(not BoutiqueManager.slot_unlocked(1), "workshop 2 starts locked")
	_check(not BoutiqueManager.slot_unlocked(2), "workshop 3 starts locked")
	_check(not BoutiqueManager.buy_slot(1), "buy_slot rejected without coins")
	_check(not BoutiqueManager.buy_slot(2), "buy_slot workshop 3 rejected without coins")
	sm.coins = 50000
	_check(BoutiqueManager.buy_slot(2), "buy_slot unlocks workshop 3 with 50000 coins")
	_check(BoutiqueManager.slot_unlocked(2), "workshop 3 unlocks after its own purchase")
	_check(not BoutiqueManager.slot_unlocked(1), "workshop 2 still locked when workshop 3 bought directly")
	_check(sm.coins == 0, "buy_slot deducts 50000 coins")
	_check(not BoutiqueManager.buy_slot(2), "already-owned workshop not purchasable again")
	sm.coins = 50000
	_check(BoutiqueManager.buy_slot(1), "workshop 2 purchasable after workshop 3")
	_check(BoutiqueManager.slot_unlocked(1), "workshop 2 unlocks after its own purchase")
	_check(not BoutiqueManager.buy_slot(0), "workshop 1 not purchasable")
	_check(not BoutiqueManager.buy_slot(3), "out-of-range slot not purchasable")

func _test_extended_workshops_migration():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.boutique = {"extended_workshops": 1, "requests": [], "slots": sm.boutique["slots"]}
	BoutiqueManager.ensure_state()
	_check(BoutiqueManager.slot_unlocked(1), "old count save migrates to unlock workshop 2")
	_check(not BoutiqueManager.slot_unlocked(2), "old count save keeps workshop 3 locked")

func _find_button_by_text(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == text:
			return child
		var found := _find_button_by_text(child, text)
		if found != null:
			return found
	return null

func _find_label_containing(node: Node, text: String) -> Label:
	for child in node.get_children():
		if child is Label and (child as Label).text.contains(text):
			return child
		var found := _find_label_containing(child, text)
		if found != null:
			return found
	return null

func _find_cancel_texture_button(node: Node) -> TextureButton:
	for child in node.find_children("*", "TextureButton", true, false):
		var tn := (child as TextureButton).texture_normal
		if tn != null and tn.resource_path.contains("cancel"):
			return child as TextureButton
	return null

func _make_touch_event(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	return ev

func _make_drag_event(index: int, pos: Vector2) -> InputEventScreenDrag:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	return ev

func _test_locked_workshop_ui():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.coins = 1000
	var boutique = load("res://scenes/boutique/Boutique.tscn").instantiate()
	root.add_child(boutique)
	await process_frame
	await process_frame
	var panel: Panel = boutique._workshop_panels[1]
	var tm := root.get_node("TranslationManager")
	var buy_text: String = tm.tf("buy_workshop", [BoutiqueManager.EXTENDED_COST])
	var insufficient_text: String = tm.t("insufficient_coins")
	var buy_btn := _find_button_by_text(panel, buy_text)
	_check(buy_btn != null and buy_btn.disabled, "buy button disabled when coins insufficient")
	_check(_find_label_containing(panel, insufficient_text) != null, "insufficient-coins label shown when coins insufficient")

	sm.coins = 50000
	sm.add_coins(0)
	await process_frame
	await process_frame
	buy_btn = _find_button_by_text(panel, buy_text)
	_check(buy_btn != null and not buy_btn.disabled, "buy button enabled when coins sufficient")
	_check(_find_label_containing(panel, insufficient_text) == null, "insufficient-coins label hidden when coins sufficient")

	var sfx := root.get_node("SfxManager")
	buy_btn.pressed.emit()
	_check(sfx._click_player.playing, "workshop buy button plays the click sound")
	await process_frame
	_check(is_instance_valid(boutique._confirm_popup), "confirmation popup opens on purchase click")
	var ok_btn := _find_button_by_text(boutique._confirm_popup, tm.t("ok"))
	_check(ok_btn != null, "confirmation popup has an OK button")
	if ok_btn != null:
		ok_btn.pressed.emit()
		_check(sfx._click_player.playing, "confirmation OK button plays the click sound")
		await process_frame
	_check(BoutiqueManager.slot_unlocked(1), "workshop 2 unlocks after confirming purchase")
	_check(sm.coins == 0, "confirming purchase deducts the cost")
	boutique.queue_free()


func _test_gallery_page():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	for tile_id in range(TileDatabase.get_count()):
		_check(GalleryDescriptions.has_description(tile_id), "gallery has a description for tile %d" % tile_id)
		_check(not GalleryDescriptions.get_description(tile_id, "en").is_empty(), "gallery en description non-empty for tile %d" % tile_id)
		_check(not GalleryDescriptions.get_description(tile_id, "id").is_empty(), "gallery id description non-empty for tile %d" % tile_id)
	_check(GalleryDescriptions.has_description(TileDatabase.get_count()) == false, "gallery: out-of-range tile has no description")
	var gallery_script := load("res://scenes/gallery/Gallery.gd")
	sm.max_level = 1
	_check(not gallery_script.is_locked(0), "gallery tile 0 unlocked at max_level 1")
	_check(gallery_script.is_locked(55), "gallery tile 55 locked at max_level 1")
	_check(gallery_script.next_tile(55) == 0, "gallery next wraps 55 -> 0")
	_check(gallery_script.prev_tile(0) == 55, "gallery prev wraps 0 -> 55")
	_check(gallery_script.unlock_level(0) == 0, "gallery tile 0 unlocks after level 0")
	_check(gallery_script.unlock_level(5) == 0, "gallery tile 5 unlocks after level 0")
	_check(gallery_script.unlock_level(6) == 10, "gallery tile 6 unlocks after level 10")
	_check(gallery_script.unlock_level(55) == 500, "gallery tile 55 unlocks after level 500")
	_check(gallery_script.swipe_target(0, -80.0) == 1, "swipe left goes to next tile")
	_check(gallery_script.swipe_target(0, 80.0) == 55, "swipe right goes to previous tile")
	_check(gallery_script.swipe_target(55, -80.0) == 0, "swipe left wraps 55 -> 0")
	_check(gallery_script.swipe_target(0, 30.0) == -1, "short drag does not navigate")
	_check(gallery_script.swipe_target(0, -30.0) == -1, "short drag below threshold does not navigate")

	var gallery = load("res://scenes/gallery/Gallery.tscn").instantiate()
	root.add_child(gallery)
	await process_frame
	await process_frame
	_check(gallery._cloth_images.size() == 7, "gallery page shows 7 cloth-type images")
	_check(gallery._cloth_images[0].texture != null, "gallery first cloth image has a texture")
	_check(gallery._title_label.text.length() > 0, "gallery shows a title")
	_check(gallery._current_tile == 0, "gallery starts on tile 0")
	gallery._input(_make_touch_event(0, Vector2(200, 400), true))
	gallery._input(_make_drag_event(0, Vector2(120, 410)))
	gallery._input(_make_touch_event(0, Vector2(120, 410), false))
	await create_timer(0.4).timeout
	_check(gallery._current_tile == 1, "gallery swipe left goes to next tile")
	gallery._input(_make_touch_event(0, Vector2(120, 410), true))
	gallery._input(_make_drag_event(0, Vector2(260, 400)))
	gallery._input(_make_touch_event(0, Vector2(260, 400), false))
	await create_timer(0.4).timeout
	_check(gallery._current_tile == 0, "gallery swipe right goes to previous tile")
	gallery.queue_free()

func _test_gallery_instant_swap():
	await process_frame
	var gallery = load("res://scenes/gallery/Gallery.tscn").instantiate()
	root.add_child(gallery)
	await process_frame
	await process_frame
	var before: int = gallery._current_tile
	var gallery_script := load("res://scenes/gallery/Gallery.gd")
	gallery._on_next_pressed()
	_check(gallery._current_tile == gallery_script.next_tile(before), "next button swaps tile instantly without fade")
	gallery._on_prev_pressed()
	_check(gallery._current_tile == before, "prev button swaps tile instantly without fade")
	gallery.queue_free()


func _test_old_sewing_machine():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.coins = 100000
	var tm := root.get_node("TranslationManager")
	var boutique = load("res://scenes/boutique/Boutique.tscn").instantiate()
	root.add_child(boutique)
	await process_frame
	await process_frame
	sm.boutique["slots"][0]["upgrade"] = 1
	boutique._refresh_workshop(0)
	await process_frame
	var panel: Panel = boutique._workshop_panels[0]
	var machine := _find_texture_rect(panel, boutique.OLD_SEWING_TEX)
	_check(machine != null, "tier-1 idle panel shows the old sewing machine image")
	if machine != null:
		_check(machine.size == Vector2(96, 73), "old sewing machine at 96x73")
	var character := panel.get_node_or_null("Character")
	if character != null:
		var combo_w: float = boutique.OLD_SEWING_SIZE.x + boutique.CHARACTER_GAP + 216.0 * 0.24
		var left: float = (232.0 - combo_w) / 2.0
		_check(absf(character.position.x - (left + boutique.OLD_SEWING_SIZE.x + boutique.CHARACTER_GAP + 216.0 * 0.24 / 2.0)) < 0.5, "character shifted right so the pair is centered")
	sm.boutique["slots"][0]["upgrade"] = 2
	boutique._refresh_workshop(0)
	await process_frame
	var panel2: Panel = boutique._workshop_panels[0]
	var modern := _find_texture_rect(panel2, boutique.MODERN_SEWING_TEX)
	_check(modern != null, "tier-2 idle panel shows the modern sewing machine image")
	if modern != null:
		_check(modern.size == Vector2(62, 73), "modern sewing machine at 62x73")
		_check(absf(modern.position.y - (144.0 - boutique.MODERN_IDLE_Y_OFFSET - 73.0 / 2.0)) < 0.5, "modern machine moved up by 10px")
	var char2 := _find_character_node(panel2)
	if char2 != null:
		_check(absf(char2.position.y - (144.0 - boutique.MODERN_IDLE_Y_OFFSET)) < 0.5, "modern character moved up by 10px")
	var work_text: String = tm.t("work")
	var work_btn2 := _find_button_by_text(panel2, work_text)
	if work_btn2 != null:
		_check(absf(work_btn2.position.y - (190.0 - boutique.MODERN_IDLE_Y_OFFSET)) < 0.5, "modern work button moved up by 10px")
	boutique.queue_free()


func _find_texture_rect(node: Node, texture: Texture2D) -> TextureRect:
	for child in node.get_children():
		if child is TextureRect and (child as TextureRect).texture == texture:
			return child
		var found := _find_texture_rect(child, texture)
		if found != null:
			return found
	return null

func _find_character_node(node: Node) -> Node2D:
	for child in node.get_children():
		if child is Node2D and (child as Node2D).get_node_or_null("Sprite") != null:
			return child
		var found := _find_character_node(child)
		if found != null:
			return found
	return null


func _test_slot_upgrade_defaults():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	_check(BoutiqueManager.slot_upgrade(0) == 0, "new slot starts at tier 0")
	sm.boutique["slots"][0].erase("upgrade")
	BoutiqueManager.ensure_state()
	_check(BoutiqueManager.slot_upgrade(0) == 0, "old-format slot without upgrade defaults to 0")

func _test_upgrade_options():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	var tier0: Array = BoutiqueManager.upgrade_options(0)
	_check(tier0.size() == 2, "tier 0 offers old and modern")
	_check(int(tier0[0].tier) == 1 and int(tier0[0].cost) == 50000, "tier 0 first option is old for 50000")
	_check(int(tier0[1].tier) == 2 and int(tier0[1].cost) == 100000, "tier 0 second option is modern for 100000")
	sm.boutique["slots"][0]["upgrade"] = 1
	var tier1: Array = BoutiqueManager.upgrade_options(0)
	_check(tier1.size() == 1 and int(tier1[0].tier) == 2, "tier 1 offers only modern")
	sm.boutique["slots"][0]["upgrade"] = 2
	_check(BoutiqueManager.upgrade_options(0).is_empty(), "tier 2 offers nothing")

func _test_upgrade_slot():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	sm.coins = 0
	_check(not BoutiqueManager.upgrade_slot(0, 1), "upgrade rejected without coins")
	sm.coins = 200000
	_check(BoutiqueManager.upgrade_slot(0, 1), "upgrade to old succeeds with coins")
	_check(sm.coins == 150000, "upgrade to old deducts 50000 coins")
	_check(BoutiqueManager.slot_upgrade(0) == 1, "slot tier becomes 1")
	_check(not BoutiqueManager.upgrade_slot(0, 0), "downgrade to manual rejected")
	_check(BoutiqueManager.upgrade_slot(0, 2), "old can upgrade to modern")
	_check(BoutiqueManager.slot_upgrade(0) == 2, "slot tier becomes 2")
	_check(not BoutiqueManager.upgrade_slot(0, 2), "re-buying current tier rejected")
	sm.boutique["slots"][0]["upgrade"] = 0
	_check(not BoutiqueManager.upgrade_slot(1, 1), "locked slot cannot be upgraded")
	sm.coins = 50000
	BoutiqueManager.ensure_state()
	sm.tile_fabrics = {0: 100}
	_check(BoutiqueManager.start_work(0, 1, 0), "busy fixture starts work")
	_check(not BoutiqueManager.upgrade_slot(0, 1), "working slot cannot be upgraded")
	var slot: Dictionary = BoutiqueManager.workshop_slots()[0]
	slot.finish_at = Time.get_unix_time_from_system() - 1.0
	BoutiqueManager.reconcile()
	_check(not BoutiqueManager.upgrade_slot(0, 1), "ready slot cannot be upgraded")

func _test_start_work_multiplier():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	BoutiqueManager.ensure_state()
	sm.tile_fabrics = {3: 500}
	var seconds := float(ClothDatabase.type_seconds(0))

	var now0 := Time.get_unix_time_from_system()
	_check(BoutiqueManager.start_work(0, 0, 3), "multiplier fixture starts work")
	_check(absf(float(BoutiqueManager.workshop_slots()[0].finish_at) - (now0 + seconds * 1.0)) < 1.0, "tier 0 uses full time")
	var slot: Dictionary = BoutiqueManager.workshop_slots()[0]
	slot.finish_at = Time.get_unix_time_from_system() - 1.0
	BoutiqueManager.reconcile()
	BoutiqueManager.serve(0)
	sm.boutique["slots"][0]["upgrade"] = 1

	var now1 := Time.get_unix_time_from_system()
	_check(BoutiqueManager.start_work(0, 0, 3), "old-machine fixture starts work")
	_check(absf(float(BoutiqueManager.workshop_slots()[0].finish_at) - (now1 + seconds * 0.75)) < 1.0, "tier 1 uses 75% of time")
	var slot2: Dictionary = BoutiqueManager.workshop_slots()[0]
	slot2.finish_at = Time.get_unix_time_from_system() - 1.0
	BoutiqueManager.reconcile()
	BoutiqueManager.serve(0)
	sm.boutique["slots"][0]["upgrade"] = 2

	var now2 := Time.get_unix_time_from_system()
	_check(BoutiqueManager.start_work(0, 0, 3), "modern-machine fixture starts work")
	_check(absf(float(BoutiqueManager.workshop_slots()[0].finish_at) - (now2 + seconds * 0.25)) < 1.0, "tier 2 uses 25% of time")

func _test_save_roundtrip_upgrade():
	var path := "user://test_upgrade_save.save"
	DirAccess.remove_absolute(path)
	var sm = load("res://autoload/SaveManager.gd").new()
	sm.save_file_path = path
	sm.boutique = {"unlocked_slots": [], "requests": [], "slots": [
		{"state": "idle", "type": 0, "motive": 0, "finish_at": 0.0, "upgrade": 2},
		{"state": "idle", "type": 0, "motive": 0, "finish_at": 0.0, "upgrade": 1},
		{"state": "idle", "type": 0, "motive": 0, "finish_at": 0.0},
	]}
	sm.save_game()
	var sm2 = load("res://autoload/SaveManager.gd").new()
	sm2.save_file_path = path
	_check(sm2.load_game(), "upgrade save loads")
	_check(int(sm2.boutique.slots[0].get("upgrade", 0)) == 2, "round-trip preserves slot 0 tier")
	_check(int(sm2.boutique.slots[1].get("upgrade", 0)) == 1, "round-trip preserves slot 1 tier")
	_check(int(sm2.boutique.slots[2].get("upgrade", 0)) == 0, "missing upgrade defaults to 0 on load")
	DirAccess.remove_absolute(path)

func _test_sewing_frames():
	var paths := [
		"res://assets/workshop/sewing_manual/frame_%03d.png",
		"res://assets/workshop/sewing_machine_old/frame_%03d.png",
		"res://assets/workshop/sewing_machine_modern/frame_%03d.png",
	]
	for path_fmt in paths:
		var label: String = path_fmt.get_slice("/", path_fmt.get_slice_count("/") - 2)
		for i in range(1, 31):
			var tex: Texture2D = load(path_fmt % i)
			_check(tex != null, "%s frame %03d loads" % [label, i])
			if tex != null:
				var img: Image = tex.get_image()
				_check(img != null and img.get_width() == 256 and img.get_height() == 256, "%s frame %03d is 256x256" % [label, i])

func _test_sewing_pingpong():
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.tile_fabrics = {3: 500}
	var boutique = load("res://scenes/boutique/Boutique.tscn").instantiate()
	root.add_child(boutique)
	await process_frame
	await process_frame
	_check(BoutiqueManager.start_work(0, 0, 3), "pingpong fixture starts manual work")
	boutique._refresh_workshop(0)
	await process_frame
	var panel: Panel = boutique._workshop_panels[0]
	var anim: AnimatedSprite2D = null
	for child in panel.get_children():
		if child is AnimatedSprite2D:
			anim = child
	_check(anim != null, "manual working panel has the sewing sprite")
	if anim == null:
		sm.tile_fabrics = {}
		boutique.queue_free()
		return
	var frames: SpriteFrames = anim.sprite_frames
	_check(frames.get_animation_names().size() == 2, "sewing sprite has forward + reverse animations")
	_check(frames.get_frame_count("sew") == 30 and frames.get_frame_count("sew_back") == 30, "both sewing animations have 30 frames")
	_check(not frames.get_animation_loop("sew") and not frames.get_animation_loop("sew_back"), "sewing animations do not loop")
	_check(anim.animation == "sew", "sewing sprite starts playing forward")
	anim.animation_finished.emit()
	_check(anim.animation == "sew_back", "sewing sprite reverses after forward cycle")
	anim.animation_finished.emit()
	_check(anim.animation == "sew", "sewing sprite plays forward again after reverse cycle")
	sm.tile_fabrics = {}
	boutique.queue_free()

func _test_save_boutique_roundtrip():
	var path := "user://test_boutique_save.save"
	DirAccess.remove_absolute(path)
	var sm = load("res://autoload/SaveManager.gd").new()
	sm.save_file_path = path
	sm.tile_fabrics = {3: 55, 12: 60}
	sm.boutique = {"unlocked_slots": [1], "requests": [{"npc": "npc_03.png", "type": 2, "motive": 9}], "slots": [{"state": "ready", "type": 0, "motive": 11, "finish_at": 100.0}, {"state": "idle", "type": 0, "motive": 0, "finish_at": 0.0}, {"state": "idle", "type": 0, "motive": 0, "finish_at": 0.0}]}
	sm.save_game()
	var sm2 = load("res://autoload/SaveManager.gd").new()
	sm2.save_file_path = path
	_check(sm2.load_game(), "boutique save loads")
	_check(sm2.tile_fabrics.get(3, 0) == 55 and sm2.tile_fabrics.get(12, 0) == 60, "round-trip preserves per-tile fabric")
	_check(sm2.boutique.unlocked_slots == [1], "round-trip preserves unlocked workshops")
	_check(sm2.boutique.requests[0].npc == "npc_03.png", "round-trip preserves request npc")
	_check(sm2.boutique.slots[0].state == "ready", "round-trip preserves slot state")
	sm2._apply_save_data({"max_level": 3})
	_check(sm2.tile_fabrics.is_empty(), "old-format save defaults per-tile fabric empty")
	_check(sm2.boutique.unlocked_slots.is_empty(), "old-format save defaults unlocked workshops empty")
	_check(sm2.boutique.slots.size() == 3, "old-format save defaults 3 workshop slots")
	DirAccess.remove_absolute(path)

func _test_fabric_banking():
	await process_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	main.start_level(3)
	main._on_matched(0)
	main._on_matched(1)
	_check(main._matches == 2, "matches counted per level")
	sm.reset_to_defaults()
	main.start_level(3)
	main._on_matched(0)
	_check(not sm.tile_fabrics.has(0), "fabric not banked while level running")
	main.time_left = 0.6 * LevelData.time_limit(3)
	main._win()
	_check(sm.tile_fabrics.get(0, 0) == 1, "fabric banked on win for the matched tile type")
	_check(not sm.tile_fabrics.has(1), "unmatched tile types get no fabric")
	var popup := _first_result_popup(main)
	_check(popup.get_node("Panel/Margin/VBox/FabricLabel").visible, "win popup shows fabric earned")
	_check(popup.get_node("Panel/Margin/VBox/FabricLabel").text.find("1") >= 0, "win popup fabric label shows the earned amount")
	var grid: GridContainer = popup.get_node("Panel/Margin/VBox/PreviewScroll/PreviewCenter/PreviewGrid")
	_check(grid.visible, "win popup shows preview grid")
	_check(grid.get_child_count() == 1, "win popup preview grid shows matched tile types only")
	main.queue_free()
