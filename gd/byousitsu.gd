extends Node2D

## プレイヤーから隠れ場所までの最大許容距離
@export var hide_distance: float = 100.0

## プレイヤーからアイテムまでの最大取得許容距離
@export var item_pickup_distance: float = 100.0


## Monster回避の検出半径
@export var monster_avoid_radius: float = 50.0

## Monster回避の最大移動距離
@export var monster_avoid_distance: float = 50.0

## 出現位置調整の最大試行回数
@export var max_spawn_position_attempts: int = 10

## 状態管理
var is_hiding: bool = false
var current_hide_point: Area2D = null
var current_find_difficulty: float = 0.0
var pre_hide_player_position: Vector2 = Vector2.ZERO

## プレイヤーノード参照
@onready var player: CharacterBody2D = $player

## UIノード参照
@onready var hide_ui: CanvasLayer = $HideUI
@onready var confirmation_window: Control = $HideUI/HideConfirmationUI
@onready var question_label: Label = $HideUI/HideConfirmationUI/QuestionLabel
@onready var yes_button: Button = $HideUI/HideConfirmationUI/YesButton
@onready var no_button: Button = $HideUI/HideConfirmationUI/NoButton


func _ready() -> void:
	Global.fade_in(Color.BLACK)
	
	# ボタンシグナルの接続
	if yes_button:
		yes_button.pressed.connect(_on_yes_button_pressed)
	if no_button:
		no_button.pressed.connect(_on_no_button_pressed)
		
	# UIの初期状態は非表示
	hide_confirmation_ui()


func _unhandled_input(event: InputEvent) -> void:
	# 隠れている最中は右クリックを受け付けない（「出る？」UIを維持する）
	if is_hiding:
		return

	# 右クリックされた際にマウス位置でインタラクション判定を実行
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var mouse_pos: Vector2 = get_global_mouse_position()
			_handle_right_click_interaction(mouse_pos)


# ========================================================
# 1. 右クリックインタラクション処理 (優先順位: アイテム -> 隠れ場所)
# ========================================================
func _handle_right_click_interaction(click_pos: Vector2) -> void:
	if is_hiding:
		return

	# マウス位置にあるArea2Dを取得
	var clicked_area: Area2D = _get_area_at_position(click_pos)
	if clicked_area == null:
		return

	# 1. アイテム取得判定 (最優先)
	if clicked_area.is_in_group("item"):
		_try_pickup_item(clicked_area)
		return

	# 2. 隠れ場所判定
	if clicked_area.is_in_group("hide_point"):
		var distance: float = player.global_position.distance_to(clicked_area.global_position)
		if distance <= hide_distance:
			select_hide_point(clicked_area)


## アイテム拾い処理
func _try_pickup_item(area: Area2D) -> void:
	var item_node: Node = area.get_parent()
	var item_id: String = ""

	if item_node and "item_id" in item_node:
		item_id = item_node.item_id
	elif "item_id" in area:
		item_id = area.item_id

	if item_id == "":
		return

	# プレイヤーからの距離をチェック（100px以内か）
	var target_pos: Vector2 = area.global_position
	if item_node is Node2D:
		target_pos = (item_node as Node2D).global_position

	var distance: float = player.global_position.distance_to(target_pos)
	if distance > item_pickup_distance:
		return


	# アイテムノードのscaleを取得（transformの調整値の保持）
	var node_scale: Vector2 = Vector2.ONE
	if item_node is Node2D and item_node != self:
		node_scale = (item_node as Node2D).scale
	else:
		node_scale = area.scale

	if InventoryManager and InventoryManager.add_item(item_id, 1, node_scale):
		# 成功した場合、マップ上からアイテムノードを削除
		if item_node and item_node != self and item_node is Node2D:
			item_node.queue_free()
		else:
			area.queue_free()




## 既存互換用
func _check_and_select_hide_point(click_pos: Vector2) -> void:
	_handle_right_click_interaction(click_pos)



## 隠れ場所を選択し、メタデータの読み込みとUI表示を行う
func select_hide_point(area: Area2D) -> void:
	current_hide_point = area
	
	# GodotのInspectorで設定した metadata "find_difficulty" を取得 (デフォルト値 50)
	if area.has_meta("find_difficulty"):
		current_find_difficulty = float(area.get_meta("find_difficulty"))
	else:
		current_find_difficulty = 50.0
		
	print("隠れ場所を選択: ", area.name, " | 見つかりにくさ(find_difficulty): ", current_find_difficulty)
	
	# 「隠れる？」確認UIの表示
	show_hide_confirmation()


# ========================================================
# 2. 隠れ場所に実際に隠れる処理 (実行)
# ========================================================
func hide_player_in_current_point() -> void:
	if current_hide_point == null:
		return
		
	# 隠れる直前のプレイヤー位置を記録
	pre_hide_player_position = player.global_position
	
	# 隠れている状態にする
	is_hiding = true
	if player.has_method("set_hidden_state"):
		player.set_hidden_state(true, current_hide_point.global_position)
	else:
		player.global_position = current_hide_point.global_position
		player.visible = false

	print("プレイヤーが隠れました: ", current_hide_point.name, " (見つかりにくさ: ", current_find_difficulty, ")")
	
	# 隠れている最中の「出る？」UI表示に切り替え
	show_exit_confirmation()


# ========================================================
# 3. 隠れ場所から出る処理 (Monster検出・重複回避)
# ========================================================
func exit_hide_point() -> void:
	if not is_hiding:
		return
		
	# 出現予定位置の決定 (隠れる前の位置、なければ隠れ場所の位置)
	var candidate_position: Vector2 = pre_hide_player_position
	if candidate_position == Vector2.ZERO and current_hide_point != null:
		candidate_position = current_hide_point.global_position
		
	# 画面上のすべてのMonsterノードを取得
	var monster_nodes: Array[Node] = get_tree().get_nodes_in_group("monster")
	var monsters_near_spawn: Array[Node2D] = []
	
	for node in monster_nodes:
		if node is Node2D:
			var d: float = candidate_position.distance_to((node as Node2D).global_position)
			if d <= monster_avoid_radius:
				monsters_near_spawn.append(node as Node2D)
				
	# 1. 出現予定位置の50px以内にMonsterが存在した場合、「発見された」と判定
	if monsters_near_spawn.size() > 0:
		be_found()
		
	# 2. 出現位置の重複回避調整
	var final_spawn_position: Vector2 = candidate_position
	if monsters_near_spawn.size() > 0:
		final_spawn_position = _calculate_safe_spawn_position(candidate_position, monster_nodes)
		
	# 3. プレイヤーの隠れ状態解除と出現位置移動
	is_hiding = false
	if player.has_method("set_hidden_state"):
		player.set_hidden_state(false)
	else:
		player.visible = true
		
	player.global_position = final_spawn_position
	current_hide_point = null
	current_find_difficulty = 0.0
	
	print("隠れ場所から出ました。出現位置: ", final_spawn_position)
	
	# 4. UIを閉じる
	hide_confirmation_ui()


## 発見された際の処理 (現在はpassのみ)
func be_found() -> void:
	print("Monsterに発見されました！ (be_foundが呼び出されました)")
	pass


# ========================================================
# Monster回避アルゴリズム
# ========================================================
## Monsterから離れる安全な出現位置を計算
func _calculate_safe_spawn_position(start_pos: Vector2, monsters: Array[Node]) -> Vector2:
	# 全てのMonsterから離れる方向ベクトルを合成
	var combined_away_dir: Vector2 = Vector2.ZERO
	for node in monsters:
		if node is Node2D:
			var m_pos: Vector2 = (node as Node2D).global_position
			var diff: Vector2 = start_pos - m_pos
			if diff.length_squared() < 0.001:
				diff = Vector2.LEFT
			else:
				diff = diff.normalized()
			combined_away_dir += diff
			
	if combined_away_dir.length_squared() < 0.001:
		combined_away_dir = Vector2.UP
	else:
		combined_away_dir = combined_away_dir.normalized()

	var best_position: Vector2 = start_pos
	var max_min_distance: float = -1.0

	# max_spawn_position_attempts の回数だけ安全な位置を探索
	for i in range(max_spawn_position_attempts):
		var step_ratio: float = float(i + 1) / float(max_spawn_position_attempts)
		var offset_dist: float = monster_avoid_distance * step_ratio
		
		# 角度にわずかなバリエーションを付けて探索
		var angle_offset: float = 0.0
		if i > 0:
			angle_offset = (float(i % 4) - 1.5) * (PI / 4.0)
			
		var test_dir: Vector2 = combined_away_dir.rotated(angle_offset).normalized()
		var test_pos: Vector2 = start_pos + test_dir * offset_dist
		
		# 最もMonsterから離れられる位置を候補として保持
		var min_m_dist: float = _get_min_distance_to_monsters(test_pos, monsters)
		if min_m_dist > max_min_distance:
			max_min_distance = min_m_dist
			best_position = test_pos
			
		# 完全にMonsterの検知範囲外かつ衝突しない場所が見つかれば確定
		if min_m_dist >= monster_avoid_radius and _is_position_physics_safe(test_pos):
			return test_pos

	# 最大試行回数に達した場合は、最もMonsterから離れていた候補を採用
	return best_position


## 指定位置から最も近いMonsterまでの距離を計算
func _get_min_distance_to_monsters(pos: Vector2, monsters: Array[Node]) -> float:
	var min_dist: float = 999999.0
	for node in monsters:
		if node is Node2D:
			var d: float = pos.distance_to((node as Node2D).global_position)
			if d < min_dist:
				min_dist = d
	return min_dist


## 物理クエリでプレイヤーとMonster等のCollisionShape2Dが重ならないか確認
func _is_position_physics_safe(pos: Vector2) -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results: Array[Dictionary] = space_state.intersect_point(query)
	for res in results:
		var collider = res.collider
		if collider is Node2D and collider.is_in_group("monster"):
			return false
	return true


# ========================================================
# 物理クエリ・ユーティリティ
# ========================================================
## マウス位置の2D物理クエリでArea2Dを取得
func _get_area_at_position(pos: Vector2) -> Area2D:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results: Array[Dictionary] = space_state.intersect_point(query)
	for result in results:
		var collider = result.collider
		if collider is Area2D:
			return collider
	return null


# ========================================================
# UI制御 & シグナルハンドラ
# ========================================================
## 通常時：「隠れる？」確認UIを表示
func show_hide_confirmation() -> void:
	if question_label:
		question_label.text = "隠れる？"
	if yes_button:
		yes_button.text = "はい"
	if no_button:
		no_button.text = "いいえ"
	if confirmation_window:
		confirmation_window.show()

## 隠れ中：「出る？」確認UIを表示
func show_exit_confirmation() -> void:
	if question_label:
		question_label.text = "出る？"
	if yes_button:
		yes_button.text = "出る"
	if no_button:
		no_button.text = "出ない"
	if confirmation_window:
		confirmation_window.show()

## UIを非表示にする
func hide_confirmation_ui() -> void:
	if confirmation_window:
		confirmation_window.hide()

## 既存互換用
func open_hide_confirmation_ui() -> void:
	show_hide_confirmation()

func close_hide_confirmation_ui() -> void:
	hide_confirmation_ui()

## 「はい」または「出る」ボタンが押されたとき
func _on_yes_button_pressed() -> void:
	if is_hiding:
		exit_hide_point()
	else:
		hide_player_in_current_point()

## 「いいえ」または「出ない」ボタンが押されたとき
func _on_no_button_pressed() -> void:
	if is_hiding:
		# 「出ない」を押した場合は隠れ続け、UIもそのまま表示
		show_exit_confirmation()
	else:
		current_hide_point = null
		current_find_difficulty = 0.0
		hide_confirmation_ui()
