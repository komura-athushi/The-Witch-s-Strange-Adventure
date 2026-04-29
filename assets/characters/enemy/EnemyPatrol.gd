extends CharacterBody2D
class_name EnemyPatrol

enum State {
	PATROL,
	WAIT,
	DEAD,
	FADING,
}

@export var max_hp: int = 3
@export var move_speed: float = 40.0
@export var patrol_seconds: float = 5.0
@export var wait_seconds: float = 1.0
@export var damage_invincible_seconds: float = 1.0
@export var body_contact_damage: int = 1
@export var moving_object_speed_threshold: float = 80.0
@export var fade_delay_seconds: float = 2.0
@export var fade_duration_seconds: float = 1.0

@onready var state_timer: Timer = $StateTimer
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var fade_delay_timer: Timer = $FadeDelayTimer
@onready var fade_tween_player: AnimationPlayer = $FadeAnimationPlayer
@onready var detector: Area2D = $DamageDetector
@onready var hp_label: Label = $HpLabel

var state: State = State.PATROL
var current_hp: int
var patrol_direction: float = -1.0
var is_damage_invincible: bool = false

func _ready() -> void:
	current_hp = max_hp
	_update_hp_label()
	state_timer.timeout.connect(_on_state_timer_timeout)
	invincible_timer.timeout.connect(_on_invincible_timer_timeout)
	fade_delay_timer.timeout.connect(_on_fade_delay_timer_timeout)
	detector.body_entered.connect(_on_damage_detector_body_entered)
	_enter_patrol_state()

func _physics_process(_delta: float) -> void:
	match state:
		State.PATROL:
			velocity = Vector2(patrol_direction * move_speed, 0.0)
			move_and_slide()
		State.WAIT, State.DEAD, State.FADING:
			velocity = Vector2.ZERO

func _enter_patrol_state() -> void:
	state = State.PATROL
	state_timer.start(patrol_seconds)
	scale.x = sign(patrol_direction)

func _enter_wait_state() -> void:
	state = State.WAIT
	state_timer.start(wait_seconds)

func _on_state_timer_timeout() -> void:
	if state == State.PATROL:
		_enter_wait_state()
	elif state == State.WAIT:
		patrol_direction *= -1.0
		_enter_patrol_state()

func _on_damage_detector_body_entered(body: Node) -> void:
	if state == State.DEAD or state == State.FADING:
		return

	if body.is_in_group("Player") and body.has_method("receive_damage"):
		body.receive_damage(body_contact_damage)
		return

	if body is CharacterBody2D:
		var mover := body as CharacterBody2D
		if mover.velocity.length() >= moving_object_speed_threshold:
			receive_damage(1)

func receive_damage(amount: int = 1) -> void:
	if is_damage_invincible or state == State.DEAD or state == State.FADING:
		return

	current_hp = max(current_hp - amount, 0)
	_update_hp_label()

	if current_hp <= 0:
		_die()
		return

	is_damage_invincible = true
	invincible_timer.start(damage_invincible_seconds)
	modulate = Color(1.0, 0.6, 0.6, 1.0)

func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	set_physics_process(false)
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	fade_delay_timer.start(fade_delay_seconds)

func _on_fade_delay_timer_timeout() -> void:
	state = State.FADING
	fade_tween_player.play("fade_out")

func _on_fade_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"fade_out":
		queue_free()

func _on_invincible_timer_timeout() -> void:
	is_damage_invincible = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)

func _update_hp_label() -> void:
	hp_label.text = "Enemy HP: %d" % current_hp
