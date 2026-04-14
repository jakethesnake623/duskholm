extends CharacterBody2D

## Skeletal enemy with three variants.
## State machine: PATROL → CHASE → ATTACK → HURT → DEAD

@export var variant: int = 0  # 0=standard  1=tall/fast  2=ancient/heavy

# --- Physics ---
const GRAVITY  = 1200.0
const TERM_VEL = 1200.0

# --- Attack ---
const ATTACK_RANGE    = 52.0   # horizontal distance to trigger a lunge
const WINDUP_TIME     = 0.35   # pause before lunge
const LUNGE_TIME      = 0.20   # duration hitbox is active
const LUNGE_FORCE     = 370.0
const ATTACK_COOLDOWN = 2.2    # seconds before can attack again

# --- Variant stats (set in _apply_variant) ---
var max_health : int
var move_speed : float
var damage     : int

# --- Runtime state ---
enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var state        := State.PATROL
var health       := 0
var embers_value := 0        # embers granted on death
var facing_right := true
var patrol_dir   := 1.0
var state_timer  := 0.0
var attack_cd    := 0.0
var attack_phase := 0        # 0 = windup  1 = lunge
var base_scale_x  := 1.0      # preserve variant x-scale when flipping
var player_ref    : CharacterBody2D = null

# Procedural animation
var _walk_time  := 0.0
var _leg_l      : ColorRect = null
var _leg_r      : ColorRect = null
var _arm_l      : ColorRect = null
var _arm_r      : ColorRect = null
var _leg_l_base := 0.0
var _leg_r_base := 0.0
var _arm_l_base := 0.0
var _arm_r_base := 0.0

# Respawn
var _spawn_position : Vector2
var _base_scale_y   : float = 1.0
var _death_tween    : Tween = null

@onready var visual   : Node2D           = $Visual
@onready var hurtbox  : Area2D           = $Hurtbox
@onready var detect   : Area2D           = $DetectionZone
@onready var atk_box  : Area2D           = $AttackHitbox
@onready var atk_col  : CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var body_col : CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_spawn_position = global_position
	_apply_variant()
	health = max_health
	_build_visual()

	detect.body_entered.connect(_on_body_entered_detect)
	detect.body_exited.connect(_on_body_exited_detect)
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	atk_box.body_entered.connect(_on_attack_body)

	atk_box.monitoring = false
	atk_col.disabled   = true

	GameData.rested.connect(_reset)


# ── Variant setup ──────────────────────────────────────────────────────────────

func _apply_variant() -> void:
	match variant:
		0:  # Standard — balanced
			max_health   = 3
			move_speed   = 80.0
			damage       = 1
			embers_value = 100
			base_scale_x = 1.0
		1:  # Tall — quick and fragile
			max_health   = 2
			move_speed   = 110.0
			damage       = 1
			embers_value = 75
			base_scale_x = 0.80
		2:  # Ancient — slow, tanky, hits harder
			max_health   = 5
			move_speed   = 55.0
			damage       = 2
			embers_value = 300
			base_scale_x = 1.25


# ── Visual builder ─────────────────────────────────────────────────────────────
# Skeleton is assembled from colored rectangles so it can be replaced with
# proper sprites later without touching any logic.

func _build_visual() -> void:
	var bone_color: Color
	var scale_y   : float

	match variant:
		0:  # classic bone-white
			bone_color = Color(0.88, 0.87, 0.76, 1.0)
			scale_y    = 1.0
		1:  # pale blue-grey (fresher corpse)
			bone_color = Color(0.74, 0.80, 0.85, 1.0)
			scale_y    = 1.30
		2:  # yellowed ancient bone
			bone_color = Color(0.72, 0.65, 0.45, 1.0)
			scale_y    = 0.88
		_:
			bone_color = Color(0.88, 0.87, 0.76, 1.0)
			scale_y    = 1.0

	_base_scale_y = scale_y
	visual.scale  = Vector2(base_scale_x, scale_y)

	# Parts: [center_offset, size]  (centered around origin = physics center)
	var parts := [
		[Vector2(0,  -30), Vector2(18, 18)],  # skull
		[Vector2(0,  -19), Vector2( 6,  9)],  # neck
		[Vector2(0,   -7), Vector2(20, 22)],  # ribcage
		[Vector2(-14, -10), Vector2( 7, 18)],  # left arm
		[Vector2( 14, -10), Vector2( 7, 18)],  # right arm
		[Vector2(0,   15), Vector2(16,  8)],  # pelvis
		[Vector2(-7,   27), Vector2( 7, 22)],  # left leg
		[Vector2( 7,   27), Vector2( 7, 22)],  # right leg
	]

	for i in parts.size():
		var rect := ColorRect.new()
		rect.size     = parts[i][1]
		rect.position = parts[i][0] - parts[i][1] * 0.5
		rect.color    = bone_color
		visual.add_child(rect)
		# Store limb references by index (3=left arm, 4=right arm, 6=left leg, 7=right leg)
		match i:
			3: _arm_l = rect; _arm_l_base = rect.position.y
			4: _arm_r = rect; _arm_r_base = rect.position.y
			6: _leg_l = rect; _leg_l_base = rect.position.y
			7: _leg_r = rect; _leg_r_base = rect.position.y

	# Glowing eye sockets inside the skull
	var eye_color := Color(0.88, 0.50, 0.08, 0.90)
	if variant == 2:
		eye_color = Color(0.75, 0.28, 0.06, 0.90)  # ancient — deeper ember glow
	elif variant == 1:
		eye_color = Color(0.72, 0.82, 0.95, 0.90)  # tall/fresh — cold blue-white

	for ex in [-4.5, 4.5]:
		var eye := ColorRect.new()
		eye.size     = Vector2(3.0, 3.0)
		eye.position = Vector2(ex - 1.5, -32.5)
		eye.color    = eye_color
		visual.add_child(eye)


# ── Physics loop ───────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_apply_gravity(delta)
	state_timer -= delta
	attack_cd    = max(attack_cd - delta, 0.0)

	match state:
		State.PATROL: _state_patrol(delta)
		State.CHASE:  _state_chase(delta)
		State.ATTACK: _state_attack(delta)
		State.HURT:   _state_hurt(delta)

	_update_facing()
	_animate(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = min(velocity.y + GRAVITY * delta, TERM_VEL)


# ── States ─────────────────────────────────────────────────────────────────────

func _state_patrol(_delta: float) -> void:
	velocity.x = patrol_dir * move_speed
	if is_on_wall():
		patrol_dir *= -1


func _state_chase(_delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = null
		state = State.PATROL
		return

	var diff := player_ref.global_position - global_position

	if abs(diff.x) < ATTACK_RANGE and abs(diff.y) < 50.0 and attack_cd <= 0.0:
		_start_attack()
		return

	velocity.x = sign(diff.x) * move_speed


func _start_attack() -> void:
	state        = State.ATTACK
	attack_phase = 0
	state_timer  = WINDUP_TIME
	velocity.x   = 0.0


func _state_attack(delta: float) -> void:
	match attack_phase:
		0:  # Wind-up: slow to a halt
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			if state_timer <= 0.0:
				attack_phase = 1
				state_timer  = LUNGE_TIME
				atk_box.monitoring = true
				atk_col.disabled   = false
				velocity.x = (1.0 if facing_right else -1.0) * LUNGE_FORCE

		1:  # Active lunge — hitbox live
			if state_timer <= 0.0:
				atk_box.monitoring = false
				atk_col.disabled   = true
				attack_cd = ATTACK_COOLDOWN
				state = State.CHASE if is_instance_valid(player_ref) else State.PATROL


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	if state_timer <= 0.0:
		state = State.CHASE if is_instance_valid(player_ref) else State.PATROL


# ── Procedural animation ───────────────────────────────────────────────────────

func _animate(delta: float) -> void:
	if _leg_l == null:
		return

	# _update_facing() owns visual.scale.x — we only touch scale.y and rotation.
	var t_scale_y := 1.0
	var t_lean    := 0.0

	match state:
		State.PATROL, State.CHASE:
			var speed_frac : float = abs(velocity.x) / move_speed
			if speed_frac > 0.05:
				_walk_time += delta * 7.5 * speed_frac
				var swing : float = sin(_walk_time)
				_leg_l.position.y = _leg_l_base + swing * 5.0
				_leg_r.position.y = _leg_r_base - swing * 5.0
				_arm_l.position.y = _arm_l_base - swing * 3.5
				_arm_r.position.y = _arm_r_base + swing * 3.5
			t_lean = clampf(velocity.x / (move_speed * 1.5), -0.12, 0.12)

		State.ATTACK:
			if attack_phase == 0:
				t_scale_y = 0.88   # anticipation: crouch down
				t_lean    = 0.18 * (1.0 if facing_right else -1.0)
			else:
				t_scale_y = 1.18   # lunge: stretch forward
				t_lean    = 0.28 * (1.0 if facing_right else -1.0)
			_leg_l.position.y = lerpf(_leg_l.position.y, _leg_l_base, 0.3)
			_leg_r.position.y = lerpf(_leg_r.position.y, _leg_r_base, 0.3)
			_arm_l.position.y = lerpf(_arm_l.position.y, _arm_l_base, 0.3)
			_arm_r.position.y = lerpf(_arm_r.position.y, _arm_r_base, 0.3)

		State.HURT:
			t_scale_y = 1.08
			t_lean    = -0.20 * (1.0 if facing_right else -1.0)

		_:
			_leg_l.position.y = lerpf(_leg_l.position.y, _leg_l_base, 0.2)
			_leg_r.position.y = lerpf(_leg_r.position.y, _leg_r_base, 0.2)
			_arm_l.position.y = lerpf(_arm_l.position.y, _arm_l_base, 0.2)
			_arm_r.position.y = lerpf(_arm_r.position.y, _arm_r_base, 0.2)

	visual.scale.y  = lerpf(visual.scale.y, t_scale_y, 10.0 * delta)
	visual.rotation = lerpf(visual.rotation, t_lean,    9.0  * delta)


# ── Facing ─────────────────────────────────────────────────────────────────────

func _update_facing() -> void:
	if velocity.x > 10.0:
		facing_right    = true
		visual.scale.x  = base_scale_x
	elif velocity.x < -10.0:
		facing_right    = false
		visual.scale.x  = -base_scale_x


# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_body_entered_detect(body: Node) -> void:
	if body.is_in_group("player"):
		player_ref = body
		state      = State.CHASE


func _on_body_exited_detect(body: Node) -> void:
	if body.is_in_group("player"):
		player_ref = null
		if state == State.CHASE:
			state = State.PATROL


func _on_hurtbox_hit(area: Area2D) -> void:
	# Fires when the player's nail hitbox overlaps this enemy's hurtbox
	if area.name == "NailHitbox":
		_take_damage(GameData.get_nail_damage())


func _on_attack_body(body: Node) -> void:
	# Fires during lunge if the player's body enters the attack hitbox
	if body.is_in_group("player") and body.has_method("take_damage"):
		var dir := Vector2(1.0 if facing_right else -1.0, 0.0)
		body.take_damage(damage, dir)


# ── Damage & death ─────────────────────────────────────────────────────────────

func _take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	AudioManager.play("enemy_hit")
	health -= amount

	if health <= 0:
		_die()
		return

	# Stagger briefly
	state       = State.HURT
	state_timer = 0.25
	_flash_red()


func _flash_red() -> void:
	visual.modulate = Color(1.6, 0.25, 0.25, 1.0)
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self) and state != State.DEAD:
		visual.modulate = Color.WHITE


func _die() -> void:
	AudioManager.play("enemy_die")
	state               = State.DEAD
	atk_box.monitoring  = false
	hurtbox.monitoring  = false
	detect.monitoring   = false
	body_col.disabled   = true
	collision_layer     = 0
	collision_mask      = 0
	velocity            = Vector2.ZERO
	set_physics_process(false)

	GameData.gain_embers(embers_value)

	# Crumble animation — node stays in the scene for respawning
	if _death_tween:
		_death_tween.kill()
	_death_tween = create_tween().set_parallel(true)
	_death_tween.tween_property(visual, "modulate:a", 0.0, 0.6)
	_death_tween.tween_property(visual, "scale:y",    0.0, 0.6)


func _reset() -> void:
	if state != State.DEAD:
		return

	if _death_tween:
		_death_tween.kill()
		_death_tween = null

	# Restore visual
	visual.modulate   = Color.WHITE
	visual.scale      = Vector2(base_scale_x, _base_scale_y)
	visual.rotation   = 0.0

	# Restore limb positions if animated
	if _leg_l:
		_leg_l.position.y = _leg_l_base
		_leg_r.position.y = _leg_r_base
		_arm_l.position.y = _arm_l_base
		_arm_r.position.y = _arm_r_base

	# Restore stats and state
	health       = max_health
	state        = State.PATROL
	state_timer  = 0.0
	attack_cd    = 0.0
	attack_phase = 0
	player_ref   = null
	patrol_dir   = 1.0
	velocity     = Vector2.ZERO
	_walk_time   = 0.0

	# Re-enable physics and hitboxes
	collision_layer    = 1
	collision_mask     = 1
	body_col.disabled  = false
	hurtbox.monitoring = true
	detect.monitoring  = true
	atk_box.monitoring = false
	atk_col.disabled   = true
	set_physics_process(true)

	# Return to original spawn position
	global_position = _spawn_position
