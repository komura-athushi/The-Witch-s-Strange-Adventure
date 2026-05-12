class_name Enemy
extends CharacterBody2D

@export var hp: int = 3
@export var invincible_duration: float = 0.45
@export var contact_damage: int = 1
@export var death_fade_duration: float = 0.6
@export var damage_blink_interval: float = 0.08
@export var death_blink_interval: float = 0.08

@onready var visual: CanvasItem = $Visual
@onready var player_contact_area: Area2D = $PlayerContactArea

var _current_hp: int
var _invincible_time_left: float = 0.0
var _blink_time_left: float = 0.0
var _death_fade_time: float = 0.0
var _is_dead: bool = false
var _touching_players: Array[Player] = []
var _default_visual_modulate: Color = Color.WHITE

func _ready() -> void:
	_current_hp = hp
	_default_visual_modulate = visual.modulate
	player_contact_area.body_entered.connect(_on_player_contact_body_entered)
	player_contact_area.body_exited.connect(_on_player_contact_body_exited)

func _process(delta: float) -> void:
	if _is_dead:
		_process_death_fade(delta)
		return

	_process_invincibility(delta)
	_damage_touching_players()

func take_damage(amount: int) -> bool:
	if _is_dead or amount <= 0 or is_invincible():
		return false

	_current_hp = maxi(_current_hp - amount, 0)
	if _current_hp == 0:
		_start_death()
	else:
		_start_invincibility()
	return true

func is_invincible() -> bool:
	return _invincible_time_left > 0.0

func is_dead() -> bool:
	return _is_dead

func can_move() -> bool:
	return not _is_dead

func _process_invincibility(delta: float) -> void:
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

func _process_death_fade(delta: float) -> void:
	if death_fade_duration <= 0.0:
		queue_free()
		return

	_death_fade_time += delta
	_blink_time_left -= delta
	if _blink_time_left <= 0.0:
		visual.visible = not visual.visible
		_blink_time_left = death_blink_interval

	var fade_ratio := clampf(_death_fade_time / death_fade_duration, 0.0, 1.0)
	var faded_color := _default_visual_modulate
	faded_color.a = lerpf(_default_visual_modulate.a, 0.0, fade_ratio)
	visual.modulate = faded_color

	if fade_ratio >= 1.0:
		queue_free()

func _start_invincibility() -> void:
	_invincible_time_left = invincible_duration
	_blink_time_left = 0.0
	visual.visible = true

func _start_death() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	visual.visible = true
	visual.modulate = _default_visual_modulate
	_blink_time_left = 0.0
	_disable_player_contact()
	_on_death_started()

func _disable_player_contact() -> void:
	player_contact_area.set_deferred("monitoring", false)
	player_contact_area.set_deferred("monitorable", false)
	for child in player_contact_area.get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape != null:
			collision_shape.set_deferred("disabled", true)
	_touching_players.clear()

func _damage_touching_players() -> void:
	for player in _touching_players:
		if is_instance_valid(player):
			player.take_damage(contact_damage)

func _on_death_started() -> void:
	pass

func _on_player_contact_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null or _touching_players.has(player):
		return

	_touching_players.append(player)

func _on_player_contact_body_exited(body: Node) -> void:
	var player := body as Player
	if player != null:
		_touching_players.erase(player)
