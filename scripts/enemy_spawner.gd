extends Node2D

@export var spawn_rate: float = 1.0
@export var enemy_speed: float = 150.0
@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

const SPAWN_X_MIN := 50.0
const SPAWN_X_MAX := 1030.0
const SPAWN_Y := -50.0

@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	randomize()
	_configure_spawn_timer()


func _configure_spawn_timer() -> void:
	spawn_timer.wait_time = max(spawn_rate, 0.1)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	var enemy_instance := enemy_scene.instantiate()
	if enemy_instance == null:
		return

	if enemy_instance is CharacterBody2D:
		var enemy_body: CharacterBody2D = enemy_instance
		enemy_body.position = Vector2(randf_range(SPAWN_X_MIN, SPAWN_X_MAX), SPAWN_Y)
		enemy_body.set("move_speed", enemy_speed)

	get_parent().add_child(enemy_instance)
