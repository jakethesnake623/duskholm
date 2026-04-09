extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal souls_changed(current: int)
signal died(death_pos: Vector2, soul_amount: int)

# --- Movement ---
const SPEED         = 200.0
const ACCELERATION  = 1400.0
const FRICTION      = 1600.0
const JUMP_VELOCITY = -480.0
const GRAVITY       = 1200.0
const TERM_VEL      = 1200.0

# --- Polish timers ---
const COYOTE_TIME      = 0.12
const JUMP_BUFFER_TIME = 0.12

# --- Attack ---
const ATTACK_COOLDOWN = 0.45
const ATTACK_DURATION = 0.15

# --- Health ---
const MAX_HEALTH      = 5
const I_FRAMES        = 1.5
const KNOCKBACK_FORCE = 320.0

var health            := MAX_HEALTH
var i_frames_timer    := 0.0
var spawn_position    : Vector2
var last_safe_position: Vector2   # where the death orb spawns on a fall

# --- Souls ---
var souls := 0

var coyote_timer      := 0.0
var jump_buffer_timer := 0.0
var attack_timer      := 0.0
var is_attacking      := false
var facing_right      := true

@onready var visual        : ColorRect        = $Visual
@onready var nail_hitbox   : Area2D           = $NailHitbox
@onready var nail_collision: CollisionShape2D = $NailHitbox/NailCollision


func _ready() -> void:
	add_to_group("player")
	spawn_position     = global_position
	last_safe_position = global_position


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_tick_timers(delta)
	_handle_movement(delta)
	_handle_jump()
	_handle_attack()
	_update_visuals()
	move_and_slide()


# ── Gravity ────────────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = min(velocity.y + GRAVITY * delta, TERM_VEL)


# ── Timers ─────────────────────────────────────────────────────────────────────

func _tick_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer       = COYOTE_TIME
		last_safe_position = global_position   # track last grounded spot
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	attack_timer      = max(attack_timer      - delta, 0.0)
	i_frames_timer    = max(i_frames_timer    - delta, 0.0)

	if is_attacking and attack_timer < ATTACK_COOLDOWN - ATTACK_DURATION:
		is_attacking = false
		nail_hitbox.monitoring  = false
		nail_collision.disabled = true


# ── Movement ───────────────────────────────────────────────────────────────────

func _handle_movement(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")

	if dir > 0:
		facing_right = true
	elif dir < 0:
		facing_right = false

	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)


# ── Jump ───────────────────────────────────────────────────────────────────────

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y        = JUMP_VELOCITY
		coyote_timer      = 0.0
		jump_buffer_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < -150.0:
		velocity.y = -150.0


# ── Attack ─────────────────────────────────────────────────────────────────────

func _handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and attack_timer <= 0.0:
		_swing_nail()


func _swing_nail() -> void:
	is_attacking = true
	attack_timer = ATTACK_COOLDOWN
	nail_hitbox.monitoring  = true
	nail_collision.disabled = false
	nail_hitbox.position.x  = 40.0 if facing_right else -40.0


# ── Health ─────────────────────────────────────────────────────────────────────

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if i_frames_timer > 0.0:
		return

	health = max(health - amount, 0)
	i_frames_timer = I_FRAMES

	if knockback_dir != Vector2.ZERO:
		velocity.x = knockback_dir.normalized().x * KNOCKBACK_FORCE
		velocity.y = -200.0

	health_changed.emit(health, MAX_HEALTH)

	if health <= 0:
		_die()


func kill() -> void:
	if not is_physics_processing():
		return
	health = 0
	health_changed.emit(health, MAX_HEALTH)
	_die()


func _die() -> void:
	# Drop all souls at last known safe ground position
	died.emit(last_safe_position, souls)
	souls = 0
	souls_changed.emit(souls)

	set_physics_process(false)
	visual.modulate.a = 0.0
	await get_tree().create_timer(0.8).timeout
	_respawn()


func _respawn() -> void:
	health          = MAX_HEALTH
	global_position = spawn_position
	velocity        = Vector2.ZERO
	i_frames_timer  = I_FRAMES
	visual.modulate.a = 1.0
	set_physics_process(true)
	health_changed.emit(health, MAX_HEALTH)


# ── Souls ──────────────────────────────────────────────────────────────────────

func gain_souls(amount: int) -> void:
	souls += amount
	souls_changed.emit(souls)


func retrieve_souls(amount: int) -> void:
	souls += amount
	souls_changed.emit(souls)


# ── Visuals ────────────────────────────────────────────────────────────────────

func _update_visuals() -> void:
	if i_frames_timer > 0.0:
		visual.modulate.a = 0.25 + 0.75 * abs(sin(Time.get_ticks_msec() * 0.015))
	else:
		visual.modulate.a = 1.0
