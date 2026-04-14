extends CanvasLayer

signal menu_button_pressed

@onready var strip_panel: ColorRect = $StripPanel
@onready var active_page_label: Label = $StripPanel/ActivePageLabel
@onready var spell_cd_label: Label = $StripPanel/SpellCDLabel
@onready var summon_label: Label = $StripPanel/SummonLabel

const STRIP_HEIGHT := 384.0
const SCREEN_WIDTH := 1080.0
const SCREEN_HEIGHT := 1920.0
const BUFF_COLOURS := {
	"fire": Color(0.88, 0.31, 0.19),
	"ice": Color(0.38, 0.82, 0.94),
	"earth": Color(0.75, 0.50, 0.25),
	"thunder": Color(0.94, 0.89, 0.13),
	"water": Color(0.25, 0.50, 0.88),
	"holy": Color(0.95, 0.95, 0.85),
	"dark": Color(0.56, 0.25, 0.75)
}
const DEBUFF_FLASH_COLOURS := {
	"burn":    Color(1.0,  0.35, 0.0,  1.0),
	"burndot": Color(1.0,  0.35, 0.0,  1.0),
	"wet":     Color(0.05, 0.15, 0.6,  1.0),
	"chilled": Color(0.45, 0.85, 1.0,  1.0),
	"chill":   Color(0.45, 0.85, 1.0,  1.0),
	"slow":    Color(0.45, 0.85, 1.0,  1.0),
	"blind":   Color(0.95, 0.95, 0.95, 1.0),
	"corrupt": Color(0.55, 0.0,  0.8,  1.0),
	"stagger": Color(0.9,  0.7,  0.1,  1.0),
	"brittle": Color(0.6,  0.9,  1.0,  1.0),
}

var _hp_bar: ProgressBar
var _hp_label: Label
var _buff_row: HBoxContainer = null
var _summon_hp_bar: ProgressBar
var _summon_recharge_label: Label
var _school_tier_labels: Dictionary = {}
var _life_rects: Array[ColorRect] = []
var _action_buttons: Array[ColorRect] = []
var _menu_btn_cooldown: float = 0.0
var _buff_refresh_timer: float = 0.0
var _menu_button_screen_rect: Rect2 = Rect2()
var _boss_bar_container: Control
var _slot_cd_labels: Array[Label] = []
var _slot_cd_bars: Array[ColorRect] = []
var _slot_cd_bar_bgs: Array[ColorRect] = []
var _soul_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	strip_panel.size = Vector2(SCREEN_WIDTH, STRIP_HEIGHT)
	strip_panel.position = Vector2(0, SCREEN_HEIGHT - STRIP_HEIGHT)
	strip_panel.color = Color(0.05, 0.05, 0.1, 0.85)

	_build_hp_row()
	_build_summon_status()
	_build_mana_display()
	_build_action_buttons()
	_build_boss_bar()

	active_page_label.position = Vector2(SCREEN_WIDTH / 2.0 - 150.0, 80.0)
	active_page_label.size = Vector2(300.0, 50.0)
	active_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_page_label.add_theme_font_size_override("font_size", 28)

	spell_cd_label.position = Vector2(SCREEN_WIDTH / 2.0 - 150.0, 130.0)
	spell_cd_label.size = Vector2(300.0, 40.0)
	spell_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spell_cd_label.add_theme_font_size_override("font_size", 22)

	summon_label.position = Vector2(SCREEN_WIDTH / 2.0 - 150.0, 178.0)
	summon_label.size = Vector2(300.0, 40.0)
	summon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summon_label.add_theme_font_size_override("font_size", 22)

	var tm = get_node_or_null("/root/TomeManager")
	if tm != null and tm.has_signal("page_flipped"):
		tm.page_flipped.connect(_on_page_flipped)

	var pm = get_node_or_null("/root/ProgressionManager")
	if pm != null:
		if pm.has_signal("hp_changed"):
			pm.hp_changed.connect(_on_hp_changed)
		if pm.has_signal("lives_changed"):
			pm.lives_changed.connect(_on_lives_changed)
		elif pm.has_signal("life_lost"):
			pm.life_lost.connect(_on_lives_changed)

		if pm.has_method("get_current_hp") and pm.has_method("get_max_hp"):
			update_hp(pm.get_current_hp(), pm.get_max_hp())
		elif "current_hp" in pm and "max_hp" in pm:
			update_hp(float(pm.current_hp), float(pm.max_hp))

		if pm.has_method("get_lives"):
			update_lives(pm.get_lives())
		elif "lives" in pm:
			update_lives(int(pm.lives))

	var sm = get_node_or_null("/root/SummonManager")
	if sm:
		sm.summon_hp_changed.connect(_on_summon_hp_changed)
		sm.summon_recharge_tick.connect(_on_summon_recharge_tick)

	_refresh_all()
	_refresh_buffs()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null:
		hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud != null:
		var margin = hud.get_node_or_null("MarginContainer")
		if margin != null:
			margin.visible = false
	_build_slot_cd_row()


func _build_hp_row() -> void:
	_hp_bar = ProgressBar.new()
	_hp_bar.position = Vector2(40.0, 12.0)
	_hp_bar.size = Vector2(600.0, 28.0)
	_hp_bar.show_percentage = false
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	strip_panel.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.position = Vector2(648.0, 12.0)
	_hp_label.size = Vector2(120.0, 28.0)
	_hp_label.text = "100 / 100"
	_hp_label.add_theme_font_size_override("font_size", 22)
	strip_panel.add_child(_hp_label)

	_buff_row = HBoxContainer.new()
	_buff_row.name = "BuffRow"
	_buff_row.position = Vector2(10.0, 44.0)
	_buff_row.size = Vector2(SCREEN_WIDTH - 20.0, 36.0)
	_buff_row.add_theme_constant_override("separation", 8)
	strip_panel.add_child(_buff_row)

	_soul_label = Label.new()
	_soul_label.name = "SoulLabel"
	_soul_label.position = Vector2(10.0, 82.0)
	_soul_label.size = Vector2(500.0, 28.0)
	_soul_label.add_theme_font_size_override("font_size", 20)
	_soul_label.add_theme_color_override("font_color", Color(0.56, 0.25, 0.75))
	_soul_label.visible = false
	strip_panel.add_child(_soul_label)

	for i in range(3):
		var life_rect: ColorRect = ColorRect.new()
		life_rect.position = Vector2(800.0 + 36.0 * i, 16.0)
		life_rect.size = Vector2(28.0, 28.0)
		life_rect.color = Color(0.9, 0.2, 0.3)
		strip_panel.add_child(life_rect)
		_life_rects.append(life_rect)


func _build_summon_status() -> void:
	_summon_hp_bar = ProgressBar.new()
	_summon_hp_bar.position = Vector2(140.0, 212.0)
	_summon_hp_bar.size = Vector2(800.0, 28.0)
	_summon_hp_bar.show_percentage = false
	_summon_hp_bar.min_value = 0.0
	_summon_hp_bar.max_value = 100.0
	_summon_hp_bar.value = 100.0
	_summon_hp_bar.visible = false
	strip_panel.add_child(_summon_hp_bar)

	_summon_recharge_label = Label.new()
	_summon_recharge_label.position = Vector2(140.0, 212.0)
	_summon_recharge_label.size = Vector2(800.0, 28.0)
	_summon_recharge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summon_recharge_label.add_theme_font_size_override("font_size", 28)
	_summon_recharge_label.visible = false
	strip_panel.add_child(_summon_recharge_label)


func _build_mana_display() -> void:
	var schools := [
		{"name": "fire", "color": Color(1.0, 0.2, 0.2)},
		{"name": "ice", "color": Color(0.4, 0.8, 1.0)},
		{"name": "earth", "color": Color(0.6, 0.3, 0.1)},
		{"name": "water", "color": Color(0.0, 0.2, 0.8)},
		{"name": "thunder", "color": Color(1.0, 1.0, 0.0)},
		{"name": "holy", "color": Color(1.0, 1.0, 1.0)},
		{"name": "dark", "color": Color(0.5, 0.0, 0.8)},
	]
	var column_width := SCREEN_WIDTH / float(schools.size())

	for i in range(schools.size()):
		var school_data: Dictionary = schools[i]
		var center_x := column_width * (i + 0.5)

		var swatch := ColorRect.new()
		swatch.size = Vector2(28.0, 28.0)
		swatch.position = Vector2(center_x - 14.0, 256.0)
		swatch.color = school_data["color"]
		strip_panel.add_child(swatch)

		var tier_label := Label.new()
		tier_label.position = Vector2(center_x - 20.0, 288.0)
		tier_label.size = Vector2(40.0, 24.0)
		tier_label.text = "M0"
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.add_theme_font_size_override("font_size", 20)
		strip_panel.add_child(tier_label)

		_school_tier_labels[school_data["name"]] = tier_label

	var mana_label := Label.new()
	mana_label.name = "ManaPoolLabel"
	mana_label.position = Vector2(0.0, 320.0)
	mana_label.size = Vector2(SCREEN_WIDTH, 28.0)
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label.add_theme_font_size_override("font_size", 22)
	mana_label.text = "Mana: 0  |  Free: 0"
	strip_panel.add_child(mana_label)


func _build_action_buttons() -> void:
	var button_layer: Control = Control.new()
	button_layer.name = "ActionButtonLayer"
	button_layer.position = Vector2(0.0, 1400.0)
	button_layer.size = Vector2(1080.0, 192.0)
	add_child(button_layer)
	button_layer.mouse_filter = Control.MOUSE_FILTER_PASS

	var button_xs: Array[float] = [20.0, 284.0, 548.0, 812.0]
	for button_x in button_xs:
		var button_rect: ColorRect = ColorRect.new()
		button_rect.position = Vector2(button_x, 60.0)
		button_rect.size = Vector2(248.0, 72.0)
		button_rect.color = Color(0.15, 0.15, 0.25, 0.9)

		var button_label: Label = Label.new()
		button_label.position = Vector2(0.0, 0.0)
		button_label.size = button_rect.size
		button_label.text = "—"
		button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button_label.add_theme_font_size_override("font_size", 26)
		button_rect.add_child(button_label)

		button_layer.add_child(button_rect)
		_action_buttons.append(button_rect)

	# Store menu button screen rect for input checking
	if _action_buttons.size() > 0:
		var menu_btn_rect: ColorRect = _action_buttons[0]
		var menu_lbl: Label = menu_btn_rect.get_child(0)
		menu_lbl.text = "Menu"
		# button_layer is at y=1400, button_rect is at x=20, y=60, size 248x72
		# Rect will be calculated dynamically in _input using node position
		_menu_button_screen_rect = Rect2(20.0, 1460.0, 248.0, 72.0)


func _build_boss_bar() -> void:
	_boss_bar_container = Control.new()
	_boss_bar_container.name = "BossBarContainer"
	_boss_bar_container.position = Vector2.ZERO
	_boss_bar_container.size = Vector2(1080.0, 60.0)
	_boss_bar_container.visible = false
	add_child(_boss_bar_container)

	var boss_background: ColorRect = ColorRect.new()
	boss_background.position = Vector2.ZERO
	boss_background.size = Vector2(1080.0, 60.0)
	boss_background.color = Color(0.05, 0.05, 0.1, 0.85)
	_boss_bar_container.add_child(boss_background)

	var boss_hp_bar: ProgressBar = ProgressBar.new()
	boss_hp_bar.name = "BossHPBar"
	boss_hp_bar.position = Vector2(140.0, 10.0)
	boss_hp_bar.size = Vector2(800.0, 24.0)
	boss_hp_bar.show_percentage = false
	_boss_bar_container.add_child(boss_hp_bar)

	var boss_name_label: Label = Label.new()
	boss_name_label.name = "BossNameLabel"
	boss_name_label.position = Vector2(0.0, 36.0)
	boss_name_label.size = Vector2(1080.0, 30.0)
	boss_name_label.text = "— BOSS —"
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 20)
	_boss_bar_container.add_child(boss_name_label)


func _build_slot_cd_row() -> void:
	# Hide the original single spell_cd_label — replaced by the 4-slot row
	spell_cd_label.visible = false

	var slot_width: float = SCREEN_WIDTH / 4.0
	for i in range(4):
		var cx: float = slot_width * (i + 0.5)

		# Background bar
		var bg := ColorRect.new()
		bg.size = Vector2(slot_width - 20.0, 6.0)
		bg.position = Vector2(slot_width * i + 10.0, 158.0)
		bg.color = Color(0.1, 0.1, 0.1, 0.6)
		strip_panel.add_child(bg)
		_slot_cd_bar_bgs.append(bg)

		# Fill bar
		var bar := ColorRect.new()
		bar.size = Vector2(0.0, 6.0)
		bar.position = Vector2(slot_width * i + 10.0, 158.0)
		bar.color = Color(0.2, 0.8, 1.0, 0.85)
		strip_panel.add_child(bar)
		_slot_cd_bars.append(bar)

		# Label
		var lbl := Label.new()
		lbl.position = Vector2(cx - 60.0, 130.0)
		lbl.size = Vector2(120.0, 28.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.text = "S%d —" % (i + 1)
		strip_panel.add_child(lbl)
		_slot_cd_labels.append(lbl)


func _process(delta: float) -> void:
	if _menu_btn_cooldown > 0.0:
		_menu_btn_cooldown -= delta
	_buff_refresh_timer += delta
	if _buff_refresh_timer >= 0.5:
		_buff_refresh_timer = 0.0
		_refresh_buffs()
	_refresh_spell_cd()
	_refresh_summon()
	update_mana_display()


func _refresh_buffs() -> void:
	if _buff_row == null or not is_instance_valid(_buff_row):
		return
	for child in _buff_row.get_children():
		child.queue_free()

	var pm := get_node_or_null("/root/PassiveManager")
	if pm == null:
		return
	var passives: Array = pm._active_passives

	var seen: Dictionary = {}
	for effect in passives:
		if not effect is Dictionary:
			continue
		var effect_dict := effect as Dictionary
		var effect_name: String = str(effect_dict.get("effect_name", ""))
		if effect_name == "" or seen.has(effect_name):
			continue

		if effect_name == "iceshield":
			if not pm.is_iceshield_active():
				continue
		if effect_name == "flowstate":
			if not pm.get("_flowstate_active"):
				continue
		if effect_name == "overheat":
			var player_node := get_tree().get_first_node_in_group("player")
			if player_node != null:
				var oh_ready := false
				for child in player_node.get_children():
					if child.has_method("refresh_spell"):
						var ready_val = child.get("_overheat_ready")
						if ready_val is bool and ready_val == true:
							oh_ready = true
							break
				if not oh_ready:
					continue
		# rootedpower, bloodpower etc. can add state checks here when implemented.

		seen[effect_name] = true

		var element: String = str(effect_dict.get("element", "")).to_lower()
		var badge_colour: Color = BUFF_COLOURS.get(element, Color(0.7, 0.7, 0.7))
		var is_debuff: bool = DEBUFF_FLASH_COLOURS.has(effect_name)
		var flash_colour: Color = DEBUFF_FLASH_COLOURS.get(effect_name, badge_colour)

		var wrapper := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(flash_colour.r, flash_colour.g, flash_colour.b, 0.2) if is_debuff else Color(badge_colour.r, badge_colour.g, badge_colour.b, 0.2)
		style.set_corner_radius_all(4)
		style.border_color = flash_colour if is_debuff else badge_colour
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		wrapper.add_theme_stylebox_override("panel", style)

		var lbl := Label.new()
		lbl.text = effect_name.replace("_", " ").capitalize()
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", flash_colour if is_debuff else badge_colour)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		wrapper.add_child(lbl)

		_buff_row.add_child(wrapper)

		# Flash tween for debuffs only
		if is_debuff:
			var tween := wrapper.create_tween()
			tween.set_loops()
			tween.tween_property(wrapper, "modulate:a", 0.25, 0.35)
			tween.tween_property(wrapper, "modulate:a", 1.0,  0.35)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(10, 0)
		_buff_row.add_child(spacer)

	if _soul_label != null and is_instance_valid(_soul_label):
		var stacks: int = int(pm.get("_soul_stacks") if pm.get("_soul_stacks") != null else 0)
		if stacks > 0:
			_soul_label.text = "Soul: %d (AoE: %.0f)" % [stacks, _get_soul_aoe_dmg(pm)]
			_soul_label.visible = true
		else:
			_soul_label.visible = false


func _get_soul_aoe_dmg(pm: Node) -> float:
	var cast_passives = pm.get("_active_cast_passives")
	if cast_passives == null:
		return 0.0
	for effect in cast_passives:
		if effect.get("effect_name", "") == "soulrequiem":
			var tier: int = effect.get("tier", 0)
			var base: float = float(str(effect.get("value1", 0.0)))
			var scale_v: float = float(str(effect.get("scale_value1", 0.0)))
			var dmg_per_stack: float = base + scale_v * float(tier)
			return dmg_per_stack * float(pm._soul_stacks) * 5.0
	return 0.0


func _refresh_all() -> void:
	_refresh_page()
	_refresh_spell_cd()
	_refresh_summon()


func _refresh_page() -> void:
	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return
	var page = tm.get_active_page()
	if page != null:
		active_page_label.text = "▶ " + page.page_name
	else:
		active_page_label.text = "▶ —"


func _refresh_spell_cd() -> void:
	if _slot_cd_labels.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		for i in range(4):
			_slot_cd_labels[i].text = "S%d —" % (i + 1)
			_slot_cd_bars[i].size.x = 0.0
		return

	var casters: Array = []
	for child in player.get_children():
		if child.has_method("refresh_spell"):
			casters.append(child)

	for i in range(4):
		var lbl: Label = _slot_cd_labels[i]
		var bar: ColorRect = _slot_cd_bars[i]
		var bg: ColorRect = _slot_cd_bar_bgs[i]
		var max_width: float = bg.size.x

		if i >= casters.size():
			lbl.text = "S%d —" % (i + 1)
			bar.size.x = 0.0
			continue

		var caster = casters[i]
		var sd = caster.get("spell_data")
		if sd == null:
			lbl.text = "S%d —" % (i + 1)
			bar.size.x = 0.0
			continue

		var el: String = str(caster.get("elemental_element") if caster.get("elemental_element") != null else "")
		var delivery: String = str(caster.get("delivery_type") if caster.get("delivery_type") != null else "")

		var timer: Timer = caster.get_node_or_null("CooldownTimer")
		if timer == null or delivery == "utility":
			lbl.text = "S%d —" % (i + 1)
			bar.size.x = 0.0
			continue

		var remaining: float = timer.time_left
		var full_cd: float = maxf(float(sd.get("cooldown") if "cooldown" in sd else 2.0), 1.5)
		var cd_reduction: float = float(caster.get("_cd_reduction") if caster.get("_cd_reduction") != null else 0.0)
		full_cd = maxf(full_cd - cd_reduction, 1.5)
		var pct: float = clampf(1.0 - (remaining / full_cd), 0.0, 1.0)

		if remaining <= 0.05:
			lbl.text = "S%d RDY" % (i + 1)
			lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			bar.size.x = max_width
			bar.color = Color(0.3, 1.0, 0.4, 0.85)
		else:
			lbl.text = "S%d %.1f" % [i + 1, remaining]
			lbl.add_theme_color_override("font_color", Color.WHITE)
			bar.size.x = max_width * pct
			if pct < 0.5:
				bar.color = Color(1.0, pct * 2.0, 0.0, 0.85)
			else:
				bar.color = Color(1.0 - (pct - 0.5) * 2.0, 1.0, 0.0, 0.85)


func _refresh_summon() -> void:
	var sm = get_node_or_null("/root/SummonManager")
	if sm == null:
		summon_label.text = ""
		return
	if sm.has_method("is_recharged") and not sm.is_recharged():
		var remaining: float = 0.0
		if sm.has_method("get_recharge_remaining"):
			remaining = float(sm.get_recharge_remaining())
		summon_label.text = "Summon: %.0fs" % remaining
	else:
		summon_label.text = "Summon: Ready"


func update_hp(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "%d / %d" % [int(current), int(maximum)]


func update_lives(count: int) -> void:
	for i in range(_life_rects.size()):
		_life_rects[i].visible = i < count


func update_mana_display() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null:
		return
	for school in _school_tier_labels:
		var tier: int = int(inv.get_school_tier(school))
		_school_tier_labels[school].text = "M%d" % tier
	var mana_label := strip_panel.get_node_or_null("ManaPoolLabel")
	if mana_label != null:
		mana_label.text = "Mana: %d  |  Free: %d" % [inv.mana_pool, inv.unallocated_mana]


func _show_summon_active(current: float, maximum: float) -> void:
	_summon_hp_bar.visible = true
	_summon_recharge_label.visible = false
	_summon_hp_bar.max_value = maximum
	_summon_hp_bar.value = current


func _show_summon_recharging(seconds: float) -> void:
	if seconds <= 0.0:
		_summon_hp_bar.visible = false
		_summon_recharge_label.visible = false
		return
	_summon_hp_bar.visible = false
	_summon_recharge_label.visible = true
	_summon_recharge_label.text = "Recharging: %ds" % int(seconds)


func _on_hp_changed(current: float, maximum: float) -> void:
	update_hp(current, maximum)


func _on_lives_changed(count: int) -> void:
	update_lives(count)


func _on_page_flipped(_index: int) -> void:
	_refresh_page()


func _on_summon_hp_changed(current: float, maximum: float) -> void:
	_show_summon_active(current, maximum)


func _on_summon_recharge_tick(seconds: float) -> void:
	_show_summon_recharging(seconds)


func _input(event: InputEvent) -> void:
	if _menu_btn_cooldown > 0.0:
		return
	# Recalculate menu rect dynamically accounting for viewport scale
	var vp := get_viewport()
	var vp_size := vp.get_visible_rect().size
	var scale_x := vp_size.x / 1080.0
	var scale_y := vp_size.y / 1920.0
	var dynamic_rect := Rect2(
		20.0 * scale_x,
		1460.0 * scale_y,
		248.0 * scale_x,
		72.0 * scale_y
	)
	var fired := false
	if event is InputEventScreenTouch and event.pressed:
		if dynamic_rect.has_point(event.position):
			fired = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dynamic_rect.has_point(event.position):
			fired = true
	elif event.is_action_pressed("ui_cancel"):
		fired = true
	if fired:
		_menu_btn_cooldown = 0.3
		emit_signal("menu_button_pressed")
		get_viewport().set_input_as_handled()
