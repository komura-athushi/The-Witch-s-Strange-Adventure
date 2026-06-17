class_name PlayerHUD
extends CanvasLayer

@export var player: Player

@onready var health_display: HeartHealthDisplay = $HealthDisplay

func _ready() -> void:
	if player == null:
		push_error("PlayerHUD requires a Player reference.")
		return

	player.health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(player.current_hp, player.max_hp)

func _exit_tree() -> void:
	if player != null and player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.disconnect(_on_player_health_changed)

func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	health_display.set_health(current_hp, max_hp)
