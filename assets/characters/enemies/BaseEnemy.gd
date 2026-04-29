class_name BaseEnemy
extends CharacterBody2D

signal died(enemy: BaseEnemy)
signal damaged(amount: int, current_hp: int)

@export var max_hp: int = 1
@export var contact_damage: int = 1
@export var move_speed: float = 40.0
@export var gravity_scale: float = 1.0
@export var facing_right: bool = true

var hp: int
var is_dead: bool = false
var state_name: String = ""

@onready var debug_label: Label = $DebugLabel

func _ready() -> void:
	hp = max_hp
	update_facing(facing_right)
	_update_debug_label()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	apply_gravity(delta)
	move_and_slide()
	deal_contact_damage_to_player()
	_update_debug_label()

func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	velocity.y += _get_gravity_value() * gravity_scale * delta

func move_horizontal(direction: float, speed: float = move_speed) -> void:
	if is_dead:
		return
	velocity.x = direction * speed
	if absf(direction) > 0.01:
		update_facing(direction > 0)

func stop_horizontal() -> void:
	velocity.x = 0.0

func update_facing(should_face_right: bool) -> void:
	facing_right = should_face_right
	scale.x = absf(scale.x) if facing_right else -absf(scale.x)

func set_state_name(next_state_name: String) -> void:
	state_name = next_state_name
	_update_debug_label()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp -= amount
	damaged.emit(amount, hp)
	if hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	set_state_name("DEAD")
	set_physics_process(false)
	hide()
	died.emit(self)
	queue_free()

func deal_contact_damage_to_player() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as Node
		if body == null:
			continue
		if body.is_in_group("Player") and body.has_method("take_damage"):
			body.take_damage(contact_damage)

func _get_gravity_value() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func _update_debug_label() -> void:
	if debug_label == null:
		return
	debug_label.text = "%s\nHP:%d" % [state_name, hp]
