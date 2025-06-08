extends Control

@onready var progress_bar: ProgressBar = $PlayerSpriteEren/ProgressBar
@onready var label: Label = $PlayerSpriteEren/Label

func _ready() -> void:
	progress_bar.value = progress_bar.max_value

func _process(delta: float) -> void:
	progress_bar.value -= 25 * delta
	if progress_bar.value <= progress_bar.min_value + 20:
		label.visible = true

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
