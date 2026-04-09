extends CharacterBody2D

# --- Movement ---
const SPEED         = 200.0
const ACCELERATION  = 1400.0
const FRICTION      = 1600.0
const JUMP_VELOCITY = -480.0
const GRAVITY       = 1200.0
const TERM_VEL      = 1200.0   # terminal fall speed

# --- Polish timers ---
const COYOTE_TIME       = 0.12  # grace window after walking off a ledge
const JUMP_BUFFER_TIME  = 0.12  # pre-press window before landing

# --- Attack ---
const ATTACK_COOLDOWN = 0.45
const ATTACK_DURATION = 0.15   # how long the hitbox is active

var coyote_timer      := 0.0
var jump_buffer_timer := 0.0
var attack_timer      := 0.0
var is_attacking      := false
var facing_right      := true

@onready var nail_hitbox   : Area2D          = $NailHitbox
@onready var nail_collision: CollisionShape2D = $NailHitbox/NailCollision


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_tick_timers(delta)
	_handle_movement(delta)
	_handle_jump()
	_handle_attack()
	move_and_slide()


# ── Gravity ────────────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = min(velocity.y + GRAVITY * delta, TERM_VEL)


# ── Timers ─────────────────────────────────────────────────────────────────────

func _tick_timers(delta: float) -> void:
	# Coyote time: stays fresh while grounded, counts down in the air
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	attack_timer      = max(attack_timer      - delta, 0.0)

	# End attack hitbox after active window expires
	if is_attacking and attack_timer < ATTACK_COOLDOWN - ATTACK_DURATION:
		is_attacking = false
		nail_hitbox.monitoring    = false
		nail_collision.disabled   = true


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

	# Consume buffer + coyote together so both windows feel natural
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y        = JUMP_VELOCITY
		coyote_timer      = 0.0
		jump_buffer_timer = 0.0

	# Variable height: release early → shorter arc
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

	# Place hitbox in front of the player based on facing direction
	nail_hitbox.position.x = 40.0 if facing_right else -40.0
