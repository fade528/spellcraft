extends Area2D

signal hit(target: Node, damage: float)

@export var damage: float = 10.0
@export var projectile_speed: float = 850.0
@export var direction: Vector2 = Vector2.UP
var on_hit_effects: Array[Dictionary] = []
var spell_final_dmg: float = 0.0
var _speed_multiplier: float = 1.0

const DESPAWN_Y := -50.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * projectile_speed * _speed_multiplier * delta

	if global_position.y < DESPAWN_Y:
		queue_free()


func set_speed_multiplier(mult: float) -> void:
	_speed_multiplier = clampf(mult, 0.0, 1.0)


func setup(spawn_position: Vector2, move_direction: Vector2, new_damage: float, new_projectile_speed: float) -> void:
	global_position = spawn_position
	damage = new_damage
	projectile_speed = new_projectile_speed

	if move_direction != Vector2.ZERO:
		direction = move_direction.normalized()

	rotation = direction.angle() + PI / 2.0


func setup_from_spell(
	spell: SpellData,
	spawn_pos: Vector2,
	move_dir: Vector2,
	item_base_dmg: float,
	weakness_mult: float
) -> void:
	spell_final_dmg = item_base_dmg * spell.dmgmult_chain * weakness_mult
	on_hit_effects = spell.on_hit_effects.duplicate()
	setup(spawn_pos, move_dir, spell_final_dmg, spell.projectile_speed)


func _on_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(3):
		var pm = get_node_or_null("/root/ProgressionManager")
		if pm and pm.has_method("take_damage"):
			pm.take_damage(damage)
		queue_free()
		return

	# Summon hurtbox — layer 6
	if area.get_collision_layer_value(6):
		var sum = get_node_or_null("/root/SummonManager")
		if sum != null and sum.has_method("take_summon_damage"):
			sum.take_summon_damage(damage)
		queue_free()
		return

	if not area.get_collision_layer_value(4):
		return

	var target := area.get_parent()
	if target == null:
		return
	if has_meta("ignore_node") and get_meta("ignore_node") == target:
		return
	if target.has_method("take_damage"):
		target.take_damage(damage)
		_apply_on_hit_effects(target)
		hit.emit(target, damage)
		queue_free()


func _scaled(effect: Dictionary, base_key: String, scale_key: String) -> float:
	var tier: int = effect.get("tier", 0)
	var base: Variant = effect.get(base_key, 0.0)
	var scale: Variant = effect.get(scale_key, 0.0)
	var base_f := 0.0
	if base is float:
		base_f = base
	elif base is int:
		base_f = float(base)
	elif base is String and (base as String).is_valid_float():
		base_f = (base as String).to_float()
	var scale_f := 0.0
	if scale is float:
		scale_f = scale
	elif scale is int:
		scale_f = float(scale)
	elif scale is String and (scale as String).is_valid_float():
		scale_f = (scale as String).to_float()
	return base_f + scale_f * float(tier)


func _apply_on_hit_effects(target: Node) -> void:
	for effect in on_hit_effects:
		var effect_name = effect.get("effect_name", "")
		match effect_name:
			"burndot":
				if target.has_method("apply_burn"):
					target.apply_burn(
						spell_final_dmg * _scaled(effect, "value1", "scale_value1"),
						_scaled(effect, "value2", "scale_value2"),
						_scaled(effect, "value3", "scale_value3")
					)
			"corruption":
				var dmg_per_tick := spell_final_dmg * _scaled(effect, "value1", "scale_value1")
				var interval := _scaled(effect, "value2", "scale_value2")
				var duration := _scaled(effect, "value3", "scale_value3")
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
				var bounce_val := _scaled(effect, "value1", "scale_value1")
				var bounce_count := roundi(bounce_val)
				if target.has_method("apply_chain"):
					target.apply_chain(bounce_count)
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
					var tidal_pushback := _scaled(effect, "value1", "scale_value1")
					target.apply_pushback(tidal_pushback)
				if target.has_method("apply_wet"):
					target.apply_wet()
			"voidpull":
				if target.has_method("apply_pushback"):
					target.apply_pushback(-_scaled(effect, "value1", "scale_value1"))
			"execute":
				if target.has_method("execute"):
					target.execute(_scaled(effect, "value1", "scale_value1"))
			"soulsiphon":
				var heal := spell_final_dmg * _scaled(effect, "value1", "scale_value1")
				var pm := get_node_or_null("/root/ProgressionManager")
				if pm != null and pm.has_method("heal"):
					pm.heal(heal)
			"radiance":
				if target.has_method("apply_blind"):
					target.apply_blind(_scaled(effect, "value1", "scale_value1"))
			_:
				pass


func _apply_aoe(radius: float, dmg: float, exclude: Node = null) -> void:
	for body in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(body):
			continue
		if body == exclude:
			continue
		if body.global_position.distance_to(global_position) <= radius:
			if body.has_method("take_damage"):
				body.take_damage(dmg)
