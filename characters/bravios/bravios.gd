class_name Bravios
extends Fighter

const SPEED := 300.0
const JUMP_VELOCITY := -400.0
const MAX_JUMPS := 2
const COMBO_WINDOW_MS := 450
const COMBO_ANIMATION := &"combo"
const COMBO_SIZE := 3
const ATTACK_FRAME_TIME := 0.18

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


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	is_sneaking = Input.is_action_pressed("sneak") and is_on_floor()

	# "attack" executa o combo em pé. "sneak-attack" continua separado e só
	# funciona enquanto o personagem está agachado.
	var attack_pressed := Input.is_action_just_pressed("attack")
	var sneak_attack_pressed := Input.is_action_just_pressed("sneak-attack")
	if is_on_floor():
		if is_sneaking and sneak_attack_pressed:
			if not is_attacking:
				_start_sneak_attack()
		elif attack_pressed:
			if is_attacking:
				if is_combo_attacking:
					_buffer_combo_attack()
			else:
				_start_combo_attack()

	if is_attacking:
		velocity.x = 0
		move_and_slide()
		return

	if is_on_floor():
		jump_count = MAX_JUMPS

	if Input.is_action_just_pressed("jump") and jump_count > 0:
		velocity.y = JUMP_VELOCITY
		jump_count -= 1

	var direction := Input.get_axis("ui_left", "ui_right")
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
	sprite.play("sneak-attack")
	await sprite.animation_finished
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
		sprite.play(COMBO_ANIMATION)
		sprite.pause()
		sprite.frame = combo_step
		await get_tree().create_timer(ATTACK_FRAME_TIME).timeout
		combo_step += 1

		if combo_step >= COMBO_SIZE:
			_reset_combo()
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

	if not is_on_floor():
		sprite.play("jump" if velocity.y < 0 else "fall")
	elif is_sneaking:
		sprite.play("sneak_walk" if velocity.x != 0 else "sneak")
	elif velocity.x != 0:
		sprite.play("walk")
	else:
		sprite.play("idle")
