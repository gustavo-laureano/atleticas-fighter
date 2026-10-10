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
signal special_changed(current: int, maximum: int)
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
# Recuperação (como no Street Fighter): depois de um golpe o lutador fica
# parado na pose, sem atacar nem andar, e apertar ataque nesse tempo não faz
# nada. É o que impede ficar apertando sem parar. Encadear o próximo golpe
# DURANTE o atual (combo) continua valendo.
const ATTACK_RECOVERY := 0.2
# Recuperação maior depois do último golpe de um combo completo.
const COMBO_RECOVERY := 0.5
# Agachar e levantar: depois de trocar de postura, ela fica travada por esse
# tempo. Apertar e soltar rápido não faz o lutador ficar subindo e descendo.
const CROUCH_LOCK := 0.25
# Quanto um lutador pode entrar no outro, em fração da largura do desenho.
# 0 = só se encostam, 0.5 = até metade, 1 = atravessa.
const MAX_OVERLAP := 0.5
# Camada de física 3 ("hurtbox" em Projeto > Configurações > Nomes de Camadas).
const HURTBOX_LAYER := 1 << 2
# Barra de especial (Super Gauge, como no Street Fighter): começa vazia, enche
# ao acertar golpes e ao apanhar, e o especial só sai com ela cheia.
const SPECIAL_MAX := 100
const SPECIAL_GAIN_ON_HIT := 15
const SPECIAL_GAIN_ON_DAMAGE := 10
# Quanto tempo a pose de aterrissagem ("land") aparece ao tocar o chão.
const LAND_MS := 120

@export var max_health: int = 10
@export var attack_damage: int = 1
# Qual jogador controla este lutador. Define o prefixo das ações de input
# (Projeto > Configurações > Mapa de Entrada): o jogador 1 usa "p1_jump",
# "p1_attack"... e o jogador 2 usa "p2_jump", "p2_attack"...
@export_range(1, 2) var player_id: int = 1

var current_health: int = 0
var current_special: int = 0

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
# Dano do golpe atual (definido em begin_attack).
var _attack_damage_now := 0
# Área desenhada de cada textura (Rect2), em px da textura.
var _drawn_rects: Dictionary = {}
# Até quando (Time.get_ticks_msec) o lutador está em recuperação.
var _recovery_until_ms := 0
# Postura atual (agachado ou não) e até quando ela está travada.
var _crouching := false
var _crouch_locked_until_ms := 0
var _was_on_floor := true
var _land_until_ms := 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	_apply_standard_size()
	_create_boxes()
	current_health = max_health
	health_changed.emit(current_health, max_health)
	special_changed.emit(current_special, SPECIAL_MAX)


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
	gain_special(SPECIAL_GAIN_ON_DAMAGE)
	# Pisca vermelho para mostrar que apanhou.
	sprite.modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)


func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	_set_health(current_health + amount)


func gain_special(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	_set_special(current_special + amount)


func is_special_ready() -> bool:
	return current_special >= SPECIAL_MAX


# Gasta a barra inteira. Retorna false (e não gasta) se ela não estava cheia.
func spend_special() -> bool:
	if not is_special_ready():
		return false
	_set_special(0)
	return true


func die() -> void:
	died.emit()
	# Para de ler os controles (o _physics_process da subclasse), mas o corpo
	# continua sob gravidade: quem morre no ar cai até o chão.
	set_physics_process(false)
	get_tree().physics_frame.connect(_fall_while_dead)


func _fall_while_dead() -> void:
	velocity.x = move_toward(velocity.x, 0, 20.0)
	if not is_on_floor():
		velocity += get_gravity() * get_physics_process_delta_time()
	move_and_slide()


# Subclasses: retorne true enquanto o frame atual for um golpe.
func _is_attack_frame() -> bool:
	return false


# Subclasses: chame no início de cada golpe, para ele poder acertar de novo.
# `damage` < 0 usa o attack_damage do lutador.
func begin_attack(damage := -1) -> void:
	_already_hit.clear()
	_attack_damage_now = attack_damage if damage < 0 else damage


# Toca um golpe que dura `duration` segundos e, no fim, entra em recuperação
# (ATTACK_RECOVERY). `frames` escolhe quais frames da animação mostrar;
# vazio = todos. `damage` < 0 usa o attack_damage. Use com await.
# O tempo é dividido pela "Duração" relativa de cada frame no SpriteFrames:
# um frame com 2.0 fica o dobro do tempo de um com 1.0.
func play_attack(animation: StringName, frames: Array[int] = [], duration := ATTACK_DURATION, damage := -1) -> void:
	var shown: Array[int] = frames.duplicate()
	if shown.is_empty():
		shown.assign(range(sprite.sprite_frames.get_frame_count(animation)))
	var total_weight := 0.0
	for frame in shown:
		total_weight += sprite.sprite_frames.get_frame_duration(animation, frame)
	# Morto não golpeia: um combo em andamento não pode trocar a animação de morte.
	if current_health <= 0:
		return
	begin_attack(damage)
	sprite.play(animation)
	sprite.pause()
	for frame in shown:
		if current_health <= 0:
			return
		sprite.frame = frame
		var weight := sprite.sprite_frames.get_frame_duration(animation, frame)
		await get_tree().create_timer(duration * weight / total_weight).timeout
	start_recovery(ATTACK_RECOVERY)


# Deixa o lutador em recuperação por `seconds` (nunca encurta uma já em andamento).
func start_recovery(seconds: float) -> void:
	_recovery_until_ms = maxi(_recovery_until_ms, Time.get_ticks_msec() + roundi(seconds * 1000.0))


func is_recovering() -> bool:
	return Time.get_ticks_msec() < _recovery_until_ms


# Subclasses: chame todo frame com o botão de agachar e use o retorno como
# "está agachado". Só troca de postura depois de CROUCH_LOCK; no ar nunca
# fica agachado (e sair do chão não tem trava).
func update_crouch(wants_to_crouch: bool) -> bool:
	if not is_on_floor():
		_crouching = false
	elif wants_to_crouch != _crouching and Time.get_ticks_msec() >= _crouch_locked_until_ms:
		_crouching = wants_to_crouch
		_crouch_locked_until_ms = Time.get_ticks_msec() + roundi(CROUCH_LOCK * 1000.0)
	return _crouching


# Subclasses: chame uma vez por frame, depois do move_and_slide. Retorna true
# durante LAND_MS depois de tocar o chão (hora de mostrar a pose "land").
func update_landing() -> bool:
	if is_on_floor() and not _was_on_floor:
		_land_until_ms = Time.get_ticks_msec() + LAND_MS
	_was_on_floor = is_on_floor()
	return is_on_floor() and Time.get_ticks_msec() < _land_until_ms


# Começa a animação do zero (ex.: cada pulo, inclusive o segundo, no ar).
func restart_animation(animation: StringName) -> void:
	sprite.play(animation)
	sprite.frame = 0


# Use no lugar de sprite.play() quando chamar todo frame. No Godot 4, play()
# numa animação sem loop que já terminou recomeça do início: o pulo tocaria
# de novo no meio do ar.
func play_animation(animation: StringName) -> void:
	if sprite.animation != animation or not sprite.is_playing() and sprite.sprite_frames.get_animation_loop(animation):
		sprite.play(animation)


func _set_health(value: int) -> void:
	var new_health := clampi(value, 0, max_health)
	if new_health == current_health:
		return
	current_health = new_health
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		die()


func _set_special(value: int) -> void:
	var new_special := clampi(value, 0, SPECIAL_MAX)
	if new_special == current_special:
		return
	current_special = new_special
	special_changed.emit(current_special, SPECIAL_MAX)


func _check_hits() -> void:
	for area in _attack_box.get_overlapping_areas():
		var target := area.get_parent() as Fighter
		if target == null or target == self or target in _already_hit:
			continue
		_already_hit.append(target)
		target.take_damage(_attack_damage_now)
		gain_special(SPECIAL_GAIN_ON_HIT)


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
