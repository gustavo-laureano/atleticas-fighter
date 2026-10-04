extends Control

# Barras de vida no estilo Street Fighter / King of Fighters (referência em
# referencia/life bar.png): rosto e nome de cada lutador nas pontas, barras
# saindo do centro, caixa "KO" no meio e o tempo da luta embaixo dela.
# Tudo é desenhado aqui no _draw(), então não depende de imagens prontas:
# cada lutador aparece com o rosto e o nome do personagem escolhido.

signal time_up

const FONT := preload("res://assets/fonts/pixelta/Pixelta.ttf")
const ROUND_TIME := 99

# Medidas em px da tela (viewport 1920 x 1080).
const MARGIN := Vector2(36, 26)
const FACE_SIZE := 116
const BAR_HEIGHT := 40
const BAR_TOP := 46
const KO_SIZE := Vector2(112, 64)
const BORDER := 4

const COLOR_OUTLINE := Color("0b0b10")
const COLOR_FRAME := Color("c9ccd6")
const COLOR_EMPTY := Color("3a0f12")
const COLOR_TRAIL := Color("e9c43b")
const COLOR_FILL := Color("2fa844")
const COLOR_FILL_LIGHT := Color("7be36f")
const COLOR_FILL_DARK := Color("1d6b2c")
const COLOR_KO_BORDER := Color("2b6ef0")
const COLOR_KO_BG := Color("101828")
const COLOR_KO_TEXT := Color("ff4a2a")

# Recorte automático do rosto (frações da altura do desenho do portrait).
const FACE_BAND := 0.06
const FACE_SIDE := 0.24
const FACE_FORWARD := 0.12

var _names: Array[String] = ["", ""]
var _faces: Array[Texture2D] = [null, null]
# Vida atual (0..1) e a faixa amarela que "segue" a vida depois de um dano.
var _health: Array[float] = [1.0, 1.0]
var _trail: Array[float] = [1.0, 1.0]
var _trail_tweens: Array[Tween] = [null, null]
var _time_left := float(ROUND_TIME)


func setup_player(index: int, data: CharacterData) -> void:
	_names[index] = data.display_name.to_upper()
	_faces[index] = data.face if data.face else _auto_face(data.portrait)
	queue_redraw()


func set_health(current: int, maximum: int, index: int) -> void:
	if maximum <= 0:
		return
	var ratio := clampf(float(current) / maximum, 0.0, 1.0)
	_health[index] = ratio
	if ratio > _trail[index]:
		_trail[index] = ratio
	else:
		# Como nos jogos de luta: o pedaço perdido fica amarelo um instante e
		# depois desce até a vida atual.
		if _trail_tweens[index]:
			_trail_tweens[index].kill()
		var tween := create_tween()
		tween.tween_interval(0.4)
		tween.tween_method(_set_trail.bind(index), _trail[index], ratio, 0.35)
		_trail_tweens[index] = tween
	queue_redraw()


func _set_trail(value: float, index: int) -> void:
	_trail[index] = value
	queue_redraw()


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	var before := ceili(_time_left)
	_time_left = maxf(_time_left - delta, 0.0)
	if ceili(_time_left) != before:
		queue_redraw()
	if _time_left == 0.0:
		time_up.emit()


func _draw() -> void:
	var center := size.x / 2.0
	for index in 2:
		_draw_side(index, center)
	_draw_ko_and_timer(center)


func _draw_side(index: int, center: float) -> void:
	var right_side := index == 1
	var face_x := size.x - MARGIN.x - FACE_SIZE if right_side else MARGIN.x
	var face_rect := Rect2(face_x, MARGIN.y, FACE_SIZE, FACE_SIZE)

	# Rosto, com moldura. O do jogador 2 é espelhado para olhar para o centro.
	_draw_frame(face_rect)
	draw_rect(face_rect, Color("23232b"))
	if _faces[index]:
		_draw_face(_faces[index], face_rect, right_side)

	# Nome embaixo do rosto.
	var name_pos := Vector2(face_rect.position.x - 40, face_rect.end.y + 34)
	draw_string_outline(FONT, name_pos, _names[index], HORIZONTAL_ALIGNMENT_CENTER, FACE_SIZE + 80, 32, 8, COLOR_OUTLINE)
	draw_string(FONT, name_pos, _names[index], HORIZONTAL_ALIGNMENT_CENTER, FACE_SIZE + 80, 32, Color.WHITE)

	# Barra: vai do rosto até perto da caixa KO. A vida perdida some do lado do
	# centro, como na referência.
	var gap := KO_SIZE.x / 2.0 + 14
	var bar_start := face_rect.end.x + 14 if not right_side else center + gap
	var bar_end := center - gap if not right_side else face_rect.position.x - 14
	var bar := Rect2(bar_start, BAR_TOP, bar_end - bar_start, BAR_HEIGHT)
	_draw_frame(bar)
	draw_rect(bar, COLOR_EMPTY)
	_draw_fill(bar, _trail[index], right_side, COLOR_TRAIL, COLOR_TRAIL.lightened(0.3), COLOR_TRAIL.darkened(0.3))
	_draw_fill(bar, _health[index], right_side, COLOR_FILL, COLOR_FILL_LIGHT, COLOR_FILL_DARK)


# Desenha a foto preenchendo o quadro sem distorcer (corta as sobras do centro
# para fora). `mirrored` espelha para olhar para o outro lado.
func _draw_face(texture: Texture2D, rect: Rect2, mirrored: bool) -> void:
	var tex_size := texture.get_size()
	var side := minf(tex_size.x, tex_size.y)
	var src := Rect2((tex_size.x - side) / 2.0, (tex_size.y - side) / 2.0, side, side)
	if mirrored:
		draw_set_transform(Vector2(rect.end.x, rect.position.y), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, rect.size), src)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(texture, rect, src)


# Preenche `ratio` da barra a partir do lado do rosto, com brilho em cima e
# sombra embaixo (visual pixel art).
func _draw_fill(bar: Rect2, ratio: float, from_right: bool, base: Color, light: Color, dark: Color) -> void:
	if ratio <= 0.0:
		return
	var width := roundf(bar.size.x * ratio)
	var x := bar.end.x - width if from_right else bar.position.x
	draw_rect(Rect2(x, bar.position.y, width, bar.size.y), base)
	draw_rect(Rect2(x, bar.position.y + 4, width, 6), light)
	draw_rect(Rect2(x, bar.end.y - 8, width, 8), dark)


# Contorno escuro + moldura clara em volta de `rect`.
func _draw_frame(rect: Rect2) -> void:
	draw_rect(rect.grow(BORDER * 2), COLOR_OUTLINE)
	draw_rect(rect.grow(BORDER), COLOR_FRAME)


func _draw_ko_and_timer(center: float) -> void:
	var ko := Rect2(center - KO_SIZE.x / 2.0, BAR_TOP + BAR_HEIGHT / 2.0 - KO_SIZE.y / 2.0, KO_SIZE.x, KO_SIZE.y)
	draw_rect(ko.grow(BORDER * 2), COLOR_OUTLINE)
	draw_rect(ko.grow(BORDER), COLOR_KO_BORDER)
	draw_rect(ko, COLOR_KO_BG)
	var ko_pos := Vector2(ko.position.x, ko.end.y - 14)
	draw_string_outline(FONT, ko_pos, "KO", HORIZONTAL_ALIGNMENT_CENTER, ko.size.x, 52, 8, COLOR_OUTLINE)
	draw_string(FONT, ko_pos, "KO", HORIZONTAL_ALIGNMENT_CENTER, ko.size.x, 52, COLOR_KO_TEXT)

	var timer_text := "%02d" % ceili(_time_left)
	var timer_pos := Vector2(ko.position.x - 40, ko.end.y + 70)
	draw_string_outline(FONT, timer_pos, timer_text, HORIZONTAL_ALIGNMENT_CENTER, ko.size.x + 80, 72, 10, COLOR_OUTLINE)
	draw_string(FONT, timer_pos, timer_text, HORIZONTAL_ALIGNMENT_CENTER, ko.size.x + 80, 72, Color.WHITE)


# Recorta a cabeça do topo do portrait (o personagem olha para a direita):
# acha o topo do desenho, o centro da faixa de cima e pega um quadrado um
# pouco à frente, onde fica o rosto.
func _auto_face(portrait: Texture2D) -> Texture2D:
	if portrait == null:
		return null
	var image := portrait.get_image()
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	var band := maxi(1, roundi(used.size.y * FACE_BAND))
	var min_x := image.get_width()
	var max_x := -1
	for y in range(used.position.y, used.position.y + band):
		for x in range(used.position.x, used.end.x):
			if image.get_pixel(x, y).a >= 0.5:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
	if max_x < 0:
		return portrait
	var side := roundf(used.size.y * FACE_SIDE)
	var center_x := (min_x + max_x) / 2.0 + side * FACE_FORWARD
	var face := AtlasTexture.new()
	face.atlas = portrait
	face.region = Rect2(center_x - side / 2.0, used.position.y, side, side)
	return face
