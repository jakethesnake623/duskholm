extends CharacterBody2D

## Cinder Hound — Tier 4 mechanical quadruped.
## Built from scavenged iron and copper by the old civilisation's automated
## foundries. The ember corruption keeps them hunting long after their purpose ended.
##
## Faster and more relentless than the skeletal enemies above.
## State machine: PATROL → CHASE → ATTACK → HURT → DEAD

# ── Physics ───────────────────────────────────────────────────────────────────
const GRAVITY  = 1200.0
const TERM_VEL = 1200.0

# ── Stats ─────────────────────────────────────────────────────────────────────
const MAX_HEALTH   = 5
const MOVE_SPEED   = 155.0
const DAMAGE       = 2
const EMBERS_VALUE = 250

# ── Attack ────────────────────────────────────────────────────────────────────
const POUNCE_RANGE    = 72.0    # horizontal distance to trigger pounce
const WINDUP_TIME     = 0.22    # crouch-and-lunge windup
const POUNCE_TIME     = 0.20    # how long the pounce lasts
const POUNCE_FORCE    = 520.0   # horizontal launch velocity
const ATTACK_COOLDOWN = 1.50    # seconds before next pounce

# ── Navigation ────────────────────────────────────────────────────────────────
const JUMP_VELOCITY = -440.0    # Hounds can short-hop to follow the player
const JUMP_CD_TIME  = 0.9

# ── State ─────────────────────────────────────────────────────────────────────
enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var state        := State.PATROL
var health       := MAX_HEALTH
var facing_right := true
var patrol_dir   := 1.0
var state_timer  := 0.0
var attack_cd    := 0.0
var attack_phase := 0          # 0 = windup  1 = pounce
var _jump_cd     := 0.0
var player_ref   : CharacterBody2D = null

# ── Procedural animation ──────────────────────────────────────────────────────
var _walk_time   := 0.0
var _legs        : Array[ColorRect] = []
var _legs_base_y : Array[float]     = []

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
	collision_mask  = 5   # world (1) + enemy barriers (3 = bit value 4)
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
	var iron   := Color(0.22, 0.20, 0.18, 1.0)
	var copper := Color(0.58, 0.38, 0.14, 1.0)
	var dark   := Color(0.10, 0.09, 0.08, 1.0)
	var ember  := Color(0.98, 0.52, 0.08, 0.95)

	# Main chassis — long, low body
	_rect(Vector2( 0, -6), Vector2(44, 14), iron)
	# Recessed interior panel
	_rect(Vector2(-2, -6), Vector2(36,  8), dark)
	# Copper armour strips (top / bottom edge)
	_rect(Vector2( 0, -12), Vector2(44,  4), copper)
	_rect(Vector2( 0,   1), Vector2(44,  4), copper)

	# Head — pushed forward in the facing direction (+x = right)
	_rect(Vector2(26, -11), Vector2(22, 20), iron)
	_rect(Vector2(27,  -9), Vector2(14, 12), dark)
	# Jaw / snout plate
	_rect(Vector2(31,   0), Vector2(14,  6), copper)

	# Ember eye sensors
	for ey: float in [-9.0, -3.0]:
		var eye := ColorRect.new()
		eye.size     = Vector2(4.0, 4.0)
		eye.position = Vector2(19.0, ey - 2.0)
		eye.color    = ember
		visual.add_child(eye)

	# Tail stub — short, pointing backward (-x direction)
	_rect(Vector2(-25, -5), Vector2(10, 6), iron)
	_rect(Vector2(-30, -5), Vector2( 6, 4), copper)

	# Four legs — front pair then rear pair, stored for animation
	for lx: float in [14.0, 20.0]:           # front legs
		var leg := ColorRect.new()
		leg.size     = Vector2(6.0, 13.0)
		leg.position = Vector2(lx - 3.0, 2.0)
		leg.color    = copper
		visual.add_child(leg)
		_legs.append(leg)
		_legs_base_y.append(leg.position.y)

	for lx: float in [-16.0, -10.0]:         # rear legs
		var leg := ColorRect.new()
		leg.size     = Vector2(6.0, 13.0)
		leg.position = Vector2(lx - 3.0, 2.0)
		leg.color    = iron
		visual.add_child(leg)
		_legs.append(leg)
		_legs_base_y.append(leg.position.y)


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
	_jump_cd     = maxf(_jump_cd   - delta, 0.0)

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
	velocity.x = patrol_dir * MOVE_SPEED * 0.55   # slower while patrolling


func _state_chase() -> void:
	if not is_instance_valid(player_ref):
		player_ref = null
		state      = State.PATROL
		return

	var diff := player_ref.global_position - global_position

	if absf(diff.x) < POUNCE_RANGE and absf(diff.y) < 44.0 and attack_cd <= 0.0:
		_start_pounce()
		return

	velocity.x = sign(diff.x) * MOVE_SPEED

	# Short hop to follow player up to a nearby platform
	if is_on_floor() and _jump_cd <= 0.0:
		var needs_hop := is_on_wall() and diff.y < -20.0
		if needs_hop:
			velocity.y = JUMP_VELOCITY
			_jump_cd   = JUMP_CD_TIME


func _start_pounce() -> void:
	state        = State.ATTACK
	attack_phase = 0
	state_timer  = WINDUP_TIME
	velocity.x   = 0.0


func _state_attack(delta: float) -> void:
	match attack_phase:
		0:  # Windup — crouch in place
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			if state_timer <= 0.0:
				attack_phase       = 1
				state_timer        = POUNCE_TIME
				atk_box.monitoring = true
				atk_col.disabled   = false
				velocity.x = (1.0 if facing_right else -1.0) * POUNCE_FORCE
				velocity.y = -160.0   # slight upward arc

		1:  # Active pounce
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
	if _legs.is_empty():
		return

	var t_scale_y := 1.0
	var t_lean    := 0.0

	match state:
		State.PATROL, State.CHASE:
			if absf(velocity.x) > 20.0:
				_walk_time += delta * 10.0 * (absf(velocity.x) / MOVE_SPEED)
				var swing := sin(_walk_time)
				# Alternate front/rear pairs in opposing phase
				_legs[0].position.y = _legs_base_y[0] + swing * 4.0
				_legs[1].position.y = _legs_base_y[1] - swing * 4.0
				_legs[2].position.y = _legs_base_y[2] - swing * 4.0
				_legs[3].position.y = _legs_base_y[3] + swing * 4.0
			t_lean = clampf(velocity.x / (MOVE_SPEED * 1.5), -0.10, 0.10)

		State.ATTACK:
			if attack_phase == 0:
				t_scale_y = 0.82   # crouch before pounce
				t_lean    = 0.22 * (1.0 if facing_right else -1.0)
			else:
				t_scale_y = 1.14   # stretch during pounce
				t_lean    = 0.30 * (1.0 if facing_right else -1.0)

		State.HURT:
			t_scale_y = 1.10
			t_lean    = -0.18 * (1.0 if facing_right else -1.0)

	visual.scale.y  = lerpf(visual.scale.y,  t_scale_y, 12.0 * delta)
	visual.rotation = lerpf(visual.rotation, t_lean,    10.0 * delta)


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
		var dir := Vector2(1.0 if facing_right else -1.0, -0.20).normalized()
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
	state_timer = 0.20
	_flash()


func _flash() -> void:
	visual.modulate = Color(1.8, 0.40, 0.10, 1.0)   # amber-red flash (not cold white)
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

	for i in _legs.size():
		_legs[i].position.y = _legs_base_y[i]

	health       = MAX_HEALTH
	state        = State.PATROL
	state_timer  = 0.0
	attack_cd    = 0.0
	attack_phase = 0
	_jump_cd     = 0.0
	patrol_dir   = 1.0
	player_ref   = null
	velocity     = Vector2.ZERO
	_walk_time   = 0.0

	collision_layer    = 2
	collision_mask     = 5
	body_col.disabled  = false
	hurtbox.monitoring = true
	detect.monitoring  = true
	atk_box.monitoring = false
	atk_col.disabled   = true
	set_physics_process(true)

	global_position = _spawn_position
