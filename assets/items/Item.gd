class_name Item
extends Area2D

signal collected(item: Item, collector: Node)

@export var consume_on_success: bool = true

var _collection_in_progress: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func can_collect(_collector: Node) -> bool:
	return not _collection_in_progress


func collect(collector: Node) -> bool:
	if not can_collect(collector):
		return false

	_collection_in_progress = true
	if not apply_effect(collector):
		_collection_in_progress = false
		return false

	collected.emit(self, collector)
	_on_collected(collector)

	if consume_on_success:
		_disable_collection()
		queue_free()
	else:
		_collection_in_progress = false

	return true


func apply_effect(_collector: Node) -> bool:
	return false


func _on_collected(_collector: Node) -> void:
	pass


func _on_body_entered(body: Node) -> void:
	collect(body)


func _disable_collection() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
