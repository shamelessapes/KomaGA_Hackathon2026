# ========================================================
# ４．ばけもの（うごきかんち）
# ========================================================

extends MonsterBase

var moved_items_signaled: Array[Node] = []

func _init() -> void:
	target_day = 4
	weakness_category = ["動く"]


func _ready() -> void:
	super._ready()

	# メインシーンからの「動いた」シグナル受信接続
	var main_scene = get_tree().current_scene if get_tree() else null
	if main_scene and main_scene.has_signal("item_moved_signal"):
		if not main_scene.item_moved_signal.is_connected(_on_item_moved_signal):
			main_scene.item_moved_signal.connect(_on_item_moved_signal)


func _on_item_moved_signal(item_node: Node, _anim_sprite: AnimatedSprite2D) -> void:
	if item_node and is_instance_valid(item_node) and not item_node in moved_items_signaled:
		moved_items_signaled.append(item_node)
	print("[Monster_4] 「動いた」シグナルを受信しました: %s" % (item_node.name if item_node else "null"))


## play_check 実行時：半径400px以内の「動く」カテゴリかつ「動いた」シグナル発信済みアイテムをサーチして消去
func play_check() -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	var main_scene = get_tree().current_scene
	if main_scene and "is_captured" in main_scene and main_scene.is_captured:
		return

	_check_and_destroy_moving_items()

	await super.play_check()


## 「動く」カテゴリかつ「動いた」シグナル発信済みアイテムのサーチ・破壊処理
func _check_and_destroy_moving_items() -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	var detected_items: Array[Node] = []
	var monster_pos: Vector2 = get_monster_center_position()

	# シーン内のアイテムノード一覧を取得
	var items_to_check: Array = []
	var scene_items = get_tree().get_nodes_in_group("item")
	for item in scene_items:
		if not is_instance_valid(item):
			continue
		var target_node: Node = item
		if item is Area2D and item.get_parent() and item.get_parent().is_in_group("item"):
			target_node = item.get_parent()
		if not target_node in items_to_check:
			items_to_check.append(target_node)

	for item in moved_items_signaled:
		if is_instance_valid(item) and not item in items_to_check:
			items_to_check.append(item)

	for item in items_to_check:
		if not is_instance_valid(item):
			continue

		# アイテムIDの取得
		var item_id: String = ""
		if "item_id" in item:
			item_id = item.item_id
		elif item.has_meta("item_id"):
			item_id = item.get_meta("item_id")

		if item_id == "" or not ItemDatabase.has_item(item_id):
			continue

		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		# 1. 「動く」カテゴリの判定
		var is_motion_category = item_data.has_category("動く") or item_data.has_category("動き") or item_data.has_category(ItemDatabase.CATEGORY_MOTION)
		if not is_motion_category:
			continue

		# 2. 「動いた」シグナル発信済み判定
		var has_moved_signal = (item in moved_items_signaled) or (item.has_meta("ugoku_active") and item.get_meta("ugoku_active") == true)
		if not has_moved_signal:
			continue

		# 3. 半径400px以内の距離判定
		var item_pos: Vector2 = item.global_position
		var dist: float = monster_pos.distance_to(item_pos)
		print("[Monster_4] アイテム '%s' (ID: %s) との距離: %.1fpx (判定半径: 400.0px)" % [item.name, item_id, dist])

		if dist <= 600.0:
			detected_items.append(item)

	if detected_items.size() > 0:
		print("[Monster_4] 600px以内で「動く」かつ「動いた」アイテムを %d 個検知！" % detected_items.size())

		# 効果音 (res://sound/broken-glass.mp3) を1回再生
		Global.play_sound("res://sound/broken-glass.mp3")

		# 該当アイテムと対応する AnimatedSprite2D を消去
		for item in detected_items:
			if not is_instance_valid(item):
				continue

			# 対応する AnimatedSprite2D の削除
			var anim_sprite: AnimatedSprite2D = null
			if item.has_meta("anim_sprite"):
				anim_sprite = item.get_meta("anim_sprite") as AnimatedSprite2D
			elif item.item_id == "ketuatu" or "ketuatu" in item.name:
				anim_sprite = get_tree().current_scene.get_node_or_null("ugoku_ketuatu") as AnimatedSprite2D
			elif item.item_id == "tv" or "tv" in item.name:
				anim_sprite = get_tree().current_scene.get_node_or_null("ugoku_tv") as AnimatedSprite2D

			if anim_sprite and is_instance_valid(anim_sprite):
				print("[Monster_4] 対応する AnimatedSprite2D (%s) を queue_free します。" % anim_sprite.name)
				anim_sprite.queue_free()

			if item in moved_items_signaled:
				moved_items_signaled.erase(item)

			print("[Monster_4] 該当アイテム (%s) を queue_free します。" % item.name)
			item.queue_free()
