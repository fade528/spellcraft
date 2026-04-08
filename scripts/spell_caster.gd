extends Node2D

@export var elemental_element: String = "fire"
@export var empowerment_element: String = "fire"
@export var enchantment_element: String = "fire"
@export var delivery_type: String = "bolt"
@export var target_type: String = "enemy"
@export var item_base_dmg: float = 10.0
@export var projectile_scene: PackedScene
@export var fire_offset: Vector2 = Vector2(0.0, -72.0)
@export var aim_range: float = 1400.0

var spell_data: SpellData
var _is_moving: bool = false
var _just_stopped: bool = false

@onready var cooldown_timer: Timer = $CooldownTimer


func _ready() -> void:
	_recompose_spell()


func _configure_cooldown_timer() -> void:
	if spell_data == null:
		return

	cooldown_timer.wait_time = max(spell_data.cooldown, 0.05)
	if not cooldown_timer.timeout.is_connected(_on_cooldown_timer_timeout):
		cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	cooldown_timer.start()


func set_moving(moving: bool) -> void:
	if _is_moving and not moving:
		_just_stopped = true
	_is_moving = moving


func _recompose_spell() -> void:
	var spell_composer = get_node_or_null("/root/SpellComposer")
	if spell_composer == null or not spell_composer.has_method("compose_spell"):
		spell_data = null
		return

	spell_data = spell_composer.compose_spell(
		elemental_element,
		empowerment_element,
		enchantment_element,
		delivery_type,
		target_type
	)
	_configure_cooldown_timer()


func refresh_spell(
	new_elemental: String,
	new_empowerment: String,
	new_enchantment: String,
	new_delivery: String,
	new_target: String
) -> void:
	elemental_element = new_elemental
	empowerment_element = new_empowerment
	enchantment_element = new_enchantment
	delivery_type = new_delivery
	target_type = new_target
	_recompose_spell()


func _on_cooldown_timer_timeout() -> void:
	if spell_data == null or projectile_scene == null:
		return

	var spell_composer = get_node_or_null("/root/SpellComposer")
	var is_stop_cast := false
	if spell_composer != null and spell_composer.has_method("is_stop_cast"):
		is_stop_cast = spell_composer.is_stop_cast(elemental_element)
	if is_stop_cast:
		if not _just_stopped:
			return
		_just_stopped = false

	var projectile_instance := projectile_scene.instantiate()
	if projectile_instance == null:
		return

	var spawn_position := global_position + fire_offset
	var target := _get_nearest_enemy()
	var shot_direction := Vector2.UP

	if target != null:
		var to_target := target.global_position - spawn_position
		if to_target != Vector2.ZERO and to_target.length() <= aim_range:
			shot_direction = to_target.normalized()

	if projectile_instance.has_method("setup_from_spell"):
		var target_el := _get_target_element()
		var weakness := 1.0
		if spell_composer != null:
			weakness = spell_composer.get_weakness_multiplier(
				elemental_element, target_el
			)
		projectile_instance.setup_from_spell(
			spell_data,
			spawn_position,
			shot_direction,
			item_base_dmg,
			weakness
		)
	elif projectile_instance.has_method("setup"):
		projectile_instance.setup(
			spawn_position,
			shot_direction,
			spell_data.damage,
			spell_data.projectile_speed
		)

	var projectile_container := get_tree().get_first_node_in_group("projectiles")
	if projectile_container == null:
		projectile_container = get_tree().current_scene

	projectile_instance.add_to_group("projectiles_active")
	projectile_container.add_child(projectile_instance)


func _get_target_element() -> String:
	var target := _get_nearest_enemy()
	if target != null and target.has_method("get_element"):
		return target.get_element()
	return ""


func _get_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance: float = INF

	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Node2D):
			continue
		if not is_instance_valid(enemy_node):
			continue

		var enemy := enemy_node as Node2D
		if enemy.global_position.y >= global_position.y:
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy
