extends Node

signal summon_hp_changed(current: float, maximum: float)
signal summon_recharge_tick(seconds_remaining: float)

const PROJECTILE_SCENE = preload("res://scenes/spell_projectile.tscn")
const TRAIL_RECORD_DIST: float = 8.0
const TRAIL_FOLLOW_DIST: float = 60.0

var active_summon: Node2D = null
var _summon_data: Dictionary = {}
var _player_ref: Node2D = null
var _recharge_timer: float = 0.0
var _recharge_display_timer: float = 0.0
var _current_element: String = ""
var _summon_hp: float = 30.0
var _max_hp: float = 30.0
var _attack_spell = null
var _attack_cooldown: float = 2.5  # summon base attack rate, independent of player spell CD
var _attack_timer_elapsed: float = 0.0
var _trail_positions: Array[Vector2] = []
var _summon_invincible: bool = false


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
	var attack_cd = _summon_data.get("attack_cd", null)
	if attack_cd != null and str(attack_cd).is_valid_float():
		_attack_cooldown = maxf(float(str(attack_cd)), 0.5)
	else:
		_attack_cooldown = 2.5

	var summon_root: Node2D = Node2D.new()
	var placeholder: ColorRect = ColorRect.new()
	placeholder.size = Vector2(30, 30)
	placeholder.color = Color.YELLOW
	placeholder.position = Vector2(-15, -15)
	summon_root.add_child(placeholder)

	var hurtbox := Area2D.new()
	hurtbox.collision_layer = 6
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	hurtbox.add_child(shape)
	summon_root.add_child(hurtbox)
	hurtbox.area_entered.connect(_on_summon_hit)

	active_summon = summon_root

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		current_scene.add_child.call_deferred(summon_root)
		await get_tree().process_frame
		if not is_instance_valid(summon_root):
			return
		if _player_ref != null and is_instance_valid(_player_ref):
			summon_root.global_position = _player_ref.global_position + Vector2(30, 0)
		else:
			summon_root.global_position = Vector2(540, 1400)
		_current_element = element
		_attack_timer_elapsed = 0.0
		_summon_invincible = false
		_trail_positions.clear()
		if _player_ref != null and is_instance_valid(_player_ref):
			for i in range(20):
				_trail_positions.append(_player_ref.global_position)

		var hp_val = _summon_data.get("hp", 30.0)
		if hp_val is String:
			hp_val = hp_val.to_float() if hp_val.is_valid_float() else 30.0
		_max_hp = float(hp_val)
		_summon_hp = _max_hp
		summon_hp_changed.emit(_summon_hp, _max_hp)
		summon_root.add_to_group("summon")


func set_attack_spell(spell) -> void:
	_attack_spell = spell
	# Attack cooldown is NOT taken from spell data - that is the player's
	# spell CD. Summon attack rate is fixed at _attack_cooldown default.
	# Future: read from summon CSV row if an attack_cd field is added.


func _on_summon_hit(area: Area2D) -> void:
	if _summon_invincible:
		return
	_summon_invincible = true
	take_summon_damage(5.0)
	# take_summon_damage calls despawn_summon() via call_deferred when HP <= 0,
	# which sets _recharge_timer from _summon_data["cd"]. Do NOT set
	# _recharge_timer here, that would override the correct CD value.
	# _summon_invincible is reset by the stagger timer in _process after death,
	# or is irrelevant once the summon is gone.


func _process(delta: float) -> void:
	if active_summon == null or not is_instance_valid(active_summon):
		if _recharge_timer > 0.0:
			_recharge_timer -= delta
			_recharge_display_timer += delta
			if _recharge_display_timer >= 1.0:
				summon_recharge_tick.emit(max(_recharge_timer, 0.0))
				_recharge_display_timer = 0.0
			if _recharge_timer <= 0.0:
				_recharge_timer = 0.0
				_recharge_display_timer = 0.0
				var summon_element := _get_active_page_summon_element()
				if summon_element != "":
					spawn_summon(summon_element)
					summon_recharge_tick.emit(0.0)

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

		if not _summon_invincible:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy):
					continue
				var dist: float = active_summon.global_position.distance_to(
					enemy.global_position)
				if dist <= 300.0:
					_summon_invincible = true
					take_summon_damage(5.0)
					var t := get_tree().create_timer(1.0)
					t.timeout.connect(func() -> void:
						_summon_invincible = false
					)
					break

		_attack_timer_elapsed += delta
		if _attack_timer_elapsed >= _attack_cooldown:
			_attack_timer_elapsed = 0.0
			_fire_summon_attack()


func _fire_summon_attack() -> void:
	if active_summon == null or not is_instance_valid(active_summon):
		return

	var nearest: Node2D = null
	var nearest_dist: float = 2000.0
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
	_recharge_display_timer = 0.0


func take_summon_damage(amount: float) -> void:
	_summon_hp -= amount
	summon_hp_changed.emit(_summon_hp, _max_hp)
	if _summon_hp <= 0.0:
		call_deferred("despawn_summon")


func heal_summon(amount: float) -> void:
	if active_summon == null or not is_instance_valid(active_summon):
		return
	_summon_hp = minf(_summon_hp + amount, _max_hp)
	summon_hp_changed.emit(_summon_hp, _max_hp)


func get_summon_max_hp() -> float:
	return _max_hp


func clear_debuffs() -> void:
	# No-op: summon debuff tracking not yet implemented.
	pass


func is_recharged() -> bool:
	if active_summon != null and is_instance_valid(active_summon):
		return true
	return _recharge_timer <= 0.0


func get_recharge_remaining() -> float:
	return max(_recharge_timer, 0.0)


func get_summon_stat(key: String) -> Variant:
	return _summon_data.get(key, null)


func _get_active_page_summon_element() -> String:
	var tm = get_node_or_null("/root/TomeManager")
	if tm == null or not tm.has_method("get_active_page"):
		return _current_element
	var active_page = tm.get_active_page()
	if active_page == null:
		return _current_element
	var summon_element := str(active_page.summon_element)
	if summon_element == "none":
		return ""
	return summon_element
