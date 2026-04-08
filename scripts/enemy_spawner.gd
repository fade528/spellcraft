extends Node2D

@export var spawn_rate: float = 1.0
@export var enemy_speed: float = 150.0
@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var shooter_scene: PackedScene = preload("res://scenes/enemies/shooter.tscn")
@export var tank_scene: PackedScene = preload("res://scenes/enemies/tank.tscn")

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
	var spawn_options: Array[PackedScene] = []
	if enemy_scene != null:
		spawn_options.append(enemy_scene)
	if shooter_scene != null:
		spawn_options.append(shooter_scene)
	if tank_scene != null:
		spawn_options.append(tank_scene)

	if spawn_options.is_empty():
		return

	var selected_scene := spawn_options[randi() % spawn_options.size()]
	var enemy_instance := selected_scene.instantiate()
	if enemy_instance == null:
		return

	if enemy_instance is CharacterBody2D:
		var enemy_body: CharacterBody2D = enemy_instance
		enemy_body.position = Vector2(randf_range(SPAWN_X_MIN, SPAWN_X_MAX), SPAWN_Y)
		if selected_scene == enemy_scene:
			enemy_body.set("move_speed", enemy_speed)

	get_parent().add_child(enemy_instance)
