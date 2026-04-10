extends CharacterBody2D

signal died

@export var move_speed: float = 60.0
@export var patrol_speed: float = 40.0
@export var max_hp: float = 15.0
@export var contact_damage: float = 8.0
@export var fire_rate: float = 3.0
@export var fire_range: float = 1920.0
@export var projectile_speed: float = 550.0
@export var crit_chance: float = 0.20
@export var crit_multiplier: float = 2.5
@export var element: String = "none"
@export var is_boss: bool = false

const DESPAWN_Y := 1980.0
const PROJECTILE_SCENE = preload("res://scenes/spell_projectile.tscn")
const DROP_CHANCE: float = 0.20

var player_ref: Node2D
var current_hp: float
var hit_flash_tween: Tween
var _patrol_y: float = 0.0
var _patrol_reached: bool = false
var _patrol_dir: float = 1.0
var _fire_timer: float = 0.0
var _sprite: ColorRect
var _burn_timer: Timer = null
var _burn_damage: float = 0.0
var _burn_ticks_remaining: int = 0
var _burn_interval: float = 1.0
var _is_slowed: bool = false
var _original_speed: float = 0.0
var _slow_timer: Timer = null
var _is_staggered: bool = false
var _stagger_timer: Timer = null
var _last_chain_damage: float = 0.0
var _is_blinded: bool = false
var _blind_direction: Vector2 = Vector2.UP
var _blind_wander_timer: float = 0.0
var _blind_timer: Timer = null
var _is_wet: bool = false
var _wet_timer: Timer = null
var _corruption_timer: Timer = null
var _corruption_damage: float = 0.0
var _corruption_ticks_remaining: int = 0
var _corruption_interval: float = 1.0
var _is_chilled: bool = false
var _chill_timer: Timer = null


func _ready() -> void:
	add_to_group("enemies")
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	current_hp = max_hp
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
	proj.set_collision_layer_value(5, true)
	proj.collision_mask = 3 | (1 << 5)
	proj.set_collision_mask_value(4, false)
	proj.setup(global_position, dir, contact_damage, projectile_speed)
	var container = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(proj)


func _process(delta: float) -> void:
	if not _is_blinded:
		return

	_blind_wander_timer -= delta
	if _blind_wander_timer <= 0.0:
		_blind_wander_timer = 0.5
		_blind_direction = Vector2.from_angle(randf_range(0.0, TAU))


func take_damage(amount: float) -> void:
	var is_crit := randf() < crit_chance
	var final_damage := amount

	if is_crit:
		final_damage *= crit_multiplier

	_last_chain_damage = final_damage
	current_hp -= final_damage
	_spawn_damage_number(final_damage, is_crit)

	if current_hp <= 0.0:
		_spawn_death_particles()
		died.emit()
		spawn_drop()
		call_deferred("queue_free")
		return

	_play_hit_flash()


func spawn_drop() -> void:
	if randf() > DROP_CHANCE:
		return
	var drop_scene = load("res://scenes/element_drop.tscn")
	if drop_scene == null:
		return
	var drop = drop_scene.instantiate()
	drop.position = global_position
	get_tree().current_scene.call_deferred("add_child", drop)


func _spawn_damage_number(amount: float, is_crit: bool) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return

	var damage_label := Label.new()
	damage_label.text = str(int(round(amount)))
	damage_label.z_index = 10
	damage_label.add_theme_color_override("font_color", Color.WHITE)
	damage_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08, 1.0))
	damage_label.add_theme_constant_override("outline_size", 4)

	parent_node.add_child(damage_label)

	var x_offset := randf_range(-12.0, 12.0)
	var center_position := position + Vector2(x_offset, 0)

	if is_crit:
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
		damage_label.add_theme_font_size_override("font_size", 52)
		damage_label.reset_size()
		damage_label.position = center_position - damage_label.size * 0.5

		var pop_tween := damage_label.create_tween()
		pop_tween.tween_method(
			func(s: float) -> void:
				damage_label.add_theme_font_size_override("font_size", int(s))
				damage_label.reset_size()
				damage_label.position = center_position - damage_label.size * 0.5,
			52.0, 68.0, 0.08
		)
		pop_tween.tween_method(
			func(s: float) -> void:
				damage_label.add_theme_font_size_override("font_size", int(s))
				damage_label.reset_size()
				damage_label.position = center_position - damage_label.size * 0.5,
			68.0, 56.0, 0.06
		)
		pop_tween.tween_interval(0.25)
		pop_tween.tween_property(damage_label, "modulate:a", 0.0, 0.2)
		pop_tween.finished.connect(damage_label.queue_free)
		return

	damage_label.add_theme_font_size_override("font_size", 28)
	damage_label.reset_size()
	damage_label.position = center_position - damage_label.size * 0.5

	var tween := damage_label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 40.0, 0.5)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(damage_label.queue_free)


func _play_hit_flash() -> void:
	if hit_flash_tween != null:
		hit_flash_tween.kill()

	var base_color := _sprite.color
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(_sprite, "color", Color.WHITE, 0.05)
	hit_flash_tween.tween_property(_sprite, "color", base_color, 0.05)


func _spawn_death_particles() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return

	var particles := CPUParticles2D.new()
	particles.position = position
	particles.amount = 10
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.4
	particles.emitting = false
	particles.spread = 360.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.1
	particles.gravity = Vector2.ZERO

	var gradient := Gradient.new()
	gradient.add_point(0.0, _sprite.color)
	gradient.add_point(1.0, Color(_sprite.color.r, _sprite.color.g, _sprite.color.b, 0.0))
	particles.color_ramp = gradient

	parent_node.add_child(particles)
	particles.emitting = true

	var cleanup_timer := get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(particles.queue_free)


func apply_burn(dmg_per_tick: float, interval: float, duration: float) -> void:
	_burn_damage = dmg_per_tick
	_burn_interval = max(interval, 0.1)
	_burn_ticks_remaining = int(round(duration / _burn_interval))

	if _burn_timer != null and is_instance_valid(_burn_timer):
		_burn_timer.wait_time = _burn_interval
		return

	_burn_timer = Timer.new()
	_burn_timer.wait_time = _burn_interval
	_burn_timer.one_shot = false
	_burn_timer.timeout.connect(_on_burn_tick)
	add_child(_burn_timer)
	_burn_timer.start(_burn_interval)


func _on_burn_tick() -> void:
	if not is_instance_valid(self) or current_hp <= 0.0:
		_clear_burn()
		return

	_burn_ticks_remaining -= 1
	if _burn_ticks_remaining <= 0:
		_clear_burn()
		return

	take_damage(_burn_damage)


func _clear_burn() -> void:
	if _burn_timer != null and is_instance_valid(_burn_timer):
		_burn_timer.stop()
		_burn_timer.queue_free()
	_burn_timer = null


func get_element() -> String:
	return element


func apply_slow(amount: float, duration: float) -> void:
	if not _is_slowed:
		_original_speed = move_speed
		move_speed = max(_original_speed * (1.0 - amount), 10.0)
		_is_slowed = true

	if _slow_timer == null or not is_instance_valid(_slow_timer):
		_slow_timer = Timer.new()
		_slow_timer.one_shot = true
		_slow_timer.timeout.connect(_on_slow_timeout)
		add_child(_slow_timer)
	else:
		_slow_timer.stop()

	_slow_timer.start(max(duration, 0.0))


func apply_stagger(chance: float, duration: float) -> void:
	if randf() >= chance:
		return

	velocity = Vector2.ZERO
	_is_staggered = true
	_start_stagger_timer(duration, false, crit_multiplier)


func apply_brittle(freeze_duration: float, dmg_mult: float) -> void:
	if not _is_chilled:
		return

	var original_crit := crit_multiplier
	crit_multiplier *= dmg_mult
	velocity = Vector2.ZERO
	_is_staggered = true
	_start_stagger_timer(freeze_duration, true, original_crit)


func apply_chain(bounce_count: int) -> void:
	if bounce_count <= 0:
		return

	var nearby_enemies: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not (enemy is Node2D):
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance <= 200.0:
			nearby_enemies.append({
				"enemy": enemy,
				"distance": distance
			})

	nearby_enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["distance"] < b["distance"]
	)

	var remaining_bounces: int = mini(bounce_count, nearby_enemies.size())
	for i in range(remaining_bounces):
		var target = nearby_enemies[i]["enemy"]
		if is_instance_valid(target):
			target.take_damage(_last_chain_damage)


func apply_pushback(distance: float) -> void:
	var direction := Vector2.UP
	if player_ref != null and is_instance_valid(player_ref):
		direction = (global_position - player_ref.global_position).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.UP

	velocity = direction * (distance / 0.3)


func apply_blind(duration: float) -> void:
	_is_blinded = true
	_blind_wander_timer = 0.0

	if _blind_timer == null or not is_instance_valid(_blind_timer):
		_blind_timer = Timer.new()
		_blind_timer.one_shot = true
		_blind_timer.timeout.connect(_on_blind_timeout)
		add_child(_blind_timer)
	else:
		_blind_timer.stop()

	_blind_timer.start(max(duration, 0.0))


func execute(chance: float) -> void:
	if is_boss:
		return
	if randf() >= chance:
		return

	take_damage(current_hp * 10.0)


func apply_wet(duration: float = 5.0) -> void:
	_is_wet = true

	if _wet_timer == null or not is_instance_valid(_wet_timer):
		_wet_timer = Timer.new()
		_wet_timer.one_shot = true
		_wet_timer.timeout.connect(_on_wet_timeout)
		add_child(_wet_timer)
	else:
		_wet_timer.stop()

	_wet_timer.start(max(duration, 0.0))


func apply_corruption(dmg_per_tick: float, interval: float, duration: float) -> void:
	_corruption_damage = dmg_per_tick
	_corruption_interval = max(interval, 0.1)
	_corruption_ticks_remaining = int(round(duration / _corruption_interval))

	if _corruption_timer != null and is_instance_valid(_corruption_timer):
		_corruption_damage = dmg_per_tick
		_corruption_interval = max(interval, 0.1)
		_corruption_ticks_remaining = int(round(duration / _corruption_interval))
		_corruption_timer.wait_time = _corruption_interval
		return

	_corruption_timer = Timer.new()
	_corruption_timer.wait_time = _corruption_interval
	_corruption_timer.one_shot = false
	_corruption_timer.timeout.connect(_on_corruption_tick)
	add_child(_corruption_timer)
	_corruption_timer.start(_corruption_interval)


func apply_chill(duration: float = 3.0) -> void:
	_is_chilled = true

	if _chill_timer == null or not is_instance_valid(_chill_timer):
		_chill_timer = Timer.new()
		_chill_timer.one_shot = true
		_chill_timer.timeout.connect(_on_chill_timeout)
		add_child(_chill_timer)
	else:
		_chill_timer.stop()

	_chill_timer.start(max(duration, 0.0))


func get_incoming_multiplier(attacker_element: String) -> float:
	if _is_wet and attacker_element == "thunder":
		return 1.5

	return 1.0


func _on_slow_timeout() -> void:
	move_speed = _original_speed
	_is_slowed = false


func _start_stagger_timer(duration: float, restore_crit: bool, original_crit: float) -> void:
	if _stagger_timer == null or not is_instance_valid(_stagger_timer):
		_stagger_timer = Timer.new()
		_stagger_timer.one_shot = true
		_stagger_timer.timeout.connect(_on_stagger_timeout)
		add_child(_stagger_timer)
	else:
		_stagger_timer.stop()

	_stagger_timer.set_meta("restore_crit", restore_crit)
	_stagger_timer.set_meta("original_crit", original_crit)
	_stagger_timer.start(max(duration, 0.0))


func _on_stagger_timeout() -> void:
	if _stagger_timer != null and is_instance_valid(_stagger_timer):
		if _stagger_timer.get_meta("restore_crit", false):
			var restored: float = float(_stagger_timer.get_meta("original_crit", crit_multiplier))
			crit_multiplier = restored

	_is_staggered = false


func _on_blind_timeout() -> void:
	_is_blinded = false


func _on_wet_timeout() -> void:
	_is_wet = false


func _on_corruption_tick() -> void:
	if not is_instance_valid(self) or current_hp <= 0.0:
		_clear_corruption()
		return

	_corruption_ticks_remaining -= 1
	if _corruption_ticks_remaining <= 0:
		_clear_corruption()
		return

	take_damage(_corruption_damage)


func _clear_corruption() -> void:
	if _corruption_timer != null and is_instance_valid(_corruption_timer):
		_corruption_timer.stop()
		_corruption_timer.queue_free()
	_corruption_timer = null


func _on_chill_timeout() -> void:
	_is_chilled = false
