extends Node

var active_summon: Node2D = null
var _summon_data: Dictionary = {}
var _player_ref: Node2D = null
var _recharge_timer: float = 0.0
var _recharge_duration: float = 60.0


func initialize(player: Node2D) -> void:
	_player_ref = player


func spawn_summon(element: String) -> void:
	if active_summon != null and is_instance_valid(active_summon):
		active_summon.queue_free()
	active_summon = null

	var spell_composer = get_node_or_null("/root/SpellComposer")
	if spell_composer == null or not spell_composer.has_method("get_summon_data"):
		_summon_data = {}
		return

	_summon_data = spell_composer.get_summon_data(element)
	if _summon_data.is_empty():
		return

	var summon_root := Node2D.new()
	var placeholder := ColorRect.new()
	placeholder.size = Vector2(30, 30)
	placeholder.color = Color.YELLOW
	placeholder.position = Vector2(-15, -15)
	summon_root.add_child(placeholder)

	active_summon = summon_root

	var current_scene := get_tree().current_scene
	if current_scene != null:
		current_scene.add_child(summon_root)


func _process(_delta: float) -> void:
	if active_summon == null or not is_instance_valid(active_summon):
		if _recharge_timer > 0.0:
			_recharge_timer -= _delta
	if active_summon != null and is_instance_valid(active_summon):
		if _player_ref != null and is_instance_valid(_player_ref):
			active_summon.global_position = _player_ref.global_position + Vector2(50, 0)


func despawn_summon() -> void:
	if active_summon != null and is_instance_valid(active_summon):
		active_summon.queue_free()
	active_summon = null
	var recharge = _summon_data.get("cd", 60.0)
	if recharge is String:
		recharge = recharge.to_float() if recharge.is_valid_float() else 60.0
	_recharge_timer = float(recharge)


func is_recharged() -> bool:
	if active_summon != null and is_instance_valid(active_summon):
		return true
	return _recharge_timer <= 0.0


func get_recharge_remaining() -> float:
	return max(_recharge_timer, 0.0)


func get_summon_stat(key: String) -> Variant:
	return _summon_data.get(key, null)
