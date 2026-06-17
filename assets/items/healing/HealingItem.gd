class_name HealingItem
extends Item

@export_range(1, 999, 1) var heal_amount: int = 1


func can_collect(collector: Node) -> bool:
	if not super(collector):
		return false

	var player := collector as Player
	if player == null:
		return false

	return player.current_hp > 0 and player.current_hp < player.max_hp


func apply_effect(collector: Node) -> bool:
	var player := collector as Player
	if player == null:
		return false

	return player.heal(heal_amount)
