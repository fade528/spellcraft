extends Area2D

@export var contact_damage: float = 40.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return

	var player := get_parent()
	if player != null and player.has_method("take_damage"):
		player.take_damage(contact_damage)
