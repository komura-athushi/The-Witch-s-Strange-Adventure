class_name Player
extends CharacterBody2D

@export var config: PlayerConfig

func _ready() -> void:
	if config == null:
		config = PlayerConfig.new()

func _physics_process(delta: float) -> void:

	_apply_horizontal_movement()
	_apply_vertical_movement(delta)

	move_and_slide()

# 横移動
func _apply_horizontal_movement() -> void:
	var axis = Input.get_axis("move_left", "move_right")
	velocity.x = axis * config.move_speed

# 盾移動
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
