extends CanvasLayer

@onready var strip_panel: ColorRect = $StripPanel
@onready var active_page_label: Label = $StripPanel/ActivePageLabel
@onready var spell_cd_label: Label = $StripPanel/SpellCDLabel
@onready var summon_label: Label = $StripPanel/SummonLabel

const STRIP_HEIGHT := 384.0
const SCREEN_WIDTH := 1080.0
const SCREEN_HEIGHT := 1920.0

var _hp_bar: ProgressBar
var _hp_label: Label
var _life_rects: Array[ColorRect] = []
var _action_buttons: Array[ColorRect] = []
var _boss_bar_container: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	strip_panel.size = Vector2(SCREEN_WIDTH, STRIP_HEIGHT)
	strip_panel.position = Vector2(0, SCREEN_HEIGHT - STRIP_HEIGHT)
	strip_panel.color = Color(0.05, 0.05, 0.1, 0.85)

	_build_hp_row()
	_build_action_buttons()
	_build_boss_bar()

	active_page_label.position = Vector2(SCREEN_WIDTH / 2.0 - 150.0, 60.0)
	active_page_label.size = Vector2(300.0, 50.0)
	active_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_page_label.add_theme_font_size_override("font_size", 28)

	spell_cd_label.position = Vector2(SCREEN_WIDTH / 2.0 - 150.0, 112.0)
	spell_cd_label.size = Vector2(300.0, 40.0)
	spell_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spell_cd_label.add_theme_font_size_override("font_size", 22)

	summon_label.position = Vector2(SCREEN_WIDTH / 2.0 - 150.0, 160.0)
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

	_refresh_all()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null:
		hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud != null:
		var margin = hud.get_node_or_null("MarginContainer")
		if margin != null:
			margin.visible = false


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

	for i in range(3):
		var life_rect: ColorRect = ColorRect.new()
		life_rect.position = Vector2(800.0 + 36.0 * i, 16.0)
		life_rect.size = Vector2(28.0, 28.0)
		life_rect.color = Color(0.9, 0.2, 0.3)
		strip_panel.add_child(life_rect)
		_life_rects.append(life_rect)


func _build_action_buttons() -> void:
	var button_layer: Control = Control.new()
	button_layer.name = "ActionButtonLayer"
	button_layer.position = Vector2(0.0, 1400.0)
	button_layer.size = Vector2(1080.0, 192.0)
	add_child(button_layer)

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


func _process(_delta: float) -> void:
	_refresh_spell_cd()
	_refresh_summon()


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
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		spell_cd_label.text = ""
		return
	var casters = player.find_children("*", "Node2D", true, false)
	for child in casters:
		if child.has_method("refresh_spell") and child.get("spell_data") != null:
			var sd = child.get("spell_data")
			if sd != null:
				var timer = child.get_node_or_null("CooldownTimer")
				if timer != null:
					var remaining: float = (timer as Timer).time_left
					if remaining > 0.05:
						spell_cd_label.text = "CD: %.1fs" % remaining
					else:
						spell_cd_label.text = "CD: Ready"
					return
	spell_cd_label.text = ""


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


func _on_hp_changed(current: float, maximum: float) -> void:
	update_hp(current, maximum)


func _on_lives_changed(count: int) -> void:
	update_lives(count)


func _on_page_flipped(_index: int) -> void:
	_refresh_page()
