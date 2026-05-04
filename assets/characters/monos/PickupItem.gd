@tool
extends CharacterBody2D
class_name PickupItem

enum State {
	WORLD,
	HELD,
	THROWN,
}

@export var item_settings: PickupItemSettings
@export_flags_2d_physics var world_collision_mask: int = 1
@export var throw_speed: float = 520.0
@export_range(0.1, 3.0, 0.1) var throw_weight: float = 1.0
@export var friction: float = 0.99
@export_group("Held Floating")
@export var held_float_enabled: bool = true
@export_range(0.0, 32.0, 0.5) var held_float_amplitude: float = 5.0
@export_range(0.1, 12.0, 0.1) var held_float_speed: float = 3.0
@export_range(0.0, 30.0, 0.5) var held_float_tilt_degrees: float = 6.0


@onready var sprite: Sprite2D = $Sprite2D
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var clickable: Area2D = $Clickable
@onready var clickable_collision_shape: CollisionShape2D = $Clickable/CollisionShape2D

var state: State = State.WORLD
var holder: Player = null
var _default_clickable_layer: int
var _throw_start_position: Vector2 = Vector2.ZERO
var _throw_elapsed: float = 0.0
var _held_float_elapsed: float = 0.0
var _world_z_index: int = 0
var _bound_settings: PickupItemSettings

func _enter_tree() -> void:
	_bind_item_settings()

func _ready() -> void:
	_bind_item_settings()
	_apply_item_settings()
	set_physics_process(not Engine.is_editor_hint())
	add_to_group("interactable")
	_default_clickable_layer = clickable.collision_layer
	_world_z_index = z_index

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_bind_item_settings()
		_apply_item_settings()

func _exit_tree() -> void:
	_unbind_item_settings()

func _bind_item_settings() -> void:
	if _bound_settings == item_settings:
		return

	_unbind_item_settings()
	_bound_settings = item_settings
	if _bound_settings != null and not _bound_settings.changed.is_connected(_on_item_settings_changed):
		_bound_settings.changed.connect(_on_item_settings_changed)

func _unbind_item_settings() -> void:
	if _bound_settings != null and _bound_settings.changed.is_connected(_on_item_settings_changed):
		_bound_settings.changed.disconnect(_on_item_settings_changed)
	_bound_settings = null

func _on_item_settings_changed() -> void:
	_apply_item_settings()

func _apply_item_settings() -> void:
	if item_settings == null:
		return

	if item_settings.texture != null:
		sprite.texture = item_settings.texture
	sprite.scale = item_settings.sprite_scale
	sprite.position = item_settings.sprite_offset

	var body_shape := body_collision_shape.shape as RectangleShape2D
	if body_shape != null:
		body_shape.size = item_settings.body_shape_size
	body_collision_shape.scale = item_settings.body_shape_scale

	var clickable_shape := clickable_collision_shape.shape as RectangleShape2D
	if clickable_shape != null:
		clickable_shape.size = item_settings.clickable_shape_size
	clickable_collision_shape.scale = item_settings.clickable_shape_scale

	world_collision_mask = item_settings.world_collision_mask
	throw_speed = item_settings.throw_speed
	throw_weight = item_settings.throw_weight
	friction = item_settings.friction

func _physics_process(delta: float) -> void:
	match state:
		State.WORLD:
			velocity *= friction
			velocity.y += _get_gravity_value() * delta
			move_and_slide()

		State.THROWN:
			_throw_elapsed += delta
			var throw_force_factor := _get_throw_force_factor()
			var drag_factor := exp(-_get_throw_air_drag() * throw_force_factor * delta)
			velocity *= drag_factor
			velocity.y += _get_gravity_value() * throw_force_factor * delta
			move_and_slide()
			if is_on_floor():
				state = State.WORLD
				clickable.collision_layer = _default_clickable_layer

		State.HELD:
			if holder != null:
				_held_float_elapsed += delta
				global_position = holder.get_hold_position(_get_held_offset() + _get_held_float_offset())
				sprite.rotation = _get_held_float_rotation()
			velocity = Vector2.ZERO

func can_interact(actor: Node) -> bool:
	if not actor is Player:
		return false
	return state == State.WORLD and holder == null and actor.held_item == null

func interact(actor: Node) -> void:
	if can_interact(actor):
		actor.pick_item(self)

func pick_up(by: Player) -> void:
	holder = by
	state = State.HELD
	velocity = Vector2.ZERO
	_held_float_elapsed = 0.0
	_world_z_index = z_index

	# 持っている間は地面にもクリックにも反応しない
	collision_mask = 0
	clickable.collision_layer = 0
	z_index = by.z_index + 1

func drop_to_world(drop_position: Vector2) -> void:
	global_position = drop_position
	holder = null
	state = State.WORLD
	_held_float_elapsed = 0.0
	sprite.rotation = 0.0

	collision_mask = world_collision_mask
	clickable.collision_layer = _default_clickable_layer
	z_index = _world_z_index

func throw_to(target_global: Vector2) -> void:
	holder = null
	state = State.THROWN
	_held_float_elapsed = 0.0
	sprite.rotation = 0.0
	collision_mask = world_collision_mask
	clickable.collision_layer = 0
	z_index = _world_z_index

	var direction := target_global - global_position
	if direction.length() < 1.0:
		direction = Vector2.RIGHT
	_throw_start_position = global_position
	_throw_elapsed = 0.0
	velocity = direction.normalized() * _get_effective_throw_speed()
	
func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func _get_held_offset() -> Vector2:
	return Vector2(0.0, -_get_visual_height() * 0.5)

func _get_held_float_offset() -> Vector2:
	if not held_float_enabled:
		return Vector2.ZERO
	return Vector2(0.0, sin(_held_float_elapsed * held_float_speed) * held_float_amplitude)

func _get_held_float_rotation() -> float:
	if not held_float_enabled:
		return 0.0
	return deg_to_rad(sin(_held_float_elapsed * held_float_speed * 0.7) * held_float_tilt_degrees)

func _get_visual_height() -> float:
	if sprite.texture == null:
		return 0.0
	return sprite.texture.get_height() * abs(sprite.global_scale.y)

func _get_throw_force_factor() -> float:
	var time_factor := _get_blend_factor(
		_throw_elapsed,
		_get_throw_force_free_time(),
		_get_throw_force_blend_time()
	)
	var traveled_distance := global_position.distance_to(_throw_start_position)
	var distance_factor := _get_blend_factor(
		traveled_distance,
		_get_throw_force_free_distance(),
		_get_throw_force_blend_distance()
	)
	return max(time_factor, distance_factor)

func _get_blend_factor(progress: float, free_zone: float, blend_zone: float) -> float:
	if progress <= free_zone:
		return 0.0
	if blend_zone <= 0.0:
		return 1.0
	return clamp((progress - free_zone) / blend_zone, 0.0, 1.0)

func _get_weight_ratio() -> float:
	return clamp((throw_weight - 1.0) / 1.8, 0.0, 1.0)

func _get_effective_throw_speed() -> float:
	return throw_speed / sqrt(max(throw_weight, 0.1))

func _get_throw_air_drag() -> float:
	return lerp(1.6, 2.8, _get_weight_ratio())

func _get_throw_force_free_time() -> float:
	return lerp(0.18, 0.07, _get_weight_ratio())

func _get_throw_force_blend_time() -> float:
	return lerp(0.42, 0.2, _get_weight_ratio())

func _get_throw_force_free_distance() -> float:
	return lerp(190.0, 80.0, _get_weight_ratio())

func _get_throw_force_blend_distance() -> float:
	return lerp(220.0, 120.0, _get_weight_ratio())
