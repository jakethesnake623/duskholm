extends CharacterBody2D

## Molten Serpent — Tier 7 fast ground predator.
## Low-profile, extremely quick dash that's hard to dodge in tight corridors.
## No jump — stays on the ground and pressures the player from below.
##
## State machine: PATROL → CHASE → ATTACK → HURT → DEAD

# ── Physics ───────────────────────────────────────────────────────────────────
const GRAVITY  = 1200.0
const TERM_VEL = 1200.0

# ── Stats ─────────────────────────────────────────────────────────────────────
const MAX_HEALTH   = 4
const MOVE_SPEED   = 150.0
const DAMAGE       = 2
const EMBERS_VALUE = 180

# ── Attack ────────────────────────────────────────────────────────────────────
const RUSH_RANGE      = 130.0
const WINDUP_TIME     = 0.10   # extremely fast — the tell is almost invisible
const RUSH_TIME       = 0.35
const ATTACK_COOLDOWN = 2.0
const RUSH_VEL        = 220.0

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
	var amber    := Color(0.78, 0.36, 0.06, 1.0)
	var dark_amb := Color(0.50, 0.20, 0.04, 1.0)
	var ember    := Color(1.00, 0.52, 0.08, 1.0)
	var belly    := Color(0.62, 0.28, 0.05, 1.0)
	var eye_col  := Color(1.00, 0.82, 0.10, 1.0)

	# Main body — long, flat, low to the ground
	_rect(Vector2(0, 4), Vector2(38, 16), amber)
	_rect(Vector2(0, 6), Vector2(30,  8), belly)

	# Raised head — slightly wider and taller
	_rect(Vector2(22, 2), Vector2(18, 18), dark_amb)
	_rect(Vector2(22, 2), Vector2(12, 12), amber)

	# Glowing eye
	_rect(Vector2(28, -2), Vector2(5, 4), eye_col)
	_rect(Vector2(29, -2), Vector2(3, 3), ember)

	# Flickering tongue (two tiny slits)
	_rect(Vector2(32, 4), Vector2(2, 5), ember)
	_rect(Vector2(34, 4), Vector2(2, 5), ember)

	# Tail — narrows toward the back
	_rect(Vector2(-20, 5), Vector2(14, 12), amber)
	_rect(Vector2(-28, 6), Vector2( 8,  8), dark_amb)

	# Segmentation lines — horizontal ridges suggesting scales
	_rect(Vector2(-6, 3), Vector2(2, 14), dark_amb)
	_rect(Vector2( 4, 3), Vector2(2, 14), dark_amb)
	_rect(Vector2(14, 3), Vector2(2, 14), dark_amb)


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
	velocity.x = patrol_dir * MOVE_SPEED * 0.50


func _state_chase() -> void:
	if not is_instance_valid(player_ref):
		player_ref = null
		state      = State.PATROL
		return

	var diff := player_ref.global_position - global_position

	if absf(diff.x) < RUSH_RANGE and absf(diff.y) < 40.0 and attack_cd <= 0.0:
		_start_rush()
		return

	velocity.x = sign(diff.x) * MOVE_SPEED
	# Serpent does not jump — ground only


func _start_rush() -> void:
	state        = State.ATTACK
	attack_phase = 0
	state_timer  = WINDUP_TIME
	velocity.x   = 0.0


func _state_attack(delta: float) -> void:
	match attack_phase:
		0:  # Brief coil — barely perceptible
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if state_timer <= 0.0:
				attack_phase       = 1
				state_timer        = RUSH_TIME
				atk_box.monitoring = true
				atk_col.disabled   = false
				velocity.x = (1.0 if facing_right else -1.0) * RUSH_VEL

		1:  # Full-body lunge
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if state_timer <= 0.0 or is_on_wall():
				atk_box.monitoring = false
				atk_col.disabled   = true
				attack_cd          = ATTACK_COOLDOWN
				state = State.CHASE if is_instance_valid(player_ref) else State.PATROL


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
	if state_timer <= 0.0:
		state = State.CHASE if is_instance_valid(player_ref) else State.PATROL


# ── Navigation ────────────────────────────────────────────────────────────────

func _has_floor_ahead() -> bool:
	var space  := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.new()
	var fwd    := 20.0 * (1.0 if facing_right else -1.0)
	params.from           = global_position + Vector2(fwd, 4.0)
	params.to             = global_position + Vector2(fwd, 38.0)
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
	var t_lean := 0.0

	match state:
		State.PATROL, State.CHASE:
			t_lean = clampf(velocity.x / (MOVE_SPEED * 2.0), -0.06, 0.06)

		State.ATTACK:
			if attack_phase == 0:
				t_lean = -0.12 * (1.0 if facing_right else -1.0)  # recoil
			else:
				t_lean = 0.08 * (1.0 if facing_right else -1.0)   # lunge lean

		State.HURT:
			t_lean = -0.10 * (1.0 if facing_right else -1.0)

	# No squash/stretch — keep it flat and low
	visual.rotation = lerpf(visual.rotation, t_lean, 12.0 * delta)


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
		var dir := Vector2(1.0 if facing_right else -1.0, -0.05).normalized()
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
	state_timer = 0.14
	_flash()


func _flash() -> void:
	visual.modulate = Color(1.8, 0.70, 0.10, 1.0)
	await get_tree().create_timer(0.08).timeout
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
	_death_tween.tween_property(visual, "modulate:a", 0.0, 0.40)
	_death_tween.tween_property(visual, "scale",      Vector2(1.6, 0.2), 0.40)


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
