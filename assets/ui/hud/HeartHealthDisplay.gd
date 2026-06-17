class_name HeartHealthDisplay
extends HBoxContainer

const HEART_ICON_SCRIPT := preload("res://assets/ui/hud/HeartIcon.gd")

@export_group("Heart Appearance")
@export var heart_texture: Texture2D:
	set(value):
		heart_texture = value
		if is_node_ready():
			_rebuild_hearts()

@export var heart_size := Vector2(24.0, 24.0):
	set(value):
		heart_size = value.max(Vector2.ONE)
		if is_node_ready():
			_rebuild_hearts()

@export_group("Heart Layout")
@export var first_heart_position := Vector2(12.0, 12.0):
	set(value):
		first_heart_position = value
		if is_node_ready():
			position = first_heart_position

@export_range(-32, 128, 1, "or_greater", "or_less") var horizontal_spacing: int = 4:
	set(value):
		horizontal_spacing = value
		if is_node_ready():
			add_theme_constant_override("separation", horizontal_spacing)

@export_group("Display")
@export var show_empty_hearts: bool = false:
	set(value):
		show_empty_hearts = value
		if is_node_ready():
			_rebuild_hearts()

var _current_hp: int = 0
var _max_hp: int = 0

func _ready() -> void:
	position = first_heart_position
	add_theme_constant_override("separation", horizontal_spacing)

func set_health(current_hp: int, max_hp: int) -> void:
	_max_hp = maxi(max_hp, 0)
	_current_hp = clampi(current_hp, 0, _max_hp)
	_rebuild_hearts()

func _rebuild_hearts() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var heart_count := _max_hp if show_empty_hearts else _current_hp
	for index in heart_count:
		var is_filled := index < _current_hp
		var heart := _create_heart(is_filled)
		heart.custom_minimum_size = heart_size
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(heart)

func _create_heart(is_filled: bool) -> Control:
	if heart_texture == null:
		var placeholder := HEART_ICON_SCRIPT.new() as HeartIcon
		placeholder.configure(is_filled)
		return placeholder

	var texture_rect := TextureRect.new()
	texture_rect.texture = heart_texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not is_filled:
		texture_rect.self_modulate = Color(1.0, 1.0, 1.0, 0.25)
	return texture_rect
