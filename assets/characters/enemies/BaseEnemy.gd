class_name BaseEnemy
extends CharacterBody2D

signal died(enemy: BaseEnemy)
signal damaged(amount: int, current_hp: int)

@export var max_hp: int = 3
@export var contact_damage: int = 1
@export var move_speed: float = 30.0
@export var gravity_scale: float = 1.0
@export var facing_right: bool = false

@export var patrol_move_time: float = 5.0
@export var patrol_wait_time: float = 1.0
@export var damage_invincible_time: float = 1.0

@export var thrown_object_min_speed: float = 80.0
@export var thrown_object_damage: int = 1

@export var death_freeze_time: float = 2.0
@export var fade_out_time: float = 0.6

enum State {
	PATROL_MOVE,
	PATROL_WAIT,
	DEAD,
	FADING,
}

var hp: int
var is_dead: bool = false
var state: State = State.PATROL_MOVE
var state_timer: float = 0.0
var invincible_timer: float = 0.0

@onready var debug_label: Label = $DebugLabel

func _ready() -> void:
	hp = max_hp
	update_facing(facing_right)
	_change_state(State.PATROL_MOVE)

func _physics_process(delta: float) -> void:
	_update_invincibility(delta)

	match state:
		State.PATROL_MOVE:
			_process_patrol_move(delta)
		State.PATROL_WAIT:
			_process_patrol_wait(delta)
		State.DEAD:
			_process_dead(delta)
		State.FADING:
			_process_fading(delta)

	if state == State.PATROL_MOVE or state == State.PATROL_WAIT:
		apply_gravity(delta)
		move_and_slide()
		_process_contact_interactions()

	_update_debug_label()

func _process_patrol_move(delta: float) -> void:
	state_timer -= delta
	if is_on_wall():
		_turn_around()
	move_horizontal(1.0 if facing_right else -1.0, move_speed)
	if state_timer <= 0.0:
		_change_state(State.PATROL_WAIT)

func _process_patrol_wait(delta: float) -> void:
	state_timer -= delta
	stop_horizontal()
	if state_timer <= 0.0:
		_turn_around()
		_change_state(State.PATROL_MOVE)

func _process_dead(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_change_state(State.FADING)

func _process_fading(delta: float) -> void:
	if fade_out_time <= 0.0:
		queue_free()
		return
	state_timer -= delta
	var alpha := clamp(state_timer / fade_out_time, 0.0, 1.0)
	modulate.a = alpha
	if state_timer <= 0.0:
		queue_free()

func _change_state(next_state: State) -> void:
	state = next_state
	match state:
		State.PATROL_MOVE:
			state_timer = patrol_move_time
			_set_state_name("PATROL_MOVE")
		State.PATROL_WAIT:
			state_timer = patrol_wait_time
			_set_state_name("PATROL_WAIT")
		State.DEAD:
			state_timer = death_freeze_time
			_set_state_name("DEAD")
		State.FADING:
			state_timer = fade_out_time
			_set_state_name("FADING")

func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	velocity.y += _get_gravity_value() * gravity_scale * delta

func move_horizontal(direction: float, speed: float = move_speed) -> void:
	velocity.x = direction * speed
	if absf(direction) > 0.01:
		update_facing(direction > 0.0)

func stop_horizontal() -> void:
	velocity.x = 0.0

func update_facing(should_face_right: bool) -> void:
	facing_right = should_face_right
	scale.x = absf(scale.x) if facing_right else -absf(scale.x)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	if invincible_timer > 0.0:
		return
	hp -= amount
	invincible_timer = damage_invincible_time
	damaged.emit(amount, hp)
	if hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(true)
	_change_state(State.DEAD)
	died.emit(self)

func _process_contact_interactions() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as Node
		if body == null:
			continue

		if body.is_in_group("Player") and body.has_method("take_damage"):
			body.take_damage(contact_damage)
			continue

		if _is_moving_damage_object(body):
			take_damage(thrown_object_damage)

func _is_moving_damage_object(body: Node) -> bool:
	if body.is_in_group("Player"):
		return false
	if body is BaseEnemy:
		return false
	var speed := _get_body_speed(body)
	return speed >= thrown_object_min_speed

func _get_body_speed(body: Node) -> float:
	if body is CharacterBody2D:
		return (body as CharacterBody2D).velocity.length()
	if body is RigidBody2D:
		return (body as RigidBody2D).linear_velocity.length()
	if "velocity" in body:
		var v = body.get("velocity")
		if v is Vector2:
			return v.length()
	return 0.0

func _turn_around() -> void:
	update_facing(not facing_right)

func _update_invincibility(delta: float) -> void:
	if invincible_timer > 0.0:
		invincible_timer = maxf(0.0, invincible_timer - delta)

func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func _set_state_name(state_name: String) -> void:
	if debug_label == null:
		return
	debug_label.text = "%s\nHP:%d\nINV:%.2f" % [state_name, hp, invincible_timer]

func _update_debug_label() -> void:
	if debug_label == null:
		return
	var first_line := debug_label.text.split("\n")[0] if debug_label.text != "" else "-"
	debug_label.text = "%s\nHP:%d\nINV:%.2f" % [first_line, hp, invincible_timer]
