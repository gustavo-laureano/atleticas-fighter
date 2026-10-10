class_name Bravios
extends Fighter

const SPEED := 300.0
const JUMP_VELOCITY := -600.0
const MAX_JUMPS := 2
const COMBO_WINDOW_MS := 450
const COMBO_ANIMATION := &"combo"
const COMBO_SIZE := 3
const SPECIAL_ANIMATION := &"special"
const SPECIAL_DAMAGE := 4
# Duração da animação inteira, como um Super Art do Street Fighter 6 (~78
# frames a 60 fps). O frame do acerto tem "Duração" 1.5 no SpriteFrames, então
# o golpe sai em ~0,46 s e fica ativo ~0,23 s.
const SPECIAL_DURATION := 1.3
const SPECIAL_RECOVERY := 0.6
# Só este frame do especial acerta (panther_frame_04, contando do 0).
const SPECIAL_HIT_FRAME := 3

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


func _is_attack_frame() -> bool:
	if is_attacking and sprite.animation == SPECIAL_ANIMATION:
		return sprite.frame == SPECIAL_HIT_FRAME
	return is_attacking


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	is_sneaking = update_crouch(Input.is_action_pressed(action("sneak")))

	# "attack" executa o combo em pé. "sneak-attack" continua separado e só
	# funciona enquanto o personagem está agachado. Na recuperação depois de um
	# golpe (is_recovering), apertar ataque não faz nada; durante um soco do
	# combo, o clique fica guardado e encadeia o próximo.
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
			elif not is_recovering():
				_start_combo_attack()

	# Golpeando ou se recuperando: fica parado, segurando a pose do golpe.
	if is_attacking or is_recovering():
		velocity.x = 0
		move_and_slide()
		return

	if is_on_floor():
		jump_count = MAX_JUMPS

	if Input.is_action_just_pressed(action("jump")) and jump_count > 0:
		velocity.y = JUMP_VELOCITY
		jump_count -= 1
		restart_animation(&"jump")

	var direction := Input.get_axis(action("left"), action("right"))
	var current_speed := SPEED * 0.4 if is_sneaking else SPEED

	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	move_and_slide()
	_update_animation()


func _start_sneak_attack() -> void:
	_reset_combo()
	is_attacking = true
	velocity.x = 0
	await play_attack(&"sneak-attack")
	is_attacking = false


func _start_special() -> void:
	if not spend_special():
		return
	_reset_combo()
	is_attacking = true
	velocity.x = 0
	await play_attack(SPECIAL_ANIMATION, [], SPECIAL_DURATION, SPECIAL_DAMAGE)
	start_recovery(SPECIAL_RECOVERY)
	is_attacking = false


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
		# A animação "combo" contém jab, hook e uppercut nos frames 0, 1 e 2.
		# Exibimos só um frame por clique, em vez de tocar os três de uma vez.
		await play_attack(COMBO_ANIMATION, [combo_step])
		combo_step += 1

		if combo_step >= COMBO_SIZE:
			_reset_combo()
			start_recovery(COMBO_RECOVERY)
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


func _update_animation() -> void:
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

	var landing := update_landing()

	if not is_on_floor():
		play_animation(&"jump" if velocity.y < 0 else &"fall")
	elif landing and not is_sneaking:
		play_animation(&"land")
	elif is_sneaking:
		play_animation(&"sneak_walk" if velocity.x != 0 else &"sneak")
	elif velocity.x != 0:
		play_animation(&"walk")
	else:
		play_animation(&"idle")
