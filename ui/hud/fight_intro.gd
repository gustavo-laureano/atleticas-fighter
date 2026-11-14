class_name FightIntro
extends CanvasLayer

# Anúncio do início da luta: toca o áudio FIGHT e mostra "FIGHT!" na fonte do
# jogo (Pixelta), vermelho com contorno e sombra pretos. O texto "bate" na tela
# (cresce além do tamanho, assenta), com flash branco, tremida e um brilho
# laranja atrás, e depois some.
# Uso (na fase): add_child(FightIntro.new())

const SOUND: AudioStream = preload("res://FIGHT_vorbis.ogg")
const PIXEL_FONT: FontFile = preload("res://assets/fonts/pixelta/Pixelta.ttf")
const TEXT := "FIGHT!"
const FONT_SIZE := 260
const COLOR := Color(0.92, 0.06, 0.05)
const GLOW_COLOR := Color(1.0, 0.55, 0.1, 0.55)
const SHADOW_COLOR := Color.BLACK
const SHADOW_OFFSET := 14
const OUTLINE_SIZE := 22
# Tempos (segundos).
const SLAM_TIME := 0.22
const HOLD_TIME := 0.7
const FADE_TIME := 0.3
const SHAKE_TIME := 0.3
const SHAKE_STRENGTH := 14.0

var _label: Label
var _shake_left := 0.0


func _ready() -> void:
	layer = 100

	# Flash branco rápido no impacto.
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.7)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	# Brilho laranja (mesmo texto, maior, somando luz) atrás do texto.
	var glow := _make_label(GLOW_COLOR, false)
	glow.material = CanvasItemMaterial.new()
	(glow.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_child(glow)
	_label = _make_label(COLOR, true)
	add_child(_label)

	var player := AudioStreamPlayer.new()
	player.stream = SOUND
	add_child(player)
	player.play()

	await get_tree().process_frame
	for label in [glow, _label]:
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2.ONE * 2.6
		label.modulate.a = 0.0
		label.rotation_degrees = -4.0
	_shake_left = SHAKE_TIME

	var tween := create_tween().set_parallel()
	tween.tween_property(flash, "color:a", 0.0, 0.25)
	for label in [glow, _label]:
		# Entra grande e "bate" no tamanho normal, com um repique.
		tween.tween_property(label, "scale", Vector2.ONE, SLAM_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(label, "modulate:a", 1.0, SLAM_TIME * 0.5)
		tween.tween_property(label, "rotation_degrees", 0.0, SLAM_TIME)
	# O brilho pulsa e some junto com o texto.
	tween.tween_property(glow, "scale", Vector2.ONE * 1.12, SLAM_TIME + HOLD_TIME) \
		.set_delay(SLAM_TIME).set_trans(Tween.TRANS_SINE)
	var end_delay := SLAM_TIME + HOLD_TIME
	for label in [glow, _label]:
		tween.tween_property(label, "modulate:a", 0.0, FADE_TIME).set_delay(end_delay)
	await tween.finished
	if player.playing:
		await player.finished
	queue_free()


func _process(delta: float) -> void:
	# Tremida do texto logo depois do impacto.
	if _shake_left > 0.0 and is_instance_valid(_label):
		_shake_left -= delta
		var amount := SHAKE_STRENGTH * clampf(_shake_left / SHAKE_TIME, 0.0, 1.0)
		_label.position = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	elif is_instance_valid(_label):
		_label.position = Vector2.ZERO


func _make_label(color: Color, outlined: bool) -> Label:
	var label := Label.new()
	label.text = TEXT
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A Pixelta pode não ter o "!": usa a fonte padrão só para os caracteres que faltam.
	var font := PIXEL_FONT.duplicate() as FontFile
	font.fallbacks = [ThemeDB.fallback_font]
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	if outlined:
		label.add_theme_color_override("font_outline_color", SHADOW_COLOR)
		label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
		label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
		label.add_theme_constant_override("shadow_offset_x", SHADOW_OFFSET)
		label.add_theme_constant_override("shadow_offset_y", SHADOW_OFFSET)
		label.add_theme_constant_override("shadow_outline_size", OUTLINE_SIZE)
	return label
