class_name Player
extends CharacterBody2D

@export var config: PlayerConfig


@export_flags_2d_physics var click_mask: int = 1 << 3
@export var damage_invincible_sec: float = 3.0

@onready var hold_socket: Marker2D = $HoldSocket
@onready var interaction_detector: Area2D = $InteractionDetector
var nearby_interactables: Array[Node] = []
var held_item: PickupItem = null
var hp: int = 3
var damage_invincible_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	if config == null:
		config = PlayerConfig.new()
	interaction_detector.body_entered.connect(_on_detector_body_entered)
	interaction_detector.body_exited.connect(_on_detector_body_exited)

func _physics_process(delta: float) -> void:
	if damage_invincible_timer > 0.0:
		damage_invincible_timer -= delta

	_apply_horizontal_movement()
	_apply_vertical_movement(delta)

	move_and_slide()

# 横移動
func _apply_horizontal_movement() -> void:
	var axis = Input.get_axis("move_left", "move_right")
	velocity.x = axis * config.move_speed

# 縦移動
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

func release_held_item() -> void:
	if held_item == null:
		return

	var item := held_item
	held_item = null
	item.drop_to_world(hold_socket.global_position)

func throw_held_item(target_global: Vector2) -> void:
	if held_item == null:
		return

	var item := held_item
	held_item = null
	item.throw_to(target_global)

func get_hold_position(item_offset: Vector2) -> Vector2:
	return hold_socket.global_position + item_offset

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

func _on_detector_body_exited(body: Node) -> void:
	nearby_interactables.erase(body)

func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0:
		return
	if damage_invincible_timer > 0.0:
		return

	hp = max(hp - amount, 0)
	damage_invincible_timer = damage_invincible_sec
	modulate = Color(1.0, 0.6, 0.6)
	await get_tree().create_timer(0.12).timeout
	modulate = Color(1, 1, 1)
