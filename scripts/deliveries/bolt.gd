class_name Bolt
extends Area2D

signal hit(target: Node, damage: float)

@export var damage: float = 10.0
@export var projectile_speed: float = 850.0
@export var direction: Vector2 = Vector2.UP
var on_hit_effects: Array[Dictionary] = []
var spell_final_dmg: float = 0.0

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
		target.take_damage(damage)
		var _pm_ss := get_node_or_null("/root/PassiveManager")
		if _pm_ss != null and _pm_ss.has_method("get_soulsiphon_leech"):
			var _ss_leech: float = _pm_ss.get_soulsiphon_leech()
			if _ss_leech > 0.0:
				var _prog_ss := get_node_or_null("/root/ProgressionManager")
				if _prog_ss != null and _prog_ss.has_method("heal"):
					_prog_ss.heal(spell_final_dmg * _ss_leech)
		_apply_on_hit_effects(target)
		hit.emit(target, damage)
		queue_free()


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
