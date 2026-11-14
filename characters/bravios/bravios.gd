class_name Bravios
extends Fighter

const SPEED := 300.0
# Com GRAVITY_SCALE 1.8 sobe ~440 px (mais que o corpo, de 400): dá para passar por cima.
const JUMP_VELOCITY := -1250.0
const MAX_JUMPS := 2
const COMBO_WINDOW_MS := 450
const COMBO_ANIMATION := &"combo"
const COMBO_SIZE := 3
# Avanço no início de cada golpe do combo (jab, hook, uppercut), em px. 15 a 30.
# Ponha 0 num golpe para ele não avançar. Dura LUNGE_TIME (Fighter).
const COMBO_LUNGE := [20.0, 20.0, 32.0]
const SPECIAL_ANIMATION := &"special"
const SPECIAL_DAMAGE := 20
# Empurrão de quem leva a bola, em px/s (anda ~135 px; ver KNOCKBACK_TIME).
const SPECIAL_KNOCKBACK := 900.0
# Preparação do arremesso (special/1 a 3, ~0,46 s). Ao fim dela a bola sai e o
# frame do arremesso (special/4) aparece só por um instante: o personagem não
# espera a bola acertar, volta ao idle logo depois de lançar.
const SPECIAL_WINDUP := 0.46
const SPECIAL_THROW_FRAME := 3
const SPECIAL_THROW_HOLD := 0.15
# Mão que arremessa no frame do arremesso, em px da textura, a partir do pé.
const SPECIAL_HAND := Vector2(160, -275)
var jump_count := MAX_JUMPS
var is_sneaking := false
var is_attacking := false
var is_combo_attacking := false
var combo_step := 0
var buffered_attacks := 0
var combo_deadline_ms := 0


func die() -> void:
	super()
	sprite.play("die")


# No especial quem acerta é a bola, não o corpo.
func _is_attack_frame() -> bool:
	return is_attacking and sprite.animation != SPECIAL_ANIMATION


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		apply_gravity(delta)

	is_sneaking = update_crouch(Input.is_action_pressed(action("sneak")))

	var direction := Input.get_axis(action("left"), action("right"))
	if Input.is_action_just_pressed(action("jump")):
		buffer_jump()
	apply_jump_cut(JUMP_VELOCITY, Input.is_action_pressed(action("jump")))

	# Depois do impacto, andar ou pular corta o resto da recuperação.
	if not is_attacking and can_cancel_recovery() and (direction != 0.0 or has_jump_buffered()):
		cancel_recovery()

	# "attack" executa o combo em pé. "sneak-attack" continua separado e só
	# funciona enquanto o personagem está agachado. Durante um soco do combo, o
	# clique fica guardado e encadeia o próximo. Na recuperação (ou em outro
	# golpe), o clique também fica guardado por ATTACK_BUFFER e sai assim que o
	# lutador fica livre.
	var attack_pressed := Input.is_action_just_pressed(action("attack"))
	var sneak_attack_pressed := Input.is_action_just_pressed(action("sneak-attack"))
	# Super especial: só com a barra cheia, e gasta ela inteira.
	var special_pressed := Input.is_action_just_pressed(action("special"))
	if is_on_floor():
		if special_pressed and is_special_ready() and not is_attacking and not is_recovering():
			_start_special()
		elif is_sneaking and sneak_attack_pressed:
			if not is_attacking and not is_recovering():
				_start_sneak_attack()
		elif attack_pressed:
			if is_attacking:
				if is_combo_attacking:
					_buffer_combo_attack()
				else:
					buffer_attack()
			elif is_recovering():
				buffer_attack()
			else:
				_start_combo_attack()
		if not is_attacking and not is_recovering() and consume_buffered_attack():
			_start_combo_attack()

	# No começo do golpe ainda dá para virar (bater para trás sem travar).
	if is_attacking and sprite.animation != SPECIAL_ANIMATION and can_turn_now():
		face_direction(direction)

	# Golpeando ou se recuperando: fica parado, segurando a pose do golpe
	# (só o avanço do início do golpe move o lutador).
	if is_attacking or is_recovering():
		velocity.x = lunge_velocity()
		if not is_attacking and is_hurt():
			play_animation(&"hurt")
		slide_with_knockback()
		return

	if is_on_floor():
		jump_count = MAX_JUMPS

	if has_jump_buffered() and jump_count > 0:
		consume_jump_buffer()
		velocity.y = JUMP_VELOCITY * (1.0 if is_on_floor() else AIR_JUMP_FACTOR)
		jump_count -= 1
		restart_animation(&"jump")

	var current_speed := SPEED * 0.4 if is_sneaking else SPEED
	move_horizontal(direction, current_speed, delta)

	slide_with_knockback()
	_update_animation(direction)


func _start_sneak_attack() -> void:
	_reset_combo()
	is_attacking = true
	velocity.x = 0
	face_direction(Input.get_axis(action("left"), action("right")))
	await play_attack(&"sneak-attack", [], ATTACK_DURATION, -1, true)
	is_attacking = false


func _start_special() -> void:
	if not spend_special():
		return
	_reset_combo()
	is_attacking = true
	velocity.x = 0
	show_aura()
	await play_attack(SPECIAL_ANIMATION, [0, 1, 2], SPECIAL_WINDUP)
	if current_health > 0:
		sprite.frame = SPECIAL_THROW_FRAME
		_throw_ball()
		await get_tree().create_timer(SPECIAL_THROW_HOLD).timeout
	hide_aura()
	is_attacking = false


func _throw_ball() -> void:
	var side := -1.0 if sprite.flip_h else 1.0
	var hand := Vector2(SPECIAL_HAND.x * side, SPECIAL_HAND.y) * sprite.scale + sprite.position
	Basketball.throw(self, global_position + hand, side, SPECIAL_DAMAGE, SPECIAL_KNOCKBACK)


func _start_combo_attack() -> void:
	var now := Time.get_ticks_msec()
	if now > combo_deadline_ms:
		combo_step = 0
		buffered_attacks = 0
	_play_combo()


func _buffer_combo_attack() -> void:
	var remaining_steps := COMBO_SIZE - combo_step - 1
	if buffered_attacks < remaining_steps:
		buffered_attacks += 1


func _play_combo() -> void:
	is_attacking = true
	is_combo_attacking = true
	velocity.x = 0

	while combo_step < COMBO_SIZE:
		# Vira para o lado segurado e avança um pouco no início de cada golpe.
		face_direction(Input.get_axis(action("left"), action("right")))
		start_lunge(COMBO_LUNGE[combo_step])
		# A animação "combo" contém jab, hook e uppercut nos frames 0, 1 e 2.
		# Exibimos só um frame por clique, em vez de tocar os três de uma vez.
		await play_attack(COMBO_ANIMATION, [combo_step])
		combo_step += 1

		if combo_step >= COMBO_SIZE:
			_reset_combo()
			start_recovery(COMBO_RECOVERY, false)
			break

		if buffered_attacks == 0:
			combo_deadline_ms = Time.get_ticks_msec() + COMBO_WINDOW_MS
			break

		buffered_attacks -= 1

	is_combo_attacking = false
	is_attacking = false


func _reset_combo() -> void:
	combo_step = 0
	buffered_attacks = 0
	combo_deadline_ms = 0


func _update_animation(direction: float) -> void:
	# Vira pela tecla (não pela velocidade): a troca de lado é imediata mesmo
	# com a aceleração do andar.
	face_direction(direction)

	var landing := update_landing()

	if is_hurt():
		play_animation(&"hurt")
	elif not is_on_floor():
		play_animation(&"jump" if velocity.y < 0 else &"fall")
	elif landing and not is_sneaking:
		play_animation(&"land")
	elif is_sneaking:
		play_animation(&"sneak_walk" if velocity.x != 0 else &"sneak")
	elif velocity.x != 0:
		play_animation(&"walk")
	else:
		play_animation(&"idle")
