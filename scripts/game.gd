extends Node2D

const GAME_OVER_SCENE_PATH := "res://scenes/game_over.tscn"
const SHAKE_MAGNITUDE := 8.0
const SHAKE_DURATION := 0.3

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var projectile_container: Node = $Projectiles
@onready var spell_hit_sfx: AudioStreamPlayer = $SpellHitSFX
@onready var player_hurt_sfx: AudioStreamPlayer = $PlayerHurtSFX
@onready var enemy_death_sfx: AudioStreamPlayer = $EnemyDeathSFX
@onready var crafting_ui = $CraftingUI

var last_known_hp: float = -1.0
var shake_tween: Tween


func _ready() -> void:
	child_entered_tree.connect(_on_game_child_entered_tree)
	projectile_container.child_entered_tree.connect(_on_projectile_child_entered_tree)

	var progression_manager := _get_progression_manager()
	if progression_manager != null:
		if progression_manager.lives <= 0:
			progression_manager.reset_run()

		progression_manager.life_lost.connect(_on_life_lost)
		progression_manager.game_over.connect(_on_game_over)
		progression_manager.hp_changed.connect(_on_hp_changed)
		last_known_hp = progression_manager.current_hp

	if crafting_ui != null:
		if crafting_ui.has_signal("ui_closed"):
			crafting_ui.connect("ui_closed", _on_crafting_ui_closed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if crafting_ui != null:
			if crafting_ui.visible:
				crafting_ui.close_ui()
			else:
				crafting_ui.open_ui()


func _on_life_lost(lives_remaining: int) -> void:
	_clear_group("enemies")
	_clear_group("projectiles_active")

	if lives_remaining > 0 and player != null and player.has_method("respawn"):
		player.respawn()


func _on_game_over() -> void:
	get_tree().change_scene_to_file(GAME_OVER_SCENE_PATH)


func _on_hp_changed(current_hp: float, _max_hp: float) -> void:
	if last_known_hp >= 0.0 and current_hp < last_known_hp:
		_play_camera_shake()
		_play_sfx(player_hurt_sfx)

	last_known_hp = current_hp


func _clear_group(group_name: String) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node):
			node.queue_free()


func _get_progression_manager() -> Node:
	return get_node_or_null("/root/ProgressionManager")


func _play_camera_shake() -> void:
	if camera == null:
		return

	if shake_tween != null:
		shake_tween.kill()

	camera.offset = Vector2.ZERO
	shake_tween = create_tween()
	shake_tween.tween_property(camera, "offset", Vector2(SHAKE_MAGNITUDE, 0.0), SHAKE_DURATION / 4.0)
	shake_tween.tween_property(camera, "offset", Vector2(-SHAKE_MAGNITUDE, 0.0), SHAKE_DURATION / 4.0)
	shake_tween.tween_property(camera, "offset", Vector2(0.0, SHAKE_MAGNITUDE * 0.5), SHAKE_DURATION / 4.0)
	shake_tween.tween_property(camera, "offset", Vector2.ZERO, SHAKE_DURATION / 4.0)


func _on_game_child_entered_tree(node: Node) -> void:
	var died_callable := Callable(self, "_on_enemy_died")
	if node.has_signal("died") and not node.is_connected("died", died_callable):
		node.connect("died", died_callable)

	if node is Area2D and node.has_signal("collected") and node.scene_file_path == "res://scenes/element_drop.tscn":
		var collected_callable := Callable(self, "_on_element_collected")
		if not node.is_connected("collected", collected_callable):
			node.connect("collected", collected_callable)


func _on_projectile_child_entered_tree(node: Node) -> void:
	var hit_callable := Callable(self, "_on_spell_hit")
	if node.has_signal("hit") and not node.is_connected("hit", hit_callable):
		node.connect("hit", hit_callable)


func _on_spell_hit(_target: Node, _damage: float) -> void:
	_play_sfx(spell_hit_sfx)


func _on_enemy_died() -> void:
	_play_sfx(enemy_death_sfx)


func _on_element_collected(drop_position: Vector2) -> void:
	_spawn_element_label("+mana", drop_position)


func _spawn_element_label(text: String, world_pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.position = world_pos + Vector2(-30, -20)
	add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.5)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)


func _play_sfx(player_node: AudioStreamPlayer) -> void:
	if player_node == null or player_node.stream == null:
		return

	player_node.stop()
	player_node.play()


func _on_crafting_ui_closed() -> void:
	pass
