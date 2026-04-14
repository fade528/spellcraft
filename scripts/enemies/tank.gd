extends "res://scripts/enemies/base_enemy.gd"

@export var chase_distance: float = 600.0


func _ready() -> void:
	super._ready()

	_sprite = ColorRect.new()
	_sprite.color = Color(0.6, 0.1, 0.1, 1.0)
	_sprite.position = Vector2(-25, -30)
	_sprite.size = Vector2(50, 60)
	add_child(_sprite)

	var hurtbox := Area2D.new()
	hurtbox.set_collision_layer_value(1, false)
	hurtbox.set_collision_layer_value(4, true)
	hurtbox.set_collision_mask_value(1, false)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(50, 60)
	shape.shape = rect
	hurtbox.add_child(shape)
	add_child(hurtbox)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	var contact := Area2D.new()
	contact.set_collision_layer_value(1, false)
	contact.set_collision_mask_value(1, false)
	contact.set_collision_mask_value(3, true)
	var cshape := CollisionShape2D.new()
	var crect := RectangleShape2D.new()
	crect.size = Vector2(50, 60)
	cshape.shape = crect
	contact.add_child(cshape)
	add_child(contact)
	contact.area_entered.connect(_on_contact_area_entered)


func _on_hurtbox_area_entered(_area: Area2D) -> void:
	pass


func _on_contact_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(3):
		var pm = get_node_or_null("/root/ProgressionManager")
		if pm:
			pm.take_damage(contact_damage)


func _physics_process(delta: float) -> void:
	if _is_staggered:
		return

	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D

	if _knockback_timer > 0.0:
		_knockback_timer -= delta
	else:
		var move_direction := Vector2.DOWN
		if _is_blinded:
			move_direction = _blind_direction
		elif player_ref != null:
			var to_player := player_ref.global_position - global_position
			if to_player.length() <= chase_distance:
				move_direction = to_player.normalized()

		velocity = move_direction * move_speed
	move_and_slide()

	if global_position.y > DESPAWN_Y:
		queue_free()
