# ========================================================
# モンスター基底クラス (MonsterBase)
# 全モンスター(monster_1 ～ monster_7)の共通処理および拡張ポイントを定義
# ========================================================

class_name MonsterBase
extends CharacterBody2D

## 出現対象となる日数 (1 ～ 7)
@export var target_day: int = 1

## モンスターの弱点カテゴリ (例: ["音"], ["匂い"], ["音", "動く"])
@export var weakness_category: Array[String] = []

## プレイヤー感知範囲 (px)
@export var detection_radius: float = 100.0

## 移動速度
@export var speed: float = 60.0

## PathFollow2D 内での初期位置オフセット
@export var spawn_offset: Vector2 = Vector2(-221.876, -249.021)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var path_follow: PathFollow2D = get_parent() as PathFollow2D

var last_position: Vector2

## 巡回チェックポイント定義
var checkpoints: Array = [
	{"ratio": 0.1008, "check": true}, 
	{"ratio": 0.2237, "check": true},
	{"ratio": 0.3918, "check": true},
	{"ratio": 0.4620, "check": true}, 
	{"ratio": 0.5960, "check": true}, 
	{"ratio": 0.7545, "check": true},
	{"ratio": 0.9747, "check": true},
	{"ratio": 1.00, "check": true},
]

func _ready() -> void:
	# 初期位置オフセットの適用
	position = spawn_offset

	# 1. 日数判定: 自身の日数と Daymanager.current_day が一致しなければ消去
	if target_day != Daymanager.current_day:
		queue_free()
		return

	# モンスターグループに追加（未追加の場合の安全対策）
	if not is_in_group("monster"):
		add_to_group("monster")

	# 探索フェーズ中は非表示・待機 (必ず次の Phase.HIDE を待つ)
	set_monster_visible(false)
	while Phasemanager.current_phase != Phasemanager.Phase.HIDE:
		var new_phase = await Phasemanager.phase_changed
		if new_phase == Phasemanager.Phase.HIDE:
			break

	set_monster_visible(true)
	last_position = global_position

	if path_follow == null:
		push_warning("MonsterBase: 親ノードが PathFollow2D ではありません")
		return

	var path2d = path_follow.get_parent()
	if path2d == null or not ("curve" in path2d) or path2d.curve == null:
		return

	var curve_length: float = path2d.curve.get_baked_length()

	for i in range(checkpoints.size()):
		var point = checkpoints[i]
		await _move_to_ratio(point["ratio"], curve_length)

		# 捕獲発生時は巡回・チェック・消去を即座に完全停止
		var main_scene = get_tree().current_scene if get_tree() else null
		if main_scene and "is_captured" in main_scene and main_scene.is_captured:
			return

		_on_checkpoint_reached(i)

		if main_scene and "is_captured" in main_scene and main_scene.is_captured:
			return

		if i == checkpoints.size() - 1:
			queue_free()
		elif point["check"]:
			await play_check()

		if main_scene and "is_captured" in main_scene and main_scene.is_captured:
			return


## チェックポイントまでの移動ロジック
func _move_to_ratio(target_ratio: float, curve_length: float) -> void:
	while path_follow and is_inside_tree() and path_follow.progress_ratio < target_ratio:
		if get_tree() == null:
			return

		var main_scene = get_tree().current_scene
		if main_scene and "is_captured" in main_scene and main_scene.is_captured:
			return

		var delta = get_physics_process_delta_time()
		path_follow.progress_ratio += (speed * delta) / curve_length

		# 進行方向を計算してアニメーション切り替え
		var direction = global_position - last_position
		if direction.x < -0.01:
			if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("left"):
				sprite.play("left")
		elif direction.x > 0.01:
			if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("right"):
				sprite.play("right")
		last_position = global_position

		# 隠れていないプレイヤーへの即時接近・捕獲チェック
		_check_unhidden_player_capture()

		# モンスター固有の移動更新拡張フック
		_on_movement_update(delta)

		await get_tree().process_frame
		if not is_inside_tree() or get_tree() == null:
			return

	if path_follow and is_inside_tree():
		path_follow.progress_ratio = target_ratio


## チェックアニメーション再生および襲撃・発見判定
func play_check() -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	var main_scene = get_tree().current_scene
	if main_scene and "is_captured" in main_scene and main_scene.is_captured:
		return

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("check"):
		sprite.play("check")

	# play_check 時のプレイヤー発見・捕獲判定
	_check_player_capture_on_check()

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("check"):
		await sprite.animation_finished


# ========================================================
# プレイヤー感知および捕獲判定機能
# ========================================================
## モンスターおよび子ノードのスプライトの表示／非表示を一括制御
func set_monster_visible(is_vis: bool) -> void:
	visible = is_vis
	if sprite:
		sprite.visible = is_vis


## モンスターの見た目上の中心座標を取得
func get_monster_center_position() -> Vector2:
	if sprite:
		return sprite.global_position
	return global_position


## プレイヤーが感知範囲内にいるか判定 (見た目上のスプライト中心座標で距離を計算)
func is_player_detected() -> bool:
	if not is_inside_tree() or get_tree() == null:
		return false

	var player_node = get_tree().get_first_node_in_group("player")
	if player_node is Node2D:
		var m_pos = get_monster_center_position()
		var p_pos = (player_node as Node2D).global_position
		var distance = m_pos.distance_to(p_pos)
		return distance <= detection_radius
	return false


## 隠れていないプレイヤーへの即時感知・捕獲チェック (距離に関わらず即座に捕獲)
func _check_unhidden_player_capture() -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	if Phasemanager.current_phase != Phasemanager.Phase.HIDE:
		return

	var main_scene = get_tree().current_scene
	if main_scene == null or not ("is_hiding" in main_scene):
		return

	if "is_captured" in main_scene and main_scene.is_captured:
		return

	# プレイヤーが隠れていない場合、怪物を即座に表示して0.5秒間await待機後に捕獲演出を開始
	if not main_scene.is_hiding:
		if not can_avoid_capture():
			print("[%s] かくれんぼフェーズ中に隠れていないプレイヤーを発見！0.5秒後に捕獲演出へ移行します。" % name)
			set_monster_visible(true)
			if main_scene.has_method("trigger_capture"):
				main_scene.trigger_capture(self, 0.5)


## play_check 実行時の隠れている／隠れていないプレイヤーの発見判定
func _check_player_capture_on_check() -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	if Phasemanager.current_phase != Phasemanager.Phase.HIDE:
		return

	var main_scene = get_tree().current_scene
	if main_scene == null or not ("is_hiding" in main_scene):
		return

	if "is_captured" in main_scene and main_scene.is_captured:
		return

	var player_node = get_tree().get_first_node_in_group("player")
	var dist: float = -1.0
	if player_node is Node2D:
		dist = get_monster_center_position().distance_to((player_node as Node2D).global_position)

	print("[%s] play_check 実行中 (距離: %.1fpx / 判定半径: %.1fpx, プレイヤー隠れ状態: %s)" % [name, dist, detection_radius, main_scene.is_hiding])

	# 感知範囲内(100px)にプレイヤーがいるかチェック
	if not is_player_detected():
		print("[%s] プレイヤーは感知範囲外(%.1fpx > %.1fpx)のためスルーします。" % [name, dist, detection_radius])
		return

	# 捕まらない条件を満たしているかチェック
	if can_avoid_capture():
		print("[%s] 捕まらない条件を満たしているため回避されました。" % name)
		return

	# A. プレイヤーが隠れていない場合 -> 即時捕獲
	if not main_scene.is_hiding:
		print("[%s] play_check時に隠れていないプレイヤーを発見！捕獲します。" % name)
		if main_scene.has_method("trigger_capture"):
			main_scene.trigger_capture(self)
		return

	# B. プレイヤーが隠れている場合 -> Find_difficulty による確率判定
	var find_diff: float = 50.0
	if "current_find_difficulty" in main_scene:
		find_diff = float(main_scene.current_find_difficulty)

	# Find_difficulty は「見つからない確率（%）」
	# 発見閾値 (0 ～ 100)
	var found_threshold: float = 100.0 - find_diff
	var roll: float = randf() * 100.0

	if roll < found_threshold:
		# 見つかった（捕まった）場合
		print("[発見判定] 隠れ場所で発見されました！ (Find_difficulty: %.1f%% [見つからない確率], ロール値: %.1f < 発見閾値: %.1f)" % [find_diff, roll, found_threshold])
		if main_scene.has_method("trigger_capture"):
			main_scene.trigger_capture(self)
	else:
		# 見つからなかった（捕まらなかった）場合
		print("[発見判定] 隠れ場所で見つかりませんでした！ (Find_difficulty: %.1f%% [見つからない確率], ロール値: %.1f >= 発見閾値: %.1f)" % [find_diff, roll, found_threshold])


# ========================================================
# 将来の拡張フック (未実装機能用準備)
# ========================================================
## 将来用: Monster 2 以降の「捕まらない条件」判定フック
## 今後、モンスター固有の回避条件（アイテム効果等）を実装する際に各 monster_X.gd でオーバーライドします。
func can_avoid_capture() -> bool:
	return false


# ========================================================
# モンスター固有挙動の拡張ポイント (仮想メソッド)
# 各 monster_1.gd ～ monster_7.gd でオーバーライド可能
# ========================================================
## 移動フレームごとの追加処理
func _on_movement_update(_delta: float) -> void:
	pass


## チェックポイント到達時の追加処理
func _on_checkpoint_reached(_index: int) -> void:
	pass
