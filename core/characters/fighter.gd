class_name Fighter
extends CharacterBody2D

# Padrão de tamanho de TODOS os lutadores. Cada personagem pode ter sprites de
# qualquer resolução: o Fighter escala o AnimatedSprite2D para que o frame de
# referência ("idle") fique com BODY_HEIGHT px de altura na tela e, a cada
# frame, encosta o fundo do desenho na origem do nó (os pés no chão).
# Por isso a cena do personagem deve ter o nó raiz com scale 1 e todos os
# frames com a mesma largura e o corpo centralizado nela (ver README).
#
# Existem três "caixas" de colisão:
# - CollisionShape2D (retângulo): corpo físico, para andar, pular e limitar
#   quanto um lutador entra no outro. A largura é a do desenho do idle (até a
#   ponta do punho, nos dois lados) reduzida por MAX_OVERLAP: com 0.5, os
#   desenhos podem se sobrepor até metade dessa largura, e não mais que isso.
#   Não muda a cada frame de propósito, para o chão e o empurrão não
#   "tremerem". Se não existir na cena, é criado aqui.
# - Hurtbox (Area2D criada aqui): onde o lutador APANHA. Segue o desenho do
#   frame atual, pixel a pixel (ver SpriteShapes).
# - AttackBox (Area2D criada aqui): onde o golpe ACERTA. É a parte do desenho
#   que fica na frente do corpo, e só existe enquanto _is_attack_frame() for true.
# Para ver tudo isso no jogo: Depurar > Formas de Colisão Visíveis.

signal health_changed(current: int, maximum: int)
signal died

const BODY_HEIGHT := 500.0
const HITBOX_SIZE := Vector2(150, 320)
const REFERENCE_ANIMATION := &"idle"
# A AttackBox só considera o desenho a partir dessa distância do centro do
# corpo, na direção para onde o lutador olha (punho, pé, etc.).
const ATTACK_FRONT_X := HITBOX_SIZE.x / 2.0
# Duração de TODO golpe (soco em pé, ataque agachado...), em segundos, não
# importa quantos frames a animação tenha: os frames dividem esse tempo.
const ATTACK_DURATION := 0.18
# Quanto um lutador pode entrar no outro, em fração da largura do desenho.
# 0 = só se encostam, 0.5 = até metade, 1 = atravessa.
const MAX_OVERLAP := 0.5
# Camada de física 3 ("hurtbox" em Projeto > Configurações > Nomes de Camadas).
const HURTBOX_LAYER := 1 << 2

@export var max_health: int = 10
@export var attack_damage: int = 1
# Qual jogador controla este lutador. Define o prefixo das ações de input
# (Projeto > Configurações > Mapa de Entrada): o jogador 1 usa "p1_jump",
# "p1_attack"... e o jogador 2 usa "p2_jump", "p2_attack"...
@export_range(1, 2) var player_id: int = 1

var current_health: int = 0

var _hurtbox := Area2D.new()
var _attack_box := Area2D.new()
var _hurtbox_nodes: Array[CollisionShape2D] = []
var _attack_box_nodes: Array[CollisionShape2D] = []
# Formas já calculadas por [textura, lado]: { "body": [...], "attack": [...] }.
var _shape_cache: Dictionary = {}
# [textura, lado, atacando] mostrado agora; evita refazer as formas sem necessidade.
var _current_boxes: Array = []
# Quem já levou dano do golpe atual (um golpe acerta cada alvo uma vez só).
var _already_hit: Array[Fighter] = []
# Área desenhada de cada textura (Rect2), em px da textura.
var _drawn_rects: Dictionary = {}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	_apply_standard_size()
	_create_boxes()
	current_health = max_health
	health_changed.emit(current_health, max_health)


# Roda todo frame em todos os lutadores (as subclasses usam só _physics_process).
func _process(_delta: float) -> void:
	_update_boxes()
	if _is_attack_frame() and current_health > 0:
		_check_hits()


# Nome da ação de input deste jogador. Ex.: action("jump") -> "p2_jump".
func action(action_name: String) -> String:
	return "p%d_%s" % [player_id, action_name]


func take_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	_set_health(current_health - amount)
	# Pisca vermelho para mostrar que apanhou.
	sprite.modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)


func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	_set_health(current_health + amount)


func die() -> void:
	died.emit()
	set_physics_process(false)


# Subclasses: retorne true enquanto o frame atual for um golpe.
func _is_attack_frame() -> bool:
	return false


# Subclasses: chame no início de cada golpe, para ele poder acertar de novo.
func begin_attack() -> void:
	_already_hit.clear()


# Toca um golpe com a duração padrão (ATTACK_DURATION). `frames` escolhe quais
# frames da animação mostrar; vazio = todos. Use com await.
func play_attack(animation: StringName, frames: Array[int] = []) -> void:
	var shown: Array[int] = frames.duplicate()
	if shown.is_empty():
		shown.assign(range(sprite.sprite_frames.get_frame_count(animation)))
	begin_attack()
	sprite.play(animation)
	sprite.pause()
	for frame in shown:
		sprite.frame = frame
		await get_tree().create_timer(ATTACK_DURATION / shown.size()).timeout


func _set_health(value: int) -> void:
	var new_health := clampi(value, 0, max_health)
	if new_health == current_health:
		return
	current_health = new_health
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		die()


func _check_hits() -> void:
	for area in _attack_box.get_overlapping_areas():
		var target := area.get_parent() as Fighter
		if target == null or target == self or target in _already_hit:
			continue
		_already_hit.append(target)
		target.take_damage(attack_damage)


func _apply_standard_size() -> void:
	var reference := sprite.sprite_frames.get_frame_texture(REFERENCE_ANIMATION, 0)
	var body := _drawn_rect(reference)

	sprite.centered = true
	sprite.scale = Vector2.ONE * (BODY_HEIGHT / body.size.y)
	# Cada frame tem a altura do próprio desenho: a cada troca de frame, o pé
	# (fundo do desenho) desse frame é levado para y = 0.
	sprite.frame_changed.connect(_align_frame)
	sprite.animation_changed.connect(_align_frame)
	_align_frame()

	if hitbox == null:
		hitbox = CollisionShape2D.new()
		hitbox.name = "CollisionShape2D"
		add_child(hitbox)

	# Ponta da frente do desenho (o personagem olha para a direita), em px do lutador.
	var front := (body.end.x - reference.get_width() / 2.0) * sprite.scale.x + sprite.position.x
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2.0 * front * (1.0 - MAX_OVERLAP), HITBOX_SIZE.y)
	hitbox.shape = shape
	hitbox.scale = Vector2.ONE
	hitbox.position = Vector2(0, -HITBOX_SIZE.y / 2.0)


# Área realmente desenhada da textura (sem a margem transparente). Usa o mesmo
# contorno da hurtbox, que ignora pixels quase transparentes (brilho, sombra
# suave): eles não podem mudar o tamanho nem a altura do personagem.
func _drawn_rect(texture: Texture2D) -> Rect2:
	if _drawn_rects.has(texture):
		return _drawn_rects[texture]
	var points := PackedVector2Array()
	for outline in SpriteShapes.outlines(texture):
		points.append_array(outline)
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	_drawn_rects[texture] = rect
	return rect


# offset (em px da textura) que coloca o fundo do desenho deste frame em y = 0.
func _frame_offset(texture: Texture2D) -> Vector2:
	return Vector2(0, texture.get_height() / 2.0 - _drawn_rect(texture).end.y)


func _align_frame() -> void:
	sprite.offset = _frame_offset(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))


func _create_boxes() -> void:
	# A hurtbox só "existe" para ser encontrada; quem procura é a AttackBox.
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = HURTBOX_LAYER
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	add_child(_hurtbox)

	_attack_box.name = "AttackBox"
	_attack_box.collision_layer = 0
	_attack_box.collision_mask = HURTBOX_LAYER
	_attack_box.monitorable = false
	add_child(_attack_box)

	# Calcula todos os frames agora, para não engasgar no meio da luta.
	var canvas_width := sprite.sprite_frames.get_frame_texture(REFERENCE_ANIMATION, 0).get_width()
	for animation in sprite.sprite_frames.get_animation_names():
		for frame in sprite.sprite_frames.get_frame_count(animation):
			var texture := sprite.sprite_frames.get_frame_texture(animation, frame)
			# A altura de cada frame é a do próprio desenho, mas a largura é fixa:
			# o corpo fica no meio da imagem, então outra largura desloca o
			# personagem para o lado (ver README).
			if texture.get_width() != canvas_width:
				push_warning("%s: frame %d de \"%s\" tem %d px de largura, mas o idle tem %d. Exporte todos os frames com a mesma largura." % [
					name, frame, animation, texture.get_width(), canvas_width])
			_shapes_for(texture, 1.0)
			_shapes_for(texture, -1.0)


func _update_boxes() -> void:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var side := -1.0 if sprite.flip_h else 1.0
	var attacking := _is_attack_frame() and current_health > 0
	var key := [texture, side, attacking, current_health > 0]
	if key == _current_boxes:
		return
	_current_boxes = key

	var shapes: Dictionary = _shapes_for(texture, side)
	var no_shapes: Array[Shape2D] = []
	_set_area_shapes(_hurtbox, _hurtbox_nodes, shapes.body if current_health > 0 else no_shapes)
	_set_area_shapes(_attack_box, _attack_box_nodes, shapes.attack if attacking else no_shapes)


# Reaproveita os CollisionShape2D da área: troca só a forma de cada um e
# desliga os que sobram.
func _set_area_shapes(area: Area2D, nodes: Array[CollisionShape2D], shapes: Array[Shape2D]) -> void:
	while nodes.size() < shapes.size():
		var node := CollisionShape2D.new()
		area.add_child(node)
		nodes.append(node)
	for i in nodes.size():
		var active := i < shapes.size()
		if active:
			nodes[i].shape = shapes[i]
		nodes[i].set_deferred("disabled", not active)


func _shapes_for(texture: Texture2D, side: float) -> Dictionary:
	var key := [texture, side]
	if _shape_cache.has(key):
		return _shape_cache[key]

	var texture_size := texture.get_size()
	# Tudo que está na frente do corpo (olhando para a direita).
	var front := PackedVector2Array([
		Vector2(ATTACK_FRONT_X, -10000), Vector2(10000, -10000),
		Vector2(10000, 10000), Vector2(ATTACK_FRONT_X, 10000),
	])
	var body: Array[Shape2D] = []
	var attack: Array[Shape2D] = []
	for outline in SpriteShapes.outlines(texture):
		# Pixels da textura -> coordenadas do lutador (mesma conta do AnimatedSprite2D).
		var polygon := PackedVector2Array()
		for point in outline:
			polygon.append((point - texture_size / 2.0 + _frame_offset(texture)) * sprite.scale + sprite.position)
		var whole: Array[PackedVector2Array] = [polygon]
		body.append_array(_to_convex_shapes(whole, side))
		attack.append_array(_to_convex_shapes(Geometry2D.intersect_polygons(polygon, front), side))

	var result := {"body": body, "attack": attack}
	_shape_cache[key] = result
	return result


# A física só aceita polígonos convexos: quebra o contorno em pedaços convexos
# e espelha para o lado esquerdo quando side = -1.
func _to_convex_shapes(polygons: Array[PackedVector2Array], side: float) -> Array[Shape2D]:
	var shapes: Array[Shape2D] = []
	for original in polygons:
		var polygon := original.duplicate()
		if side < 0:
			for i in polygon.size():
				polygon[i] = Vector2(-polygon[i].x, polygon[i].y)
		var parts := Geometry2D.decompose_polygon_in_convex(polygon)
		if parts.is_empty():
			# Contorno estranho (ex.: se cruza): usa o "envelope" dele.
			parts = [Geometry2D.convex_hull(polygon)]
		for part in parts:
			var shape := ConvexPolygonShape2D.new()
			shape.set_point_cloud(part)
			shapes.append(shape)
	return shapes
