extends CharacterBody2D
class_name PickupItem

enum State {
	WORLD,
	HELD,
	THROWN,
}

@export_flags_2d_physics var world_collision_mask: int = 1
@export var throw_speed: float = 520.0
@export var friction: float = 0.985
@export var throw_horizontal_deceleration: float = 900.0
@export var throw_gravity_free_distance: float = 120.0
@export var throw_gravity_blend_distance: float = 180.0

@onready var clickable: Area2D = $Clickable

var state: State = State.WORLD
var holder: Player = null
var _default_clickable_layer: int
var _throw_start_position: Vector2 = Vector2.ZERO

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
			velocity.x = move_toward(velocity.x, 0.0, throw_horizontal_deceleration * delta)
			velocity.y += _get_gravity_value() * _get_throw_gravity_factor() * delta
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

	var throw_direction_x := sign(target_global.x - global_position.x)
	if is_zero_approx(throw_direction_x):
		throw_direction_x = 1.0
	_throw_start_position = global_position
	velocity = Vector2(throw_direction_x * throw_speed, 0.0)
	
func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func _get_throw_gravity_factor() -> float:
	var traveled_distance := global_position.distance_to(_throw_start_position)
	if traveled_distance <= throw_gravity_free_distance:
		return 0.0

	if throw_gravity_blend_distance <= 0.0:
		return 1.0

	return clamp(
		(traveled_distance - throw_gravity_free_distance) / throw_gravity_blend_distance,
		0.0,
		1.0
	)
