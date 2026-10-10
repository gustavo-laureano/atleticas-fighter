class_name Basketball
extends Area2D

# Bola do especial da Bravios. Desenhada em código (não há sprite da bola
# solta) e com o tamanho da bola nos frames do especial.

const RADIUS := 44.0
const SPEED := 1100.0
const LIFT := -150.0
const GRAVITY := 900.0
const SPIN := 12.0
const MAX_DISTANCE := 2200.0
const COLOR := Color("e8742a")
const SEAM_COLOR := Color("2a1508")

var thrower: Fighter
var damage := 0
var velocity := Vector2.ZERO
var _travelled := 0.0
# Some ao tocar o chão: o pé de quem arremessou (o especial só sai do chão).
var _floor_y := 0.0


# `direction`: 1 para a direita, -1 para a esquerda.
static func throw(by: Fighter, from: Vector2, direction: float, hit_damage: int) -> Basketball:
	var ball := Basketball.new()
	ball.thrower = by
	ball.damage = hit_damage
	ball.velocity = Vector2(SPEED * direction, LIFT)
	ball._floor_y = by.global_position.y
	by.get_parent().add_child(ball)
	ball.global_position = from
	return ball


func _ready() -> void:
	collision_layer = 0
	collision_mask = Fighter.HURTBOX_LAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	var step := velocity * delta
	position += step
	rotation += SPIN * signf(velocity.x) * delta
	_travelled += step.length()
	if _travelled > MAX_DISTANCE or global_position.y + RADIUS > _floor_y:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent() as Fighter
	if target == null or target == thrower or is_queued_for_deletion():
		return
	if is_instance_valid(thrower):
		thrower.hit(target, damage)
	else:
		target.take_damage(damage)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, COLOR)
	var width := RADIUS * 0.09
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 48, SEAM_COLOR, width, true)
	draw_line(Vector2(-RADIUS, 0), Vector2(RADIUS, 0), SEAM_COLOR, width, true)
	draw_line(Vector2(0, -RADIUS), Vector2(0, RADIUS), SEAM_COLOR, width, true)
	draw_arc(Vector2(-RADIUS * 1.25, 0), RADIUS * 0.85, -0.9, 0.9, 24, SEAM_COLOR, width, true)
	draw_arc(Vector2(RADIUS * 1.25, 0), RADIUS * 0.85, PI - 0.9, PI + 0.9, 24, SEAM_COLOR, width, true)
