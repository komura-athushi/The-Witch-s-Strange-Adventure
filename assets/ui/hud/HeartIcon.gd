class_name HeartIcon
extends Control

var filled: bool = true

func configure(is_filled: bool) -> void:
	filled = is_filled
	queue_redraw()

func _draw() -> void:
	_draw_placeholder_heart()

func _draw_placeholder_heart() -> void:
	var points := PackedVector2Array([
		Vector2(0.50, 0.90),
		Vector2(0.12, 0.52),
		Vector2(0.10, 0.30),
		Vector2(0.22, 0.16),
		Vector2(0.39, 0.16),
		Vector2(0.50, 0.28),
		Vector2(0.61, 0.16),
		Vector2(0.78, 0.16),
		Vector2(0.90, 0.30),
		Vector2(0.88, 0.52),
	])

	for index in points.size():
		points[index] *= size

	var fill_color := Color("e74856") if filled else Color(0.18, 0.08, 0.10, 0.45)
	var outline_color := Color("7d1f2a") if filled else Color(0.45, 0.35, 0.37, 0.7)
	draw_colored_polygon(points, fill_color)

	var outline_points := points.duplicate()
	outline_points.append(points[0])
	draw_polyline(outline_points, outline_color, 2.0, true)
