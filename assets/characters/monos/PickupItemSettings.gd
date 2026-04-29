extends Resource
class_name PickupItemSettings

@export var texture: Texture2D
@export var sprite_scale: Vector2 = Vector2.ONE
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var body_shape_size: Vector2 = Vector2(20, 234)
@export var body_shape_scale: Vector2 = Vector2(11.719998, 1)
@export var clickable_shape_size: Vector2 = Vector2(20, 253)
@export var clickable_shape_scale: Vector2 = Vector2(12.519998, 1)

@export_flags_2d_physics var world_collision_mask: int = 1
@export var throw_speed: float = 520.0
@export_range(0.1, 3.0, 0.1) var throw_weight: float = 1.0
@export var friction: float = 0.99
