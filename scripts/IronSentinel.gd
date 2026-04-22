extends CharacterBody2D

## Iron Sentinel — Tier 5 heavy mechanical biped.
## Slow and tanky — built to absorb punishment and dish out worse.
## Long sweep windup is the tell; getting caught deals 3 damage.
##
## State machine: PATROL → CHASE → ATTACK → HURT → DEAD

# ── Physics ───────────────────────────────────────────────────────────────────
const GRAVITY  = 1200.0
const TERM_VEL = 1200.0

# ── Stats ─────────────────────────────────────────────────────────────────────
const MAX_HEALTH   = 8
const MOVE_SPEED   = 65.0
const DAMAGE       = 3
const EMBERS_VALUE = 400

# ── Attack ────────────────────────────────────────────────────────────────────
const SWEEP_RANGE     = 95.0    # horizontal distance to begin windup
const WINDUP_TIME     = 0.55    # long windup — gives the player time to react
const SWEEP_TIME      = 0.30    # active hitbox window
const ATTACK_COOLDOWN = 2.2

# ── State ─────────────────────────────────────────────────────────────────────
enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var state        := State.PATROL
var health       := MAX_HEALTH
var facing_right := true
var patrol_dir   := 1.0
var state_timer  := 0.0
var attack_cd    := 0.0
var attack_phase := 0   # 0 = windup  1 = sweep
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
	var iron   := Color(0.18, 0.16, 0.14, 1.0)
	var copper := Color(0.52, 0.32, 0.10, 1.0)
	var dark   := Color(0.08, 0.07, 0.06, 1.0)
	var ember  := Color(0.98, 0.52, 0.06, 1.0)
	var molten := Color(1.00, 0.28, 0.04, 0.90)

	# Main torso — tall and narrow
	_rect(Vector2(0, -18), Vector2(26, 46), iron)
	_rect(Vector2(0, -14), Vector2(16, 32), dark)   # recessed chest

	# Copper shoulder plates — wide, prominent
	_rect(Vector2(-20, -30), Vector2(14, 10), copper)
	_rect(Vector2( 20, -30), Vector2(14, 10), copper)

	# Copper belt
	_rect(Vector2(0, -2), Vector2(28,  6), copper)

	# Head — boxy, slightly wider than torso
	_rect(Vector2(0, -40), Vector2(24, 18), iron)
	_rect(Vector2(0, -40), Vector2(16, 12), dark)

	# Single cyclopean eye — wide amber slit
	_rect(Vector2(0, -41), Vector2(12,  6), ember)
	_rect(Vector2(0, -42), Vector2( 6,  3), molten)   # hot core

	# Heavy arms — thick, hanging
	_rect(Vector2(-18,  -8), Vector2(8, 30), iron)
	_rect(Vector2( 18,  -8), Vector2(8, 30), iron)
	# Gauntlets
	_rect(Vector2(-18,  18), Vector2(12, 10), copper)
	_rect(Vector2( 18,  18), Vector2(12, 10), copper)

	# Legs — short and thick
	_rect(Vector2(-8,  22), Vector2(10, 18), iron)
	_rect(Vector2( 8,  22), Vector2(10, 18), iron)
	# Feet / plated boots
	_rect(Vector2(-8,  34), Vector2(14,  8), copper)
	_rect(Vector2( 8,  34), Vector2(14,  8), copper)

	# Gear emblem on chest — horizontal + vertical copper bars suggesting a cog
	_rect(Vector2(0, -14), Vector2(10,  4), copper)
	_rect(Vector2(0, -14), Vector2( 4, 10), copper)


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

	if absf(diff.x) < SWEEP_RANGE and absf(diff.y) < 60.0 and attack_cd <= 0.0:
		_start_sweep()
		return

	velocity.x = sign(diff.x) * MOVE_SPEED
	# Sentinels do not jump — too heavy


func _start_sweep() -> void:
	state        = State.ATTACK
	attack_phase = 0
	state_timer  = WINDUP_TIME
	velocity.x   = 0.0


func _state_attack(delta: float) -> void:
	match attack_phase:
		0:  # Windup — planting feet, raising arm
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_timer <= 0.0:
				attack_phase       = 1
				state_timer        = SWEEP_TIME
				atk_box.monitoring = true
				atk_col.disabled   = false
				# Short forward shove during the sweep
				velocity.x = (1.0 if facing_right else -1.0) * 90.0

		1:  # Active sweep
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if state_timer <= 0.0 or is_on_wall():
				atk_box.monitoring = false
				atk_col.disabled   = true
				attack_cd          = ATTACK_COOLDOWN
				state = State.CHASE if is_instance_valid(player_ref) else State.PATROL


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	if state_timer <= 0.0:
		state = State.CHASE if is_instance_valid(player_ref) else State.PATROL


# ── Navigation ────────────────────────────────────────────────────────────────

func _has_floor_ahead() -> bool:
	var space  := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.new()
	var fwd    := 18.0 * (1.0 if facing_right else -1.0)
	params.from           = global_position + Vector2(fwd, 4.0)
	params.to             = global_position + Vector2(fwd, 56.0)
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
			t_lean = clampf(velocity.x / (MOVE_SPEED * 1.5), -0.07, 0.07)

		State.ATTACK:
			if attack_phase == 0:
				t_scale_y = 0.86   # compress — weight shifting forward
				t_lean    = 0.30 * (1.0 if facing_right else -1.0)
			else:
				t_scale_y = 1.10   # lunge extension
				t_lean    = 0.14 * (1.0 if facing_right else -1.0)

		State.HURT:
			t_scale_y = 1.06
			t_lean    = -0.16 * (1.0 if facing_right else -1.0)

	visual.scale.y  = lerpf(visual.scale.y,  t_scale_y, 10.0 * delta)
	visual.rotation = lerpf(visual.rotation, t_lean,     8.0 * delta)


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
		var dir := Vector2(1.0 if facing_right else -1.0, -0.10).normalized()
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
	state_timer = 0.24
	_flash()


func _flash() -> void:
	visual.modulate = Color(1.8, 0.45, 0.10, 1.0)
	await get_tree().create_timer(0.10).timeout
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
	_death_tween.tween_property(visual, "modulate:a", 0.0, 0.70)
	_death_tween.tween_property(visual, "scale:y",    0.0, 0.70)


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
