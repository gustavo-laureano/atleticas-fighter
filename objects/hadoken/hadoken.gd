extends Area2D


@export var speed: float = 200
@export var damage: int = 10
var direction := Vector2.ZERO

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _set_direction(dir: Vector2):
	direction = dir

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(10)
