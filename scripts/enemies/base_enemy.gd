extends CharacterBody2D

signal died

@export var move_speed: float = 60.0
@export var max_hp: float = 20.0
@export var contact_damage: float = 10.0
@export var crit_chance: float = 0.15
@export var crit_multiplier: float = 2.0
@export var element: String = "none"
@export var is_boss: bool = false

const DESPAWN_Y := 1980.0
const DROP_CHANCE: float = 0.20
const KNOCKBACK_DURATION: float = 0.3

var player_ref: Node2D
var current_hp: float
var hit_flash_tween: Tween
var _sprite: ColorRect
var _burn_timer: Timer = null
var _active_debuffs: Array[String] = []
var _active_buffs: Array[String] = []
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
var _knockback_timer: float = 0.0
var _last_two_hit_schools: Array[String] = []


func _ready() -> void:
	add_to_group("enemies")
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	current_hp = max_hp
	print("[BaseEnemy] ready — type: %s | hp: %.1f" % [get_script().resource_path, max_hp])


func _process(delta: float) -> void:
	if not _is_blinded:
		return
	_blind_wander_timer -= delta
	if _blind_wander_timer <= 0.0:
		_blind_wander_timer = 0.5
		_blind_direction = Vector2.from_angle(randf_range(0.0, TAU))


func take_damage(amount: float, attacker_element: String = "") -> void:
	var incoming_mult := get_incoming_multiplier(attacker_element)
	var is_crit := randf() < crit_chance
	var final_damage := amount * incoming_mult
	if is_crit:
		final_damage *= crit_multiplier
	_last_chain_damage = final_damage
	current_hp -= final_damage
	print("[BaseEnemy] hit — dmg: %.2f | element: %s | hp remaining: %.2f" % [final_damage, attacker_element, current_hp])
	_spawn_damage_number(final_damage, is_crit)
	if current_hp <= 0.0:
		var _player_node = get_tree().get_first_node_in_group("player")
		if _player_node != null and is_instance_valid(_player_node):
			var _pm_kf = get_node_or_null("/root/PassiveManager")
			if _pm_kf != null and _pm_kf.has_method("on_enemy_killed"):
				_pm_kf.on_enemy_killed()
		_spawn_death_particles()
		died.emit()
		spawn_drop()
		call_deferred("queue_free")
		return
	_play_hit_flash()


func get_element() -> String:
	return element


func get_incoming_multiplier(attacker_element: String) -> float:
	if _is_wet and attacker_element == "thunder":
		return 1.5
	return 1.0


func register_hit_school(school: String) -> void:
	_last_two_hit_schools.push_back(school)
	if _last_two_hit_schools.size() > 2:
		_last_two_hit_schools.pop_front()
	print("[Smite] %s hit schools: %s" % [get_script().resource_path.get_file(), _last_two_hit_schools])


func consume_smite_hit() -> bool:
	if _last_two_hit_schools.size() == 2 \
			and _last_two_hit_schools[0] == _last_two_hit_schools[1]:
		_last_two_hit_schools.clear()
		print("[Smite] proc triggered — clearing hit schools")
		return true
	return false


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


func _spawn_death_particles() -> void:
	pass  # Subclasses can override for unique death FX


func _play_hit_flash() -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		return
	if hit_flash_tween != null:
		hit_flash_tween.kill()
	var base_color := _sprite.color
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(_sprite, "color", Color.WHITE, 0.05)
	hit_flash_tween.tween_property(_sprite, "color", base_color, 0.05)


func _flash_debuff_colour(colour: Color) -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "color", colour, 0.1)
	tween.tween_property(_sprite, "color", _sprite.color, 0.2)


func apply_burn(dmg_per_tick: float, interval: float, duration: float) -> void:
	_burn_interval = maxf(interval, 0.1)
	_burn_ticks_remaining = int(round(duration / _burn_interval))
	print("[BaseEnemy] burn applied — dmg/tick: %.2f | ticks: %d" % [dmg_per_tick, _burn_ticks_remaining])

	if _burn_timer != null and is_instance_valid(_burn_timer):
		# Stack: add to existing damage per tick, reset duration
		_burn_damage += dmg_per_tick
		_burn_timer.wait_time = _burn_interval
		if not _active_debuffs.has("burn"):
			_active_debuffs.push_back("burn")
		_flash_debuff_colour(Color(1.0, 0.35, 0.0, 1.0))
		return

	# Fresh application
	_burn_damage = dmg_per_tick
	_burn_timer = Timer.new()
	_burn_timer.wait_time = _burn_interval
	_burn_timer.one_shot = false
	_burn_timer.timeout.connect(_on_burn_tick)
	add_child(_burn_timer)
	_burn_timer.start(_burn_interval)
	if not _active_debuffs.has("burn"):
		_active_debuffs.push_back("burn")
	_flash_debuff_colour(Color(1.0, 0.35, 0.0, 1.0))


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


func apply_slow(amount: float, duration: float) -> void:
	_is_chilled = true
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
	_active_debuffs.push_back("slow")
	_flash_debuff_colour(Color(0.45, 0.85, 1.0, 1.0))


func apply_stagger(chance: float, duration: float) -> void:
	var triggered := randf() < chance
	if not triggered:
		return

	velocity = Vector2.ZERO
	_is_staggered = true
	_start_stagger_timer(duration, false, crit_multiplier)
	_active_debuffs.push_back("stagger")


func apply_brittle(freeze_duration: float, dmg_mult: float) -> void:
	if not _is_chilled:
		return

	var original_crit := crit_multiplier
	crit_multiplier *= dmg_mult
	velocity = Vector2.ZERO
	_is_staggered = true
	_start_stagger_timer(freeze_duration, true, original_crit)
	_active_debuffs.push_back("brittle")


func apply_chain(bounce_count: int) -> void:
	var nearby_enemies_found := 0
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

	nearby_enemies_found = nearby_enemies.size()

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

	velocity = direction * distance
	_knockback_timer = KNOCKBACK_DURATION


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
	_active_debuffs.push_back("blind")
	_flash_debuff_colour(Color(0.95, 0.95, 0.95, 1.0))


func execute(chance: float) -> void:
	if is_boss:
		return
	if current_hp <= 0.0:
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
	_active_debuffs.push_back("wet")
	_flash_debuff_colour(Color(0.05, 0.15, 0.8, 1.0))


func apply_corruption(dmg_per_tick: float, interval: float, duration: float) -> void:
	_corruption_damage = dmg_per_tick
	_corruption_interval = max(interval, 0.1)
	_corruption_ticks_remaining = int(round(duration / _corruption_interval))

	if _corruption_timer != null and is_instance_valid(_corruption_timer):
		_corruption_damage = dmg_per_tick
		_corruption_interval = max(interval, 0.1)
		_corruption_ticks_remaining = int(round(duration / _corruption_interval))
		_corruption_timer.wait_time = _corruption_interval
		_active_debuffs.push_back("corrupt")
		_flash_debuff_colour(Color(0.55, 0.0, 0.8, 1.0))
		return

	_corruption_timer = Timer.new()
	_corruption_timer.wait_time = _corruption_interval
	_corruption_timer.one_shot = false
	_corruption_timer.timeout.connect(_on_corruption_tick)
	add_child(_corruption_timer)
	_corruption_timer.start(_corruption_interval)
	_active_debuffs.push_back("corrupt")
	_flash_debuff_colour(Color(0.55, 0.0, 0.8, 1.0))


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
	_active_debuffs.push_back("chill")
	_flash_debuff_colour(Color(0.45, 0.85, 1.0, 1.0))


func apply_purge(count: int) -> void:
	for i in range(count):
		if _active_buffs.is_empty():
			break
		_active_buffs.pop_back()
		# Buff clear logic will go here when buffs are implemented.


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
