extends CharacterBody2D

## "The Warden" — first boss of Duskholm.
## Phase 1: walks and charges. Phase 2 (≤50% HP): also ground-slams.
## State machine: DORMANT → INTRO → IDLE → WALK → WINDUP → CHARGE
##                → SLAM_RISE → SLAM_FALL → RECOIL → PHASE2_ENTER → DEAD

signal health_changed(current: int, maximum: int)
signal boss_died

const GRAVITY         = 1200.0
const TERM_VEL        = 1500.0

const MAX_HEALTH      = 30
const PHASE2_HP       = 15
const EMBERS_DROP     = 500

const WALK_SPEED      = 60.0
const CHARGE_SPEED_P1 = 340.0
const CHARGE_SPEED_P2 = 430.0
const CHARGE_WINDUP_T = 0.55
const CHARGE_DUR      = 0.42
const CHARGE_COOLDOWN = 2.2
const CHARGE_RANGE    = 520.0
const SLAM_RISE_VEL   = -640.0
const SLAM_FALL_VEL   = 900.0
const SLAM_RADIUS     = 220.0
const SLAM_DAMAGE     = 2
const RECOIL_TIME     = 0.60
const INTRO_DUR       = 2.5
const PHASE2_PAUSE    = 1.8
const IDLE_DUR        = 0.5
const WALK_MAX_DUR    = 3.0

enum State { DORMANT, INTRO, IDLE, WALK, WINDUP, CHARGE, SLAM_RISE, SLAM_FALL, RECOIL, PHASE2_ENTER, DEAD }

var state                := State.DORMANT
var health               := MAX_HEALTH
var phase                := 1
var facing_right         := true
var state_timer          := 0.0
var charge_cd            := 0.0
var slam_ready           := true
var _phase2_triggered    := false
var _double_charge_avail := true

var player_ref       : CharacterBody2D = null
var _spawn_position  : Vector2
var _death_tween     : Tween = null

@onready var visual   : Node2D           = $Visual
@onready var hurtbox  : Area2D           = $Hurtbox
@onready var atk_box  : Area2D           = $AttackHitbox
@onready var atk_col  : CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var body_col : CollisionShape2D = $CollisionShape2D
@onready var detect   : Area2D           = $DetectZone


func _ready() -> void:
	_spawn_position = global_position
	collision_layer = 2
	collision_mask  = 1
	health = MAX_HEALTH
	_build_visual()

	detect.body_entered.connect(_on_detect_entered)
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	atk_box.body_entered.connect(_on_atk_body)

	atk_box.monitoring = false
	atk_col.disabled   = true

	GameData.rested.connect(_reset)
	set_physics_process(false)  # stays dormant until player enters detect zone


# ── Visual builder ─────────────────────────────────────────────────────────────

func _build_visual() -> void:
	var bone  := Color(0.75, 0.68, 0.48, 1.0)   # ancient yellowed bone
	var armor := Color(0.22, 0.20, 0.24, 1.0)   # dark iron plate
	var eye_c := Color(0.90, 0.15, 0.10, 0.95)  # crimson eye glow

	# Iron helm
	_part(Vector2(0,   -91), Vector2(42, 13), armor)
	# Skull
	_part(Vector2(0,   -74), Vector2(36, 34), bone)
	# Neck
	_part(Vector2(0,   -55), Vector2(11, 14), bone)
	# Chest armor plate (front)
	_part(Vector2(0,   -27), Vector2(54, 46), armor)
	# Ribcage (bone visible through gaps)
	_part(Vector2(0,   -25), Vector2(40, 40), bone)
	# Pauldron L
	_part(Vector2(-36, -45), Vector2(22, 18), armor)
	# Pauldron R
	_part(Vector2( 36, -45), Vector2(22, 18), armor)
	# Arm L
	_part(Vector2(-34, -18), Vector2(14, 42), bone)
	# Arm R
	_part(Vector2( 34, -18), Vector2(14, 42), bone)
	# Pelvis
	_part(Vector2(0,     8), Vector2(36, 15), bone)
	# Leg L
	_part(Vector2(-14,  32), Vector2(18, 48), bone)
	# Leg R
	_part(Vector2( 14,  32), Vector2(18, 48), bone)

	# Glowing eyes inside skull
	for ex in [-8.0, 8.0]:
		var e := ColorRect.new()
		e.size     = Vector2(6.0, 6.0)
		e.position = Vector2(ex - 3.0, -78.0)
		e.color    = eye_c
		visual.add_child(e)


func _part(center: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.size     = size
	r.position = center - size * 0.5
	r.color    = color
	visual.add_child(r)


# ── Physics loop ───────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_apply_gravity(delta)
	state_timer -= delta
	charge_cd    = maxf(charge_cd - delta, 0.0)

	match state:
		State.INTRO:        _state_intro()
		State.IDLE:         _state_idle()
		State.WALK:         _state_walk(delta)
		State.WINDUP:       _state_windup(delta)
		State.CHARGE:       _state_charge()
		State.SLAM_RISE:    _state_slam_rise()
		State.SLAM_FALL:    _state_slam_fall()
		State.RECOIL:       _state_recoil(delta)
		State.PHASE2_ENTER: _state_phase2_enter()

	_update_facing()
	_animate(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if state == State.SLAM_FALL:
		velocity.y = SLAM_FALL_VEL   # forced fast fall, ignores gravity
	elif not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, TERM_VEL)


# ── States ─────────────────────────────────────────────────────────────────────

func _state_intro() -> void:
	velocity.x = 0.0
	if state_timer <= 0.0:
		state       = State.IDLE
		state_timer = IDLE_DUR


func _state_idle() -> void:
	velocity.x = 0.0
	if state_timer <= 0.0:
		_decide_action()


func _decide_action() -> void:
	if not is_instance_valid(player_ref):
		state = State.DORMANT
		set_physics_process(false)
		return

	var diff : Vector2 = player_ref.global_position - global_position
	var dist : float   = abs(diff.x)

	if phase == 2 and slam_ready and dist < 350.0:
		slam_ready = false
		_enter_slam_rise()
	elif dist < CHARGE_RANGE and charge_cd <= 0.0:
		state       = State.WINDUP
		state_timer = CHARGE_WINDUP_T
		velocity.x  = 0.0
	else:
		state       = State.WALK
		state_timer = WALK_MAX_DUR


func _state_walk(delta: float) -> void:
	if not is_instance_valid(player_ref):
		state       = State.IDLE
		state_timer = IDLE_DUR
		return

	var diff : Vector2 = player_ref.global_position - global_position
	var dist : float   = abs(diff.x)
	velocity.x = sign(diff.x) * WALK_SPEED

	if dist < CHARGE_RANGE and charge_cd <= 0.0:
		state       = State.WINDUP
		state_timer = CHARGE_WINDUP_T
		velocity.x  = 0.0
	elif state_timer <= 0.0:
		state       = State.IDLE
		state_timer = IDLE_DUR


func _state_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
	if state_timer <= 0.0:
		var spd : float = CHARGE_SPEED_P2 if phase == 2 else CHARGE_SPEED_P1
		var dir : float = 1.0 if facing_right else -1.0
		atk_col.position   = Vector2(50.0 * dir, 0.0)
		atk_box.monitoring = true
		atk_col.disabled   = false
		velocity.x         = dir * spd
		state              = State.CHARGE
		state_timer        = CHARGE_DUR


func _state_charge() -> void:
	if is_on_wall():
		# Hit a wall — possibly bounce back for a double charge
		atk_box.monitoring = false
		atk_col.disabled   = true
		velocity.x         = 0.0
		var double_chance : float = 0.70 if phase == 2 else 0.50
		if _double_charge_avail and randf() < double_chance:
			_double_charge_avail = false
			facing_right         = not facing_right
			state                = State.WINDUP
			state_timer          = CHARGE_WINDUP_T * 0.55   # shorter windup for the follow-up
		else:
			_double_charge_avail = true
			charge_cd            = CHARGE_COOLDOWN
			state                = State.RECOIL
			state_timer          = RECOIL_TIME

	elif state_timer <= 0.0:
		# Charge ran its full duration without hitting a wall
		atk_box.monitoring   = false
		atk_col.disabled     = true
		_double_charge_avail = true
		# Phase 2: sometimes chain directly into a slam with no idle gap
		if phase == 2 and slam_ready and randf() < 0.45:
			slam_ready = false
			_enter_slam_rise()
		else:
			charge_cd   = CHARGE_COOLDOWN
			state       = State.RECOIL
			state_timer = RECOIL_TIME


func _enter_slam_rise() -> void:
	state      = State.SLAM_RISE
	velocity.y = SLAM_RISE_VEL
	velocity.x = 0.0


func _state_slam_rise() -> void:
	if velocity.y >= 0.0:
		state = State.SLAM_FALL


func _state_slam_fall() -> void:
	# velocity.y is forced to SLAM_FALL_VEL inside _apply_gravity
	if is_on_floor():
		_on_slam_land()
		state       = State.RECOIL
		state_timer = RECOIL_TIME
		velocity.x  = 0.0


func _on_slam_land() -> void:
	AudioManager.play("slam")
	slam_ready = true
	if not is_instance_valid(player_ref):
		return

	# Immediate impact — close range, full damage. Airborne players are safe.
	var dist : float = abs(player_ref.global_position.x - global_position.x)
	if dist < SLAM_RADIUS and player_ref.is_on_floor() and player_ref.has_method("take_damage"):
		var dir : Vector2 = (player_ref.global_position - global_position).normalized()
		player_ref.take_damage(SLAM_DAMAGE, dir)

	# Phase 2: shockwave ring that expands outward after a short delay
	if phase == 2:
		_slam_shockwave()


func _slam_shockwave() -> void:
	await get_tree().create_timer(0.22).timeout
	if not is_instance_valid(self) or not is_instance_valid(player_ref):
		return
	if state == State.DEAD:
		return
	# Hits the band between the immediate radius and 2x that distance. Airborne players are safe.
	var dist : float = abs(player_ref.global_position.x - global_position.x)
	if dist >= SLAM_RADIUS and dist < SLAM_RADIUS * 2.2 and player_ref.is_on_floor() and player_ref.has_method("take_damage"):
		var dir : Vector2 = (player_ref.global_position - global_position).normalized()
		player_ref.take_damage(1, dir)


func _state_recoil(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
	if state_timer <= 0.0:
		state       = State.IDLE
		state_timer = IDLE_DUR


func _state_phase2_enter() -> void:
	velocity.x = 0.0
	if state_timer <= 0.0:
		state       = State.IDLE
		state_timer = IDLE_DUR


# ── Facing ─────────────────────────────────────────────────────────────────────

func _update_facing() -> void:
	if velocity.x > 5.0:
		facing_right   = true
		visual.scale.x = 1.0
	elif velocity.x < -5.0:
		facing_right   = false
		visual.scale.x = -1.0
	elif is_instance_valid(player_ref):
		# Face the player while standing still
		match state:
			State.IDLE, State.DORMANT, State.INTRO, State.PHASE2_ENTER:
				var diff : Vector2 = player_ref.global_position - global_position
				if diff.x > 0.0:
					facing_right   = true
					visual.scale.x = 1.0
				else:
					facing_right   = false
					visual.scale.x = -1.0


# ── Procedural animation ───────────────────────────────────────────────────────

func _animate(delta: float) -> void:
	var t_scale_y : float = 1.0
	var t_lean    : float = 0.0
	var facing    : float = 1.0 if facing_right else -1.0

	match state:
		State.INTRO:
			t_scale_y = 1.06
		State.WINDUP:
			t_scale_y = 0.86
			t_lean    = 0.14 * facing
		State.CHARGE:
			t_scale_y = 1.14
			t_lean    = 0.20 * facing
		State.SLAM_RISE:
			t_scale_y = 1.24
		State.SLAM_FALL:
			t_scale_y = 0.78
		State.RECOIL:
			t_scale_y = 1.10
			t_lean    = -0.16 * facing
		State.PHASE2_ENTER:
			t_scale_y = 1.18

	visual.scale.y  = lerpf(visual.scale.y,  t_scale_y, 7.0 * delta)
	visual.rotation = lerpf(visual.rotation, t_lean,    6.0 * delta)


# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_detect_entered(body: Node) -> void:
	if body.is_in_group("player") and state == State.DORMANT:
		player_ref  = body
		state       = State.INTRO
		state_timer = INTRO_DUR
		set_physics_process(true)


func _on_hurtbox_hit(area: Area2D) -> void:
	if area.name == "NailHitbox":
		_take_damage(GameData.get_nail_damage())


func _on_atk_body(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		var dmg : int   = 3 if phase == 2 else 2
		var dir : Vector2 = Vector2(1.0 if facing_right else -1.0, -0.3).normalized()
		body.take_damage(dmg, dir)


# ── Damage & death ─────────────────────────────────────────────────────────────

func _take_damage(amount: int) -> void:
	if state == State.DEAD or state == State.PHASE2_ENTER:
		return

	AudioManager.play("enemy_hit")
	health -= amount
	health_changed.emit(health, MAX_HEALTH)

	if health <= 0:
		_die()
		return

	if not _phase2_triggered and health <= PHASE2_HP:
		_phase2_triggered = true
		phase             = 2
		atk_box.monitoring = false
		atk_col.disabled   = true
		state              = State.PHASE2_ENTER
		state_timer        = PHASE2_PAUSE

	_flash_red()


func _flash_red() -> void:
	visual.modulate = Color(1.6, 0.25, 0.25, 1.0)
	await get_tree().create_timer(0.14).timeout
	if is_instance_valid(self) and state != State.DEAD:
		visual.modulate = Color.WHITE


func _die() -> void:
	state              = State.DEAD
	atk_box.monitoring = false
	hurtbox.monitoring = false
	detect.monitoring  = false
	body_col.disabled  = true
	collision_layer    = 0
	collision_mask     = 0
	velocity           = Vector2.ZERO
	set_physics_process(false)

	GameData.gain_embers(EMBERS_DROP)
	AudioManager.play("enemy_die")
	boss_died.emit()

	if _death_tween:
		_death_tween.kill()
	_death_tween = create_tween().set_parallel(true)
	_death_tween.tween_property(visual, "modulate:a", 0.0, 1.4)
	_death_tween.tween_property(visual, "scale:y",    0.0, 1.4)


func _reset() -> void:
	if state != State.DEAD:
		return

	if _death_tween:
		_death_tween.kill()
		_death_tween = null

	visual.modulate = Color.WHITE
	visual.scale    = Vector2(1.0, 1.0)
	visual.rotation = 0.0

	health               = MAX_HEALTH
	phase                = 1
	state                = State.DORMANT
	state_timer          = 0.0
	charge_cd            = 0.0
	slam_ready           = true
	_phase2_triggered    = false
	_double_charge_avail = true
	player_ref           = null
	velocity             = Vector2.ZERO

	body_col.disabled  = false
	collision_layer    = 2
	collision_mask     = 1
	hurtbox.monitoring = true
	detect.monitoring  = true
	atk_box.monitoring = false
	atk_col.disabled   = true
	set_physics_process(false)  # wait for player to re-enter detect zone

	global_position = _spawn_position
