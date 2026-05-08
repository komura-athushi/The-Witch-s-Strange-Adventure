class_name ThrowPredictionLine
extends Node2D

@export var solid_color: Color = Color(1.0, 0.0, 0.0, 0.85)
@export var dotted_color: Color = Color(1.0, 0.0, 0.0, 0.85)
@export_range(1.0, 8.0, 0.5) var line_width: float = 2.0
@export_range(2.0, 24.0, 1.0) var dash_length: float = 8.0
@export_range(2.0, 24.0, 1.0) var dash_gap: float = 7.0

var target_item: PickupItem = null

func _ready() -> void:
	visible = false
	set_process(false)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if target_item == null or not is_instance_valid(target_item):
		target_item = null
		visible = false
		set_process(false)
		return

	var start_global := target_item.global_position
	var direction := _get_throw_direction(start_global)
	var end_global := _get_screen_edge_point(start_global, direction)
	var prediction_length := start_global.distance_to(end_global)
	var straight_length: float = minf(target_item.get_throw_straight_distance(), prediction_length)
	var solid_end_global := start_global + direction * straight_length

	draw_line(to_local(start_global), to_local(solid_end_global), solid_color, line_width, true)

	if straight_length < prediction_length:
		_draw_dotted_line(solid_end_global, end_global)

func set_target_item(item: PickupItem) -> void:
	target_item = item
	visible = target_item != null
	set_process(visible)
	queue_redraw()

func clear_target_item() -> void:
	target_item = null
	visible = false
	set_process(false)
	queue_redraw()

func _get_throw_direction(start_global: Vector2) -> Vector2:
	var direction := get_global_mouse_position() - start_global
	if direction.length() < 1.0:
		return Vector2.RIGHT
	return direction.normalized()

func _draw_dotted_line(from_global: Vector2, end_global: Vector2) -> void:
	var segment := end_global - from_global
	var segment_length := segment.length()
	if segment_length <= 0.0:
		return

	var direction := segment / segment_length
	var distance := 0.0
	while distance < segment_length:
		var dash_start := from_global + direction * distance
		var dash_end_distance: float = minf(distance + dash_length, segment_length)
		var dash_end := from_global + direction * dash_end_distance
		draw_line(to_local(dash_start), to_local(dash_end), dotted_color, line_width, true)
		distance += dash_length + dash_gap

func _get_screen_edge_point(start_global: Vector2, direction: Vector2) -> Vector2:
	var viewport_rect := _get_viewport_global_rect()
	var nearest_distance: float = INF

	if abs(direction.x) > 0.001:
		nearest_distance = _get_nearest_edge_distance(
			start_global,
			direction,
			(viewport_rect.position.x - start_global.x) / direction.x,
			viewport_rect,
			nearest_distance
		)
		nearest_distance = _get_nearest_edge_distance(
			start_global,
			direction,
			(viewport_rect.end.x - start_global.x) / direction.x,
			viewport_rect,
			nearest_distance
		)

	if abs(direction.y) > 0.001:
		nearest_distance = _get_nearest_edge_distance(
			start_global,
			direction,
			(viewport_rect.position.y - start_global.y) / direction.y,
			viewport_rect,
			nearest_distance
		)
		nearest_distance = _get_nearest_edge_distance(
			start_global,
			direction,
			(viewport_rect.end.y - start_global.y) / direction.y,
			viewport_rect,
			nearest_distance
		)

	if nearest_distance == INF:
		return start_global + direction * 1000.0
	return start_global + direction * nearest_distance

func _get_nearest_edge_distance(
	start_global: Vector2,
	direction: Vector2,
	distance: float,
	viewport_rect: Rect2,
	current_nearest: float
) -> float:
	if distance <= 0.0 or distance >= current_nearest:
		return current_nearest

	var point := start_global + direction * distance
	if viewport_rect.grow(0.5).has_point(point):
		return distance
	return current_nearest

func _get_viewport_global_rect() -> Rect2:
	var viewport := get_viewport()
	var screen_rect := viewport.get_visible_rect()
	var screen_to_global := viewport.get_canvas_transform().affine_inverse()
	var top_left := screen_to_global * screen_rect.position
	var top_right := screen_to_global * (screen_rect.position + Vector2(screen_rect.size.x, 0.0))
	var bottom_left := screen_to_global * (screen_rect.position + Vector2(0.0, screen_rect.size.y))
	var bottom_right := screen_to_global * screen_rect.end

	var min_x: float = minf(minf(top_left.x, top_right.x), minf(bottom_left.x, bottom_right.x))
	var min_y: float = minf(minf(top_left.y, top_right.y), minf(bottom_left.y, bottom_right.y))
	var max_x: float = maxf(maxf(top_left.x, top_right.x), maxf(bottom_left.x, bottom_right.x))
	var max_y: float = maxf(maxf(top_left.y, top_right.y), maxf(bottom_left.y, bottom_right.y))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
