extends CharacterBody2D
class_name PickupItem

enum State {
	WORLD,
	HELD,
	THROWN,
}

@export_flags_2d_physics var world_collision_mask: int = 1
@export var throw_speed: float = 520.0
@export_range(0.1, 3.0, 0.1) var throw_weight: float = 1.0
@export var friction: float = 0.985

@onready var clickable: Area2D = $Clickable

var state: State = State.WORLD
var holder: Player = null
var _default_clickable_layer: int
var _throw_start_position: Vector2 = Vector2.ZERO
var _throw_elapsed: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	_default_clickable_layer = clickable.collision_layer

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
				global_position = holder.get_hold_position(Vector2.ZERO)
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

	# 持っている間は地面にもクリックにも反応しない
	collision_mask = 0
	clickable.collision_layer = 0
	z_index = 10

func drop_to_world(drop_position: Vector2) -> void:
	global_position = drop_position
	holder = null
	state = State.WORLD

	collision_mask = world_collision_mask
	clickable.collision_layer = _default_clickable_layer
	z_index = 0

func throw_to(target_global: Vector2) -> void:
	holder = null
	state = State.THROWN
	collision_mask = world_collision_mask
	clickable.collision_layer = 0
	z_index = 0

	var direction := target_global - global_position
	if direction.length() < 1.0:
		direction = Vector2.RIGHT
	_throw_start_position = global_position
	_throw_elapsed = 0.0
	velocity = direction.normalized() * _get_effective_throw_speed()
	
func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))

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
	return clamp((throw_weight - 0.6) / 1.8, 0.0, 1.0)

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
