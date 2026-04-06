extends CanvasLayer

@onready var life_1: ColorRect = $MarginContainer/VBoxContainer/HBoxContainer/Life1
@onready var life_2: ColorRect = $MarginContainer/VBoxContainer/HBoxContainer/Life2
@onready var life_3: ColorRect = $MarginContainer/VBoxContainer/HBoxContainer/Life3
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPRow/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPRow/HPLabel

var life_icons: Array[ColorRect]


func _ready() -> void:
	life_icons = [life_1, life_2, life_3]

	var progression_manager := _get_progression_manager()
	if progression_manager != null:
		progression_manager.life_lost.connect(_on_life_lost)
		progression_manager.hp_changed.connect(_on_hp_changed)
		_update_lives(progression_manager.lives)
		_update_hp(progression_manager.current_hp, progression_manager.max_hp)


func _on_life_lost(lives_remaining: int) -> void:
	_update_lives(lives_remaining)


func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	_update_hp(current_hp, max_hp)


func _update_lives(lives_remaining: int) -> void:
	for index in life_icons.size():
		var icon := life_icons[index]
		var is_active := index < lives_remaining
		icon.color = Color(0.94, 0.2, 0.35, 1.0) if is_active else Color(0.28, 0.23, 0.26, 0.65)


func _update_hp(current_hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "%d / %d" % [int(current_hp), int(max_hp)]


func _get_progression_manager() -> Node:
	return get_node_or_null("/root/ProgressionManager")
