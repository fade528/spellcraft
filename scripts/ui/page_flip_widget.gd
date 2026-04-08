extends Control

const DRAG_DEAD_ZONE := 30.0
const EDGE_ZONE_PCT := 0.10
const STRIP_START_PCT := 0.80

enum Phase { IDLE, SELECTING }

const DIRECTIONS := [
	Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
	Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0),
	Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)
]

var _phase: Phase = Phase.IDLE
var _select_start: Vector2 = Vector2.ZERO
var _hovered_cell: int = -1
var _vp_size: Vector2 = Vector2.ZERO
var _entered_mid_zone: bool = false

@onready var flip_button: Button = $FlipButton
@onready var flip_grid: Control = $FlipGrid
@onready var grid_container: GridContainer = $FlipGrid/GridContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp_size = get_viewport().get_visible_rect().size
	flip_button.hide()
	flip_grid.hide()
	position = Vector2.ZERO
	size = _vp_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	flip_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_grid_cells()
	var tm = get_node_or_null("/root/TomeManager")
	if tm != null and tm.has_signal("page_flipped"):
		tm.page_flipped.connect(_on_page_flipped)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _is_in_edge_zone(event.position):
				return
			if _phase == Phase.IDLE:
				_on_gesture_start(event.position)
		else:
			if _phase == Phase.SELECTING:
				_on_gesture_release()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _is_in_edge_zone(event.position):
				return
			if _phase == Phase.IDLE:
				_on_gesture_start(event.position)
		else:
			if _phase == Phase.SELECTING:
				_on_gesture_release()
	elif event is InputEventScreenDrag:
		if _phase == Phase.SELECTING:
			_on_gesture_drag(event.position)
	elif event is InputEventMouseMotion:
		if _phase == Phase.SELECTING:
			_on_gesture_drag(event.position)
	else:
		return


func _is_in_edge_zone(pos: Vector2) -> bool:
	var in_strip := pos.y >= _vp_size.y * STRIP_START_PCT
	var in_left_edge := pos.x <= _vp_size.x * 0.10
	var in_right_edge := pos.x >= _vp_size.x * 0.90
	return in_strip and (in_left_edge or in_right_edge)


func _on_gesture_start(pos: Vector2) -> void:
	_phase = Phase.SELECTING
	_select_start = pos
	_hovered_cell = -1
	_entered_mid_zone = false
	_build_grid_cells()
	flip_grid.position = Vector2(
		_vp_size.x / 2.0 - 150.0,
		_vp_size.y / 2.0 - 150.0
	)
	flip_grid.show()


func _on_gesture_drag(pos: Vector2) -> void:
	if not _entered_mid_zone:
		var in_mid := pos.x > _vp_size.x * 0.10 and pos.x < _vp_size.x * 0.90
		if in_mid:
			_entered_mid_zone = true
			_select_start = pos
		return
	var drag := pos - _select_start
	if drag.length() < DRAG_DEAD_ZONE:
		return
	var best_cell := -1
	var best_dot := -INF
	for i in range(9):
		if i == 4:
			continue
		var dot := drag.normalized().dot(DIRECTIONS[i].normalized())
		if dot > best_dot:
			best_dot = dot
			best_cell = i
	if best_cell != _hovered_cell:
		_hovered_cell = best_cell
		_highlight_cell(best_cell)


func _on_gesture_release() -> void:
	if _hovered_cell >= 0 and _hovered_cell != 4:
		_do_flip(_hovered_cell)
	_entered_mid_zone = false
	_hide_grid()


func _show_grid() -> void:
	_phase = Phase.SELECTING
	_hovered_cell = -1
	_select_start = _vp_size / 2.0
	_build_grid_cells()
	flip_grid.position = _vp_size / 2.0 - Vector2(150.0, 150.0)
	flip_grid.show()


func _hide_grid() -> void:
	_phase = Phase.IDLE
	_hovered_cell = -1
	flip_grid.hide()


func _build_grid_cells() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	var tm = get_node_or_null("/root/TomeManager")
	for i in range(9):
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(100, 100)

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		if i == 4:
			label.text = "●"
			cell.modulate = Color(0.6, 0.8, 1.0)
		else:
			var page_index := i if i < 4 else i - 1
			if tm != null and page_index < tm.pages.size():
				var page = tm.pages[page_index]
				label.text = "%d\n%s" % [page_index + 1, page.page_name]
				cell.modulate = Color(1, 1, 1)
			else:
				label.text = "—"
				cell.modulate = Color(0.3, 0.3, 0.3)

		cell.add_child(label)
		grid_container.add_child(cell)


func _highlight_cell(cell_index: int) -> void:
	var cells := grid_container.get_children()
	for i in range(cells.size()):
		if i == 4:
			continue
		cells[i].modulate = Color(1, 1, 1) if i != cell_index else Color(1, 0.8, 0.2)


func _do_flip(cell_index: int) -> void:
	var page_index := cell_index if cell_index < 4 else cell_index - 1
	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return
	if page_index >= tm.pages.size():
		return
	tm.flip_to_page(page_index)
	_build_grid_cells()


func _on_page_flipped(_index: int) -> void:
	_build_grid_cells()
