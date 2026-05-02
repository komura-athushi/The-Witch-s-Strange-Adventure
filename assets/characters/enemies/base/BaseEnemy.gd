class_name BaseEnemy
extends CharacterBody2D

enum State {
	PATROL,
	WAIT,
	DAMAGED,
	DEAD,
	FADING,
}

@export var max_hp: int = 3
@export var contact_damage: int = 1
@export var invincible_time: float = 1.0
@export var move_speed: float = 50.0
@export var patrol_duration: float = 5.0
@export var wait_duration: float = 1.0
@export var throwable_min_speed: float = 140.0
@export var throwable_bounce_damping: float = 0.6

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hit_area: Area2D = $HitArea
@onready var hit_collision: CollisionShape2D = $HitArea/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var debug_label: Label = $DebugLabel

var state: State = State.PATROL
var hp: int = 0
var facing_dir: int = -1
var state_timer: float = 0.0
var invincible_timer: float = 0.0
var damage_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	hp = max_hp
	change_state(State.PATROL)
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	add_to_group("Enemy")
	_update_debug_label()

func _physics_process(delta: float) -> void:
	state_timer += delta
	if invincible_timer > 0.0:
		invincible_timer = max(invincible_timer - delta, 0.0)

	velocity.y += _get_gravity_value() * delta

	match state:
		State.PATROL:
			velocity.x = move_speed * facing_dir
			if state_timer >= patrol_duration:
				change_state(State.WAIT)
		State.WAIT:
			velocity.x = 0.0
			if state_timer >= wait_duration:
				facing_dir *= -1
				change_state(State.PATROL)
		State.DAMAGED:
			damage_timer -= delta
			velocity.x = knockback_velocity.x
			if damage_timer <= 0.0:
				change_state(State.PATROL)
		State.DEAD:
			velocity = Vector2.ZERO
			if state_timer >= 2.0:
				change_state(State.FADING)
		State.FADING:
			velocity = Vector2.ZERO
			sprite.modulate.a = max(sprite.modulate.a - delta * 1.5, 0.0)
			if sprite.modulate.a <= 0.01:
				queue_free()

	if state != State.DEAD and state != State.FADING:
		move_and_slide()

	_update_visuals()
	_update_debug_label()

func change_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_timer = 0.0

	match state:
		State.PATROL:
			damage_timer = 0.0
		State.WAIT:
			velocity.x = 0.0
		State.DAMAGED:
			damage_timer = 0.25
		State.DEAD:
			velocity = Vector2.ZERO
			_disable_collision()
		State.FADING:
			velocity = Vector2.ZERO

func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0:
		return
	if state == State.DEAD or state == State.FADING:
		return
	if invincible_timer > 0.0:
		return

	hp = max(hp - amount, 0)
	invincible_timer = invincible_time

	if hp <= 0:
		change_state(State.DEAD)
		return

	var from_position := global_position
	if source != null and source is Node2D:
		from_position = source.global_position
	var away_sign := sign(global_position.x - from_position.x)
	if away_sign == 0:
		away_sign = -facing_dir
	knockback_velocity = Vector2(away_sign * move_speed * 1.25, velocity.y)
	change_state(State.DAMAGED)

func _on_hit_area_body_entered(body: Node) -> void:
	if state == State.DEAD or state == State.FADING:
		return

	if body.is_in_group("Player"):
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, self)
		return

	if _is_valid_throwable(body):
		take_damage(1, body)
		if body is CharacterBody2D:
			var throwable := body as CharacterBody2D
			throwable.velocity.x *= -1.0
			throwable.velocity.x *= throwable_bounce_damping

func _is_valid_throwable(body: Node) -> bool:
	var is_throwable_group := body.is_in_group("Throwable")
	var is_pickup_item := body is PickupItem
	if not is_throwable_group and not is_pickup_item:
		return false
	if not body is CharacterBody2D:
		return false

	var throwable := body as CharacterBody2D
	if abs(throwable.velocity.x) <= 0.01 and abs(throwable.velocity.y) <= 0.01:
		return false
	return throwable.velocity.length() >= throwable_min_speed

func _update_visuals() -> void:
	sprite.flip_h = facing_dir > 0
	if state == State.DAMAGED and int(Time.get_ticks_msec() / 60.0) % 2 == 0:
		sprite.modulate = Color(1.0, 0.45, 0.45, 1.0)
	elif state != State.FADING:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _update_debug_label() -> void:
	debug_label.text = "%s | HP:%d" % [_state_name(state), hp]

func _state_name(value: State) -> String:
	return State.keys()[value]

func _disable_collision() -> void:
	body_collision.disabled = true
	hit_collision.disabled = true

func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))
