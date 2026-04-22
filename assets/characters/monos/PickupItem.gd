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

@onready var clickable: Area2D = $Clickable

var state: State = State.WORLD
var holder: Player = null
var _default_clickable_layer: int

func _ready() -> void:
	add_to_group("interactable")
	_default_clickable_layer = clickable.collision_layer

func _physics_process(delta: float) -> void:
	match state:
		State.WORLD, State.THROWN:
			velocity *= friction
			velocity.y += _get_gravity_value() * delta
			move_and_slide()
			if state == State.THROWN and is_on_floor():
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
	velocity = direction.normalized() * throw_speed
	
func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))
