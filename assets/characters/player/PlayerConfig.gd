class_name PlayerConfig
extends Resource

@export_group("Move")
# 左右の移動速度尾
@export var move_speed: float = 220.0

@export_group("Jump")
# ジャンプ
@export var jump_velocity: float = -460.0
# プロジェクトの重力を使用するならtrue
@export var use_project_gravity: bool = true
# 重力
@export var gravity: float = 980.0
