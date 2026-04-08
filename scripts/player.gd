extends CharacterBody2D

@export var move_speed: float = 300.0
@export var iframe_duration: float = 1.5

const SCREEN_SIZE := Vector2(1080.0, 1920.0)
const TOUCHPAD_RADIUS := 110.0
const TOUCHPAD_DEADZONE := 12.0
const TOUCHPAD_ZONE_RATIO := 0.65
const RESPAWN_POSITION := Vector2(540.0, 1400.0)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var facing_marker: Polygon2D = $FacingMarker
@onready var hurtbox: Area2D = $Hurtbox
@onready var touchpad_base: ColorRect = $TouchpadLayer/TouchpadBase
@onready var touchpad_knob: ColorRect = $TouchpadLayer/TouchpadKnob
@onready var iframe_timer: Timer = $IframeTimer

var move_input := Vector2.ZERO
var active_touch_index := -1
var touchpad_center := Vector2.ZERO
var clamp_margin := Vector2(48.0, 48.0)
var facing_rotation := 0.0
var is_invincible := false
var iframe_tween: Tween


func _ready() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	position = RESPAWN_POSITION
	set_collision_mask_value(2, false)
	_configure_touchpad()
	_update_clamp_margin()
	_apply_facing_rotation()
	_set_touchpad_visible(false)
	iframe_timer.timeout.connect(_on_iframe_timer_timeout)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _physics_process(_delta: float) -> void:
	velocity = move_input * move_speed
	move_and_slide()
	var vp := get_viewport().get_visible_rect().size
	position = position.clamp(
		clamp_margin,
		Vector2(vp.x - clamp_margin.x, vp.y * 0.80 - clamp_margin.y)
	)

	if move_input != Vector2.ZERO:
		_update_facing(move_input)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if active_touch_index == -1 and event.position.y >= get_viewport().get_visible_rect().size.y * 0.80 and event.position.x > get_viewport().get_visible_rect().size.x * 0.10 and event.position.x < get_viewport().get_visible_rect().size.x * 0.90:
			active_touch_index = event.index
			touchpad_center = event.position
			_update_touchpad(event.position)
			_set_touchpad_visible(true)
		return

	if event.index == active_touch_index:
		active_touch_index = -1
		move_input = Vector2.ZERO
		velocity = Vector2.ZERO
		_set_touchpad_visible(false)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != active_touch_index:
		return

	_update_touchpad(event.position)


func _update_touchpad(screen_position: Vector2) -> void:
	var drag_vector := screen_position - touchpad_center
	var clamped_vector := drag_vector.limit_length(TOUCHPAD_RADIUS)

	touchpad_base.position = touchpad_center - touchpad_base.size * 0.5
	touchpad_knob.position = touchpad_center + clamped_vector - touchpad_knob.size * 0.5

	if clamped_vector.length() <= TOUCHPAD_DEADZONE:
		move_input = Vector2.ZERO
		return

	move_input = clamped_vector / TOUCHPAD_RADIUS


func _update_facing(direction: Vector2) -> void:
	var snapped_angle: float = round(direction.angle() / (PI / 4.0)) * (PI / 4.0)
	facing_rotation = snapped_angle + PI / 2.0
	_apply_facing_rotation()


func _apply_facing_rotation() -> void:
	player_sprite.rotation = facing_rotation
	facing_marker.rotation = facing_rotation


func _configure_touchpad() -> void:
	touchpad_base.size = Vector2(220.0, 220.0)
	touchpad_knob.size = Vector2(96.0, 96.0)
	touchpad_base.color = Color(1.0, 1.0, 1.0, 0.16)
	touchpad_knob.color = Color(0.45, 0.85, 1.0, 0.7)


func _update_clamp_margin() -> void:
	var shape := collision_shape.shape

	if shape is CircleShape2D:
		var radius: float = shape.radius
		clamp_margin = Vector2(radius, radius)
	elif shape is RectangleShape2D:
		clamp_margin = shape.size * 0.5


func _set_touchpad_visible(is_visible: bool) -> void:
	touchpad_base.visible = is_visible
	touchpad_knob.visible = is_visible


func take_damage(amount: float) -> void:
	if is_invincible:
		return

	_start_iframes()
	var progression_manager := _get_progression_manager()
	if progression_manager != null:
		progression_manager.take_damage(amount)


func respawn() -> void:
	position = RESPAWN_POSITION
	velocity = Vector2.ZERO
	move_input = Vector2.ZERO
	active_touch_index = -1
	_set_touchpad_visible(false)


func _start_iframes() -> void:
	is_invincible = true
	iframe_timer.start(iframe_duration)
	_play_iframe_visual()


func _on_iframe_timer_timeout() -> void:
	is_invincible = false
	if iframe_tween != null:
		iframe_tween.kill()
		player_sprite.modulate.a = 1.0
		facing_marker.modulate.a = 1.0


func _play_iframe_visual() -> void:
	if iframe_tween != null:
		iframe_tween.kill()

	iframe_tween = create_tween()
	iframe_tween.set_loops()
	iframe_tween.tween_property(player_sprite, "modulate:a", 0.25, 0.12)
	iframe_tween.parallel().tween_property(facing_marker, "modulate:a", 0.25, 0.12)
	iframe_tween.tween_property(player_sprite, "modulate:a", 1.0, 0.12)
	iframe_tween.parallel().tween_property(facing_marker, "modulate:a", 1.0, 0.12)


func _get_progression_manager() -> Node:
	return get_node_or_null("/root/ProgressionManager")
