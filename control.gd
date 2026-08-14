extends Control

@onready var label: Label = $Label

@export var display_duration: float = 3.0
@export var fade_duration: float = 0.5

func _ready() -> void:
	label.modulate.a = 0.0
	Daymanager.day_changed.connect(_on_day_changed)
	_show_day_text()

func _on_day_changed(_new_day: int) -> void:
	_show_day_text()

func _show_day_text() -> void:
	label.text = Daymanager.get_day_display_text()

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, fade_duration)
	tween.tween_interval(display_duration)
	tween.tween_property(label, "modulate:a", 0.0, fade_duration)
