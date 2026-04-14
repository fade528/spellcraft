extends Node2D

@export var elemental_element: String = "fire"
@export var empowerment_element: String = "fire"
@export var enchantment_element: String = "fire"
@export var delivery_type: String = "bolt"
@export var target_type: String = "enemy"
@export var item_base_dmg: float = 10.0
@export var fire_offset: Vector2 = Vector2(0.0, -72.0)
@export var aim_range: float = 1400.0

var spell_data: SpellData
var _is_moving: bool = false
var _just_stopped: bool = false
var cooldown_timer: Timer = null
var _stagger_delay: float = 0.0
var _stagger_elapsed: bool = true
var _stop_cast_pending: bool = false
var _stop_cast_timer: float = 0.0
var _cd_reduction: float = 0.0
var _cast_count: int = 0
var _overheat_amp: float = 1.0
var _overheat_ready: bool = false

const DELIVERY_SCENES: Dictionary = {
	"bolt":    preload("res://scenes/deliveries/bolt.tscn"),
	"missile": preload("res://scenes/deliveries/missile.tscn"),
	"burst":   preload("res://scenes/deliveries/burst.tscn"),
	"beam":    preload("res://scenes/deliveries/beam.tscn"),
	"blast":   preload("res://scenes/deliveries/aoe.tscn"),
	"cleave":  preload("res://scenes/deliveries/cleave.tscn"),
	"orbs":    preload("res://scenes/deliveries/orbs.tscn"),
}
const STOP_CAST_DELAY: float = 0.5

func _ready() -> void:
	cooldown_timer = get_node_or_null("CooldownTimer")
	if cooldown_timer == null:
		cooldown_timer = Timer.new()
		cooldown_timer.name = "CooldownTimer"
		cooldown_timer.one_shot = true
		add_child(cooldown_timer)
	add_to_group("spell_casters")
	var sm_init: Node = get_node_or_null("/root/SummonManager")
	if sm_init != null and sm_init.has_method("initialize"):
		var player: Node2D = get_parent() as Node2D
		if player != null:
			sm_init.initialize(player)
	_recompose_spell()


func _configure_cooldown_timer() -> void:
	if _is_stop_cast_slot():
		cooldown_timer.stop()
		return
	if spell_data == null:
		return
	var full_cd: float = maxf(spell_data.cooldown - _cd_reduction, 1.5)
	cooldown_timer.wait_time = full_cd
	if not cooldown_timer.timeout.is_connected(_on_cooldown_timer_timeout):
		cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	if _stagger_elapsed and cooldown_timer.is_stopped():
		cooldown_timer.start()


func set_stagger_delay(delay: float) -> void:
	_stagger_delay = delay
	if delay <= 0.0:
		_stagger_elapsed = true
		return
	_stagger_elapsed = false
	cooldown_timer.stop()
	var stagger_timer := Timer.new()
	stagger_timer.one_shot = true
	stagger_timer.wait_time = delay
	add_child(stagger_timer)
	stagger_timer.timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		_stagger_elapsed = true
		stagger_timer.queue_free()
		if spell_data != null and not _is_stop_cast_slot():
			cooldown_timer.start()
	)
	stagger_timer.start()


func set_moving(moving: bool) -> void:
	var was_moving := _is_moving
	_is_moving = moving
	_just_stopped = was_moving and not moving
	if _just_stopped and _is_stop_cast_slot():
		_stop_cast_pending = true
		_stop_cast_timer = 0.0


func _is_stop_cast_slot() -> bool:
	var composer = get_node_or_null("/root/SpellComposer")
	if composer == null:
		return false
	return composer.is_stop_cast(elemental_element)


func _process(delta: float) -> void:
	if not _stop_cast_pending:
		return
	if _is_moving:
		_stop_cast_pending = false
		_stop_cast_timer = 0.0
		return
	_stop_cast_timer += delta
	if _stop_cast_timer >= STOP_CAST_DELAY:
		_stop_cast_pending = false
		_stop_cast_timer = 0.0
		_try_stop_cast_fire()


func _try_stop_cast_fire() -> void:
	var _inventory := get_node_or_null("/root/PlayerInventory")
	if _inventory != null and not _inventory.school_allocation.is_empty() \
			and _inventory.get_school_tier(elemental_element) == 0:
		return
	if spell_data == null:
		return
	if elemental_element == "" or delivery_type == "" or delivery_type == "-":
		return

	var spell_composer = get_node_or_null("/root/SpellComposer")
	var spawn_position := global_position + fire_offset
	var target := _get_nearest_enemy()
	var shot_direction := Vector2.UP
	if target != null:
		var to_target := target.global_position - spawn_position
		if to_target != Vector2.ZERO and to_target.length() <= aim_range:
			shot_direction = to_target.normalized()

	var target_el := _get_target_element()
	var weakness := 1.0
	if spell_composer != null:
		weakness = spell_composer.get_weakness_multiplier(elemental_element, target_el)
	var school_mult := 1.0
	var inv2 := get_node_or_null("/root/PlayerInventory")
	if inv2 != null and inv2.has_method("get_school_multiplier"):
		school_mult = inv2.get_school_multiplier(elemental_element)
	var final_dmg := item_base_dmg * school_mult
	var _passmgr = get_node_or_null("/root/PassiveManager")
	if _passmgr != null and _passmgr.has_method("get_damage_amp"):
		final_dmg *= (1.0 + _passmgr.get_damage_amp())
	if _passmgr != null and _passmgr.has_method("get_bloodpower_amp"):
		final_dmg *= (1.0 + _passmgr.get_bloodpower_amp())
	if _passmgr != null and _passmgr.has_method("get_soul_amp"):
		final_dmg *= (1.0 + _passmgr.get_soul_amp())
		print("[Soul] soul amp: %.2f | final_dmg: %.2f" % [_passmgr.get_soul_amp(), final_dmg])
	_check_overheat()
	if _overheat_ready:
		var _oh_dmg := final_dmg * _overheat_amp
		var _oh_pos := spawn_position
		var _oh_dir := shot_direction
		var _oh_weak := weakness
		var _oh_timer := get_tree().create_timer(0.3)
		_oh_timer.timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			_spawn_delivery(_oh_pos, _oh_dir, _oh_dmg, _oh_weak)
			_overheat_amp = 1.0
			_overheat_ready = false
		)
	_spawn_delivery(spawn_position, shot_direction, final_dmg, weakness)
	# Soulsiphon leech
	if _passmgr != null and _passmgr.has_method("get_soulsiphon_leech"):
		var _leech: float = _passmgr.get_soulsiphon_leech()
		if _leech > 0.0:
			var _heal_amount: float = final_dmg * _leech
			var _prog = get_node_or_null("/root/ProgressionManager")
			if _prog != null and _prog.has_method("heal"):
				_prog.heal(_heal_amount)
			print("[Siphon] leech: %.4f | heal: %.2f" % [_leech, _heal_amount])


func apply_cd_reduction(reduction: float) -> void:
	_cd_reduction = reduction
	if cooldown_timer != null and not cooldown_timer.is_stopped():
		cooldown_timer.wait_time = maxf(cooldown_timer.wait_time - reduction, 1.5)


func apply_cd_reduction_instant(seconds: float) -> void:
	if cooldown_timer == null or cooldown_timer.is_stopped():
		return
	var full_cd: float = maxf(spell_data.cooldown - _cd_reduction, 1.5) if spell_data != null else 1.5
	var new_time := maxf(cooldown_timer.time_left - seconds, 0.1)
	cooldown_timer.wait_time = full_cd
	cooldown_timer.stop()
	cooldown_timer.start(new_time)


func _check_overheat() -> void:
	var _pm := get_node_or_null("/root/PassiveManager")
	if _pm == null or not _pm.has_method("get_overheat_effect"):
		return
	var effect: Dictionary = _pm.get_overheat_effect()
	if effect.is_empty():
		return
	var threshold_raw: Variant = effect.get("value1", 0.0)
	var threshold_f := 0.0
	if threshold_raw is float:
		threshold_f = threshold_raw
	elif threshold_raw is int:
		threshold_f = float(threshold_raw)
	elif threshold_raw is String and (threshold_raw as String).is_valid_float():
		threshold_f = (threshold_raw as String).to_float()
	var tier: int = effect.get("tier", 0)
	var scale_raw: Variant = effect.get("scale_value1", 0.0)
	var scale_f := 0.0
	if scale_raw is float:
		scale_f = scale_raw
	elif scale_raw is int:
		scale_f = float(scale_raw)
	elif scale_raw is String and (scale_raw as String).is_valid_float():
		scale_f = (scale_raw as String).to_float()
	var threshold: int = roundi(threshold_f + scale_f * float(tier))
	if threshold <= 0:
		return
	_cast_count += 1
	if _cast_count >= threshold:
		_cast_count = 0
		var amp_raw: Variant = effect.get("value2", 0.0)
		var amp_f := 0.0
		if amp_raw is float:
			amp_f = amp_raw
		elif amp_raw is int:
			amp_f = float(amp_raw)
		elif amp_raw is String and (amp_raw as String).is_valid_float():
			amp_f = (amp_raw as String).to_float()
		var amp_scale_raw: Variant = effect.get("scale_value2", 0.0)
		var amp_scale_f := 0.0
		if amp_scale_raw is float:
			amp_scale_f = amp_scale_raw
		elif amp_scale_raw is int:
			amp_scale_f = float(amp_scale_raw)
		elif amp_scale_raw is String and (amp_scale_raw as String).is_valid_float():
			amp_scale_f = (amp_scale_raw as String).to_float()
		_overheat_amp = 1.0 + amp_f + amp_scale_f * float(tier)
		_overheat_ready = true


func _recompose_spell() -> void:
	var spell_composer = get_node_or_null("/root/SpellComposer")
	if spell_composer == null or not spell_composer.has_method("compose_spell"):
		spell_data = null
		return

	spell_data = spell_composer.compose_spell(
		elemental_element,
		empowerment_element,
		enchantment_element,
		delivery_type,
		target_type
	)
	_configure_cooldown_timer()
	var sm = get_node_or_null("/root/SummonManager")
	if sm:
		sm.set_attack_spell(spell_data)


func refresh_spell(
	new_elemental: String,
	new_empowerment: String,
	new_enchantment: String,
	new_delivery: String,
	new_target: String
) -> void:
	elemental_element = new_elemental
	empowerment_element = new_empowerment
	enchantment_element = new_enchantment
	delivery_type = new_delivery
	target_type = new_target
	_recompose_spell()


func _on_cooldown_timer_timeout() -> void:
	if _is_stop_cast_slot():
		return
	var _inventory := get_node_or_null("/root/PlayerInventory")
	if elemental_element == "":
		return
	if delivery_type == "" or delivery_type == "-":
		return
	if _inventory != null and not _inventory.school_allocation.is_empty() and _inventory.get_school_tier(elemental_element) == 0:
		return

	if spell_data == null:
		return

	if delivery_type == "orbs":
		var existing_orbs := get_tree().get_nodes_in_group("orbs")
		if existing_orbs.size() > 0:
			return

	var spell_composer = get_node_or_null("/root/SpellComposer")
	var is_stop_cast := false
	if spell_composer != null and spell_composer.has_method("is_stop_cast"):
		is_stop_cast = spell_composer.is_stop_cast(elemental_element)
	if is_stop_cast:
		if not _just_stopped:
			return
		_just_stopped = false

	var spawn_position := global_position + fire_offset
	var target := _get_nearest_enemy()
	var shot_direction := Vector2.UP

	if target != null:
		var to_target := target.global_position - spawn_position
		if to_target != Vector2.ZERO and to_target.length() <= aim_range:
			shot_direction = to_target.normalized()

	var target_el := _get_target_element()
	var weakness := 1.0
	if spell_composer != null:
		weakness = spell_composer.get_weakness_multiplier(
			elemental_element, target_el
		)
	var school_mult := 1.0
	var _inv2 := get_node_or_null("/root/PlayerInventory")
	if _inv2 != null and _inv2.has_method("get_school_multiplier"):
		school_mult = _inv2.get_school_multiplier(elemental_element)
	var final_dmg := item_base_dmg * school_mult
	var _passmgr = get_node_or_null("/root/PassiveManager")
	if _passmgr != null and _passmgr.has_method("get_damage_amp"):
		final_dmg *= (1.0 + _passmgr.get_damage_amp())
	if _passmgr != null and _passmgr.has_method("get_bloodpower_amp"):
		final_dmg *= (1.0 + _passmgr.get_bloodpower_amp())
	if _passmgr != null and _passmgr.has_method("get_soul_amp"):
		final_dmg *= (1.0 + _passmgr.get_soul_amp())
		print("[Soul] soul amp: %.2f | final_dmg: %.2f" % [_passmgr.get_soul_amp(), final_dmg])
	_check_overheat()
	if _overheat_ready:
		var _oh_dmg := final_dmg * _overheat_amp
		var _oh_pos := global_position + fire_offset
		var _oh_dir := shot_direction
		var _oh_weak := weakness
		var _oh_timer := get_tree().create_timer(0.3)
		_oh_timer.timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			_spawn_delivery(_oh_pos, _oh_dir, _oh_dmg, _oh_weak)
			_overheat_amp = 1.0
			_overheat_ready = false
		)
	_spawn_delivery(spawn_position, shot_direction, final_dmg, weakness)
	# Soulsiphon leech
	if _passmgr != null and _passmgr.has_method("get_soulsiphon_leech"):
		var _leech: float = _passmgr.get_soulsiphon_leech()
		if _leech > 0.0:
			var _heal_amount: float = final_dmg * _leech
			var _prog = get_node_or_null("/root/ProgressionManager")
			if _prog != null and _prog.has_method("heal"):
				_prog.heal(_heal_amount)
			print("[Siphon] leech: %.4f | heal: %.2f" % [_leech, _heal_amount])
	var full_cd: float = maxf(spell_data.cooldown - _cd_reduction, 1.5) if spell_data != null else 1.5
	cooldown_timer.wait_time = full_cd
	cooldown_timer.start()


func _spawn_delivery(spawn_pos: Vector2, shot_dir: Vector2, final_dmg: float, weakness: float) -> void:
	var projectile_container := get_tree().get_first_node_in_group("projectiles")
	if projectile_container == null:
		projectile_container = get_tree().current_scene

	match delivery_type:
		"bolt", "missile":
			var delivery_instance = DELIVERY_SCENES[delivery_type].instantiate()
			if delivery_instance == null:
				return
			delivery_instance.setup_from_spell(
				spell_data,
				spawn_pos,
				shot_dir,
				final_dmg,
				weakness
			)
			delivery_instance.add_to_group("projectiles_active")
			projectile_container.add_child(delivery_instance)
		"burst":
			for offset in [-20, -10, 0, 10, 20]:
				var burst_instance = DELIVERY_SCENES["burst"].instantiate()
				if burst_instance == null:
					continue
				var burst_dir := shot_dir.rotated(deg_to_rad(offset))
				burst_instance.setup_from_spell(
					spell_data,
					spawn_pos,
					burst_dir,
					final_dmg * 0.75,
					weakness
				)
				burst_instance.add_to_group("projectiles_active")
				projectile_container.add_child(burst_instance)
		"beam":
			var beam_instance = DELIVERY_SCENES["beam"].instantiate()
			if beam_instance == null:
				return
			projectile_container.add_child(beam_instance)
			beam_instance.setup_from_spell(
				spell_data,
				spawn_pos,
				shot_dir,
				final_dmg,
				weakness
			)
			beam_instance.add_to_group("projectiles_active")
		"blast", "cleave":
			var area_instance = DELIVERY_SCENES[delivery_type].instantiate()
			if area_instance == null:
				return
			area_instance.add_to_group("projectiles_active")
			projectile_container.add_child(area_instance)
			area_instance.setup_from_spell(
				spell_data,
				global_position,
				shot_dir,
				final_dmg,
				weakness
			)
		"orbs":
			for existing in get_tree().get_nodes_in_group("orbs"):
				existing.queue_free()
			for i in range(3):
				var orb_instance = DELIVERY_SCENES["orbs"].instantiate()
				if orb_instance == null:
					continue
				orb_instance.set_meta("orbit_index", i)
				orb_instance.setup_from_spell(
					spell_data,
					spawn_pos,
					shot_dir,
					final_dmg,
					weakness
				)
				orb_instance.add_to_group("projectiles_active")
				projectile_container.add_child(orb_instance)
		"utility":
			pass
		_:
			pass


func _get_target_element() -> String:
	var target := _get_nearest_enemy()
	if target != null and target.has_method("get_element"):
		return target.get_element()
	return ""


func _get_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance: float = INF

	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Node2D):
			continue
		if not is_instance_valid(enemy_node):
			continue

		var enemy := enemy_node as Node2D
		if enemy.global_position.y >= global_position.y:
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy
