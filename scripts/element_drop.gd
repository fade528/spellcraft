extends Area2D

signal collected(element_name: String)

@export var element: String = "fire"
@export var drop_chance: float = 0.20

const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.5, 0.0, 1.0),
	"ice": Color(0.0, 1.0, 1.0, 1.0),
	"earth": Color(0.55, 0.27, 0.07, 1.0),
	"thunder": Color(1.0, 1.0, 0.0, 1.0),
	"water": Color(0.0, 0.4, 1.0, 1.0),
	"holy": Color(1.0, 1.0, 1.0, 1.0),
	"dark": Color(0.5, 0.0, 0.5, 1.0),
}


func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = 1 << 2
	area_entered.connect(_on_area_entered)
	_create_visual()
	_start_lifetime_timer()


func _on_area_entered(area: Area2D) -> void:
	print("DROP HIT: layer=", area.collision_layer, " lv3=", area.get_collision_layer_value(3))

	if area == null:
		return

	var is_player_hurtbox := area.collision_layer == 4 or area.get_collision_layer_value(3)
	if not is_player_hurtbox:
		return

	var inventory := get_node_or_null("/root/PlayerInventory")
	if inventory != null:
		inventory.add_element(element)

	collected.emit(element)
	call_deferred("queue_free")


func _create_visual() -> void:
	var color_rect := ColorRect.new()
	color_rect.size = Vector2(16, 16)
	color_rect.position = Vector2(-8, -8)
	color_rect.color = ELEMENT_COLORS.get(element.to_lower(), ELEMENT_COLORS["fire"])
	add_child(color_rect)


func _start_lifetime_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = 8.0
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)
	add_child(timer)
	timer.start()
