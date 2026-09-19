class_name Fighter
extends CharacterBody2D


signal health_changed(current: int, maximum: int)
signal died

@export var max_health: int = 10

var current_health: int = 0


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	_set_health(current_health - amount)


func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	_set_health(current_health + amount)


func _set_health(value: int) -> void:
	var new_health := clampi(value, 0, max_health)
	if new_health == current_health:
		return
	current_health = new_health
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		die()


func die() -> void:
	died.emit()
	set_physics_process(false)
