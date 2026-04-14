extends "res://scripts/enemies/base_enemy.gd"

@export var patrol_speed: float = 40.0
@export var fire_rate: float = 3.0
@export var fire_range: float = 1920.0
@export var projectile_speed: float = 550.0

const PROJECTILE_SCENE = preload("res://scenes/spell_projectile.tscn")

var _patrol_y: float = 0.0
var _patrol_reached: bool = false
var _patrol_dir: float = 1.0
var _fire_timer: float = 0.0


func _ready() -> void:
	super._ready()
	_patrol_y = randf_range(200.0, 900.0)

	_sprite = ColorRect.new()
	_sprite.color = Color(0.8, 0.2, 0.8, 1.0)
	_sprite.position = Vector2(-15, -20)
	_sprite.size = Vector2(30, 40)
	add_child(_sprite)

	var hurtbox := Area2D.new()
	hurtbox.set_collision_layer_value(1, false)
	hurtbox.set_collision_layer_value(4, true)
	hurtbox.set_collision_mask_value(1, false)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 40)
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
	crect.size = Vector2(30, 40)
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
		if not _patrol_reached:
			velocity = Vector2(0.0, move_speed)
			if global_position.y >= _patrol_y:
				_patrol_reached = true
				velocity.y = 0.0
		else:
			velocity.x = _patrol_dir * patrol_speed
			if global_position.x <= 80.0:
				_patrol_dir = 1.0
			if global_position.x >= 1000.0:
				_patrol_dir = -1.0
			velocity.y = 0.0

	move_and_slide()

	if global_position.y > DESPAWN_Y:
		queue_free()

	if player_ref != null and is_instance_valid(player_ref):
		var dist := global_position.distance_to(player_ref.global_position)
		if dist <= fire_range:
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_timer = fire_rate
				_try_fire()


func _try_fire() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var dir := (player_ref.global_position - global_position).normalized()
	var proj = PROJECTILE_SCENE.instantiate()
	var vis := ColorRect.new()
	vis.size = Vector2(12, 12)
	vis.position = Vector2(-6, -6)
	vis.color = Color(1.0, 0.3, 1.0)
	proj.add_child(vis)
	proj.collision_layer = 0
	proj.collision_mask = 0
	proj.set_collision_layer_value(5, true)
	proj.set_collision_mask_value(3, true)
	proj.set_collision_mask_value(6, true)
	proj.add_to_group("enemy_projectiles")
	proj.setup(global_position, dir, contact_damage, projectile_speed)
	var container = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(proj)
