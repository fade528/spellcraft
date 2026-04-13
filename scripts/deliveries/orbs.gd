class_name Orb
extends Area2D

var damage: float
var _weakness: float
var orbit_radius: float = 85.0
var orbit_speed_deg: float = 90.0
var _angle: float = 0.0
var _player: Node2D = null
var _hit_this_cycle: bool = false
var on_hit_effects: Array[Dictionary] = []
var spell_final_dmg: float = 0.0


func setup_from_spell(
	spell: SpellData,
	spawn_pos: Vector2,
	move_dir: Vector2,
	item_base_dmg: float,
	weakness_mult: float
) -> void:
	damage = item_base_dmg
	_weakness = weakness_mult
	spell_final_dmg = item_base_dmg * weakness_mult
	on_hit_effects = spell.on_hit_effects.duplicate(true)


func _ready() -> void:
	add_to_group("orbs")
	if not has_node("ColorRect"):
		var cr := ColorRect.new()
		cr.size = Vector2(14.0, 14.0)
		cr.position = Vector2(-7.0, -7.0)
		cr.color = Color(0.3, 0.9, 1.0, 0.9)
		add_child(cr)
	var idx: int = int(get_meta("orbit_index", 0))
	_angle = idx * 120.0
	_player = get_tree().get_first_node_in_group("player") as Node2D
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var old_angle: float = _angle
	_angle += orbit_speed_deg * delta
	if _angle >= 360.0:
		_angle -= 360.0
	if _angle < old_angle:
		_hit_this_cycle = false
	global_position = _player.global_position + Vector2(orbit_radius, 0.0).rotated(deg_to_rad(_angle))


func _on_area_entered(area: Area2D) -> void:
	if _hit_this_cycle:
		return
	if not area.get_collision_layer_value(4):
		return

	var enemy: Node = area.get_parent()
	if enemy == null:
		return
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage * _weakness)
	_apply_on_hit_effects(enemy)
	_hit_this_cycle = true


func _scaled(effect: Dictionary, base_key: String, scale_key: String) -> float:
	var tier: int = int(effect.get("tier", 0))
	var base: Variant = effect.get(base_key, 0.0)
	var scale: Variant = effect.get(scale_key, 0.0)
	var base_f: float = 0.0
	if base is float:
		base_f = base
	elif base is int:
		base_f = float(base)
	elif base is String and (base as String).is_valid_float():
		base_f = (base as String).to_float()
	var scale_f: float = 0.0
	if scale is float:
		scale_f = scale
	elif scale is int:
		scale_f = float(scale)
	elif scale is String and (scale as String).is_valid_float():
		scale_f = (scale as String).to_float()
	return base_f + scale_f * float(tier)


func _apply_on_hit_effects(target: Node) -> void:
	for effect in on_hit_effects:
		var effect_name: String = str(effect.get("effect_name", ""))
		match effect_name:
			"burndot":
				if target.has_method("apply_burn"):
					target.apply_burn(
						spell_final_dmg * _scaled(effect, "value1", "scale_value1"),
						_scaled(effect, "value2", "scale_value2"),
						_scaled(effect, "value3", "scale_value3")
					)
			"corruption":
				var dmg_per_tick: float = spell_final_dmg * _scaled(effect, "value1", "scale_value1")
				var interval: float = _scaled(effect, "value2", "scale_value2")
				var duration: float = _scaled(effect, "value3", "scale_value3")
				if target.has_method("apply_corruption"):
					target.apply_corruption(dmg_per_tick, interval, duration)
				elif target.has_method("apply_burn"):
					target.apply_burn(dmg_per_tick, interval, duration)
			"chilled":
				if target.has_method("apply_slow"):
					target.apply_slow(
						_scaled(effect, "value3", "scale_value3"),
						_scaled(effect, "value2", "scale_value2")
					)
			"brittle":
				if target.has_method("apply_brittle"):
					target.apply_brittle(
						_scaled(effect, "value1", "scale_value1"),
						_scaled(effect, "value2", "scale_value2")
					)
			"explosion":
				_apply_aoe(
					_scaled(effect, "value1", "scale_value1"),
					spell_final_dmg * _scaled(effect, "value2", "scale_value2"),
					target
				)
			"chain 1":
				if target.has_method("apply_chain"):
					target.apply_chain(roundi(_scaled(effect, "value1", "scale_value1")))
			"purge":
				if target.has_method("apply_purge"):
					target.apply_purge(roundi(_scaled(effect, "value1", "scale_value1")))
			"stagger":
				if target.has_method("apply_stagger"):
					target.apply_stagger(
						_scaled(effect, "value1", "scale_value1"),
						_scaled(effect, "value2", "scale_value2")
					)
			"splash":
				_apply_aoe(
					_scaled(effect, "value1", "scale_value1"),
					spell_final_dmg * _scaled(effect, "value2", "scale_value2"),
					target
				)
				if target.has_method("apply_wet"):
					target.apply_wet()
			"tidal":
				if target.has_method("apply_pushback"):
					target.apply_pushback(_scaled(effect, "value1", "scale_value1"))
				if target.has_method("apply_wet"):
					target.apply_wet()
			"voidpull":
				if target.has_method("apply_pushback"):
					target.apply_pushback(-_scaled(effect, "value1", "scale_value1"))
			"execute":
				if target.has_method("execute"):
					target.execute(_scaled(effect, "value1", "scale_value1"))
			"soulsiphon":
				var heal: float = spell_final_dmg * _scaled(effect, "value1", "scale_value1")
				var pm: Node = get_node_or_null("/root/ProgressionManager")
				if pm != null and pm.has_method("heal"):
					pm.heal(heal)
			"radiance":
				if target.has_method("apply_blind"):
					target.apply_blind(_scaled(effect, "value1", "scale_value1"))
			_:
				pass


func _apply_aoe(radius: float, dmg: float, exclude: Node = null) -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy_node in enemies:
		var body: Node2D = enemy_node as Node2D
		if body == null:
			continue
		if not is_instance_valid(body):
			continue
		if body == exclude:
			continue
		if body.global_position.distance_to(global_position) <= radius:
			if body.has_method("take_damage"):
				body.take_damage(dmg)
