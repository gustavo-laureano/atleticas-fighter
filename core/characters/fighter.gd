class_name Fighter
extends CharacterBody2D

# Padrão de tamanho de TODOS os lutadores. Cada personagem pode ter sprites de
# qualquer resolução: o Fighter escala o AnimatedSprite2D para que o frame de
# referência ("idle") fique com BODY_HEIGHT px de altura na tela, encosta os
# pés na origem do nó e monta a hitbox com o mesmo tamanho para todo mundo.
# Por isso a cena do personagem deve ter o nó raiz com scale 1 e todos os
# frames exportados no mesmo canvas, com os pés na mesma linha (ver README).

signal health_changed(current: int, maximum: int)
signal died

const BODY_HEIGHT := 500.0
const HITBOX_SIZE := Vector2(150, 320)
const REFERENCE_ANIMATION := &"idle"

@export var max_health: int = 10

var current_health: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_apply_standard_size()
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


func _apply_standard_size() -> void:
	var reference := sprite.sprite_frames.get_frame_texture(REFERENCE_ANIMATION, 0)
	# Área realmente desenhada do frame de referência (sem a margem transparente).
	var image := reference.get_image()
	if image.is_compressed():
		image.decompress()
	var body := image.get_used_rect()

	sprite.centered = true
	sprite.scale = Vector2.ONE * (BODY_HEIGHT / body.size.y)
	# offset é em pixels da textura: leva o pé (fundo da área desenhada) para y = 0.
	sprite.offset = Vector2(0, reference.get_height() / 2.0 - body.end.y)

	var shape := RectangleShape2D.new()
	shape.size = HITBOX_SIZE
	hitbox.shape = shape
	hitbox.scale = Vector2.ONE
	hitbox.position = Vector2(0, -HITBOX_SIZE.y / 2.0)
