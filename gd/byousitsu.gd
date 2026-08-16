extends Node2D

## プレイヤーから隠れ場所までの最大許容距離
@export var hide_distance: float = 100.0

## プレイヤーからアイテムまでの最大取得許容距離
@export var item_pickup_distance: float = 100.0

## Inspector から探索フェーズの秒数を変更できる設定
@export_range(0.1, 600.0, 0.1, "suffix:s") var search_phase_duration: float = 60.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var day_display_duration: float = 3.0
@export_range(0.0, 5.0, 0.1, "suffix:s") var day_display_fade_duration: float = 0.5


## Monster回避の検出半径
@export var monster_avoid_radius: float = 50.0

## Monster回避の最大移動距離
@export var monster_avoid_distance: float = 50.0

## 出現位置調整の最大試行回数
@export var max_spawn_position_attempts: int = 10

## 捕獲演出の設定 (Inspector から変更可能)
@export var capture_duration: float = 1.5
@export var capture_zoom_delay: float = 1.0
@export var capture_zoom_scale: float = 7.5

## アイテム効果音の音量設定 (Inspector から変更可能)
@export_range(-80.0, 24.0, 0.5, "suffix:dB") var item_sound_volume_db: float = 0.0

## 状態管理
var is_hiding: bool = false
var is_captured: bool = false
var is_medicine_used_today: bool = false
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
@onready var day_label: Label = $DayUI/DayLabel
@onready var nioi_sprite: Sprite2D = get_node_or_null("nioi") as Sprite2D

var _day_label_tween: Tween
var _day_transition_in_progress := false
var initial_player_position: Vector2 = Vector2.ZERO
var timer_label: Label = null
var item_sound_player: AudioStreamPlayer = null


func _ready() -> void:
	Global.fade_in(Color.BLACK)
	is_captured = false
	is_hiding = false
	current_hide_point = null
	current_find_difficulty = 0.0
	_day_transition_in_progress = false

	if Phasemanager:
		Phasemanager.reset_to_search_phase()

	if nioi_sprite:
		nioi_sprite.hide()

	if player:
		initial_player_position = player.global_position

	item_sound_player = AudioStreamPlayer.new()
	item_sound_player.name = "ItemSoundPlayer"
	add_child(item_sound_player)

	_setup_timer_ui()

	# The scene owns the playable phase flow; the manager only keeps the state/timer.
	Phasemanager.search_phase_duration = search_phase_duration

	if not Phasemanager.search_phase_ended.is_connected(_on_search_phase_ended):
		Phasemanager.search_phase_ended.connect(_on_search_phase_ended)
	if not Phasemanager.hide_phase_ended.is_connected(_on_hide_phase_ended):
		Phasemanager.hide_phase_ended.connect(_on_hide_phase_ended)
	if not Daymanager.day_changed.is_connected(_on_day_changed):
		Daymanager.day_changed.connect(_on_day_changed)
	if InventoryManager and not InventoryManager.item_used.is_connected(_on_item_used):
		InventoryManager.item_used.connect(_on_item_used)

	spawn_current_day_monster()
	_connect_monster_exit_signals()
	_show_day_text()

	_start_day_flow()

	if SaveManager:
		SaveManager.save_game()
	
	# ボタンシグナルの接続
	if yes_button:
		yes_button.pressed.connect(_on_yes_button_pressed)
	if no_button:
		no_button.pressed.connect(_on_no_button_pressed)
		
	# UIの初期状態は非表示
	hide_confirmation_ui()

	# item および hide_point グループへのホバー白枠演出初期化
	_setup_all_hover_outlines()


func _start_day_flow() -> void:
	if Daymanager and Daymanager.current_day == 1:
		# 1日目: コード上で tutorial.tscn を動的生成。チュートリアルの合図があるまで探索を開始しない
		var tuto_scene = load("res://tscn/tutorial.tscn") as PackedScene
		if tuto_scene:
			var tuto_inst = tuto_scene.instantiate()
			add_child(tuto_inst)
			var cam = get_node_or_null("Camera2D") as Camera2D
			var hb = get_node_or_null("hintbook") as Area2D
			if tuto_inst.has_method("setup_references"):
				tuto_inst.setup_references(self, cam, hb)
			print("[Byousitsu] 1日目: コード上で tutorial.tscn を生成しました")
	elif Daymanager and Daymanager.current_day == 2:
		# 2日目: コード上で day2_text.tscn を動的生成。会話終了まで探索を開始しない
		var day2_scene = load("res://tscn/day2_text.tscn") as PackedScene
		if day2_scene:
			var day2_inst = day2_scene.instantiate()
			add_child(day2_inst)
			if day2_inst.has_method("setup_references"):
				day2_inst.setup_references(self)
			print("[Byousitsu] 2日目: コード上で day2_text.tscn を生成しました")
	else:
		Phasemanager.start_search_phase()
		$tansaku.play()


func _is_hint_book_open() -> bool:
	var hb = get_node_or_null("hintbook")
	return hb != null and "is_open" in hb and hb.is_open


func _is_tutorial_active() -> bool:
	var tuto = get_node_or_null("tutorial")
	return tuto != null and is_instance_valid(tuto) and "is_sequence_finished" in tuto and not tuto.is_sequence_finished


func _is_tutorial_waiting_hintbook() -> bool:
	var tuto = get_node_or_null("tutorial")
	return tuto != null and is_instance_valid(tuto) and "is_waiting_hintbook" in tuto and tuto.is_waiting_hintbook


func _is_day2_text_active() -> bool:
	var d2 = get_node_or_null("day2_text")
	return d2 != null and is_instance_valid(d2) and "is_finished" in d2 and not d2.is_finished


func _unhandled_input(event: InputEvent) -> void:
	# 隠れている最中・ヒント本を開いている最中・2日目会話進行中は移動を受け付けない
	if is_hiding or _is_hint_book_open() or _is_day2_text_active():
		return

	# チュートリアル中（ヒント本閲覧待機時以外）は移動を受け付けない
	if _is_tutorial_active() and not _is_tutorial_waiting_hintbook():
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
	if is_hiding or _is_hint_book_open() or _is_day2_text_active():
		return

	# マウス位置にあるArea2Dを取得
	var clicked_area: Area2D = _get_area_at_position(click_pos)
	if clicked_area == null:
		return

	# チュートリアル中のインタラクション制限
	if _is_tutorial_active():
		if _is_tutorial_waiting_hintbook():
			# ヒント本閲覧待機中: hintbook の右クリックのみ許可し、ヒント本を開く
			if clicked_area.has_method("open_book") or clicked_area.name == "hintbook":
				if clicked_area.has_method("open_book"):
					clicked_area.open_book()
		# ヒント本以外、または待機中でない場合は他のインタラクションを全て禁止
		return

	# 0. ヒント本インタラクション (特殊処理: インベントリ追加・消去なし)
	if clicked_area.has_method("open_book") or clicked_area.name == "hintbook":
		var distance: float = player.global_position.distance_to(clicked_area.global_position)
		if distance <= item_pickup_distance:
			if clicked_area.has_method("open_book"):
				clicked_area.open_book()
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


func _process(_delta: float) -> void:
	if Phasemanager and Phasemanager.current_phase == Phasemanager.Phase.SEARCH:
		if timer_label and timer_label.visible:
			var time_sec: int = max(0, int(ceil(Phasemanager._time_left)))
			timer_label.text = "残り時間: %d秒" % time_sec

	if item_sound_player and item_sound_player.playing:
		item_sound_player.volume_db = item_sound_volume_db


func _setup_timer_ui() -> void:
	var day_ui = get_node_or_null("DayUI")
	if day_ui == null:
		return

	timer_label = day_ui.get_node_or_null("TimerLabel") as Label
	if timer_label == null:
		timer_label = Label.new()
		timer_label.name = "TimerLabel"
		timer_label.anchors_preset = Control.PRESET_TOP_RIGHT
		timer_label.anchor_left = 1.0
		timer_label.anchor_top = 0.0
		timer_label.anchor_right = 1.0
		timer_label.anchor_bottom = 0.0
		timer_label.offset_left = -260.0
		timer_label.offset_top = 20.0
		timer_label.offset_right = -20.0
		timer_label.offset_bottom = 65.0
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var font_res = load("res://font/shippori3/ShipporiMincho-OTF-Bold.otf") as Font
		if font_res:
			timer_label.add_theme_font_override("font", font_res)
		timer_label.add_theme_font_size_override("font_size", 26)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		timer_label.add_theme_constant_override("outline_size", 4)
		day_ui.add_child(timer_label)

	timer_label.show()


func _on_search_phase_ended() -> void:
	$tansaku.stop()
	if timer_label:
		timer_label.hide()
	await Global.play_sound("res://sound/ドア閉.mp3")
	Phasemanager.start_hide_phase()
	if not is_medicine_used_today:
		$dokidoki.play()
	else:
		print("[Byousitsu] 本日は薬剤が使用されたため、かくれんぼフェーズの$dokidoki再生をスキップします")


func _on_hide_phase_ended() -> void:
	if is_captured or _day_transition_in_progress:
		return
	_day_transition_in_progress = true
	$dokidoki.stop()

	# かくれんぼフェーズ終了と同時にアイテムループ効果音を停止
	if item_sound_player:
		item_sound_player.stop()

	await Global.play_sound("res://sound/ドア閉.mp3")

	if Daymanager and Daymanager.current_day >= Daymanager.MAX_DAY:
		print("[Byousitsu] 7日目終了。エピローグ画面へ遷移します (3秒フェードアウト)")
		Global.change_scene_with_fade("res://tscn/ending.tscn", Color.BLACK, 3.0)
		return

	await Scenetransition.change_day()
	_day_transition_in_progress = false


func _connect_monster_exit_signals() -> void:
	for monster in get_tree().get_nodes_in_group("monster"):
		if not monster.tree_exited.is_connected(_on_monster_exited):
			monster.tree_exited.connect(_on_monster_exited)


func _on_monster_exited() -> void:
	if is_captured:
		return
	if Phasemanager.current_phase == Phasemanager.Phase.HIDE:
		print("[Byousitsu] 鬼が退出しました。翌日に切り替えます")
		Phasemanager.end_hide_phase()


func _on_day_changed(_new_day: int) -> void:
	# 0. 本日の薬剤使用フラグをリセット
	is_medicine_used_today = false

	# 1. 隠れ状態の解除、「出る？」UIの閉鎖、プレイヤー初期位置復元
	if is_hiding or current_hide_point != null:
		is_hiding = false
		if player and player.has_method("set_hidden_state"):
			player.set_hidden_state(false)
		elif player:
			player.visible = true
		current_hide_point = null
		current_find_difficulty = 0.0
		hide_confirmation_ui()

	if player and initial_player_position != Vector2.ZERO:
		player.global_position = initial_player_position

	# 2. 「音」効果音ループの停止
	if item_sound_player:
		item_sound_player.stop()

	# 3. 制限時間UIの表示再開
	if timer_label:
		timer_label.show()

	if nioi_sprite:
		nioi_sprite.hide()

	if Phasemanager:
		Phasemanager.reset_to_search_phase()

	_show_day_text()
	spawn_current_day_monster()
	_start_day_flow()


func _on_item_used(item_id: String, _slot_index: int) -> void:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return

	# 薬剤使用時は本日のかくれんぼフェーズ心音($dokidoki)を停止対象に設定
	if item_id == "medicine":
		is_medicine_used_today = true
		print("【薬剤使用】本日のかくれんぼフェーズの心音($dokidoki)再生を停止します。")

	# 匂い演出
	if item_data.has_category("匂い") or item_data.has_category(ItemDatabase.CATEGORY_SMELL):
		if nioi_sprite:
			nioi_sprite.show()

	# 音アイテム効果音ループ再生
	if item_data.has_category("音") or item_data.has_category(ItemDatabase.CATEGORY_SOUND) or item_data.sound_path != "":
		_play_loop_sound_for_item(item_data)


func _play_loop_sound_for_item(item_data: ItemDatabase.ItemData) -> void:
	if item_sound_player == null:
		return

	var s_path: String = item_data.sound_path
	if s_path == "" or not ResourceLoader.exists(s_path):
		var default_sounds = {
			"nursecall": "res://sound/ナースコール.mp3",
			"tv": "res://sound/砂嵐.mp3",
			"konsento": "res://sound/ドライヤー.mp3",
			"doraiya-": "res://sound/ドライヤー.mp3",
			"medicine": "res://sound/心音.mp3",
			"ketuatu": "res://sound/心音.mp3"
		}
		s_path = default_sounds.get(item_data.id, "")

	if s_path != "" and ResourceLoader.exists(s_path):
		var stream = load(s_path) as AudioStream
		if stream:
			if "loop" in stream:
				stream.set("loop", true)
			if "parameters/looping" in stream:
				stream.set("parameters/looping", true)
			item_sound_player.stream = stream
			item_sound_player.volume_db = item_sound_volume_db
			item_sound_player.play()
			print("【音アイテム再生開始】: ", item_data.name, " (パス: ", s_path, ", dB: ", item_sound_volume_db, ")")


## 現在の日数に応じたモンスターを PathFollow2D 配下に動的生成する
func spawn_current_day_monster() -> void:
	var path_follow = get_node_or_null("Path2D/PathFollow2D")
	if path_follow == null:
		return

	# PathFollow の進行度をリセット
	path_follow.progress_ratio = 0.0

	# 既存の monster グループノードがあれば削除
	for child in path_follow.get_children():
		if child.is_in_group("monster"):
			child.queue_free()

	var day = Daymanager.current_day
	var monster_scene_path = "res://tscn/monster/monster_%d.tscn" % day
	if not ResourceLoader.exists(monster_scene_path):
		print("[Byousitsu] モンスターシーンが存在しません: ", monster_scene_path)
		return

	var monster_scene = load(monster_scene_path) as PackedScene
	if monster_scene:
		var monster_instance = monster_scene.instantiate()
		if monster_instance is Node2D:
			(monster_instance as Node2D).position = Vector2(-221.876, -249.021)
		path_follow.add_child(monster_instance)
		if not monster_instance.tree_exited.is_connected(_on_monster_exited):
			monster_instance.tree_exited.connect(_on_monster_exited)
		print("[Byousitsu] %d 日目のモンスター (%s) を生成しました" % [day, monster_instance.name])


func _show_day_text() -> void:
	day_label.text = Daymanager.get_day_display_text()
	day_label.modulate.a = 0.0
	if _day_label_tween and _day_label_tween.is_valid():
		_day_label_tween.kill()
	_day_label_tween = create_tween()
	_day_label_tween.tween_property(day_label, "modulate:a", 1.0, day_display_fade_duration)
	_day_label_tween.tween_interval(day_display_duration)
	_day_label_tween.tween_property(day_label, "modulate:a", 0.0, day_display_fade_duration)


## アイテム拾い・設置物インタラクション処理
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

	var item_data = ItemDatabase.get_item(item_id)

	# 設置物カテゴリ判定
	if item_data and (item_data.has_category("設置物") or item_data.has_category(ItemDatabase.CATEGORY_SETTIBUTSU) or item_data.settibutsu != ""):
		_interact_with_settibutsu(item_data, area, item_node)
		return

	# 通常アイテムの拾い処理
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


## 設置物カテゴリの右クリックインタラクション
func _interact_with_settibutsu(item_data: ItemDatabase.ItemData, area: Area2D, item_node: Node) -> void:
	var required_item_id: String = item_data.settibutsu
	if required_item_id == "":
		# settibutsu 未設定時（tv や konsento 等）：右クリックしても何も起こらない
		return

	if InventoryManager == null:
		return

	# プレイヤーが settibutsu で指定された必要アイテムを所持しているか判定
	if not InventoryManager.has_item(required_item_id):
		# 未所持時：右クリックしても何も起こらない
		return

	# 必要アイテムを所持している場合：必要アイテムを1個消費（設置物自体は消去しない）
	var consumed = InventoryManager.remove_item_by_id(required_item_id, 1)
	if consumed:
		var req_data = ItemDatabase.get_item(required_item_id)
		var req_name = req_data.name if req_data else required_item_id
		print("【設置物使用】設置物 '%s' を作動。必要アイテム '%s' を1個消費しました。" % [item_data.name, req_name])

		# 後から設置物ごとの処理を追加できる拡張用フック呼び出し
		ItemDatabase.execute_settibutsu_effect(item_data.id, required_item_id, player, item_node if item_node != self else area)

		# 設置物作動時のループ効果音再生 (ドライヤー, 砂嵐等)
		var settibutsu_sounds = {
			"konsento": "res://sound/ドライヤー.mp3",
			"tv": "res://sound/砂嵐.mp3"
		}
		var sound_to_play: String = settibutsu_sounds.get(item_data.id, item_data.sound_path)
		if sound_to_play != "" and ResourceLoader.exists(sound_to_play):
			if item_sound_player:
				var stream = load(sound_to_play) as AudioStream
				if stream:
					if "loop" in stream:
						stream.set("loop", true)
					if "parameters/looping" in stream:
						stream.set("parameters/looping", true)
					item_sound_player.stream = stream
					item_sound_player.volume_db = item_sound_volume_db
					item_sound_player.play()
					print("【設置物音再生開始】: %s (パス: %s, dB: %.1f)" % [item_data.name, sound_to_play, item_sound_volume_db])




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


# ========================================================
# 捕獲処理 & 演出制御
# ========================================================
## 共通の捕獲処理関数 (プレイヤー・怪物の停止 -> go_X.png 表示 -> ズーム演出 -> title.tscn へ遷移)
func trigger_capture(monster: Node2D = null, delay: float = 0.0) -> void:
	if is_captured:
		return
	is_captured = true

	# 捕獲発生時は PhaseManager のフェーズタイマー進行を停止
	if Phasemanager:
		Phasemanager._timer_active = false

	var monster_name = monster.name if monster else "Unknown"
	print("==================================================")
	print("[捕獲発生] プレイヤーが捕まりました！ (Monster: %s)" % monster_name)
	print("==================================================")
	$tansaku.stop()
	$dokidoki.stop()
	Global.play_bgm_by_path("res://sound/ジャンプスケア.mp3",8.0)

	# 1. 怪物の姿を画面に確実に表示させ、動きを即座に停止（怪物は画面に表示されたまま静止）
	if monster:
		if monster.has_method("set_monster_visible"):
			monster.set_monster_visible(true)
		else:
			monster.visible = true
		monster.set_physics_process(false)
		if "speed" in monster:
			monster.speed = 0.0

	if player:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		if "is_moving" in player:
			player.is_moving = false
		if "velocity" in player:
			player.velocity = Vector2.ZERO

	# 隠れていない状態からの捕獲など、演出開始前のディレイ待機 (0.5秒)
	if delay > 0.0 and is_inside_tree() and get_tree() != null:
		print("[Byousitsu] 怪物を画面に表示したまま 捕獲演出開始前に %.1f 秒間待機します..." % delay)
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree() or get_tree() == null:
			return

	# 2. 捕獲画像 (go_X.png) 演出突入の瞬間に怪物の姿を非表示にする
	if monster:
		if monster.has_method("set_monster_visible"):
			monster.set_monster_visible(false)
		else:
			monster.visible = false

	# 隠れ確認UIを閉じる
	hide_confirmation_ui()

	# 2. 捕獲画像 (go_X.png) の決定
	var day: int = Daymanager.current_day
	if monster and "target_day" in monster:
		day = monster.target_day

	var img_path: String = "res://image/go_%d.png" % day
	var capture_tex: Texture2D = null
	if ResourceLoader.exists(img_path):
		capture_tex = load(img_path) as Texture2D
	else:
		push_warning("捕獲画像が見つかりません: %s" % img_path)

	# 3. 捕獲画像UIの表示とズーム演出
	var capture_ui = get_node_or_null("CaptureUI")
	var capture_rect: TextureRect = null
	if capture_ui:
		capture_rect = capture_ui.get_node_or_null("CaptureRect") as TextureRect

	if capture_rect and capture_tex:
		capture_rect.texture = capture_tex
		capture_rect.pivot_offset = capture_rect.size / 2.0
		capture_rect.scale = Vector2.ONE
		if capture_ui is CanvasLayer:
			(capture_ui as CanvasLayer).visible = true

		# 最初の capture_zoom_delay 秒間は通常サイズ、残り時間で急速ズームアップ
		var zoom_duration: float = max(0.1, capture_duration - capture_zoom_delay)
		var tween = create_tween()
		tween.tween_interval(capture_zoom_delay)
		tween.tween_property(capture_rect, "scale", Vector2.ONE * capture_zoom_scale, zoom_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished
	else:
		await get_tree().create_timer(capture_duration).timeout

	# 4. title.tscn へ直接パスを指定して遷移
	var target_scene_path: String = "res://tscn/title.tscn"
	print("[Byousitsu] 捕獲演出終了。直接パス '%s' へ遷移します" % target_scene_path)

	if is_inside_tree() and get_tree() != null:
		var err = get_tree().change_scene_to_file(target_scene_path)
		if err != OK:
			push_error("[Byousitsu] シーン遷移に失敗しました (%s)。Error code: %d" % [target_scene_path, err])
	else:
		push_error("[Byousitsu] ツリー離脱により get_tree() が null のため遷移できませんでした。")


# ========================================================
# ホバー時スプライト画像発光・点滅（ピカピカ）シェーダー演出機能 (item / hide_point グループ対象)
# ========================================================
const FLASH_SHADER_CODE: String = """
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (color.a > 0.0) {
		color.rgb = mix(color.rgb, flash_color.rgb, color.a * flash_modifier * 0.85);
	}
	COLOR = color;
}
"""

var _flash_shader: Shader = null


func _get_flash_shader_material() -> ShaderMaterial:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = FLASH_SHADER_CODE

	var mat = ShaderMaterial.new()
	mat.shader = _flash_shader
	mat.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
	mat.set_shader_parameter("flash_modifier", 0.0)
	return mat


func _setup_all_hover_outlines() -> void:
	for node in get_tree().get_nodes_in_group("item"):
		_setup_node_hover_outline(node)
	for node in get_tree().get_nodes_in_group("hide_point"):
		_setup_node_hover_outline(node)


func _setup_node_hover_outline(target: Node) -> void:
	if target == null:
		return

	var area: Area2D = null
	if target is Area2D:
		area = target as Area2D
	else:
		area = target.get_node_or_null("Area2D") as Area2D
		if area == null:
			for child in target.get_children():
				if child is Area2D:
					area = child as Area2D
					break

	if area == null:
		return

	var sprite: Sprite2D = _find_sprite_for_hover(target)
	if sprite == null:
		sprite = _find_sprite_for_hover(area)

	if sprite == null:
		return

	_attach_blinking_shader_to_sprite(area, sprite)


func _find_sprite_for_hover(node: Node) -> Sprite2D:
	if node == null:
		return null
	if node is Sprite2D:
		return node as Sprite2D
	for child in node.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	if node.get_parent() and node.get_parent() != self:
		for sibling in node.get_parent().get_children():
			if sibling is Sprite2D:
				return sibling as Sprite2D
	return null


func _attach_blinking_shader_to_sprite(area: Area2D, sprite: Sprite2D) -> void:
	if area == null or sprite == null:
		return

	var mat: ShaderMaterial = _get_flash_shader_material()
	var orig_material: Material = sprite.material

	var state = {
		"tween": null
	}

	var start_blink = func():
		if not is_instance_valid(sprite):
			return
		if state["tween"] and (state["tween"] as Tween).is_valid():
			(state["tween"] as Tween).kill()

		sprite.material = mat
		mat.set_shader_parameter("flash_modifier", 0.0)

		var tween = sprite.create_tween().set_loops()
		tween.tween_property(mat, "shader_parameter/flash_modifier", 0.85, 0.15).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mat, "shader_parameter/flash_modifier", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
		state["tween"] = tween

	var stop_blink = func():
		if state["tween"] and (state["tween"] as Tween).is_valid():
			(state["tween"] as Tween).kill()
			state["tween"] = null
		if is_instance_valid(sprite):
			mat.set_shader_parameter("flash_modifier", 0.0)
			sprite.material = orig_material

	if area.mouse_entered.is_connected(start_blink):
		area.mouse_entered.disconnect(start_blink)
	if area.mouse_exited.is_connected(stop_blink):
		area.mouse_exited.disconnect(stop_blink)

	area.mouse_entered.connect(start_blink)
	area.mouse_exited.connect(stop_blink)

	stop_blink.call()
