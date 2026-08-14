# ========================================================
# ５．ばけもの（おんど）
# ========================================================

extends MonsterBase

func _init() -> void:
	target_day = 5
	weakness_category = ["温度"]

# モンスター5固有の拡張処理が必要な場合は以下をオーバーライド可能
# func _on_movement_update(delta: float) -> void:
# 	super._on_movement_update(delta)

# func _on_checkpoint_reached(index: int) -> void:
# 	super._on_checkpoint_reached(index)
