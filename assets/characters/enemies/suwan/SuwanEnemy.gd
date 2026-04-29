class_name SuwanEnemy
extends BaseEnemy

enum State {
	PATROL,
	NOTICE,
	APPROACH,
	CHARGE,
	LEAP_ATTACK,
	RECOVER,
	DEAD,
}

@export var patrol_direction: float = 1.0
@export var patrol_speed: float = 30.0
@export var detect_range: float = 220.0
@export var approach_distance: float = 100.0
@export var notice_time: float = 0.35
@export var charge_time: float = 0.45
@export var recover_time: float = 0.6
@export var leap_speed: float = 220.0
@export var leap_upward_velocity: float = -300.0
@export var notice_jump_velocity: float = -150.0

@onready var exclamation_label: Label = $ExclamationLabel

var current_state: State = State.PATROL
var timer: float = 0.0
var leap_target: Vector2 = Vector2.ZERO
var player: Node2D = null

func _ready() -> void:
	max_hp = 3
	super._ready()
	_change_state(State.PATROL)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if player == null or not is_instance_valid(player):
		player = _get_player()

	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.NOTICE:
			_process_notice(delta)
		State.APPROACH:
			_process_approach(delta)
		State.CHARGE:
			_process_charge(delta)
		State.LEAP_ATTACK:
			_process_leap_attack(delta)
		State.RECOVER:
			_process_recover(delta)
		State.DEAD:
			pass

	super._physics_process(delta)

func die() -> void:
	_change_state(State.DEAD)
	super.die()

func _process_patrol(_delta: float) -> void:
	if is_on_wall():
		patrol_direction *= -1.0
	move_horizontal(patrol_direction, patrol_speed)
	if _can_notice_player():
		_change_state(State.NOTICE)

func _process_notice(delta: float) -> void:
	stop_horizontal()
	timer -= delta
	if timer <= 0.0:
		_change_state(State.APPROACH)

func _process_approach(_delta: float) -> void:
	if player == null:
		_change_state(State.PATROL)
		return
	var to_player := player.global_position - global_position
	var distance := absf(to_player.x)
	if distance <= approach_distance:
		_change_state(State.CHARGE)
		return
	var direction := signf(to_player.x)
	move_horizontal(direction, patrol_speed * 1.8)

func _process_charge(delta: float) -> void:
	stop_horizontal()
	timer -= delta
	if timer <= 0.0:
		if player != null:
			leap_target = player.global_position
		else:
			leap_target = global_position + Vector2(120.0 * (1.0 if facing_right else -1.0), 0.0)
		_change_state(State.LEAP_ATTACK)

func _process_leap_attack(_delta: float) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		_change_state(State.RECOVER)

func _process_recover(delta: float) -> void:
	stop_horizontal()
	timer -= delta
	if timer <= 0.0:
		_change_state(State.PATROL)

func _change_state(next_state: State) -> void:
	current_state = next_state
	match current_state:
		State.PATROL:
			exclamation_label.visible = false
			set_state_name("PATROL")
		State.NOTICE:
			exclamation_label.visible = true
			velocity.y = notice_jump_velocity
			timer = notice_time
			set_state_name("NOTICE")
		State.APPROACH:
			exclamation_label.visible = false
			set_state_name("APPROACH")
		State.CHARGE:
			stop_horizontal()
			timer = charge_time
			set_state_name("CHARGE")
		State.LEAP_ATTACK:
			exclamation_label.visible = false
			_start_leap()
			set_state_name("LEAP_ATTACK")
		State.RECOVER:
			timer = recover_time
			set_state_name("RECOVER")
		State.DEAD:
			set_state_name("DEAD")

func _start_leap() -> void:
	var to_target := leap_target - global_position
	var horizontal_direction := signf(to_target.x)
	if absf(horizontal_direction) < 0.01:
		horizontal_direction = 1.0 if facing_right else -1.0
	move_horizontal(horizontal_direction, leap_speed)
	velocity.y = leap_upward_velocity

func _can_notice_player() -> bool:
	if player == null:
		return false
	var to_player := player.global_position - global_position
	if absf(to_player.x) > detect_range:
		return false
	if to_player.x == 0.0:
		return true
	var is_in_facing_side := (to_player.x > 0.0 and facing_right) or (to_player.x < 0.0 and not facing_right)
	return is_in_facing_side

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return null
	return players[0] as Node2D
