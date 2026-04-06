extends Control


func _ready() -> void:
	var restart_button: Button = $CenterContainer/PanelContainer/VBoxContainer/RestartButton
	restart_button.pressed.connect(_on_restart_button_pressed)


func _on_restart_button_pressed() -> void:
	var progression_manager := get_node_or_null("/root/ProgressionManager")
	if progression_manager != null:
		progression_manager.reset_run()

	get_tree().change_scene_to_file("res://scenes/game.tscn")
