extends CharacterBody2D

## Chain Wraith — Tier 6 spectral revenant.
## Fast and relentless — leaps onto platforms, punishes hesitation.
## Twin hollow eyes track the player; chains snap at close range.
##
## State machine: PATROL → CHASE → ATTACK → HURT → DEAD

# ── Physics ───────────────────────────────────────────────────────────────────
const GRAVITY  = 1200.0
const TERM_VEL = 1200.0
const JUMP_VEL = -340.0

# ── Stats ─────────────────────────────────────────────────────────────────────
const MAX_HEALTH   = 5
const MOVE_SPEED   = 110.0
const DAMAGE       = 2
const EMBERS_VALUE = 250

# ── Attack ────────────────────────────────────────────────────────────────────
const LASH_RANGE      = 110.0
const WINDUP_TIME     = 0.20
const LASH_TIME       = 0.18
const ATTACK_COOLDOWN = 1.6

# ── State ─────────────────────────────────────────────────────────────────────
enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var state        := State.PATROL
var health       := MAX_HEALTH
var facing_right := true
var patrol_dir   := 1.0
var state_timer  := 0.0
var attack_cd    := 0.0
var attack_phase := 0
var player_ref   : CharacterBody2D = null

# ── Respawn ───────────────────────────────────────────────────────────────────
var _spawn_position : Vector2
var _death_tween    : Tween = null

@onready var visual   : Node2D           = $Visual
@onready var hurtbox  : Area2D           = $Hurtbox
@onready var detect   : Area2D           = $DetectZone
@onready var atk_box  : Area2D           = $AttackHitbox
@onready var atk_col  : CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var body_col : CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_spawn_position = global_position
	collision_layer = 2
	collision_mask  = 5
	health = MAX_HEALTH
	_build_visual()

	detect.body_entered.connect(_on_detect_entered)
	detect.body_exited.connect(_on_detect_exited)
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	atk_box.body_entered.connect(_on_atk_body)

	atk_box.monitoring = false
	atk_col.disabled   = true

	GameData.rested.connect(_reset)


# ── Visual ────────────────────────────────────────────────────────────────────

func _build_visual() -> void:
	var void_dark := Color(0.08, 0.05, 0.14, 1.0)
	var shadow    := Color(0.04, 0.02, 0.08, 1.0)
	var chain     := Color(0.72, 0.72, 0.80, 1.0)
	var eye_glow  := Color(0.40, 0.90, 1.00, 1.0)
	var eye_core  := Color(0.82, 1.00, 1.00, 1.0)

	# Torso — slender, spectral
	_rect(Vector2(0, -16), Vector2(20, 40), void_dark)
	_rect(Vector2(0, -12), Vector2(12, 28), shadow)

	# Chains bound across chest — horizontal + vertical bar
	_rect(Vector2(0, -10), Vector2(20,  3), chain)
	_rect(Vector2(0,  -2), Vector2(20,  3), chain)
	_rect(Vector2(0,  -4), Vector2(4,  24), chain)

	# Head — narrow, angular
	_rect(Vector2(0, -36), Vector2(18, 16), void_dark)
	_rect(Vector2(0, -34), Vector2(12, 10), shadow)

	# Hollow eyes — twin cyan slits
	_rect(Vector2(-4, -37), Vector2(6, 5), eye_glow)
	_rect(Vector2( 4, -37), Vector2(6, 5), eye_glow)
	_rect(Vector2(-4, -37), Vector2(3, 3), eye_core)
	_rect(Vector2( 4, -37), Vector2(3, 3), eye_core)

	# Arms — thin, chains trailing at wrists
	_rect(Vector2(-13, -6), Vector2(6, 22), void_dark)
	_rect(Vector2( 13, -6), Vector2(6, 22), void_dark)
	_rect(Vector2(-15, 10), Vector2(10,  4), chain)
	_rect(Vector2( 15, 10), Vector2(10,  4), chain)

	# Legs — wispy, barely there
	_rect(Vector2(-5, 22), Vector2(7, 14), void_dark)
	_rect(Vector2( 5, 22), Vector2(7, 14), void_dark)
	_rect(Vector2(-5, 30), Vector2(10,  6), shadow)
	_rect(Vector2( 5, 30), Vector2(10,  6), shadow)


func _rect(center: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.size     = size
	r.position = center - size * 0.5
	r.color    = color
	visual.add_child(r)


# ── Physics loop ──────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_apply_gravity(delta)
	state_timer -= delta
	attack_cd    = maxf(attack_cd - delta, 0.0)

	match state:
		State.PATROL: _state_patrol()
		State.CHASE:  _state_chase()
		State.ATTACK: _state_attack(delta)
		State.HURT:   _state_hurt(delta)

	_update_facing()
	_animate(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, TERM_VEL)


# ── States ────────────────────────────────────────────────────────────────────

func _state_patrol() -> void:
	if is_on_wall() or (is_on_floor() and not _has_floor_ahead()):
		patrol_dir *= -1.0
	velocity.x = patrol_dir * MOVE_SPEED * 0.55


func _state_chase() -> void:
	if not is_instance_valid(player_ref):
		player_ref = null
		state      = State.PATROL
		return

	var diff := player_ref.global_position - global_position

	if absf(diff.x) < LASH_RANGE and absf(diff.y) < 60.0 and attack_cd <= 0.0:
		_start_lash()
		return

	velocity.x = sign(diff.x) * MOVE_SPEED

	# Wraith leaps onto elevated platforms
	if diff.y < -80.0 and is_on_floor():
		velocity.y = JUMP_VEL


func _start_lash() -> void:
	state        = State.ATTACK
	attack_phase = 0
	state_timer  = WINDUP_TIME
	velocity.x   = 0.0


func _state_attack(delta: float) -> void:
	match attack_phase:
		0:  # Windup — coiling chains
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if state_timer <= 0.0:
				attack_phase       = 1
				state_timer        = LASH_TIME
				atk_box.monitoring = true
				atk_col.disabled   = false
				velocity.x = (1.0 if facing_right else -1.0) * 120.0

		1:  # Chain snap
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_timer <= 0.0 or is_on_wall():
				atk_box.monitoring = false
				atk_col.disabled   = true
				attack_cd          = ATTACK_COOLDOWN
				state = State.CHASE if is_instance_valid(player_ref) else State.PATROL


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	if state_timer <= 0.0:
		state = State.CHASE if is_instance_valid(player_ref) else State.PATROL


# ── Navigation ────────────────────────────────────────────────────────────────

func _has_floor_ahead() -> bool:
	var space  := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.new()
	var fwd    := 16.0 * (1.0 if facing_right else -1.0)
	params.from           = global_position + Vector2(fwd, 4.0)
	params.to             = global_position + Vector2(fwd, 48.0)
	params.exclude        = [get_rid()]
	params.collision_mask = 1
	return not space.intersect_ray(params).is_empty()


# ── Animation ─────────────────────────────────────────────────────────────────

func _update_facing() -> void:
	if velocity.x > 10.0:
		facing_right   = true
		visual.scale.x = 1.0
	elif velocity.x < -10.0:
		facing_right   = false
		visual.scale.x = -1.0


func _animate(delta: float) -> void:
	var t_scale_y := 1.0
	var t_lean    := 0.0

	match state:
		State.PATROL, State.CHASE:
			t_lean = clampf(velocity.x / (MOVE_SPEED * 1.5), -0.10, 0.10)

		State.ATTACK:
			if attack_phase == 0:
				t_scale_y = 0.88
				t_lean    = 0.22 * (1.0 if facing_right else -1.0)
			else:
				t_scale_y = 1.12
				t_lean    = 0.10 * (1.0 if facing_right else -1.0)

		State.HURT:
			t_scale_y = 1.08
			t_lean    = -0.18 * (1.0 if facing_right else -1.0)

	visual.scale.y  = lerpf(visual.scale.y,  t_scale_y, 12.0 * delta)
	visual.rotation = lerpf(visual.rotation, t_lean,     9.0 * delta)


# ── Signals ───────────────────────────────────────────────────────────────────

func _on_detect_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_ref = body
		state      = State.CHASE


func _on_detect_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_ref = null
		if state == State.CHASE:
			state = State.PATROL


func _on_hurtbox_hit(area: Area2D) -> void:
	if area.name == "NailHitbox":
		_take_damage(GameData.get_nail_damage())
	elif area.name == "EmberBolt":
		_take_damage(1)


func _on_atk_body(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		var dir := Vector2(1.0 if facing_right else -1.0, -0.12).normalized()
		body.take_damage(DAMAGE, dir)


# ── Damage & death ────────────────────────────────────────────────────────────

func _take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	AudioManager.play("enemy_hit")
	health -= amount

	if health <= 0:
		_die()
		return

	atk_box.monitoring = false
	atk_col.disabled   = true
	state       = State.HURT
	state_timer = 0.18
	_flash()


func _flash() -> void:
	visual.modulate = Color(0.50, 1.80, 1.90, 1.0)
	await get_tree().create_timer(0.09).timeout
	if is_instance_valid(self) and state != State.DEAD:
		visual.modulate = Color.WHITE


func _die() -> void:
	AudioManager.play("enemy_die")
	state              = State.DEAD
	atk_box.monitoring = false
	hurtbox.monitoring = false
	detect.monitoring  = false
	body_col.disabled  = true
	collision_layer    = 0
	collision_mask     = 0
	velocity           = Vector2.ZERO
	set_physics_process(false)

	GameData.gain_embers(EMBERS_VALUE)

	if _death_tween:
		_death_tween.kill()
	_death_tween = create_tween().set_parallel(true)
	_death_tween.tween_property(visual, "modulate:a", 0.0, 0.55)
	_death_tween.tween_property(visual, "scale:y",    0.0, 0.55)


# ── Reset ─────────────────────────────────────────────────────────────────────

func _reset() -> void:
	if state != State.DEAD:
		return

	if _death_tween:
		_death_tween.kill()
		_death_tween = null

	visual.modulate = Color.WHITE
	visual.scale    = Vector2(1.0, 1.0)
	visual.rotation = 0.0

	health       = MAX_HEALTH
	state        = State.PATROL
	state_timer  = 0.0
	attack_cd    = 0.0
	attack_phase = 0
	patrol_dir   = 1.0
	player_ref   = null
	velocity     = Vector2.ZERO

	collision_layer    = 2
	collision_mask     = 5
	body_col.disabled  = false
	hurtbox.monitoring = true
	detect.monitoring  = true
	atk_box.monitoring = false
	atk_col.disabled   = true
	set_physics_process(true)

	global_position = _spawn_position
