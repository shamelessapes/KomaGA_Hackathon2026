# ========================================================
# ７．ばけもの（いきもの）
# ========================================================

extends MonsterBase

## 今期のかくれんぼフェーズ中に「生き物」アイテムを一度でも食害したか
var has_eaten_creature_item_ever: bool = false


func _init() -> void:
	target_day = 7
	weakness_category = ["生き物"]


func _ready() -> void:
	has_eaten_creature_item_ever = false
	await super._ready()


func play_check() -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	var main_scene = get_tree().current_scene
	if main_scene and "is_captured" in main_scene and main_scene.is_captured:
		return

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("check"):
		sprite.play("check")

	# 1. 半径400px以内の「生き物」カテゴリのマップアイテムを検出
	var creature_nodes: Array[Node] = []
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
					if item_data and (item_data.has_category("生き物") or item_data.has_category(ItemDatabase.CATEGORY_CREATURE)):
						var delete_target: Node = area
						if item_node and item_node != area and not (item_node is SubViewport) and not (item_node is CanvasLayer):
							delete_target = item_node
						if not creature_nodes.has(delete_target):
							creature_nodes.append(delete_target)

	var has_creature_item_now: bool = creature_nodes.size() > 0

	if has_creature_item_now:
		has_eaten_creature_item_ever = true
		print("[Monster 7] 半径400px内に「生き物」アイテムを %d 個検知。queue_free します。" % creature_nodes.size())
		for node in creature_nodes:
			if is_instance_valid(node):
				node.queue_free()

	# 2. プレイヤーとの距離判定 (400px以内か)
	var player_pos: Vector2 = Vector2.ZERO
	if main_scene and "player" in main_scene and main_scene.player:
		player_pos = main_scene.player.global_position
	var dist_to_player: float = m_pos.distance_to(player_pos)
	var is_player_within_400px: bool = (player_pos != Vector2.ZERO and dist_to_player <= 400.0)

	if has_creature_item_now:
		# 今回のチェックで「生き物」アイテムを同時に検知した場合：プレイヤー捕獲は免除
		print("[Monster 7] 「生き物」アイテムを同時に検知したため、プレイヤーの捕獲は免除されます。")
	elif has_eaten_creature_item_ever:
		# 過去に一度でも「生き物」アイテムを食害済みの場合：問答無用捕獲には入らず、通常の難易度(95%)判定
		print("[Monster 7] 過去に生き物アイテムを食害済みのため、標準の発見判定(find_difficulty: 95%%)を行います。")
		_check_player_capture_on_check()
	else:
		# 一度も「生き物」アイテムを食害しておらず、今回も検知しなかった場合：
		# 半径400px以内にプレイヤーが存在する時のみ問答無用で捕獲
		if is_player_within_400px:
			print("[Monster 7] 一度も「生き物」アイテムを食害しておらず、半径400px内にプレイヤーを検知したため問答無用で捕獲します。(距離: %.1fpx)" % dist_to_player)
			if main_scene and main_scene.has_method("trigger_capture"):
				main_scene.trigger_capture(self)
		else:
			print("[Monster 7] 一度も「生き物」アイテムを食害していませんが、プレイヤーが半径400px外のため問答無用捕獲は行いません。(距離: %.1fpx)" % dist_to_player)
			_check_player_capture_on_check()

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("check"):
		await sprite.animation_finished
