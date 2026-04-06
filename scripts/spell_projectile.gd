extends Area2D

signal hit(target: Node, damage: float)

@export var damage: float = 10.0
@export var projectile_speed: float = 850.0
@export var direction: Vector2 = Vector2.UP

const DESPAWN_Y := -50.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * projectile_speed * delta

	if global_position.y < DESPAWN_Y:
		queue_free()


func setup(spawn_position: Vector2, move_direction: Vector2, new_damage: float, new_projectile_speed: float) -> void:
	global_position = spawn_position
	damage = new_damage
	projectile_speed = new_projectile_speed

	if move_direction != Vector2.ZERO:
		direction = move_direction.normalized()

	rotation = direction.angle() + PI / 2.0


func _on_area_entered(area: Area2D) -> void:
	if not area.get_collision_layer_value(4):
		return

	var target := area.get_parent()
	if target != null and target.has_method("take_damage"):
		target.take_damage(damage)
		hit.emit(target, damage)
		queue_free()
