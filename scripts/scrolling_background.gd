extends Node2D

@export var scroll_speed: float = 240.0

const SCREEN_HEIGHT := 1920.0

@onready var background_a: ColorRect = $BackgroundA
@onready var background_b: ColorRect = $BackgroundB


func _ready() -> void:
	_configure_background()


func _physics_process(delta: float) -> void:
	_scroll(background_a, delta)
	_scroll(background_b, delta)


func _configure_background() -> void:
	background_a.position = Vector2.ZERO
	background_b.position = Vector2(0.0, -SCREEN_HEIGHT)
	background_a.size = Vector2(1080.0, SCREEN_HEIGHT)
	background_b.size = Vector2(1080.0, SCREEN_HEIGHT)
	background_a.color = Color(0.08, 0.1, 0.16, 1.0)
	background_b.color = Color(0.12, 0.15, 0.24, 1.0)


func _scroll(rect: ColorRect, delta: float) -> void:
	rect.position.y += scroll_speed * delta
	if rect.position.y >= SCREEN_HEIGHT:
		rect.position.y -= SCREEN_HEIGHT * 2.0
