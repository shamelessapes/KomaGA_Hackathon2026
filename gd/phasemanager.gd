extends Node

enum Phase { SEARCH, HIDE }

## 探索フェーズの時間（秒）。数値を変えたい場合はここを直接編集する
@export var search_phase_duration: float = 60.0

signal phase_changed(phase: Phase)
signal search_phase_ended
signal hide_phase_ended

var current_phase: Phase = Phase.SEARCH
var _time_left: float = 0.0
var _timer_active: bool = false

func start_search_phase() -> void:
	current_phase = Phase.SEARCH
	_time_left = search_phase_duration
	_timer_active = true
	phase_changed.emit(current_phase)
	print("[PhaseManager] 探索フェーズ開始（%s秒）" % search_phase_duration)
	

var _print_timer := 0.0

func _process(delta):
	if current_phase == Phase.SEARCH and _timer_active:
		_time_left -= delta
		_print_timer += delta

		if _print_timer >= 1.0:
			_print_timer = 0.0
			print("[PhaseManager] 残り時間: %.1f秒" % _time_left)

		if _time_left <= 0.0:
			_timer_active = false
			search_phase_ended.emit()

func start_hide_phase() -> void:
	current_phase = Phase.HIDE
	_timer_active = false
	phase_changed.emit(current_phase)
	print("[PhaseManager] 隠れんぼフェーズ開始（鬼待機）")

## 鬼が退出したときに、外部（鬼のスクリプト等）から呼び出す
func end_hide_phase() -> void:
	hide_phase_ended.emit()
	print("[PhaseManager] 隠れんぼフェーズ終了（鬼退出）")
