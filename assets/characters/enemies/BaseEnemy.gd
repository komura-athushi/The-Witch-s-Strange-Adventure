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
@export var move_speed: float = 60.0
@export var patrol_duration: float = 5.0
@export var wait_duration: float = 1.0
@export var death_fade_delay: float = 2.0
@export var fade_duration: float = 0.6
@export var knockback_force: Vector2 = Vector2(180, -90)
@export var throwable_min_speed: float = 140.0
@export_range(0.1, 1.0, 0.05) var throwable_bounce_damping: float = 0.6
@export var allow_repeat_hits_from_same_throwable: bool = false
@export var throwable_hit_cooldown: float = 0.0

@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var state_label: Label = $DebugUI/StateLabel
@onready var hp_label: Label = $DebugUI/HPLabel
@onready var visual: CanvasItem = $Visual

var hp: int
var state: State = State.PATROL
var facing: int = -1
var is_invincible: bool = false

var _state_time: float = 0.0
var _invincible_timer: float = 0.0
var _fade_timer: float = 0.0
var _blink_timer: float = 0.0
var _damaged_end_state: State = State.PATROL
var _throwable_hit_registry: Dictionary = {}


func _ready() -> void:
	hp = max_hp
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	change_state(State.PATROL)
	_update_debug_ui()

func _physics_process(delta: float) -> void:
	_state_time += delta
	_update_invincible(delta)
	_update_state(delta)
	_prune_throwable_registry(delta)
	move_and_slide()
	_update_debug_ui()

func change_state(new_state: State) -> void:
	if state == new_state:
		return

	state = new_state
	_state_time = 0.0

	match state:
		State.PATROL:
			velocity.x = facing * move_speed
		State.WAIT:
			velocity.x = 0.0
		State.DAMAGED:
			_blink_timer = 0.0
		State.DEAD:
			velocity = Vector2.ZERO
			if body_shape:
				body_shape.set_deferred("disabled", true)
			if hitbox:
				hitbox.set_deferred("monitoring", false)
				for child in hitbox.get_children():
					if child is CollisionShape2D:
						child.set_deferred("disabled", true)
		State.FADING:
			velocity = Vector2.ZERO
			_fade_timer = 0.0

func take_damage(amount: int, source: Node = null) -> void:
	if state == State.DEAD or state == State.FADING:
		return
	if is_invincible:
		return

	hp = max(hp - amount, 0)
	is_invincible = true
	_invincible_timer = invincible_time

	var source_dir: float = 0.0
	if source is Node2D:
		source_dir = sign(global_position.x - (source as Node2D).global_position.x)
	if is_zero_approx(source_dir):
		source_dir = -facing

	velocity.x = knockback_force.x * source_dir
	velocity.y = knockback_force.y

	if hp <= 0:
		change_state(State.DEAD)
	else:
		_damaged_end_state = State.PATROL
		change_state(State.DAMAGED)

func _update_state(delta: float) -> void:
	match state:
		State.PATROL:
			velocity.x = facing * move_speed
			velocity.y += _get_gravity_value() * delta
			# 前方が障害物で詰まっていても巡回タイマーは進行させる
			# （move_and_slide 後に速度が0になっても state_time によって必ず遷移する）
			if is_on_wall() and _state_time >= patrol_duration:
				change_state(State.WAIT)
				return
			if _state_time >= patrol_duration:
				change_state(State.WAIT)

		State.WAIT:
			velocity.x = 0.0
			velocity.y += _get_gravity_value() * delta
			if _state_time >= wait_duration:
				facing *= -1
				change_state(State.PATROL)

		State.DAMAGED:
			velocity.y += _get_gravity_value() * delta
			_blink_timer += delta
			if visual:
				visual.modulate = Color(1.0, 0.55, 0.55) if int(_blink_timer * 12.0) % 2 == 0 else Color(1, 1, 1)
			if _state_time >= 0.2:
				if visual:
					visual.modulate = Color(1, 1, 1)
				change_state(_damaged_end_state)

		State.DEAD:
			if _state_time >= death_fade_delay:
				change_state(State.FADING)

		State.FADING:
			_fade_timer += delta
			var alpha := 1.0 - clamp(_fade_timer / max(fade_duration, 0.01), 0.0, 1.0)
			if visual:
				visual.modulate.a = alpha
			if alpha <= 0.0:
				queue_free()

func _on_hitbox_body_entered(body: Node) -> void:
	if state == State.DEAD or state == State.FADING:
		return

	if body.is_in_group("Player"):
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, self)
		return

	if body.is_in_group("Throwable") or body is PickupItem:
		_process_throwable_hit(body)

func _process_throwable_hit(body: Node) -> void:
	if not body is CharacterBody2D:
		return

	var throwable := body as CharacterBody2D
	if throwable.velocity.length() < throwable_min_speed:
		return

	var throwable_id := throwable.get_instance_id()
	if not allow_repeat_hits_from_same_throwable and _throwable_hit_registry.has(throwable_id):
		return

	if allow_repeat_hits_from_same_throwable and throwable_hit_cooldown > 0.0 and _throwable_hit_registry.has(throwable_id):
		if _throwable_hit_registry[throwable_id] > 0.0:
			return

	take_damage(1, throwable)
	_throwable_hit_registry[throwable_id] = throwable_hit_cooldown
	# 投擲物側も横方向に反転 + 減衰させて跳ね返す（縦速度は維持）
	throwable.velocity.x *= -1.0
	throwable.velocity.x *= throwable_bounce_damping

func _prune_throwable_registry(delta: float) -> void:
	if _throwable_hit_registry.is_empty():
		return

	if not allow_repeat_hits_from_same_throwable:
		return

	var to_remove: Array[int] = []
	for throwable_id in _throwable_hit_registry.keys():
		var time_left: float = float(_throwable_hit_registry[throwable_id]) - delta
		if time_left <= 0.0:
			to_remove.append(throwable_id)
		else:
			_throwable_hit_registry[throwable_id] = time_left

	for throwable_id in to_remove:
		_throwable_hit_registry.erase(throwable_id)

func _update_invincible(delta: float) -> void:
	if not is_invincible:
		return

	_invincible_timer -= delta
	if _invincible_timer <= 0.0:
		is_invincible = false

func _update_debug_ui() -> void:
	state_label.text = "STATE: %s" % _state_name(state)
	hp_label.text = "HP: %d / %d" % [hp, max_hp]

func _state_name(target_state: State) -> String:
	match target_state:
		State.PATROL:
			return "PATROL"
		State.WAIT:
			return "WAIT"
		State.DAMAGED:
			return "DAMAGED"
		State.DEAD:
			return "DEAD"
		State.FADING:
			return "FADING"
		_:
			return "UNKNOWN"

func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))
