extends Area2D

signal hit(target: Node, damage: float)

@export var damage: float = 10.0
@export var projectile_speed: float = 850.0
@export var direction: Vector2 = Vector2.UP
var on_hit_effects: Array[Dictionary] = []
var spell_final_dmg: float = 0.0

const DESPAWN_Y := -50.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


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

	var target := area.get_parent()
	if target != null and target.has_method("take_damage"):
		target.take_damage(damage)
		_apply_on_hit_effects(target)
		hit.emit(target, damage)
		queue_free()


func _apply_on_hit_effects(target: Node) -> void:
	for effect in on_hit_effects:
		var effect_name = effect.get("effect_name", "")
		match effect_name:
			"burndot", "corruption":
				if target.has_method("apply_burn"):
					target.apply_burn(
						spell_final_dmg * float(effect.get("value1", 0)),
						float(effect.get("value2", 1)),
						float(effect.get("value3", 3))
					)
			"chilled":
				if target.has_method("apply_slow"):
					target.apply_slow(
						float(effect.get("value1", 0)),
						float(effect.get("value2", 0))
					)
			"brittle":
				if target.has_method("apply_brittle"):
					target.apply_brittle(
						float(effect.get("value1", 0)),
						float(effect.get("value2", 0))
					)
			"explosion":
				_apply_aoe(
					float(effect.get("value1", 0)),
					spell_final_dmg * float(effect.get("value2", 0)),
					target
				)
			"chain 1", "chain 2":
				if target.has_method("apply_chain"):
					target.apply_chain(int(float(effect.get("value1", 0))))
			"stagger":
				if target.has_method("apply_stagger"):
					target.apply_stagger(
						float(effect.get("value1", 0)),
						float(effect.get("value2", 0))
					)
			"splash":
				_apply_aoe(
					float(effect.get("value1", 0)),
					spell_final_dmg * float(effect.get("value2", 0)),
					target
				)
			"tidal":
				if target.has_method("apply_pushback"):
					target.apply_pushback(float(effect.get("value1", 0)))
			"execute":
				if target.has_method("execute"):
					target.execute(float(effect.get("value1", 0)))
			"lifeleech", "soulsiphon":
				var heal = spell_final_dmg * float(effect.get("value1", 0))
				var pm = get_node_or_null("/root/ProgressionManager")
				if pm != null and pm.has_method("heal"):
					pm.heal(heal)
			"radiance":
				if target.has_method("apply_blind"):
					target.apply_blind(float(effect.get("value1", 0)))
			"judgement":
				pass
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
