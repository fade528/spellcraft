extends "res://scripts/enemies/base_enemy.gd"


func _ready() -> void:
	super._ready()
	move_speed = 120.0
	_sprite = ColorRect.new()
	_sprite.color = Color(1.0, 0.2, 0.2, 1.0)
	_sprite.size = Vector2(24, 24)
	_sprite.position = Vector2(-12, -12)
	add_child(_sprite)

	# Hurtbox (layer 4) - receives player projectiles
	var hurtbox := Area2D.new()
	hurtbox.set_collision_layer_value(1, false)
	hurtbox.set_collision_layer_value(4, true)
	hurtbox.set_collision_mask_value(1, false)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	shape.shape = rect
	hurtbox.add_child(shape)
	add_child(hurtbox)

	# Contact area - damages player on touch (mask layer 3 = player body)
	var contact := Area2D.new()
	contact.set_collision_layer_value(1, false)
	contact.set_collision_mask_value(1, false)
	contact.set_collision_mask_value(3, true)
	var cshape := CollisionShape2D.new()
	var crect := RectangleShape2D.new()
	crect.size = Vector2(24, 24)
	cshape.shape = crect
	contact.add_child(cshape)
	add_child(contact)
	contact.area_entered.connect(_on_contact_area_entered)


func _physics_process(delta: float) -> void:
	if _is_staggered:
		return
	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D

	if _knockback_timer > 0.0:
		_knockback_timer -= delta
	else:
		if player_ref != null and is_instance_valid(player_ref):
			var dir := (player_ref.global_position - global_position).normalized()
			velocity = dir * move_speed
		else:
			velocity = Vector2.DOWN * move_speed

	move_and_slide()

	if global_position.y > DESPAWN_Y:
		queue_free()


func _on_contact_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(3):
		var pm = get_node_or_null("/root/ProgressionManager")
		if pm:
			pm.take_damage(contact_damage)
