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

	# 探索フェーズ中は非表示・待機
	visible = false
	while Phasemanager.current_phase != Phasemanager.Phase.HIDE:
		await Phasemanager.phase_changed

	visible = true
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
		_on_checkpoint_reached(i)

		if i == checkpoints.size() - 1:
			queue_free()
		elif point["check"]:
			await play_check()


## チェックポイントまでの移動ロジック
func _move_to_ratio(target_ratio: float, curve_length: float) -> void:
	while path_follow.progress_ratio < target_ratio:
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

		# モンスター固有の移動更新拡張フック
		_on_movement_update(delta)

		await get_tree().process_frame
	path_follow.progress_ratio = target_ratio


## チェックアニメーション再生および襲撃判定用フック呼び出し
func play_check() -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("check"):
		sprite.play("check")
		await sprite.animation_finished

	# TODO: 将来の play_check 時の襲撃判定フック呼び出し
	# if can_attack_player():
	#     attack_player()


# ========================================================
# プレイヤー感知機能
# ========================================================
## プレイヤーが感知範囲内にいるか判定
func is_player_detected() -> bool:
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node is Node2D:
		var distance = global_position.distance_to((player_node as Node2D).global_position)
		return distance <= detection_radius
	return false


# ========================================================
# 将来の襲撃判定用フック (未実装機能用準備)
# ========================================================
## プレイヤーを襲撃可能か判定するフック
func can_attack_player() -> bool:
	# TODO: 将来的に以下のような判定を組み込む予定:
	# 1. プレイヤーを感知しているか (is_player_detected)
	# 2. 対応する弱点カテゴリのアイテム効果が有効でないか
	if not is_player_detected():
		return false
	return true


## 襲撃を実行するフック
func attack_player() -> void:
	# TODO: 将来の襲撃・ゲームオーバー処理を実装
	print("[%s] プレイヤーを襲撃！" % name)


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
