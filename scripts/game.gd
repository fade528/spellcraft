extends Node2D

const GAME_OVER_SCENE_PATH := "res://scenes/game_over.tscn"

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	var progression_manager := _get_progression_manager()
	if progression_manager != null:
		if progression_manager.lives <= 0:
			progression_manager.reset_run()

		progression_manager.life_lost.connect(_on_life_lost)
		progression_manager.game_over.connect(_on_game_over)


func _on_life_lost(lives_remaining: int) -> void:
	_clear_group("enemies")
	_clear_group("projectiles_active")

	if lives_remaining > 0 and player != null and player.has_method("respawn"):
		player.respawn()


func _on_game_over() -> void:
	get_tree().change_scene_to_file(GAME_OVER_SCENE_PATH)


func _clear_group(group_name: String) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node):
			node.queue_free()


func _get_progression_manager() -> Node:
	return get_node_or_null("/root/ProgressionManager")
