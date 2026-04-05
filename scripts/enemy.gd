extends CharacterBody2D

@export var move_speed: float = 150.0
@export var chase_distance: float = 300.0

const DESPAWN_Y := 1980.0

@onready var enemy_sprite: ColorRect = $EnemySprite

var player_ref: Node2D


func _ready() -> void:
	add_to_group("enemies")
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	enemy_sprite.color = Color(0.93, 0.26, 0.35, 1.0)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)


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
