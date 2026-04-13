extends Node

var damage_reduction: float = 0.0
var element_resist: Dictionary = {}
var cd_reduction: float = 0.0
var move_speed_bonus: float = 0.0
var _active_passives: Array[Dictionary] = []
var _active_cast_passives: Array[Dictionary] = []
var _active_enemy_passives: Array[Dictionary] = []
var _consecration_timer: float = 0.0
var _player: Node = null
var _bubble_aura_ring: Line2D = null
var _chill_aura_ring: Line2D = null
var _flowstate_move_timer: float = 0.0
var _flowstate_regen_timer: float = 0.0
var _flowstate_active: bool = false
var _iceshield_still_timer: float = 0.0
var _iceshield_active: bool = false
var _iceshield_duration_timer: float = 0.0
var _iceshield_barrier_pct: float = 0.0
var _iceshield_debug_timer: float = 0.0
var _holylight_still_timer: float = 0.0
var _dispel_still_timer: float = 0.0
var _dispel_pending: bool = false
var _rootedpower_still_timer: float = 0.0
var _rootedpower_amp: float = 0.0


func _ready() -> void:
	var tm = get_node_or_null("/root/TomeManager")
	if tm != null:
		if tm.has_signal("page_changed"):
			tm.page_changed.connect(recalculate)
		elif tm.has_signal("page_flipped"):
			tm.page_flipped.connect(_on_page_flipped)
	get_tree().node_added.connect(_on_node_added)
	recalculate()


func _make_aura_ring(color: Color) -> Line2D:
	var ring := Line2D.new()
	ring.default_color = color
	ring.width = 3.0
	ring.z_index = 10
	for i in range(33):
		var angle := TAU * float(i) / 32.0
		ring.add_point(Vector2(cos(angle), sin(angle)))
	return ring


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var player_pos: Vector2 = _player.global_position

	for effect in _active_passives:
		var effect_name: String = effect.get("effect_name", "")
		match effect_name:
			"chillaura":
				var chill_radius: float = _scaled(effect, "value2", "scale_value2")
				var chill_slow_amount: float = _scaled(effect, "value1", "scale_value1")
				for enemy in get_tree().get_nodes_in_group("enemies"):
					if not is_instance_valid(enemy):
						continue
					if enemy.global_position.distance_to(player_pos) <= chill_radius:
						if enemy.has_method("apply_slow"):
							enemy.apply_slow(chill_slow_amount, 0.3)
				if _chill_aura_ring == null or not is_instance_valid(_chill_aura_ring):
					if _player != null and is_instance_valid(_player):
						_chill_aura_ring = _make_aura_ring(Color(0.5, 0.9, 1.0, 0.45))
						_player.add_child(_chill_aura_ring)
						_chill_aura_ring.position = Vector2.ZERO
				if _chill_aura_ring != null and is_instance_valid(_chill_aura_ring):
					for i in range(_chill_aura_ring.get_point_count()):
						var chill_angle := TAU * float(i) / 32.0
						_chill_aura_ring.set_point_position(i, Vector2(cos(chill_angle), sin(chill_angle)) * chill_radius)

			"bubbleaura":
				var bubble_radius: float = _scaled(effect, "value2", "scale_value2")
				var bubble_slow_amount: float = _scaled(effect, "value1", "scale_value1")
				for proj in get_tree().get_nodes_in_group("enemy_projectiles"):
					if not is_instance_valid(proj):
						continue
					if proj.global_position.distance_to(player_pos) <= bubble_radius:
						if proj.has_method("set_speed_multiplier"):
							proj.set_speed_multiplier(1.0 - bubble_slow_amount)
					else:
						if proj.has_method("set_speed_multiplier"):
							proj.set_speed_multiplier(1.0)
				if _bubble_aura_ring == null or not is_instance_valid(_bubble_aura_ring):
					if _player != null and is_instance_valid(_player):
						_bubble_aura_ring = _make_aura_ring(Color(0.3, 0.7, 1.0, 0.5))
						_player.add_child(_bubble_aura_ring)
						_bubble_aura_ring.position = Vector2.ZERO
				if _bubble_aura_ring != null and is_instance_valid(_bubble_aura_ring):
					for i in range(_bubble_aura_ring.get_point_count()):
						var bubble_angle := TAU * float(i) / 32.0
						_bubble_aura_ring.set_point_position(i, Vector2(cos(bubble_angle), sin(bubble_angle)) * bubble_radius)

			"radiance":
				var radiance_radius: float = _scaled(effect, "value2", "scale_value2")
				if radiance_radius <= 0.0:
					radiance_radius = 400.0
				var blind_duration: float = _scaled(effect, "value1", "scale_value1")
				for enemy in get_tree().get_nodes_in_group("enemies"):
					if not is_instance_valid(enemy):
						continue
					if enemy.global_position.distance_to(player_pos) <= radiance_radius:
						if enemy.has_method("apply_blind"):
							enemy.apply_blind(blind_duration)

	for effect in _active_passives:
		var effect_name: String = effect.get("effect_name", "")
		if effect_name != "consecration":
			continue

		_consecration_timer += delta
		var interval: float = float(str(effect.get("value3", 2.0)))
		if _consecration_timer < interval:
			continue
		_consecration_timer = 0.0

		var radius: float = _scaled(effect, "value2", "scale_value2")
		var base_spell_dmg: float = 1.0
		var inv = get_node_or_null("/root/PlayerInventory")
		if inv != null:
			base_spell_dmg = inv.get_school_multiplier("holy")
		var caster = get_tree().get_first_node_in_group("spell_casters")
		if caster != null and is_instance_valid(caster) and _has_property(caster, "item_base_dmg"):
			base_spell_dmg *= float(caster.get("item_base_dmg"))

		var dmg: float = _scaled(effect, "value1", "scale_value1") * base_spell_dmg
		if _player == null or not is_instance_valid(_player):
			return
		var consecration_pos: Vector2 = _player.global_position

		print("[Consecration] ticking dmg=%.2f radius=%.2f" % [dmg, radius])
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			if enemy.global_position.distance_to(consecration_pos) <= radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(dmg, "holy")

	for effect in _active_passives:
		if effect.get("effect_name", "") != "flowstate":
			continue

		var move_duration: float = 2.0
		var move_duration_raw := str(effect.get("value1", 2.0)).strip_edges()
		if move_duration_raw.is_valid_float():
			move_duration = float(move_duration_raw)
		var regen_pct: float = _scaled(effect, "value2", "scale_value2")
		var tick_interval: float = 1.0
		var tick_interval_raw := str(effect.get("value3", 1.0)).strip_edges()
		if tick_interval_raw.is_valid_float():
			tick_interval = float(tick_interval_raw)

		var is_moving := false
		if _player != null and is_instance_valid(_player):
			var vel = _player.get("velocity")
			if vel is Vector2:
				is_moving = (vel as Vector2).length() > 10.0

		if is_moving:
			_flowstate_move_timer += delta
		else:
			_flowstate_move_timer = 0.0
			_flowstate_active = false
			_flowstate_regen_timer = 0.0

		if _flowstate_move_timer >= move_duration:
			_flowstate_active = true

		if _flowstate_active:
			_flowstate_regen_timer += delta
			if _flowstate_regen_timer >= tick_interval:
				_flowstate_regen_timer = 0.0
				var pm = get_node_or_null("/root/ProgressionManager")
				if pm != null and pm.has_method("heal"):
					var max_hp: float = 100.0
					if pm.has_method("get_max_hp"):
						max_hp = pm.get_max_hp()
					elif _has_property(pm, "max_hp"):
						max_hp = float(pm.get("max_hp"))
					pm.heal(max_hp * regen_pct)

	for effect in _active_passives:
		if effect.get("effect_name", "") != "iceshield":
			continue

		var stand_duration: float = 3.0
		var stand_duration_raw := str(effect.get("value1", 3.0)).strip_edges()
		if stand_duration_raw.is_valid_float():
			stand_duration = float(stand_duration_raw)
		var barrier_pct: float = _scaled(effect, "value2", "scale_value2")
		var shield_duration: float = _scaled(effect, "value3", "scale_value3")
		_iceshield_debug_timer -= delta
		if _iceshield_debug_timer <= 0.0:
			_iceshield_debug_timer = 1.0

		var is_still := false
		if _player != null and is_instance_valid(_player):
			var vel = _player.get("velocity")
			if vel is Vector2:
				is_still = (vel as Vector2).length() <= 10.0

		if _iceshield_active:
			_iceshield_duration_timer += delta
			if _iceshield_duration_timer >= shield_duration:
				_iceshield_active = false
				_iceshield_barrier_pct = 0.0
				_iceshield_duration_timer = 0.0
				_iceshield_still_timer = 0.0
		else:
			if is_still:
				_iceshield_still_timer += delta
				if _iceshield_still_timer >= stand_duration:
					_iceshield_active = true
					_iceshield_barrier_pct = barrier_pct
					_iceshield_duration_timer = 0.0
			else:
				_iceshield_still_timer = 0.0

	for effect in _active_cast_passives:
		if effect.get("effect_name", "") != "holylight":
			continue

		var hl_stand: float = 3.5
		var hl_stand_raw := str(effect.get("value1", 3.5)).strip_edges()
		if hl_stand_raw.is_valid_float():
			hl_stand = float(hl_stand_raw)
		var hl_heal_pct: float = _scaled(effect, "value2", "scale_value2")

		var hl_still := false
		if _player != null and is_instance_valid(_player):
			var hl_vel = _player.get("velocity")
			if hl_vel is Vector2:
				hl_still = (hl_vel as Vector2).length() <= 10.0

		if hl_still:
			_holylight_still_timer += delta
			if _holylight_still_timer >= hl_stand:
				_holylight_still_timer = 0.0
				var hl_pm = get_node_or_null("/root/ProgressionManager")
				if hl_pm != null:
					var hl_max_hp: float = 100.0
					if _has_property(hl_pm, "max_hp"):
						hl_max_hp = float(hl_pm.get("max_hp"))
					if hl_pm.has_method("heal"):
						hl_pm.heal(hl_max_hp * hl_heal_pct)
				var hl_sm = get_node_or_null("/root/SummonManager")
				if hl_sm != null and hl_sm.has_method("heal_summon"):
					var hl_sm_max: float = 30.0
					if hl_sm.has_method("get_summon_max_hp"):
						hl_sm_max = hl_sm.get_summon_max_hp()
					hl_sm.heal_summon(hl_sm_max * hl_heal_pct)
		else:
			_holylight_still_timer = 0.0

	for effect in _active_cast_passives:
		if effect.get("effect_name", "") != "dispel":
			continue

		var disp_count: int = roundi(_scaled(effect, "value1", "scale_value1"))
		if disp_count < 1:
			disp_count = 1

		var disp_moving := false
		if _player != null and is_instance_valid(_player):
			var disp_vel = _player.get("velocity")
			if disp_vel is Vector2:
				disp_moving = (disp_vel as Vector2).length() > 10.0

		if disp_moving:
			if _dispel_pending:
				_dispel_pending = false
				_dispel_still_timer = 0.0
		else:
			if not _dispel_pending:
				_dispel_pending = true
				_dispel_still_timer = 0.0
			_dispel_still_timer += delta
			var disp_stand: float = 1.0
			var disp_stand_raw := str(effect.get("value2", 1.0)).strip_edges()
			if disp_stand_raw.is_valid_float():
				disp_stand = float(disp_stand_raw)
			if _dispel_still_timer >= disp_stand:
				_dispel_still_timer = 0.0
				_dispel_pending = false
				var disp_pm = get_node_or_null("/root/ProgressionManager")
				if disp_pm != null and disp_pm.has_method("remove_debuffs"):
					disp_pm.remove_debuffs(disp_count)
				var disp_sm = get_node_or_null("/root/SummonManager")
				if disp_sm != null and disp_sm.has_method("clear_debuffs"):
					disp_sm.clear_debuffs()

	for effect in _active_enemy_passives:
		if effect.get("effect_name", "") != "rootedpower":
			continue

		var rp_stand: float = 2.0
		var rp_stand_raw := str(effect.get("value1", 2.0)).strip_edges()
		if rp_stand_raw.is_valid_float():
			rp_stand = float(rp_stand_raw)
		var rp_amp: float = _scaled(effect, "value2", "scale_value2")

		var rp_still := false
		if _player != null and is_instance_valid(_player):
			var rp_vel = _player.get("velocity")
			if rp_vel is Vector2:
				rp_still = (rp_vel as Vector2).length() <= 10.0

		if rp_still:
			_rootedpower_still_timer += delta
			if _rootedpower_still_timer >= rp_stand:
				_rootedpower_amp = rp_amp
		else:
			_rootedpower_still_timer = 0.0
			_rootedpower_amp = 0.0


func recalculate() -> void:
	damage_reduction = 0.0
	element_resist = {}
	cd_reduction = 0.0
	move_speed_bonus = 0.0
	_active_passives = []
	_flowstate_move_timer = 0.0
	_flowstate_regen_timer = 0.0
	_flowstate_active = false
	_iceshield_active = false
	_iceshield_still_timer = 0.0
	_iceshield_duration_timer = 0.0
	_iceshield_barrier_pct = 0.0
	_active_cast_passives = []
	_holylight_still_timer = 0.0
	_dispel_still_timer = 0.0
	_dispel_pending = false
	_active_enemy_passives = []
	_rootedpower_still_timer = 0.0
	_rootedpower_amp = 0.0

	_player = get_tree().get_first_node_in_group("player")

	var tm = get_node_or_null("/root/TomeManager")
	if tm == null or not tm.has_method("get_active_page"):
		return

	var page = tm.get_active_page()
	var slots := _get_page_slots(page)
	if slots.is_empty():
		return

	var composer = get_node_or_null("/root/SpellComposer")
	if composer == null:
		return

	for i in range(4):
		var slot: Dictionary = slots[i] if i < slots.size() else {}
		var elemental: String = str(slot.get("elemental", ""))
		var empowerment: String = str(slot.get("empowerment", ""))
		var enchantment: String = str(slot.get("enchantment", ""))
		var delivery: String = str(slot.get("delivery", ""))
		if elemental == "":
			continue

		var effects := _get_passive_effects(composer, elemental, empowerment, enchantment, delivery)
		var inv_check = get_node_or_null("/root/PlayerInventory")
		for effect in effects:
			var target_type := str(effect.get("target", "")).to_lower()
			var cd_type := str(effect.get("cd_type", "")).to_lower()
			if target_type != "self" or cd_type != "passive":
				continue
			if inv_check != null \
					and not inv_check.school_allocation.is_empty() \
					and inv_check.get_school_tier(elemental) == 0:
				continue
			_active_passives.append(effect)
			_apply_stat_passive(effect)

		# Collect cd_type=cast, target=self passives
		for effect in effects:
			var cast_target := str(effect.get("target", "")).to_lower()
			var cast_cd := str(effect.get("cd_type", "")).to_lower()
			if cast_target == "self" and cast_cd == "cast":
				if inv_check != null \
						and not inv_check.school_allocation.is_empty() \
						and inv_check.get_school_tier(elemental) == 0:
					continue
				_active_cast_passives.append(effect)

		# Collect cd_type=passive, target=enemy passives
		for effect in effects:
			var ep_target := str(effect.get("target", "")).to_lower()
			var ep_cd := str(effect.get("cd_type", "")).to_lower()
			if ep_target == "enemy" and ep_cd == "passive":
				if inv_check != null \
						and not inv_check.school_allocation.is_empty() \
						and inv_check.get_school_tier(elemental) == 0:
					continue
				_active_enemy_passives.append(effect)

	damage_reduction = minf(damage_reduction, 0.75)
	for key in element_resist:
		element_resist[key] = minf(element_resist[key], 0.75)

	# Apply flashcast to all active SpellCasters
	for caster in get_tree().get_nodes_in_group("spell_casters"):
		if is_instance_valid(caster) and caster.has_method("apply_cd_reduction"):
			caster.apply_cd_reduction(cd_reduction)

	# Apply surge to player
	if _player != null and is_instance_valid(_player):
		if _player.has_method("apply_speed_bonus"):
			_player.apply_speed_bonus(move_speed_bonus)

	var has_bubble := _active_passives.any(func(e: Dictionary) -> bool:
		return e.get("effect_name", "") == "bubbleaura")
	if not has_bubble:
		if _bubble_aura_ring != null and is_instance_valid(_bubble_aura_ring):
			_bubble_aura_ring.queue_free()
		_bubble_aura_ring = null

	var has_chill := _active_passives.any(func(e: Dictionary) -> bool:
		return e.get("effect_name", "") == "chillaura")
	if not has_chill:
		if _chill_aura_ring != null and is_instance_valid(_chill_aura_ring):
			_chill_aura_ring.queue_free()
		_chill_aura_ring = null


func _apply_stat_passive(effect: Dictionary) -> void:
	var effect_name: String = str(effect.get("effect_name", ""))
	match effect_name:
		"stoneskin":
			damage_reduction += _scaled(effect, "value1", "scale_value1")

		"resist_bonus":
			var element_key: String = str(effect.get("value1", "")).to_lower()
			if element_key != "":
				var resist_val: float = _scaled(effect, "value2", "scale_value2")
				element_resist[element_key] = element_resist.get(element_key, 0.0) + resist_val

		"flashcast":
			cd_reduction += _scaled(effect, "value1", "scale_value1")

		"surge":
			move_speed_bonus += _scaled(effect, "value1", "scale_value1")


func get_effective_damage(raw: float, element: String) -> float:
	var after_shield := raw
	if _iceshield_active and _iceshield_barrier_pct > 0.0:
		after_shield = raw * (1.0 - _iceshield_barrier_pct)
	var after_dr: float = after_shield * (1.0 - damage_reduction)
	var resist: float = float(element_resist.get(element.to_lower(), 0.0)) if element != "" else 0.0
	return after_dr * (1.0 - resist)


func get_damage_amp() -> float:
	return _rootedpower_amp


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


func _on_page_flipped(_index: int) -> void:
	recalculate()


func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		call_deferred("recalculate")


func _has_property(node: Object, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _get_page_slots(page: Variant) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if page == null:
		return slots

	var raw_slots: Array = []
	if page is Dictionary:
		if not page.has("slots"):
			return slots
		var dict_slots = page.get("slots", [])
		if not dict_slots is Array:
			return slots
		raw_slots = dict_slots as Array
	elif page is PageData:
		raw_slots = page.slots
	else:
		return slots

	for slot in raw_slots:
		if slot is Dictionary:
			slots.append((slot as Dictionary).duplicate(true))
	return slots


func _get_passive_effects(
	composer: Node,
	elemental: String,
	empowerment: String,
	enchantment: String,
	delivery: String
) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []

	_append_passive_rows(effects, composer, elemental, empowerment, enchantment)
	if effects.is_empty() and composer.has_method("compose_spell"):
		var composed = composer.call("compose_spell", elemental, empowerment, enchantment, delivery, "self")
		if composed is Dictionary:
			var composed_dict := composed as Dictionary
			var composed_effects = composed_dict.get("effects", [])
			if composed_effects is Array:
				_append_effects(effects, composed_effects)
		elif composed is SpellData:
			_append_effects(effects, composed.self_effects)

	return effects


func _append_effects(target: Array[Dictionary], source: Array) -> void:
	for effect in source:
		if effect is Dictionary:
			target.append((effect as Dictionary).duplicate(true))


func _append_passive_rows(
	effects: Array[Dictionary],
	composer: Node,
	elemental: String,
	empowerment: String,
	enchantment: String
) -> void:
	if not composer.has_method("_get_row_by_key") or not composer.has_method("_build_effect_entry"):
		return

	var parts := {
		"elemental": elemental,
		"empowerment": empowerment,
		"enchantment": enchantment
	}
	var tier := 0
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv != null and inv.has_method("get_school_tier"):
		tier = int(inv.get_school_tier(elemental))

	for position in parts:
		var element_name: String = str(parts[position])
		for target in ["self", "enemy"]:
			var row = composer.call("_get_row_by_key", "%s_%s_%s" % [element_name.to_lower(), position, target])
			if not row is Dictionary:
				continue
			var row_dict := row as Dictionary
			if row_dict.is_empty():
				continue
			var row_cd_type := str(row_dict.get("cd_type", "")).to_lower()
			if row_cd_type != "passive" and row_cd_type != "cast":
				continue
			var effect = composer.call("_build_effect_entry", row_dict)
			if not effect is Dictionary:
				continue
			var effect_dict := (effect as Dictionary).duplicate(true)
			effect_dict["target"] = str(row_dict.get("target", target))
			effect_dict["tier"] = tier
			effects.append(effect_dict)


func is_iceshield_active() -> bool:
	return _iceshield_active
