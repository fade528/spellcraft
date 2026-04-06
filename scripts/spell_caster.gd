extends Node2D

@export var spell_data: SpellData
@export var projectile_scene: PackedScene
@export var fire_offset: Vector2 = Vector2(0.0, -72.0)
@export var aim_range: float = 1400.0

@onready var cooldown_timer: Timer = $CooldownTimer


func _ready() -> void:
	_configure_cooldown_timer()


func _configure_cooldown_timer() -> void:
	if spell_data == null:
		return

	cooldown_timer.wait_time = max(spell_data.cooldown, 0.05)
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	cooldown_timer.start()


func _on_cooldown_timer_timeout() -> void:
	if spell_data == null or projectile_scene == null:
		return

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

	if projectile_instance.has_method("setup"):
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
