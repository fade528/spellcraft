class_name Bolt
extends Area2D

signal hit(target: Node, damage: float)

@export var damage: float = 10.0
@export var projectile_speed: float = 850.0
@export var direction: Vector2 = Vector2.UP
var on_hit_effects: Array[Dictionary] = []
var spell_final_dmg: float = 0.0
var element: String = ""

const DESPAWN_Y: float = -50.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	if not has_node("ColorRect"):
		var cr := ColorRect.new()
		cr.size = Vector2(10.0, 20.0)
		cr.position = Vector2(-5.0, -10.0)
		cr.color = Color(1.0, 0.9, 0.2, 1.0)
		add_child(cr)


func _physics_process(delta: float) -> void:
	global_position += direction * projectile_speed * delta

	if global_position.y < DESPAWN_Y:
		queue_free()


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
	element = spell.elemental_element.to_lower()
	on_hit_effects = spell.on_hit_effects.duplicate()
	setup(spawn_pos, move_dir, spell_final_dmg, spell.projectile_speed)


func _on_area_entered(area: Area2D) -> void:
	if not area.get_collision_layer_value(4):
		return

	var target: Node = area.get_parent()
	if target == null:
		return
	if has_meta("ignore_node") and get_meta("ignore_node") == target:
		return
	if target.has_method("take_damage"):
		var _smite_element := element
		var _smite_dmg_mult := 1.0
		print("[Smite] bolt register — element: '%s' | has method: %s" % [
				element, str(target.has_method("register_hit_school"))])
		if target.has_method("register_hit_school") and element != "":
			target.register_hit_school(element)
		if target.has_method("consume_smite_hit") and target.consume_smite_hit():
			var _pm_smite = get_node_or_null("/root/PassiveManager")
			if _pm_smite != null:
				print("[Smite] searching enemy passives: ", _pm_smite._active_enemy_passives.map(func(e): return e.get("effect_name","")))
				for effect in _pm_smite._active_enemy_passives:
					if (effect.get("effect_name", "") as String).begins_with("smite"):
						var tier: int = effect.get("tier", 0)
						var base: float = float(str(effect.get("value1", 0.0)))
						var scale_v: float = float(str(effect.get("scale_value1", 0.0)))
						_smite_dmg_mult = 1.0 + base + scale_v * float(tier)
						_smite_element = "holy"
						print("[Smite] bolt proc — amp: %.2f" % _smite_dmg_mult)
						break
		target.take_damage(damage * _smite_dmg_mult, _smite_element)
		_apply_on_hit_effects(target)
		hit.emit(target, damage)
		queue_free()


func _scaled(effect: Dictionary, base_key: String, scale_key: String) -> float:
	var tier: int = int(effect.get("tier", 0))
	var base: Variant = effect.get(base_key, 0.0)
	var scale_v: Variant = effect.get(scale_key, 0.0)
	var base_f: float = 0.0
	if base is float:
		base_f = base
	elif base is int:
		base_f = float(base)
	elif base is String and (base as String).is_valid_float():
		base_f = (base as String).to_float()
	var scale_f: float = 0.0
	if scale_v is float:
		scale_f = scale_v
	elif scale_v is int:
		scale_f = float(scale_v)
	elif scale_v is String and (scale_v as String).is_valid_float():
		scale_f = (scale_v as String).to_float()
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
