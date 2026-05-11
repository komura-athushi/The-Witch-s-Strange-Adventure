class_name Player
extends CharacterBody2D

@export var config: PlayerConfig

@export_flags_2d_physics var click_mask: int = 1 << 3
@export var hp: int = 3
@export var invincible_duration: float = 1.0
@export var damage_blink_interval: float = 0.08

@onready var hold_socket: Marker2D = $HoldSocket
@onready var interaction_detector: Area2D = $InteractionDetector
@onready var visual: Node2D = $Visual
@onready var sprite2D = $Visual/AnimatedSprite2D
@onready var throw_prediction_line: ThrowPredictionLine = $ThrowPredictionLine
var nearby_interactables: Array[Node] = []
var held_item: PickupItem = null
var current_hp: int
var _invincible_time_left: float = 0.0
var _blink_time_left: float = 0.0

var ANIM_THRESHOLD = 5.0

func _ready() -> void:
	if config == null:
		config = PlayerConfig.new()
	current_hp = hp
	interaction_detector.body_entered.connect(_on_detector_body_entered)
	interaction_detector.body_exited.connect(_on_detector_body_exited)

func _process(delta: float) -> void:
	_process_damage_invincibility(delta)

func _physics_process(delta: float) -> void:
	_apply_horizontal_movement()
	_apply_vertical_movement(delta)

	_update_animation()
	_update_direction(velocity.x)

	move_and_slide()

func _update_animation() -> void:
	if abs(velocity.x) > ANIM_THRESHOLD:
		sprite2D.animation = "walk"
		sprite2D.play()
	else:
		sprite2D.stop()

func _update_direction(direction_x: float) -> void:
	if direction_x < 0:
		visual.scale.x = -1
	elif direction_x > 0:
		visual.scale.x = 1

func _apply_horizontal_movement() -> void:
	var axis = Input.get_axis("move_left", "move_right")
	velocity.x = axis * config.move_speed

func _apply_vertical_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _get_gravity_value() * delta
		return

	if Input.is_action_just_pressed("jump"):
		velocity.y = config.jump_velocity

func _get_gravity_value() -> float:
	if config.use_project_gravity:
		return float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	return config.gravity

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		var mouse_global := get_global_mouse_position()

		if held_item == null:
			var target := _get_clicked_interactable(mouse_global)
			if target != null and target.has_method("interact"):
				target.interact(self)
		else:
			throw_held_item(mouse_global)

func pick_item(item: PickupItem) -> void:
	if held_item != null:
		return

	held_item = item
	item.pick_up(self)
	throw_prediction_line.set_target_item(item)
	_refresh_nearby_interaction_highlights()

func release_held_item() -> void:
	if held_item == null:
		return

	var item := held_item
	held_item = null
	throw_prediction_line.clear_target_item()
	item.drop_to_world(hold_socket.global_position)
	_refresh_nearby_interaction_highlights()

func throw_held_item(target_global: Vector2) -> void:
	if held_item == null:
		return

	var item := held_item
	held_item = null
	throw_prediction_line.clear_target_item()
	item.throw_to(target_global)
	_refresh_nearby_interaction_highlights()

func get_hold_position(item_offset: Vector2) -> Vector2:
	return hold_socket.global_position + item_offset

func take_damage(amount: int) -> bool:
	if amount <= 0 or is_invincible():
		return false

	current_hp = maxi(current_hp - amount, 0)
	_invincible_time_left = invincible_duration
	_blink_time_left = 0.0
	visual.visible = true
	return true

func is_invincible() -> bool:
	return _invincible_time_left > 0.0

func _process_damage_invincibility(delta: float) -> void:
	if _invincible_time_left <= 0.0:
		visual.visible = true
		return

	_invincible_time_left = maxf(_invincible_time_left - delta, 0.0)
	_blink_time_left -= delta
	if _blink_time_left <= 0.0:
		visual.visible = not visual.visible
		_blink_time_left = damage_blink_interval

	if _invincible_time_left <= 0.0:
		visual.visible = true

func _get_clicked_interactable(mouse_global: Vector2) -> Node:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = mouse_global
	params.collide_with_areas = true
	params.collision_mask = click_mask

	var results := get_world_2d().direct_space_state.intersect_point(params, 8)

	for result in results:
		var area := result.collider as Area2D
		if area == null:
			continue

		var candidate := area.get_parent()
		if candidate in nearby_interactables:
			if candidate.has_method("can_interact") and candidate.can_interact(self):
				return candidate

	return null

func _on_detector_body_entered(body: Node) -> void:
	if body.is_in_group("interactable"):
		if not nearby_interactables.has(body):
			nearby_interactables.append(body)
	_refresh_nearby_interaction_highlights()

func _on_detector_body_exited(body: Node) -> void:
	nearby_interactables.erase(body)
	if body.has_method("set_interaction_highlighted"):
		body.set_interaction_highlighted(false)
	_refresh_nearby_interaction_highlights()

func _refresh_nearby_interaction_highlights() -> void:
	for interactable in nearby_interactables:
		if not is_instance_valid(interactable):
			continue

		if interactable.has_method("set_interaction_highlighted"):
			var highlighted := false
			if interactable.has_method("can_interact"):
				highlighted = interactable.can_interact(self)
			interactable.set_interaction_highlighted(highlighted)
