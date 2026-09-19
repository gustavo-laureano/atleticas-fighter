class_name Nhagare
extends Fighter

#  arquivo .tres


const SPEED := 300.0
const JUMP_VELOCITY := -400.0
const MAX_JUMPS := 2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var jump_count := MAX_JUMPS
var is_sneaking := false


func die() -> void:
	super()
	sprite.play("die")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	is_sneaking = Input.is_action_pressed("sneak") and is_on_floor()

	if is_on_floor():
		jump_count = MAX_JUMPS

	if Input.is_action_just_pressed("jump") and jump_count > 0:
		velocity.y = JUMP_VELOCITY
		jump_count -= 1

	var direction := Input.get_axis("ui_left", "ui_right")
	var current_speed := SPEED * 0.4 if is_sneaking else SPEED

	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

	if not is_on_floor():
		sprite.play("jump" if velocity.y < 0 else "fall")
	elif is_sneaking:
		sprite.play("sneak_walk" if velocity.x != 0 else "sneak")
	elif velocity.x != 0:
		sprite.play("walk")
	else:
		sprite.play("idle")
