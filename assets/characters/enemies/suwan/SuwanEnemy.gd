class_name SuwanEnemy
extends BaseEnemy

@export var patrol_direction: float = 1.0
@export var patrol_speed: float = 30.0

func _ready() -> void:
	max_hp = 3
	super._ready()
	set_state_name("PATROL")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if is_on_wall():
		patrol_direction *= -1.0
	move_horizontal(patrol_direction, patrol_speed)
	super._physics_process(delta)

func die() -> void:
	set_state_name("DEAD")
	super.die()
