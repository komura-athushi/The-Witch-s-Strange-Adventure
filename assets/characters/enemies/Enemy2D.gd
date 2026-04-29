extends CharacterBody2D
class_name Enemy2D

enum State {
	PATROL,
	WAIT,
	HURT,
	DEAD,
	FADING,
}

@export var max_hp: int = 3
@export var contact_damage: int = 1
@export var move_speed: float = 40.0
@export var patrol_duration_sec: float = 5.0
@export var wait_duration_sec: float = 1.0
@export var damage_invincible_sec: float = 1.0
@export var hurt_duration_sec: float = 0.15
@export var knockback_strength: float = 160.0
@export var death_delay_sec: float = 2.0
@export var fade_duration_sec: float = 0.8
@export var debug_visible: bool = true

@onready var sprite: ColorRect = $Visual
@onready var contact_hitbox: Area2D = $ContactHitbox
@onready var projectile_hurtbox: Area2D = $ProjectileHurtbox
@onready var state_label: Label = $DebugLabel

var hp: int
var state: State = State.PATROL
var facing: int = -1
var patrol_timer: float = 0.0
var wait_timer: float = 0.0
var invincible_timer: float = 0.0
var hurt_timer: float = 0.0
var death_timer: float = 0.0
var fade_timer: float = 0.0

func _ready() -> void:
	hp = max_hp
	contact_hitbox.body_entered.connect(_on_contact_body_entered)
	projectile_hurtbox.body_entered.connect(_on_projectile_body_entered)
	change_state(State.PATROL)
	_update_debug_text()
	state_label.visible = debug_visible

func _physics_process(delta: float) -> void:
	if invincible_timer > 0.0:
		invincible_timer -= delta

	match state:
		State.PATROL:
			velocity.x = facing * move_speed
			patrol_timer += delta
			if patrol_timer >= patrol_duration_sec:
				change_state(State.WAIT)

		State.WAIT:
			velocity.x = 0.0
			wait_timer += delta
			if wait_timer >= wait_duration_sec:
				facing *= -1
				scale.x = sign(facing)
				change_state(State.PATROL)

		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			hurt_timer += delta
			if hurt_timer >= hurt_duration_sec:
				change_state(State.PATROL)

		State.DEAD:
			velocity = Vector2.ZERO
			death_timer += delta
			if death_timer >= death_delay_sec:
				change_state(State.FADING)

		State.FADING:
			velocity = Vector2.ZERO
			fade_timer += delta
			var t := clamp(fade_timer / fade_duration_sec, 0.0, 1.0)
			modulate.a = 1.0 - t
			if t >= 1.0:
				queue_free()

	if state != State.DEAD and state != State.FADING:
		velocity.y += _get_gravity_value() * delta

	move_and_slide()
	_update_damage_flash()
	_update_debug_text()

func change_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state

	match state:
		State.PATROL:
			patrol_timer = 0.0
			sprite.color = Color(1, 1, 1)
		State.WAIT:
			wait_timer = 0.0
			velocity.x = 0.0
		State.HURT:
			hurt_timer = 0.0
		State.DEAD:
			death_timer = 0.0
			contact_hitbox.monitoring = false
			projectile_hurtbox.monitoring = false
		State.FADING:
			fade_timer = 0.0

func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0 or hp <= 0:
		return
	if invincible_timer > 0.0:
		return

	hp = max(hp - amount, 0)
	invincible_timer = damage_invincible_sec

	_apply_knockback_from_source(source)
	_play_damage_feedback()

	if hp <= 0:
		change_state(State.DEAD)
	else:
		change_state(State.HURT)

func _apply_knockback_from_source(source: Node) -> void:
	var dir := facing
	if source is Node2D:
		var src := source as Node2D
		dir = sign(global_position.x - src.global_position.x)
	if dir == 0:
		dir = facing
	velocity.x = dir * knockback_strength
	velocity.y = -knockback_strength * 0.35

func _play_damage_feedback() -> void:
	sprite.color = Color(1.0, 0.35, 0.35)

func _update_damage_flash() -> void:
	if invincible_timer <= 0.0:
		sprite.color = Color(1, 1, 1)
		return
	var blink := int(invincible_timer * 18.0) % 2 == 0
	sprite.visible = blink
	if invincible_timer <= 0.05:
		sprite.visible = true

func _on_contact_body_entered(body: Node) -> void:
	if hp <= 0:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage, self)

func _on_projectile_body_entered(body: Node) -> void:
	if hp <= 0:
		return
	if body is PickupItem:
		var item := body as PickupItem
		if item.state == PickupItem.State.THROWN and item.velocity.length() > 25.0:
			take_damage(1, item)

func _update_debug_text() -> void:
	if not debug_visible:
		state_label.visible = false
		return
	state_label.visible = true
	state_label.text = "State: %s\nHP: %d" % [_state_to_string(state), hp]

func _state_to_string(s: State) -> String:
	match s:
		State.PATROL:
			return "PATROL"
		State.WAIT:
			return "WAIT"
		State.HURT:
			return "HURT"
		State.DEAD:
			return "DEAD"
		State.FADING:
			return "FADING"
		_:
			return "UNKNOWN"

func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))
