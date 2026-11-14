class_name Basketball
extends Area2D

# Bola do especial da Bravios: sprite objects/bola_basquete/bola_basquete.png
# em chamas, em linha reta. O fogo é pixel-art gerado por tools/gerar_fogo.py
# (fogo_rastro.png e fogo_explosao.png).

const BALL_TEXTURE := preload("res://objects/bola_basquete/bola_basquete.png")
const TRAIL_TEXTURE := preload("res://objects/bola_basquete/fogo_rastro.png")
const BLAST_TEXTURE := preload("res://objects/bola_basquete/fogo_explosao.png")

const RADIUS := 37.0
const SPEED := 1100.0
const SPIN := 10.0
const MAX_DISTANCE := 2200.0

# Medidas em "pixels de arte": a bola ocupa 52 px nos sprites de fogo, e a
# bola na tela tem 2 * RADIUS, então um pixel de arte = PIXEL_SCALE na tela.
const ART_BALL_SIZE := 52.0
const PIXEL_SCALE := RADIUS * 2.0 / ART_BALL_SIZE
# A bola ocupa 1550 de 2048 px na imagem original (o resto é transparente).
const BALL_TEXTURE_FILL := 1550.0 / 2048.0
const TRAIL_FRAME := Vector2i(144, 96)
const TRAIL_BALL_X := 104.0  # centro da bola dentro do quadro do rastro
const BLAST_FRAME := Vector2i(128, 128)
const FPS := 20.0

var thrower: Fighter
var damage := 0
var knockback := 0.0
var velocity := Vector2.ZERO
var _travelled := 0.0
var _ball: Sprite2D

static var _trail_frames: SpriteFrames
static var _blast_frames: SpriteFrames


# `direction`: 1 para a direita, -1 para a esquerda.
static func throw(by: Fighter, from: Vector2, direction: float, hit_damage: int, hit_knockback := 0.0) -> Basketball:
	var ball := Basketball.new()
	ball.knockback = hit_knockback
	ball.thrower = by
	ball.damage = hit_damage
	ball.velocity = Vector2(SPEED * direction, 0.0)
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

	var dir := signf(velocity.x)

	# Rastro de fogo atrás da bola (o quadro foi desenhado com a bola à direita).
	var fire := AnimatedSprite2D.new()
	fire.sprite_frames = _get_frames(TRAIL_TEXTURE, TRAIL_FRAME, true)
	fire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fire.scale = Vector2(PIXEL_SCALE * dir, PIXEL_SCALE)
	fire.offset = Vector2(TRAIL_FRAME.x * 0.5 - TRAIL_BALL_X, 0.0)
	add_child(fire)
	fire.play(&"fire")

	_ball = Sprite2D.new()
	_ball.texture = BALL_TEXTURE
	_ball.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball.scale = Vector2.ONE * (RADIUS * 2.0 / (BALL_TEXTURE.get_width() * BALL_TEXTURE_FILL))
	add_child(_ball)

	add_child(_make_sparks(dir))


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	position += step
	_ball.rotation += SPIN * signf(velocity.x) * delta
	_travelled += step.length()
	if _travelled > MAX_DISTANCE:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent() as Fighter
	if target == null or target == thrower or is_queued_for_deletion():
		return
	if is_instance_valid(thrower):
		thrower.hit(target, damage, knockback, signf(velocity.x))
	else:
		target.take_damage(damage)
	_explode()
	queue_free()


# Explosão de fogo no impacto; independente da bola (que some).
func _explode() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var blast := AnimatedSprite2D.new()
	blast.sprite_frames = _get_frames(BLAST_TEXTURE, BLAST_FRAME, false)
	blast.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blast.scale = Vector2.ONE * PIXEL_SCALE * 1.4
	blast.animation_finished.connect(blast.queue_free)
	parent.add_child(blast)
	blast.global_position = global_position
	blast.play(&"fire")


# Faíscas de pixel soltas pelo caminho, para trás, em coordenadas globais.
func _make_sparks(dir: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.amount = 22
	p.lifetime = 0.55
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = RADIUS * 0.8
	p.direction = Vector2(-dir, -0.25)
	p.spread = 35.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 380.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1.0))
	shrink.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.94, 0.6), Color(1.0, 0.55, 0.12), Color(0.7, 0.12, 0.08, 0.0),
	])
	p.color_ramp = ramp
	return p


# Fatia a tira horizontal de quadros em um SpriteFrames (cacheado).
static func _get_frames(sheet: Texture2D, frame_size: Vector2i, loop: bool) -> SpriteFrames:
	var cache := _trail_frames if loop else _blast_frames
	if cache != null:
		return cache
	cache = SpriteFrames.new()
	cache.set_animation_loop(&"default", loop)
	cache.rename_animation(&"default", &"fire")
	cache.set_animation_speed(&"fire", FPS)
	cache.set_animation_loop(&"fire", loop)
	for i in sheet.get_width() / frame_size.x:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size.x, 0, frame_size.x, frame_size.y)
		cache.add_frame(&"fire", atlas)
	if loop:
		_trail_frames = cache
	else:
		_blast_frames = cache
	return cache
