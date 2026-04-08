extends Node

const PROJECTILE_SCENE = preload("res://scenes/spell_projectile.tscn")

var active_summon: Node2D = null
var _summon_data: Dictionary = {}
var _player_ref: Node2D = null
var _recharge_timer: float = 0.0
var _recharge_duration: float = 60.0
var _current_element: String = ""
var _summon_hp: float = 30.0
var _attack_spell = null
var _attack_cooldown: float = 3.0
var _attack_timer_elapsed: float = 0.0
var _trail_positions: Array[Vector2] = []
const TRAIL_RECORD_DIST: float = 8.0
const TRAIL_FOLLOW_DIST: float = 60.0


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

	var summon_root: Node2D = Node2D.new()
	var placeholder: ColorRect = ColorRect.new()
	placeholder.size = Vector2(30, 30)
	placeholder.color = Color.YELLOW
	placeholder.position = Vector2(-15, -15)
	summon_root.add_child(placeholder)

	active_summon = summon_root

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		current_scene.add_child.call_deferred(summon_root)
		if _player_ref != null and is_instance_valid(_player_ref):
			summon_root.global_position = _player_ref.global_position + Vector2(30, 0)
		_current_element = element
		_attack_timer_elapsed = 0.0
		_trail_positions.clear()
		if _player_ref != null and is_instance_valid(_player_ref):
			_trail_positions.clear()
			for i in range(20):
				_trail_positions.append(_player_ref.global_position)
		var hp_val = _summon_data.get("hp", 30.0)
		if hp_val is String:
			hp_val = hp_val.to_float() if hp_val.is_valid_float() else 30.0
		_summon_hp = float(hp_val)
		summon_root.add_to_group("summon")
		var hurtbox: Area2D = Area2D.new()
		hurtbox.set_collision_layer_value(4, true)
		var cshape: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 20.0
		cshape.shape = circle
		hurtbox.add_child(cshape)
		summon_root.add_child(hurtbox)
		hurtbox.body_entered.connect(_on_summon_body_entered)


func set_attack_spell(spell) -> void:
	_attack_spell = spell
	if spell != null and "cooldown" in spell:
		_attack_cooldown = float(spell.cooldown)


func _on_summon_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return
	if not body.get_collision_layer_value(2):
		return
	_summon_hp -= 5.0
	if _summon_hp <= 0.0:
		despawn_summon()


func _process(delta: float) -> void:
	if active_summon == null or not is_instance_valid(active_summon):
		if _recharge_timer > 0.0:
			_recharge_timer -= delta
			if _recharge_timer <= 0.0:
				_recharge_timer = 0.0
				if _current_element != "":
					spawn_summon(_current_element)
	if active_summon != null and is_instance_valid(active_summon):
		if _player_ref != null and is_instance_valid(_player_ref):
			var player_pos: Vector2 = _player_ref.global_position
			if _trail_positions.is_empty() or \
			   _trail_positions[0].distance_to(player_pos) >= TRAIL_RECORD_DIST:
				_trail_positions.push_front(player_pos)
				if _trail_positions.size() > 200:
					_trail_positions.pop_back()
			
			var accumulated: float = 0.0
			var follow_target: Vector2 = _trail_positions[_trail_positions.size() - 1]
			for i in range(_trail_positions.size() - 1):
				var segment: float = _trail_positions[i].distance_to(_trail_positions[i + 1])
				accumulated += segment
				if accumulated >= TRAIL_FOLLOW_DIST:
					follow_target = _trail_positions[i + 1]
					break
			
			active_summon.global_position = active_summon.global_position.move_toward(
				follow_target, 200.0 * delta
			)
		_attack_timer_elapsed += delta
		if _attack_timer_elapsed >= _attack_cooldown:
			_attack_timer_elapsed = 0.0
			_fire_summon_attack()


func _fire_summon_attack() -> void:
	if active_summon == null or not is_instance_valid(active_summon):
		return

	var nearest: Node2D = null
	var nearest_dist: float = 350.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var d: float = active_summon.global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy

	if nearest == null:
		return

	var proj = PROJECTILE_SCENE.instantiate()
	var dir: Vector2 = (nearest.global_position - active_summon.global_position).normalized()
	var dmg: float = 5.0
	if _attack_spell != null and "dmgmult_chain" in _attack_spell:
		dmg = float(_attack_spell.dmgmult_chain) * 10.0
	proj.setup(active_summon.global_position, dir, dmg, 700.0)

	var container = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(proj)


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
