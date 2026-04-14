extends Area2D

@export var width: float = 200.0
@export var height: float = 30.0
@export var duration: float = 4.0

var _shape: CollisionShape2D
var _sprite: ColorRect
var _lifetime_timer: Timer

func _ready() -> void:
	print("[Mudwall] _ready — pos: %s | width: %.1f | duration: %.1f" % [
			str(global_position), width, duration])
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_layer_value(4, false)
	set_collision_layer_value(5, false)
	set_collision_layer_value(6, true)
	set_collision_mask_value(1, false)

	# Connect to detect incoming enemy projectiles
	area_entered.connect(_on_area_entered)

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(height, width)
	_shape.shape = rect
	add_child(_shape)

	_sprite = ColorRect.new()
	_sprite.size = Vector2(height, width)
	_sprite.position = Vector2(-height * 0.5, -width * 0.5)
	_sprite.color = Color(0.45, 0.3, 0.1, 0.85)
	add_child(_sprite)

	_lifetime_timer = Timer.new()
	_lifetime_timer.one_shot = true
	_lifetime_timer.wait_time = duration
	_lifetime_timer.timeout.connect(_on_lifetime_expired)
	add_child(_lifetime_timer)
	_lifetime_timer.start()


func _on_area_entered(area: Area2D) -> void:
	# Block enemy projectiles (layer 5)
	if area.get_collision_layer_value(5):
		if area.has_method("queue_free"):
			area.queue_free()
		print("[Mudwall] blocked enemy projectile")


func _on_lifetime_expired() -> void:
	queue_free()
