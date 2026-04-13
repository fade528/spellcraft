extends CharacterBody2D

@export var move_speed: float = 300.0
@export var iframe_duration: float = 1.5

const SCREEN_SIZE := Vector2(1080.0, 1920.0)
const TOUCHPAD_RADIUS := 110.0
const TOUCHPAD_DEADZONE := 12.0
const TOUCHPAD_ZONE_RATIO := 0.65
const RESPAWN_POSITION := Vector2(540.0, 1200.0)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var facing_marker: Polygon2D = $FacingMarker
@onready var hurtbox: Area2D = $Hurtbox
@onready var touchpad_base: ColorRect = $TouchpadLayer/TouchpadBase
@onready var touchpad_knob: ColorRect = $TouchpadLayer/TouchpadKnob
@onready var iframe_timer: Timer = $IframeTimer

var move_input := Vector2.ZERO
var active_touch_index := -1
var touchpad_center := Vector2.ZERO
var clamp_margin := Vector2(48.0, 48.0)
var facing_rotation := 0.0
var is_invincible := false
var iframe_tween: Tween
var speed_bonus: float = 0.0
var _heal_flash_tween: Tween = null


func _ready() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	position = RESPAWN_POSITION
	set_collision_mask_value(2, false)
	_configure_touchpad()
	_update_clamp_margin()
	_apply_facing_rotation()
	_set_touchpad_visible(false)
	iframe_timer.timeout.connect(_on_iframe_timer_timeout)
	var sm = get_node_or_null("/root/SummonManager")
	if sm:
		sm.initialize(self)
		var summon_element: String = "fire"
		var tm = get_node_or_null("/root/TomeManager")
		if tm != null and tm.has_method("get_active_page"):
			var active_page = tm.get_active_page()
			if active_page != null and "summon_element" in active_page:
				summon_element = String(active_page.summon_element)
		sm.spawn_summon(summon_element)

	var slot1_caster: Node = null
	for child in get_children():
		if child.has_method("refresh_spell"):
			slot1_caster = child
			break

	var caster_script := load("res://scripts/spell_caster.gd")
	for slot_idx in range(1, 4):
		var caster := Node2D.new()
		caster.set_script(caster_script)
		caster.name = "SpellCaster%d" % (slot_idx + 1)
		add_child(caster)
		caster.call("set_stagger_delay", float(slot_idx) * 1.0)

	var tm3 = get_node_or_null("/root/TomeManager")
	if tm3 != null and tm3.has_signal("page_changed"):
		if not tm3.page_changed.is_connected(_refresh_all_casters):
			tm3.page_changed.connect(_refresh_all_casters)

	call_deferred("_refresh_all_casters")


func _refresh_all_casters() -> void:
	var tm := get_node_or_null("/root/TomeManager")
	if tm == null:
		return
	var page = tm.get_active_page()
	if page == null:
		return
	page.ensure_slots(4)

	# First pass: refresh all casters with their spell data
	var slot_idx := 0
	for child in get_children():
		if not child.has_method("refresh_spell"):
			continue
		if slot_idx >= 4:
			break
		var slot: Dictionary = {}
		if slot_idx < page.slots.size():
			var raw = page.slots[slot_idx]
			if raw is Dictionary:
				slot = raw
		child.refresh_spell(
			str(slot.get("elemental", "fire")),
			str(slot.get("empowerment", "fire")),
			str(slot.get("enchantment", "fire")),
			str(slot.get("delivery", "bolt")),
			str(slot.get("target", "enemy"))
		)
		slot_idx += 1

	# Second pass: collect only casters that will actively fire
	# Excludes: empty elemental, utility delivery, stop-cast slots (holy/dark)
	var spell_composer := get_node_or_null("/root/SpellComposer")
	var active_casters: Array = []
	for child in get_children():
		if not child.has_method("refresh_spell"):
			continue
		var el: String = str(child.get("elemental_element") if child.get("elemental_element") != null else "")
		var delivery: String = str(child.get("delivery_type") if child.get("delivery_type") != null else "")
		if el == "" or el == "-":
			continue
		if delivery == "" or delivery == "-" or delivery == "utility":
			continue
		if spell_composer != null and spell_composer.has_method("is_stop_cast"):
			if spell_composer.is_stop_cast(el):
				continue
		active_casters.append(child)

	# Third pass: distribute stagger evenly across active casters
	var count := active_casters.size()
	if count == 0:
		return

	# Find the shortest cooldown among active casters to use as the interval basis
	var min_cd: float = 99.0
	for caster in active_casters:
		var sd = caster.get("spell_data")
		if sd != null and sd.has_method("get") == false:
			var cd: float = float(sd.get("cooldown") if "cooldown" in sd else 99.0)
			if cd < min_cd:
				min_cd = cd
	# Fallback if spell_data not yet composed
	if min_cd >= 99.0:
		min_cd = 2.0

	var interval: float = min_cd / float(count)
	interval = maxf(interval, 0.5)

	for i in range(count):
		var caster = active_casters[i]
		if caster.has_method("set_stagger_delay"):
			caster.call("set_stagger_delay", float(i) * interval)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _physics_process(_delta: float) -> void:
	var effective_speed := move_speed * (1.0 + speed_bonus)
	velocity = move_input * effective_speed
	move_and_slide()
	var currently_moving := move_input.length() > 0.05
	for child in get_children():
		if child.has_method("set_moving"):
			child.set_moving(currently_moving)
	var vp := get_viewport().get_visible_rect().size
	position = position.clamp(
		clamp_margin,
		Vector2(vp.x - clamp_margin.x, vp.y * 0.78 - clamp_margin.y)
	)

	if move_input != Vector2.ZERO:
		_update_facing(move_input)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if active_touch_index == -1 and event.position.y >= get_viewport().get_visible_rect().size.y * 0.80 and event.position.x > get_viewport().get_visible_rect().size.x * 0.10 and event.position.x < get_viewport().get_visible_rect().size.x * 0.90:
			active_touch_index = event.index
			touchpad_center = event.position
			_update_touchpad(event.position)
			_set_touchpad_visible(true)
		return

	if event.index == active_touch_index:
		active_touch_index = -1
		move_input = Vector2.ZERO
		velocity = Vector2.ZERO
		_set_touchpad_visible(false)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != active_touch_index:
		return

	_update_touchpad(event.position)


func _update_touchpad(screen_position: Vector2) -> void:
	var drag_vector := screen_position - touchpad_center
	var clamped_vector := drag_vector.limit_length(TOUCHPAD_RADIUS)

	touchpad_base.position = touchpad_center - touchpad_base.size * 0.5
	touchpad_knob.position = touchpad_center + clamped_vector - touchpad_knob.size * 0.5

	if clamped_vector.length() <= TOUCHPAD_DEADZONE:
		move_input = Vector2.ZERO
		return

	move_input = clamped_vector / TOUCHPAD_RADIUS


func _update_facing(direction: Vector2) -> void:
	var snapped_angle: float = round(direction.angle() / (PI / 4.0)) * (PI / 4.0)
	facing_rotation = snapped_angle + PI / 2.0
	_apply_facing_rotation()


func _apply_facing_rotation() -> void:
	player_sprite.rotation = facing_rotation
	facing_marker.rotation = facing_rotation


func _configure_touchpad() -> void:
	touchpad_base.size = Vector2(220.0, 220.0)
	touchpad_knob.size = Vector2(96.0, 96.0)
	touchpad_base.color = Color(1.0, 1.0, 1.0, 0.16)
	touchpad_knob.color = Color(0.45, 0.85, 1.0, 0.7)


func _update_clamp_margin() -> void:
	var shape := collision_shape.shape

	if shape is CircleShape2D:
		var radius: float = shape.radius
		clamp_margin = Vector2(radius, radius)
	elif shape is RectangleShape2D:
		clamp_margin = shape.size * 0.5


func _set_touchpad_visible(is_visible: bool) -> void:
	touchpad_base.visible = is_visible
	touchpad_knob.visible = is_visible


func apply_speed_bonus(bonus: float) -> void:
	speed_bonus = bonus


func flash_heal() -> void:
	if _heal_flash_tween != null:
		_heal_flash_tween.kill()
	# Flash the whole player node so triangle + marker both show green
	modulate = Color(0.2, 1.0, 0.3, 1.0)
	_heal_flash_tween = create_tween()
	_heal_flash_tween.tween_property(self, "modulate", Color(0.2, 1.0, 0.3, 1.0), 0.12)
	_heal_flash_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)


func take_damage(amount: float, element: String = "") -> void:
	if is_invincible:
		return

	var pm = get_node_or_null("/root/PassiveManager")
	var effective: float = pm.get_effective_damage(amount, element) if pm != null else amount
	_start_iframes()
	var progression_manager := _get_progression_manager()
	if progression_manager != null:
		progression_manager.take_damage(effective)


func respawn() -> void:
	position = RESPAWN_POSITION
	velocity = Vector2.ZERO
	move_input = Vector2.ZERO
	active_touch_index = -1
	_set_touchpad_visible(false)


func _start_iframes() -> void:
	is_invincible = true
	iframe_timer.start(iframe_duration)
	_play_iframe_visual()


func _on_iframe_timer_timeout() -> void:
	is_invincible = false
	if iframe_tween != null:
		iframe_tween.kill()
		player_sprite.modulate.a = 1.0
		facing_marker.modulate.a = 1.0


func _play_iframe_visual() -> void:
	if iframe_tween != null:
		iframe_tween.kill()

	iframe_tween = create_tween()
	iframe_tween.set_loops()
	iframe_tween.tween_property(player_sprite, "modulate:a", 0.25, 0.12)
	iframe_tween.parallel().tween_property(facing_marker, "modulate:a", 0.25, 0.12)
	iframe_tween.tween_property(player_sprite, "modulate:a", 1.0, 0.12)
	iframe_tween.parallel().tween_property(facing_marker, "modulate:a", 1.0, 0.12)


func _get_progression_manager() -> Node:
	return get_node_or_null("/root/ProgressionManager")
