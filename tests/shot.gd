extends SceneTree

func _init():
	_run()

func _run():
	await process_frame
	var sm := root.get_node("SaveManager")
	sm.reset_to_defaults()
	sm.tile_fabrics = {0: 500, 1: 400, 2: 300, 3: 200, 4: 100, 5: 50}
	sm.save_file_path = "user://real_flow.save"
	change_scene_to_file("res://scenes/boutique/Boutique.tscn")
	await process_frame
	await process_frame
	var boutique := current_scene
	boutique._open_workshop_popup(0)
	for f in [1, 3, 5, 10, 20]:
		await process_frame
		var grid: GridContainer = boutique._popup.get_node("Panel/Margin/VBox/MotiveScroll/MotiveGrid")
		var cells := grid.get_children()
		var t0: String = cells[0].get_node("Amount").text
		var t1: String = cells[6].get_node("Amount").text
		print("frame ", f, ": cell0=", t0, " cell6=", t1, " cell0 visible=", cells[0].get_node("Amount").visible)
		if f == 20:
			root.get_viewport().get_texture().get_image().save_png("/tmp/opencode/popup_real_flow.png")
	quit(0)
