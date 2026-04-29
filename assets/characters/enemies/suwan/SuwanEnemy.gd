extends CharacterBody2D
class_name SuwanEnemy

enum State {
	PATROL,
	NOTICE,
	APPROACH,
	CHARGE,
	LEAP_ATTACK,
	RECOVER,
}

@export var max_hp: int = 3
@export var patrol_speed: float = 40.0
@export var approach_speed: float = 75.0
@export var gravity: float = 980.0
@export var patrol_half_width: float = 120.0
@export var detect_distance: float = 220.0
@export var approach_distance: float = 100.0
@export var notice_hop_velocity: float = -190.0
@export var charge_time: float = 0.5
@export var recover_time: float = 0.45
@export var leap_duration: float = 0.55
@export var leap_apex_height: float = 74.0

@onready var sprite: ColorRect = $Visual
@onready var notice_label: Label = $NoticeLabel

var hp: int
var state: State = State.PATROL
var facing: int = 1
var patrol_center_x: float
var player: CharacterBody2D

var state_timer: float = 0.0
var locked_target_position: Vector2
var leap_velocity_x: float = 0.0


func _ready() -> void:
	hp = max_hp
	patrol_center_x = global_position.x
	notice_label.visible = false
	player = _find_player()
	_add_to_group_if_missing()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()

	_apply_gravity(delta)

	match state:
		State.PATROL:
			_patrol_logic()
		State.NOTICE:
			_notice_logic()
		State.APPROACH:
			_approach_logic()
		State.CHARGE:
			_charge_logic(delta)
		State.LEAP_ATTACK:
			_leap_attack_logic()
		State.RECOVER:
			_recover_logic(delta)

	move_and_slide()

	if state == State.LEAP_ATTACK and is_on_floor():
		_change_state(State.RECOVER)


func _patrol_logic() -> void:
	if _can_notice_player():
		_change_state(State.NOTICE)
		return

	var left_limit := patrol_center_x - patrol_half_width
	var right_limit := patrol_center_x + patrol_half_width

	if global_position.x <= left_limit:
		facing = 1
	elif global_position.x >= right_limit:
		facing = -1

	velocity.x = facing * patrol_speed
	_update_visual_direction()


func _notice_logic() -> void:
	velocity.x = 0.0
	# initial hop once
	if state_timer == 0.0:
		notice_label.visible = true
		velocity.y = notice_hop_velocity
		state_timer = 0.001
		return

	if is_on_floor() and state_timer > 0.0:
		notice_label.visible = false
		_change_state(State.APPROACH)


func _approach_logic() -> void:
	if player == null:
		_change_state(State.PATROL)
		return

	var dx := player.global_position.x - global_position.x
	facing = 1 if dx >= 0.0 else -1
	_update_visual_direction()

	if absf(dx) <= approach_distance:
		velocity.x = 0.0
		_change_state(State.CHARGE)
		return

	velocity.x = facing * approach_speed


func _charge_logic(delta: float) -> void:
	velocity.x = 0.0
	state_timer += delta
	if state_timer >= charge_time:
		_locked_leap_target()
		_begin_leap_attack()


func _leap_attack_logic() -> void:
	velocity.x = leap_velocity_x


func _recover_logic(delta: float) -> void:
	velocity.x = 0.0
	state_timer += delta
	if state_timer >= recover_time:
		_change_state(State.PATROL)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif state != State.NOTICE:
		velocity.y = 0.0


func _can_notice_player() -> bool:
	if player == null:
		return false

	var to_player := player.global_position - global_position
	if to_player.length() > detect_distance:
		return false

	return signf(to_player.x) == float(facing)


func _locked_leap_target() -> void:
	if player == null:
		locked_target_position = global_position + Vector2(facing * approach_distance, 0)
		return
	locked_target_position = player.global_position


func _begin_leap_attack() -> void:
	_change_state(State.LEAP_ATTACK)

	var to_target := locked_target_position - global_position
	facing = 1 if to_target.x >= 0.0 else -1
	_update_visual_direction()

	leap_velocity_x = to_target.x / maxf(leap_duration, 0.01)
	velocity.y = (-2.0 * leap_apex_height) / maxf(leap_duration * 0.5, 0.01)


func _change_state(next_state: State) -> void:
	state = next_state
	state_timer = 0.0


func take_damage(amount: int) -> void:
	hp = max(hp - amount, 0)
	if hp == 0:
		queue_free()


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return null
	return players[0] as CharacterBody2D


func _update_visual_direction() -> void:
	sprite.scale.x = float(facing)
	notice_label.scale.x = float(facing)


func _add_to_group_if_missing() -> void:
	if not is_in_group("enemy"):
		add_to_group("enemy")
