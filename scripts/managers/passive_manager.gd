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
var _killfuel_last_physics_frame: int = -1
var _soul_stacks: int = 0
var _soul_max: int = 0
var _mudwall_still_timer: float = 0.0
var _mudwall_cooldown_timer: float = 0.0
var _recalculate_queued: bool = false
const MUDWALL_SPAWN_COOLDOWN: float = 8.0


func _ready() -> void:
	var tm = get_node_or_null("/root/TomeManager")
	if tm != null:
		if tm.has_signal("page_changed"):
			tm.page_changed.connect(recalculate)
		elif tm.has_signal("page_flipped"):
			tm.page_flipped.connect(_on_page_flipped)
	call_deferred("recalculate")


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

	for effect in _active_passives:
		if effect.get("effect_name", "") != "mudwall":
			continue

		var mw_stand: float = _scaled(effect, "value1", "scale_value1")
		if mw_stand <= 0.0:
			mw_stand = 2.0
		var mw_is_still := false
		if _player != null and is_instance_valid(_player):
			var mw_vel = _player.get("velocity")
			if mw_vel is Vector2:
				mw_is_still = (mw_vel as Vector2).length() <= 10.0

		_mudwall_cooldown_timer = maxf(_mudwall_cooldown_timer - delta, 0.0)

		if mw_is_still:
			_mudwall_still_timer += delta
			if _mudwall_still_timer >= mw_stand and _mudwall_cooldown_timer <= 0.0:
				_mudwall_still_timer = 0.0
				_mudwall_cooldown_timer = MUDWALL_SPAWN_COOLDOWN
				_spawn_mudwall(effect)
				print("[Mudwall] spawning")
		else:
			_mudwall_still_timer = 0.0


func _spawn_mudwall(effect: Dictionary) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var mw_width: float = _scaled(effect, "value2", "scale_value2")
	if mw_width <= 0.0:
		mw_width = 200.0
	var mw_duration: float = _scaled(effect, "value3", "scale_value3")
	if mw_duration <= 0.0:
		mw_duration = 4.0

	# Spawn in front of player (toward nearest enemy, default UP)
	var mw_dir := Vector2.UP
	if _player != null and is_instance_valid(_player):
		var facing_marker := _player.get_node_or_null("FacingMarker")
		if facing_marker != null:
			if facing_marker.rotation == 0.0:
				mw_dir = Vector2.UP
				print("[Mudwall] FacingMarker.rotation == 0.0 — using default UP direction")
			else:
				mw_dir = Vector2.UP.rotated(facing_marker.rotation)
				print("[Mudwall] FacingMarker.rotation: %.3f — mw_dir: %s" % [facing_marker.rotation, str(mw_dir)])
		else:
			mw_dir = Vector2.UP.rotated(_player.rotation)
			print("[Mudwall] FacingMarker not found — using player.rotation: %.3f" % _player.rotation)

	var mw_scene = load("res://scenes/effects/mud_wall.tscn")
	if mw_scene == null:
		print("[Mudwall] ERROR: scene not found")
		return
	var mw_instance = mw_scene.instantiate()
	if mw_instance == null:
		print("[Mudwall] ERROR: instantiate failed")
		return
	mw_instance.width = mw_width
	mw_instance.duration = mw_duration
	var spawn_pos: Vector2 = _player.global_position + mw_dir * 80.0
	get_tree().current_scene.add_child(mw_instance)
	mw_instance.global_position = spawn_pos
	# Rotate wall perpendicular to the direction toward the enemy
	# mw_dir points toward enemy, wall should be perpendicular to block that path
	mw_instance.rotation = mw_dir.angle()
	print("[Mudwall] player_rotation: %.3f | mw_dir: %s | wall_rotation: %.3f" % [
		_player.rotation,
		str(mw_dir),
		mw_instance.rotation
	])
	print("[Mudwall] player children rotations:")
	for child in _player.get_children():
		if child is Node2D:
			print("  %s rotation: %.3f" % [child.name, child.rotation])
	print("[Mudwall] spawned at: %s" % str(spawn_pos))


func recalculate() -> void:
	if _recalculate_queued:
		return
	_recalculate_queued = true
	call_deferred("_do_recalculate")


func _do_recalculate() -> void:
	_recalculate_queued = false
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
	_soul_stacks = 0
	_soul_max = 0
	_mudwall_still_timer = 0.0

	_player = get_tree().get_first_node_in_group("player")

	var tm = get_node_or_null("/root/TomeManager")
	if tm == null or not tm.has_method("get_active_page"):
		return

	var page = tm.get_combat_active_page() if tm.has_method("get_combat_active_page") else tm.get_active_page()
	print("[PM] recalculate() — page type: %s" % str(typeof(page)))
	if page is Dictionary:
		print("[PM] page dict keys: %s" % str((page as Dictionary).keys()))
	elif page != null:
		print("[PM] page class: %s" % str(page.get_class()))
	var _dbg_slots := _get_page_slots(page)
	print("[PM] slot count from get_active_page(): %d" % _dbg_slots.size())
	for _si in range(_dbg_slots.size()):
		var _sl := _dbg_slots[_si]
		print("[PM]   slot %d — elemental: '%s' emp: '%s' enc: '%s'" % [
			_si,
			str(_sl.get("elemental", "")),
			str(_sl.get("empowerment", "")),
			str(_sl.get("enchantment", ""))
		])
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

		# Collect cd_type=passive OR cd_type=cast, target=enemy passives
		for effect in effects:
			var ep_target := str(effect.get("target", "")).to_lower()
			var ep_cd := str(effect.get("cd_type", "")).to_lower()
			if ep_target == "enemy" and (ep_cd == "passive" or ep_cd == "cast"):
				if inv_check != null \
						and not inv_check.school_allocation.is_empty() \
						and inv_check.get_school_tier(elemental) == 0:
					continue
				_active_enemy_passives.append(effect)

	damage_reduction = minf(damage_reduction, 0.75)
	for key in element_resist:
		element_resist[key] = minf(element_resist[key], 0.75)

	# Dedup _active_passives by effect_name (keep first occurrence)
	var _seen_p: Dictionary = {}
	var _deduped_p: Array[Dictionary] = []
	for _pp in _active_passives:
		var _pn: String = str(_pp.get("effect_name", ""))
		if not _seen_p.has(_pn):
			_seen_p[_pn] = true
			_deduped_p.append(_pp)
	_active_passives = _deduped_p

	# Dedup cast passives by effect_name (keep first occurrence)
	var _seen_cast: Dictionary = {}
	var _deduped_cast: Array[Dictionary] = []
	for _cp in _active_cast_passives:
		var _cn: String = str(_cp.get("effect_name", ""))
		if not _seen_cast.has(_cn):
			_seen_cast[_cn] = true
			_deduped_cast.append(_cp)
	_active_cast_passives = _deduped_cast

	# Dedup enemy passives by effect_name (keep first occurrence)
	var _seen_enemy: Dictionary = {}
	var _deduped_enemy: Array[Dictionary] = []
	for _ep in _active_enemy_passives:
		var _en: String = str(_ep.get("effect_name", ""))
		if not _seen_enemy.has(_en):
			_seen_enemy[_en] = true
			_deduped_enemy.append(_ep)
	_active_enemy_passives = _deduped_enemy

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

	print("[PM] active passives: ", _active_passives.map(func(e): return e.get("effect_name","")))
	print("[PM] active cast passives: ", _active_cast_passives.map(func(e): return e.get("effect_name","")))


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


func get_soul_amp() -> float:
	if _soul_stacks <= 0:
		return 0.0
	var soul_effect: Dictionary = {}
	for effect in _active_cast_passives:
		if effect.get("effect_name", "") == "soulrequiem":
			soul_effect = effect
			break
	if soul_effect.is_empty():
		return 0.0
	return _soul_stacks * _scaled(soul_effect, "value1", "scale_value1")


func on_player_damaged(_amount: float) -> void:
	if _soul_stacks <= 0:
		return
	var soul_effect: Dictionary = {}
	for effect in _active_cast_passives:
		if effect.get("effect_name", "") == "soulrequiem":
			soul_effect = effect
			break
	print("[Soul] on_player_damaged — stacks: %d | has effect: %s" % [
			_soul_stacks,
			str(not soul_effect.is_empty())
	])
	if soul_effect.is_empty():
		return

	var radius: float = _scaled(soul_effect, "value3", "scale_value3")
	if radius <= 0.0:
		radius = 200.0
	print("[Soul] effect tier: %d | raw value1: %s | raw scale_value1: %s" % [
			soul_effect.get("tier", -1),
			str(soul_effect.get("value1", "MISSING")),
			str(soul_effect.get("scale_value1", "MISSING"))
	])
	# value1 is the per-stack amp (e.g. 0.04 at tier 10)
	# AoE base damage = player's active spell item_base_dmg
	# multiplied by soul stack count and the amp value
	var amp_per_stack: float = _scaled(soul_effect, "value1", "scale_value1")
	var base_dmg: float = 10.0
	var caster = get_tree().get_first_node_in_group("spell_casters")
	if caster != null and is_instance_valid(caster) and _has_property(caster, "item_base_dmg"):
		base_dmg = float(caster.get("item_base_dmg"))
	var school_mult: float = 1.0
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv != null and inv.has_method("get_school_multiplier"):
		school_mult = inv.get_school_multiplier("dark")
	if inv != null:
		print("[Soul] dark tier: %d | school_mult: %.4f" % [
				inv.get_school_tier("dark"),
				inv.get_school_multiplier("dark")
		])
	var total_dmg: float = base_dmg * school_mult * amp_per_stack * float(_soul_stacks) * 10.0
	print("[Soul] requiem vars — base_dmg: %.2f | school_mult: %.4f | amp_per_stack: %.4f | stacks: %d | multiplier: 10.0 | total: %.2f" % [
			base_dmg, school_mult, amp_per_stack, _soul_stacks, total_dmg])
	_soul_stacks = 0

	if _player == null or not is_instance_valid(_player):
		return
	var aoe_pos: Vector2 = _player.global_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(aoe_pos) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(total_dmg, "dark")

	var marker := Node2D.new()
	var ring := Line2D.new()
	ring.default_color = Color(0.4, 0.0, 0.8, 0.8)
	ring.width = 4.0
	for i in range(33):
		var angle := TAU * float(i) / 32.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
	marker.add_child(ring)
	marker.global_position = aoe_pos
	get_tree().current_scene.add_child(marker)
	var tween := marker.create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.tween_callback(marker.queue_free)


func on_enemy_killed() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var prog := get_node_or_null("/root/ProgressionManager")
	if prog != null and prog.has_method("is_dead") and prog.is_dead():
		return

	# killfuel — deduped per physics frame
	var current_frame := Engine.get_physics_frames()
	if current_frame != _killfuel_last_physics_frame:
		_killfuel_last_physics_frame = current_frame
		var killfuel_effect: Dictionary = {}
		for effect in _active_passives:
			if effect.get("effect_name", "") == "killfuel":
				killfuel_effect = effect
				break
		if not killfuel_effect.is_empty():
			var cd_cut: float = _scaled(killfuel_effect, "value1", "scale_value1")
			if cd_cut > 0.0:
				for caster in get_tree().get_nodes_in_group("spell_casters"):
					if is_instance_valid(caster) and caster.has_method("apply_cd_reduction_instant"):
						caster.apply_cd_reduction_instant(cd_cut)

	# soulrequiem — NOT deduped, every kill counts
	var soul_effect: Dictionary = {}
	for effect in _active_cast_passives:
		if effect.get("effect_name", "") == "soulrequiem":
			soul_effect = effect
			break
	if not soul_effect.is_empty():
		var soul_max_raw: int = roundi(_scaled(soul_effect, "value2", "scale_value2"))
		_soul_max = maxi(soul_max_raw, 1)
		if _soul_stacks < _soul_max:
			_soul_stacks += 1
		print("[Soul] on_enemy_killed — stacks: %d / %d" % [_soul_stacks, _soul_max])


func get_overheat_effect() -> Dictionary:
	for effect in _active_passives:
		if effect.get("effect_name", "") == "overheat":
			return effect
	return {}


func get_bloodpower_amp() -> float:
	var effect: Dictionary = {}
	for e in _active_cast_passives:
		if e.get("effect_name", "") == "bloodpower":
			effect = e
			break
	if effect.is_empty():
		return 0.0
	var pm := get_node_or_null("/root/ProgressionManager")
	if pm == null:
		return 0.0
	var current_hp: float = 0.0
	var max_hp: float = 100.0
	if _has_property(pm, "current_hp"):
		current_hp = float(pm.get("current_hp"))
	elif pm.has_method("get_current_hp"):
		current_hp = float(pm.call("get_current_hp"))
	if _has_property(pm, "max_hp"):
		max_hp = float(pm.get("max_hp"))
	elif pm.has_method("get_max_hp"):
		max_hp = float(pm.call("get_max_hp"))
	if max_hp <= 0.0:
		return 0.0
	var hp_pct: float = current_hp / max_hp
	var threshold_high: float = _scaled(effect, "value1", "scale_value1")
	var threshold_low: float = _scaled(effect, "value2", "scale_value2")
	var amp_medium: float = _scaled(effect, "value3", "scale_value3")
	var amp_low: float = _scaled(effect, "value4", "scale_value4")
	if hp_pct < threshold_low:
		return amp_low
	elif hp_pct < threshold_high:
		return amp_medium
	return 0.0


func get_soulsiphon_leech(target_element: String = "") -> float:
	for effect in _active_cast_passives:
		if effect.get("effect_name", "") == "soulsiphon":
			var base_leech: float = _scaled(effect, "value1", "scale_value1")
			if target_element.to_lower() == "holy":
				var holy_bonus: float = _scaled(effect, "value2", "scale_value2")
				print("[Siphon] holy target — base: %.4f | bonus: %.4f | total: %.4f" % [base_leech, holy_bonus, base_leech + holy_bonus])
				return base_leech + holy_bonus
			return base_leech
	return 0.0
