class_name Wolf
extends Enemy

enum MoveState {
	MOVE_LEFT,
	WAIT_AFTER_LEFT,
	MOVE_RIGHT,
	WAIT_AFTER_RIGHT,
}

@export var move_speed_x: float = 80.0
@export var move_time: float = 2.0
@export var wait_time: float = 1.0

@onready var sprite2D: AnimatedSprite2D = $Visual/AnimatedSprite2D

var _move_state: MoveState = MoveState.MOVE_LEFT
var _state_time_left: float = 0.0

func _ready() -> void:
	super()
	_enter_state(MoveState.MOVE_LEFT)

func _physics_process(delta: float) -> void:
	if not can_move():
		velocity = Vector2.ZERO
		_update_animation()
		return

	_update_move_state(delta)
	_update_animation()
	velocity.y += _get_gravity_value() * delta
	move_and_slide()

func _update_move_state(delta: float) -> void:
	_state_time_left -= delta
	match _move_state:
		MoveState.MOVE_LEFT:
			velocity.x = -move_speed_x
			if _state_time_left <= 0.0:
				_enter_state(MoveState.WAIT_AFTER_LEFT)
		MoveState.WAIT_AFTER_LEFT:
			velocity.x = 0.0
			if _state_time_left <= 0.0:
				_enter_state(MoveState.MOVE_RIGHT)
		MoveState.MOVE_RIGHT:
			velocity.x = move_speed_x
			if _state_time_left <= 0.0:
				_enter_state(MoveState.WAIT_AFTER_RIGHT)
		MoveState.WAIT_AFTER_RIGHT:
			velocity.x = 0.0
			if _state_time_left <= 0.0:
				_enter_state(MoveState.MOVE_LEFT)

func _enter_state(next_state: MoveState) -> void:
	_move_state = next_state
	match _move_state:
		MoveState.MOVE_LEFT:
			_state_time_left = move_time
			$Visual.scale.x = absf($Visual.scale.x)
		MoveState.MOVE_RIGHT:
			_state_time_left = move_time
			$Visual.scale.x = -absf($Visual.scale.x)
		_:
			_state_time_left = wait_time
			velocity.x = 0.0

func _update_animation() -> void:
	var next_animation := "walk" if absf(velocity.x) > 0.0 else "idle"
	if sprite2D.animation != next_animation:
		sprite2D.animation = next_animation
	sprite2D.play()

func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))
