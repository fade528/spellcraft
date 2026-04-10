extends Area2D

signal collected(drop_position: Vector2)


func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = 1 << 2
	area_entered.connect(_on_area_entered)
	_create_visual()
	_start_lifetime_timer()


func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return

	var is_player_hurtbox := area.collision_layer == 4 or area.get_collision_layer_value(3)
	if not is_player_hurtbox:
		return

	var inventory := get_node_or_null("/root/PlayerInventory")
	if inventory != null:
		inventory.add_mana(1)

	collected.emit(global_position)
	call_deferred("queue_free")


func _create_visual() -> void:
	var color_rect := ColorRect.new()
	color_rect.size = Vector2(16, 16)
	color_rect.position = Vector2(-8, -8)
	color_rect.color = Color(0.6, 0.8, 1.0)
	add_child(color_rect)


func _start_lifetime_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = 8.0
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)
	add_child(timer)
	timer.start()
