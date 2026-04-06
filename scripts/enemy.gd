extends CharacterBody2D

signal died

@export var move_speed: float = 150.0
@export var chase_distance: float = 300.0
@export var max_hp: float = 20.0
@export var crit_chance: float = 0.20
@export var crit_multiplier: float = 2.5

const DESPAWN_Y := 1980.0

@onready var enemy_sprite: ColorRect = $EnemySprite

var player_ref: Node2D
var current_hp: float
var hit_flash_tween: Tween


func _ready() -> void:
	add_to_group("enemies")
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	enemy_sprite.color = Color(0.93, 0.26, 0.35, 1.0)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	current_hp = max_hp


func _physics_process(_delta: float) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D

	var move_direction := Vector2.DOWN

	if player_ref != null:
		var to_player := player_ref.global_position - global_position
		if to_player.length() <= chase_distance:
			move_direction = to_player.normalized()

	velocity = move_direction * move_speed
	move_and_slide()

	if global_position.y > DESPAWN_Y:
		queue_free()


func take_damage(amount: float) -> void:
	var is_crit := randf() < crit_chance
	var final_damage := amount

	if is_crit:
		final_damage *= crit_multiplier

	current_hp -= final_damage
	_spawn_damage_number(final_damage, is_crit)

	if current_hp <= 0.0:
		_spawn_death_particles()
		died.emit()
		queue_free()
		return

	_play_hit_flash()


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

	var center_position := position

	if is_crit:
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		damage_label.add_theme_font_size_override("font_size", 14)
		damage_label.reset_size()
		damage_label.position = center_position - damage_label.size * 0.5

		var update_crit_font := func(font_size: float) -> void:
			damage_label.add_theme_font_size_override("font_size", int(round(font_size)))
			damage_label.reset_size()
			damage_label.position = center_position - damage_label.size * 0.5

		var start_crit_rise_fade := func() -> void:
			damage_label.add_theme_font_size_override("font_size", 42)
			damage_label.reset_size()
			damage_label.position = center_position - damage_label.size * 0.5

			var rise_fade_tween := damage_label.create_tween()
			rise_fade_tween.tween_property(damage_label, "position:y", damage_label.position.y - 60.0, 0.55)
			rise_fade_tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.55)
			rise_fade_tween.finished.connect(damage_label.queue_free)

		var scale_tween := damage_label.create_tween()
		scale_tween.tween_method(update_crit_font, 14.0, 42.0, 0.15)
		scale_tween.finished.connect(start_crit_rise_fade)
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

	var base_color := enemy_sprite.color
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(enemy_sprite, "color", Color.WHITE, 0.05)
	hit_flash_tween.tween_property(enemy_sprite, "color", base_color, 0.05)


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
	gradient.add_point(0.0, enemy_sprite.color)
	gradient.add_point(1.0, Color(enemy_sprite.color.r, enemy_sprite.color.g, enemy_sprite.color.b, 0.0))
	particles.color_ramp = gradient

	parent_node.add_child(particles)
	particles.emitting = true

	var cleanup_timer := get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(particles.queue_free)
