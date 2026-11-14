class_name Crocks
extends Fighter

#  arquivo .tres


const SPEED := 300.0
# Com GRAVITY_SCALE 1.8 sobe ~440 px (mais que o corpo, de 400): dá para passar por cima.
const JUMP_VELOCITY := -1250.0
const MAX_JUMPS := 2
const COMBO_WINDOW_MS := 450
# A animação "combo" tem os 3 golpes nos frames 0, 1 e 2 (soco, chute, soco).
const COMBO_ANIMATION := &"combo"
const COMBO_SIZE := 3
# Avanço no início de cada golpe do combo, em px. 15 a 30. 0 = não avança.
# Dura LUNGE_TIME (Fighter).
const COMBO_LUNGE := [20.0, 16.0, 28.0]

# Super especial: pulo com mordida. A animação "special" tem 8 frames:
# 0 preparação, 1 boca expandida (as duas com a aura), 2 salto, 3 mordida no ar,
# 4 aterrissagem, 5 recuperação agachado, 6 ataque aberto, 7 fechando a boca.
const SPECIAL_ANIMATION := &"special"
# Dano da mordida do salto e da mordida final.
const SPECIAL_DAMAGE_LEAP := 20
const SPECIAL_DAMAGE_FINAL := 10
# Empurrão (px/s) de cada mordida (anda ~105 e ~150 px; ver KNOCKBACK_TIME).
const SPECIAL_KNOCKBACK_LEAP := 700.0
const SPECIAL_KNOCKBACK_FINAL := 1000.0
const SPECIAL_WINDUP := 0.4         # frames 0 e 1, em segundos
const SPECIAL_LEAP_JUMP := -520.0   # impulso vertical do salto (sobe ~80 px)
# O salto mira o adversário: pousa SPECIAL_STOP_GAP px antes dele, e anda no
# mínimo/máximo desta distância (px). Sem adversário usa a distância padrão.
const SPECIAL_STOP_GAP := 110.0
const SPECIAL_MIN_DISTANCE := 250.0
const SPECIAL_MAX_DISTANCE := 800.0
const SPECIAL_DEFAULT_DISTANCE := 450.0
const SPECIAL_LAND_TIME := 0.10     # frame 4
const SPECIAL_RECOVER_TIME := 0.12  # frame 5
const SPECIAL_FINAL_TIME := 0.14    # frames 6 e 7 (cada um)
const SPECIAL_FINAL_LUNGE := 70.0   # avanço da mordida final, em px

var jump_count := MAX_JUMPS
var is_sneaking := false
var is_attacking := false
var is_combo_attacking := false
var combo_step := 0
var buffered_attacks := 0
var combo_deadline_ms := 0
# Especial: velocidade horizontal do salto e se a mordida está acertando.
var _special_vx := 0.0
var _special_moving := false
var _special_hit_active := false


func die() -> void:
	super()
	sprite.play("die")


# No especial só acerta durante as mordidas (_special_hit_active).
func _is_attack_frame() -> bool:
	return is_attacking and (sprite.animation != SPECIAL_ANIMATION or _special_hit_active)


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

	# Mesmas regras do Bravios: "attack" faz o combo em pé, "sneak-attack" só
	# funciona agachado. Durante um golpe do combo o clique encadeia o próximo;
	# na recuperação (ou em outro golpe) o clique fica guardado por ATTACK_BUFFER.
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
		velocity.x = _special_vx if _special_moving else lunge_velocity()
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
	var opponent := _opponent()
	if opponent != null:
		face_direction(signf(opponent.global_position.x - global_position.x))
	show_aura()
	# Preparação com a aura (frames 0 e 1).
	await play_attack(SPECIAL_ANIMATION, [0, 1], SPECIAL_WINDUP, 0)
	if current_health <= 0:
		return
	await _special_leap(opponent)
	if current_health <= 0:
		return
	# Aterrissagem e recuperação.
	await _show_special_frame(4, SPECIAL_LAND_TIME)
	await _show_special_frame(5, SPECIAL_RECOVER_TIME)
	if current_health <= 0:
		return
	# Mordida final: avança um pouco com a boca aberta e fecha.
	begin_attack(SPECIAL_DAMAGE_FINAL, false, SPECIAL_KNOCKBACK_FINAL)
	_special_hit_active = true
	start_lunge(SPECIAL_FINAL_LUNGE)
	await _show_special_frame(6, SPECIAL_FINAL_TIME)
	await _show_special_frame(7, SPECIAL_FINAL_TIME)
	_special_hit_active = false
	hide_aura()
	is_attacking = false
	start_recovery(ATTACK_RECOVERY)


# Salto na direção do adversário, mordendo no ar (frames 2 e 3). Termina ao
# tocar o chão.
func _special_leap(opponent: Fighter) -> void:
	var side := -1.0 if sprite.flip_h else 1.0
	var distance := SPECIAL_DEFAULT_DISTANCE
	if opponent != null:
		distance = clampf(absf(opponent.global_position.x - global_position.x) - SPECIAL_STOP_GAP,
			SPECIAL_MIN_DISTANCE, SPECIAL_MAX_DISTANCE)
	var airtime := 2.0 * absf(SPECIAL_LEAP_JUMP) / (get_gravity().y * GRAVITY_SCALE)
	_special_vx = side * distance / airtime
	_special_moving = true
	velocity.y = SPECIAL_LEAP_JUMP
	begin_attack(SPECIAL_DAMAGE_LEAP, false, SPECIAL_KNOCKBACK_LEAP)
	_special_hit_active = true
	sprite.play(SPECIAL_ANIMATION)
	sprite.pause()
	sprite.frame = 2
	# Espera sair do chão e voltar a ele (com um limite, por segurança).
	var elapsed := 0.0
	while elapsed < 0.05 or not is_on_floor():
		await get_tree().physics_frame
		if current_health <= 0:
			_special_moving = false
			return
		elapsed += get_physics_process_delta_time()
		if velocity.y > 0.0:
			sprite.frame = 3
		if elapsed > 3.0:
			break
	_special_moving = false
	_special_hit_active = false
	velocity.x = 0


func _show_special_frame(frame: int, seconds: float) -> void:
	if current_health <= 0:
		return
	sprite.play(SPECIAL_ANIMATION)
	sprite.pause()
	sprite.frame = frame
	await get_tree().create_timer(seconds).timeout


# O outro lutador vivo (para mirar o salto).
func _opponent() -> Fighter:
	for node in get_tree().get_nodes_in_group("fighters"):
		var other := node as Fighter
		if other != null and other != self and other.current_health > 0:
			return other
	return null


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
		# Um frame da animação "combo" por clique.
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
