@tool
extends CharacterBody2D
class_name PickupItem

signal interaction_availability_changed(item: PickupItem)

enum State {
	WORLD,
	HELD,
	THROWN,
}

@export var item_settings: PickupItemSettings
@export_flags_2d_physics var world_collision_mask: int = 1
@export_flags_2d_physics var enemy_detection_mask: int = 1 << 4
@export var throw_speed: float = 520.0
@export_range(0.1, 3.0, 0.1) var throw_weight: float = 1.0
@export var attack_power: int = 1
@export var thrown_stop_speed: float = 10.0
@export var friction: float = 0.99
@export_group("Interaction Feedback")
@export var interaction_outline_color: Color = Color(1.0, 0.92, 0.0, 1.0)
@export var interaction_outline_width: float = 3.0
@export_range(0.1, 12.0, 0.1) var interaction_highlight_pulse_speed: float = 5.0
@export_group("Held Floating")
@export var held_float_enabled: bool = true
@export_range(0.0, 32.0, 0.5) var held_float_amplitude: float = 5.0
@export_range(0.1, 12.0, 0.1) var held_float_speed: float = 3.0
@export_range(0.0, 30.0, 0.5) var held_float_tilt_degrees: float = 6.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_collision_shape: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var interaction_marker: Node2D = get_node_or_null("InteractionMarker") as Node2D
@onready var interaction_outline: Line2D = get_node_or_null("InteractionOutline") as Line2D

var state: State = State.WORLD
var holder: Player = null
var _default_interaction_layer: int
var _throw_start_position: Vector2 = Vector2.ZERO
var _throw_elapsed: float = 0.0
var _held_float_elapsed: float = 0.0
var _world_z_index: int = 0
var _bound_settings: PickupItemSettings
var _is_interaction_highlighted: bool = false
var _highlight_elapsed: float = 0.0

func _enter_tree() -> void:
	_bind_item_settings()

func _ready() -> void:
	_bind_item_settings()
	_apply_item_settings()
	_update_interaction_outline(false, 0.0)
	_update_interaction_marker(false, 0.0)
	set_physics_process(not Engine.is_editor_hint())
	add_to_group("interactable")
	_default_interaction_layer = interaction_area.collision_layer
	_world_z_index = z_index
	interaction_area.collision_mask = enemy_detection_mask
	interaction_area.monitoring = true
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_bind_item_settings()
		_apply_item_settings()
		return

	_process_interaction_feedback(delta)

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

	var interaction_shape := interaction_collision_shape.shape as RectangleShape2D
	if interaction_shape != null:
		interaction_shape.size = item_settings.clickable_shape_size
	interaction_collision_shape.scale = item_settings.clickable_shape_scale

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
			if absf(velocity.x) <= thrown_stop_speed:
				velocity.x = 0.0
			move_and_slide()
			_damage_overlapping_enemies()
			if is_on_floor() and velocity.length() <= thrown_stop_speed:
				_return_to_world_state()

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

func set_interaction_highlighted(enabled: bool) -> void:
	_is_interaction_highlighted = enabled and state == State.WORLD and holder == null
	if not _is_interaction_highlighted:
		_highlight_elapsed = 0.0
		_update_interaction_outline(false, 0.0)
		_update_interaction_marker(false, 0.0)

func pick_up(by: Player) -> void:
	holder = by
	state = State.HELD
	velocity = Vector2.ZERO
	_held_float_elapsed = 0.0
	_world_z_index = z_index

	# Held items should not collide with the world or respond to clicks.
	collision_mask = 0
	interaction_area.collision_layer = 0
	set_interaction_highlighted(false)
	z_index = by.z_index + 1
	interaction_availability_changed.emit(self)

func drop_to_world(drop_position: Vector2) -> void:
	global_position = drop_position
	holder = null
	state = State.WORLD
	_held_float_elapsed = 0.0
	sprite.rotation = 0.0

	collision_mask = world_collision_mask
	interaction_area.collision_layer = _default_interaction_layer
	set_interaction_highlighted(false)
	z_index = _world_z_index
	interaction_availability_changed.emit(self)

func throw_to(target_global: Vector2) -> void:
	holder = null
	state = State.THROWN
	_held_float_elapsed = 0.0
	sprite.rotation = 0.0
	collision_mask = world_collision_mask
	interaction_area.collision_layer = 0
	interaction_area.collision_mask = enemy_detection_mask
	interaction_area.monitoring = true
	set_interaction_highlighted(false)
	z_index = _world_z_index
	interaction_availability_changed.emit(self)

	var direction := target_global - global_position
	if direction.length() < 1.0:
		direction = Vector2.RIGHT
	_throw_start_position = global_position
	_throw_elapsed = 0.0
	velocity = direction.normalized() * _get_effective_throw_speed()

func get_throw_straight_distance() -> float:
	return minf(_get_throw_force_free_distance(), _get_effective_throw_speed() * _get_throw_force_free_time())

func _on_interaction_area_body_entered(body: Node) -> void:
	if state != State.THROWN:
		return

	_try_damage_enemy(body)

func _damage_overlapping_enemies() -> void:
	for body in interaction_area.get_overlapping_bodies():
		if _try_damage_enemy(body):
			return

	var shape := interaction_collision_shape.shape
	if shape == null:
		return

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = interaction_collision_shape.global_transform
	params.collision_mask = enemy_detection_mask
	params.collide_with_bodies = true
	params.collide_with_areas = false

	var results := get_world_2d().direct_space_state.intersect_shape(params, 8)
	for result in results:
		if _try_damage_enemy(result["collider"]):
			return

func _try_damage_enemy(body: Node) -> bool:
	var enemy := body as Enemy
	if enemy == null or enemy.is_dead():
		return false

	if not enemy.take_damage(attack_power):
		return false

	_reflect_x_from(enemy.global_position)
	return true

func _reflect_x_from(source_position: Vector2) -> void:
	if absf(velocity.x) < 1.0:
		var bounce_direction := signf(global_position.x - source_position.x)
		if bounce_direction == 0.0:
			bounce_direction = 1.0
		velocity.x = bounce_direction * _get_effective_throw_speed() * 0.5
	else:
		velocity.x = -velocity.x

func _return_to_world_state() -> void:
	state = State.WORLD
	interaction_area.collision_layer = _default_interaction_layer
	interaction_availability_changed.emit(self)

func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func _process_interaction_feedback(delta: float) -> void:
	if not _is_interaction_highlighted or state != State.WORLD or holder != null:
		_update_interaction_outline(false, 0.0)
		return

	_highlight_elapsed += delta
	var pulse := (sin(_highlight_elapsed * interaction_highlight_pulse_speed) + 1.0) * 0.5
	_update_interaction_outline(true, pulse)
	_update_interaction_marker(true, pulse)

func _update_interaction_outline(visible: bool, pulse: float) -> void:
	if interaction_outline == null:
		return

	interaction_outline.visible = visible
	if not visible:
		return

	var rect := _get_local_visual_rect()
	var padding := 6.0
	var outline_rect := rect.grow(padding)
	interaction_outline.default_color = interaction_outline_color
	interaction_outline.width = interaction_outline_width + pulse
	interaction_outline.points = PackedVector2Array([
		outline_rect.position,
		Vector2(outline_rect.end.x, outline_rect.position.y),
		outline_rect.end,
		Vector2(outline_rect.position.x, outline_rect.end.y),
	])

func _update_interaction_marker(visible: bool, pulse: float) -> void:
	if interaction_marker == null:
		return

	interaction_marker.visible = visible
	if not visible:
		return

	var safe_global_scale := Vector2(
		maxf(absf(global_scale.x), 0.001),
		maxf(absf(global_scale.y), 0.001)
	)
	var local_marker_offset := 16.0 / safe_global_scale.y
	interaction_marker.position = sprite.position + Vector2(
		0.0,
		-_get_local_visual_height() * 0.5 - local_marker_offset
	)
	interaction_marker.scale = Vector2(
		1.0 / safe_global_scale.x,
		1.0 / safe_global_scale.y
	) * (1.0 + 0.25 * pulse)

func _get_local_visual_height() -> float:
	if sprite.texture == null:
		return 0.0
	return sprite.texture.get_height() * absf(sprite.scale.y)

func _get_local_visual_rect() -> Rect2:
	if sprite.texture == null:
		return Rect2(sprite.position, Vector2.ZERO)

	var texture_size := sprite.texture.get_size()
	var scaled_size := Vector2(
		texture_size.x * absf(sprite.scale.x),
		texture_size.y * absf(sprite.scale.y)
	)
	return Rect2(sprite.position - scaled_size * 0.5, scaled_size)

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
	return maxf(time_factor, distance_factor)

func _get_blend_factor(progress: float, free_zone: float, blend_zone: float) -> float:
	if progress <= free_zone:
		return 0.0
	if blend_zone <= 0.0:
		return 1.0
	return clamp((progress - free_zone) / blend_zone, 0.0, 1.0)

func _get_weight_ratio() -> float:
	return inverse_lerp(0.1, 3.0, clampf(throw_weight, 0.1, 3.0))

func _get_effective_throw_speed() -> float:
	return throw_speed / sqrt(maxf(throw_weight, 0.1))

func _get_throw_air_drag() -> float:
	return lerp(1.6, 2.8, _get_weight_ratio())

func _get_throw_force_free_time() -> float:
	return lerp(0.24, 0.11, _get_weight_ratio())

func _get_throw_force_blend_time() -> float:
	return lerp(0.42, 0.2, _get_weight_ratio())

func _get_throw_force_free_distance() -> float:
	return lerp(230.0, 115.0, _get_weight_ratio())

func _get_throw_force_blend_distance() -> float:
	return lerp(220.0, 120.0, _get_weight_ratio())
