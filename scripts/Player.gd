extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died(death_pos: Vector2, ember_amount: int)

# --- Physics ---
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
const I_FRAMES        = 1.5
const KNOCKBACK_FORCE = 320.0

# --- Dash ---
const DASH_SPEED     = 520.0
const DASH_DURATION  = 0.14
const DASH_COOLDOWN  = 0.85
const DASH_I_FRAMES  = 0.25

var health            := 0
var i_frames_timer    := 0.0
var spawn_position    : Vector2
var last_safe_position: Vector2

var coyote_timer      := 0.0
var jump_buffer_timer := 0.0
var extra_jumps       := 0    # air jumps remaining (double jump)
var attack_timer      := 0.0
var is_attacking      := false
var facing_right      := true

var is_dashing    := false
var dash_timer    := 0.0
var dash_cd_timer := 0.0

@onready var visual        : ColorRect        = $Visual
@onready var nail_hitbox   : Area2D           = $NailHitbox
@onready var nail_collision: CollisionShape2D = $NailHitbox/NailCollision
@onready var nail_visual   : ColorRect        = $NailHitbox/NailVisual


func _ready() -> void:
	add_to_group("player")
	spawn_position     = global_position
	last_safe_position = global_position
	health = GameData.get_max_health()
	nail_hitbox.area_entered.connect(_on_nail_area_entered)


func _on_nail_area_entered(area: Area2D) -> void:
	if area.name == "Hurtbox":
		var parent := area.get_parent()
		if parent.has_method("_take_damage"):
			parent._take_damage(GameData.get_nail_damage())


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_tick_timers(delta)
	_handle_dash(delta)
	_handle_movement(delta)
	_handle_jump()
	_handle_attack()
	_update_visuals()
	move_and_slide()


# ── Gravity ────────────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if is_dashing:
		velocity.y = 0.0   # no gravity during dash
		return
	if not is_on_floor():
		velocity.y = min(velocity.y + GRAVITY * delta, TERM_VEL)


# ── Timers ─────────────────────────────────────────────────────────────────────

func _tick_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer       = COYOTE_TIME
		last_safe_position = global_position
		extra_jumps        = 1 if GameData.has_double_jump() else 0
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	attack_timer      = max(attack_timer      - delta, 0.0)
	i_frames_timer    = max(i_frames_timer    - delta, 0.0)
	dash_cd_timer     = max(dash_cd_timer     - delta, 0.0)

	if is_attacking and attack_timer < ATTACK_COOLDOWN - ATTACK_DURATION:
		is_attacking = false
		nail_hitbox.monitoring  = false
		nail_collision.disabled = true
		nail_visual.visible     = false


# ── Movement ───────────────────────────────────────────────────────────────────

func _handle_movement(delta: float) -> void:
	if is_dashing:
		return   # dash controls velocity directly

	var dir := Input.get_axis("move_left", "move_right")

	if dir > 0:
		facing_right = true
	elif dir < 0:
		facing_right = false

	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * GameData.get_speed(), ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)


# ── Jump ───────────────────────────────────────────────────────────────────────

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			# Ground jump (includes coyote window)
			velocity.y        = JUMP_VELOCITY
			coyote_timer      = 0.0
			jump_buffer_timer = 0.0
		elif extra_jumps > 0:
			# Air jump — double jump
			velocity.y        = JUMP_VELOCITY * 0.90
			extra_jumps      -= 1
			jump_buffer_timer = 0.0

	# Variable height: release early → shorter arc
	if Input.is_action_just_released("jump") and velocity.y < -150.0:
		velocity.y = -150.0


# ── Dash ───────────────────────────────────────────────────────────────────────

func _handle_dash(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		velocity.x  = (1.0 if facing_right else -1.0) * DASH_SPEED
		if dash_timer <= 0.0:
			is_dashing = false
		return

	if Input.is_action_just_pressed("dash") and GameData.has_dash() and dash_cd_timer <= 0.0:
		is_dashing     = true
		dash_timer     = DASH_DURATION
		dash_cd_timer  = DASH_COOLDOWN
		i_frames_timer = max(i_frames_timer, DASH_I_FRAMES)


# ── Attack ─────────────────────────────────────────────────────────────────────

func _handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and attack_timer <= 0.0:
		_swing_nail()


func _swing_nail() -> void:
	is_attacking = true
	attack_timer = ATTACK_COOLDOWN
	nail_hitbox.monitoring  = true
	nail_collision.disabled = false
	nail_hitbox.position.x  = GameData.get_nail_range() if facing_right else -GameData.get_nail_range()
	nail_visual.visible     = true
	nail_visual.scale.x     = 1.0 if facing_right else -1.0


# ── Health ─────────────────────────────────────────────────────────────────────

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if i_frames_timer > 0.0 or is_dashing:
		return

	health = max(health - amount, 0)
	i_frames_timer = I_FRAMES

	if knockback_dir != Vector2.ZERO:
		velocity.x = knockback_dir.normalized().x * KNOCKBACK_FORCE
		velocity.y = -200.0

	health_changed.emit(health, GameData.get_max_health())

	if health <= 0:
		_die()


func rest(well_position: Vector2) -> void:
	spawn_position = well_position + Vector2(0, -8)
	health = GameData.get_max_health()
	health_changed.emit(health, GameData.get_max_health())


func kill() -> void:
	if not is_physics_processing():
		return
	health = 0
	health_changed.emit(health, GameData.get_max_health())
	_die()


func _die() -> void:
	died.emit(last_safe_position, GameData.drop_all())
	set_physics_process(false)
	visual.modulate.a = 0.0
	await get_tree().create_timer(0.8).timeout
	_respawn()


func _respawn() -> void:
	health          = GameData.get_max_health()
	global_position = spawn_position
	velocity        = Vector2.ZERO
	i_frames_timer  = I_FRAMES
	is_dashing      = false
	visual.modulate.a = 1.0
	set_physics_process(true)
	health_changed.emit(health, GameData.get_max_health())


# ── Visuals ────────────────────────────────────────────────────────────────────

func _update_visuals() -> void:
	if is_dashing:
		# Bright flash during dash
		visual.modulate = Color(1.4, 1.4, 2.0, 0.85)
	elif i_frames_timer > 0.0:
		visual.modulate.a = 0.25 + 0.75 * abs(sin(Time.get_ticks_msec() * 0.015))
		visual.modulate.r = 1.0
		visual.modulate.g = 1.0
		visual.modulate.b = 1.0
	else:
		visual.modulate = Color.WHITE
