# ========================================================
# ６．ばけもの（たべもの）
# ========================================================

extends MonsterBase

func _init() -> void:
	target_day = 6
	weakness_category = ["食べ物"]

# モンスター6固有の拡張処理が必要な場合は以下をオーバーライド可能
# func _on_movement_update(delta: float) -> void:
# 	super._on_movement_update(delta)

# func _on_checkpoint_reached(index: int) -> void:
# 	super._on_checkpoint_reached(index)
