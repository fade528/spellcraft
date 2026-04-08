extends CanvasLayer

@onready var strip_panel: ColorRect = $StripPanel
@onready var active_page_label: Label = $StripPanel/ActivePageLabel
@onready var spell_cd_label: Label = $StripPanel/SpellCDLabel
@onready var summon_label: Label = $StripPanel/SummonLabel

const STRIP_HEIGHT := 384.0
const SCREEN_WIDTH := 1080.0
const SCREEN_HEIGHT := 1920.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	strip_panel.size = Vector2(SCREEN_WIDTH, STRIP_HEIGHT)
	strip_panel.position = Vector2(0, SCREEN_HEIGHT - STRIP_HEIGHT)
	strip_panel.color = Color(0.05, 0.05, 0.1, 0.85)

	active_page_label.position = Vector2(
		SCREEN_WIDTH / 2.0 - 150.0,
		STRIP_HEIGHT / 2.0 - 60.0
	)
	active_page_label.size = Vector2(300.0, 50.0)
	active_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_page_label.add_theme_font_size_override("font_size", 28)

	spell_cd_label.position = Vector2(
		SCREEN_WIDTH / 2.0 - 150.0,
		STRIP_HEIGHT / 2.0
	)
	spell_cd_label.size = Vector2(300.0, 40.0)
	spell_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spell_cd_label.add_theme_font_size_override("font_size", 22)

	summon_label.position = Vector2(
		SCREEN_WIDTH / 2.0 - 150.0,
		STRIP_HEIGHT / 2.0 + 48.0
	)
	summon_label.size = Vector2(300.0, 40.0)
	summon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summon_label.add_theme_font_size_override("font_size", 22)

	var tm = get_node_or_null("/root/TomeManager")
	if tm != null and tm.has_signal("page_flipped"):
		tm.page_flipped.connect(_on_page_flipped)

	_refresh_all()


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
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		spell_cd_label.text = ""
		return
	var casters := player.find_children("*", "Node2D", true, false)
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
			remaining = sm.get_recharge_remaining() as float
		summon_label.text = "Summon: %.0fs" % remaining
	else:
		summon_label.text = "Summon: Ready"


func _on_page_flipped(_index: int) -> void:
	_refresh_page()
