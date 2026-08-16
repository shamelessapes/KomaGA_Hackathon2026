# ========================================================
# ６．ばけもの（たべもの）
# ========================================================

extends MonsterBase

func _init() -> void:
	target_day = 6
	weakness_category = ["食べ物"]


func play_check() -> void:
	_check_and_eat_nearby_food_items()
	await super.play_check()


func _check_and_eat_nearby_food_items() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	if Phasemanager and Phasemanager.current_phase != Phasemanager.Phase.HIDE:
		return

	var food_nodes: Array[Node] = []
	var item_areas = get_tree().get_nodes_in_group("item")
	var m_pos = get_monster_center_position()

	for area in item_areas:
		if area is Area2D and is_instance_valid(area):
			var target_pos = (area as Area2D).global_position
			var item_node = area.get_parent()
			if item_node is Node2D:
				target_pos = (item_node as Node2D).global_position

			var dist = m_pos.distance_to(target_pos)
			if dist <= 400.0:
				var item_id: String = ""
				if item_node and "item_id" in item_node:
					item_id = item_node.item_id
				elif "item_id" in area:
					item_id = area.item_id

				if item_id != "":
					var item_data = ItemDatabase.get_item(item_id)
					if item_data and (item_data.has_category("食べ物") or item_data.has_category(ItemDatabase.CATEGORY_FOOD)):
						var delete_target: Node = area
						if item_node and item_node != area and not (item_node is SubViewport) and not (item_node is CanvasLayer):
							delete_target = item_node
						if not food_nodes.has(delete_target):
							food_nodes.append(delete_target)

	if food_nodes.size() > 0:
		Global.play_sound("res://sound/kari.mp3")
		print("[Monster 6] 半径400px内に食べ物アイテムを %d 個検知。res://sound/kari.mp3 を再生して消去します。" % food_nodes.size())
		for node in food_nodes:
			if is_instance_valid(node):
				node.queue_free()
