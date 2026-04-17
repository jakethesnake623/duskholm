extends CharacterBody2D

## FORGE-7 — "The Ember Engine"
## A construction golem built by the lost civilisation, corrupted after ages of
## neglect by the embers that now power it.  Much harder than The Warden.
##
## Lore is delivered via a typewriter panel before combat begins.
## State machine:
##   DORMANT → LORE → IDLE → WALK / WINDUP → CHARGE / EMBER_SHOT / EMBER_RAIN
##          → SLAM_RISE → SLAM_FALL → RECOIL → PHASE2_ENTER → DEAD

signal health_changed(current: int, maximum: int)
signal boss_died

const EMBER_GLOB_SCENE = preload("res://scenes/EmberGlob.tscn")

# ── Stats ────────────────────────────────────────────────────────────────────────
const GRAVITY         = 1200.0
const TERM_VEL        = 1500.0
const MAX_HEALTH      = 50
const PHASE2_HP       = 25
const EMBERS_DROP     = 1500

# Movement
const WALK_SPEED      = 45.0
const CHARGE_SPEED_P1 = 260.0
const CHARGE_SPEED_P2 = 340.0
const CHARGE_WINDUP_T = 0.85
const CHARGE_DUR      = 0.60
const CHARGE_COOLDOWN = 3.0
const CHARGE_RANGE    = 560.0
const CHARGE_DMG_P1   = 3
const CHARGE_DMG_P2   = 4

# Ember Shot
const SHOT_WINDUP_T   = 0.70
const SHOT_COOLDOWN   = 3.5
const GLOB_SPEED      = 300.0

# Ember Rain (phase 2)
const RAIN_WINDUP_T   = 1.00
const RAIN_COUNT      = 5
const RAIN_COOLDOWN   = 5.0

# Slam (phase 2)
const SLAM_RISE_VEL   = -500.0
const SLAM_FALL_VEL   = 850.0
const SLAM_RADIUS     = 300.0
const SLAM_DIRECT_DMG = 4
const SLAM_WAVE_DMG   = 2

# Timers
const RECOIL_TIME     = 0.80
const LORE_END_PAUSE  = 1.40
const PHASE2_PAUSE    = 2.50
const IDLE_DUR        = 0.65
const WALK_MAX_DUR    = 4.0

# ── Lore ─────────────────────────────────────────────────────────────────────────
const LORE_LINES := [
	["UNIT DESIGNATION: FORGE-7",          false, 0.05, 0.60],
	["STATUS: OPERATIONAL",                false, 0.05, 0.50],
	["INTRUDER CLASSIFIED: HOSTILE",       false, 0.05, 0.50],
	["INITIATING DEFENSIVE PROTOCOLS...",  false, 0.04, 1.20],
	["",                                   false, 0.00, 0.10],
	["core integrity: failing",            true,  0.08, 0.45],
	["i remember warmth... purpose...",    true,  0.08, 0.45],
	["they built us to serve. to create.", true,  0.08, 0.45],
	["they left. the embers remained.",    true,  0.08, 0.50],
	["they changed me.",                   true,  0.09, 0.60],
	["i cannot stop the burning.",         true,  0.09, 0.80],
	["",                                   false, 0.00, 0.10],
	["FORGE-7 ONLINE.",                    false, 0.04, 0.40],
	["ALL SYSTEMS: HOSTILE.",              false, 0.04, 0.00],
]
# Each entry: [text, is_corrupted_voice, char_delay, post_line_pause]

enum State {
	DORMANT, LORE, IDLE, WALK,
	WINDUP, CHARGE, EMBER_SHOT, EMBER_RAIN,
	SLAM_RISE, SLAM_FALL, RECOIL,
	PHASE2_ENTER, DEAD
}

# ── State ────────────────────────────────────────────────────────────────────────
var state               := State.DORMANT
var health              := MAX_HEALTH
var phase               := 1
var facing_right        := true
var state_timer         := 0.0
var charge_cd           := 0.0
var shot_cd             := 0.0
var rain_cd             := 0.0
var slam_ready          := true
var _phase2_triggered   := false
var _pending_action     := ""   # "charge" | "shot" | "rain" | "slam"
var _permanently_dead   := false

var player_ref      : CharacterBody2D = null
var _spawn_position : Vector2
var _death_tween    : Tween = null

# Lore
var _lore_line_idx   := 0
var _lore_char_idx   := 0
var _lore_char_timer := 0.0
var _lore_pause      := 0.0
var _lore_layer      : CanvasLayer = null
var _lore_label      : Label       = null
var _lore_bg         : ColorRect   = null
var _lore_end_timer  := 0.0

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
	_build_lore_panel()

	detect.body_entered.connect(_on_detect_entered)
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	atk_box.body_entered.connect(_on_atk_body)

	atk_box.monitoring = false
	atk_col.disabled   = true

	GameData.rested.connect(_reset)
	set_physics_process(false)


# ── Visual ───────────────────────────────────────────────────────────────────────

func _build_visual() -> void:
	var iron   := Color(0.20, 0.18, 0.16, 1.0)   # dark gunmetal
	var copper := Color(0.55, 0.38, 0.14, 1.0)   # copper trim
	var ember  := Color(0.98, 0.44, 0.06, 0.92)  # furnace glow
	var dark   := Color(0.10, 0.09, 0.08, 1.0)   # deep shadow

	# Furnace torso (the core body)
	_rect(Vector2( 0,  -35), Vector2(88, 90), iron)
	# Torso inner shadow (depth)
	_rect(Vector2( 0,  -35), Vector2(80, 82), dark)

	# Furnace glow slits — three horizontal amber openings
	_rect(Vector2( 0,  -54), Vector2(68,  9), ember)
	_rect(Vector2( 0,  -38), Vector2(68,  9), ember)
	_rect(Vector2( 0,  -22), Vector2(68,  9), ember)

	# Copper rivets / trim along torso edges
	_rect(Vector2(-44, -35), Vector2( 6, 90), copper)
	_rect(Vector2( 44, -35), Vector2( 6, 90), copper)
	_rect(Vector2(  0, -80), Vector2(88,  6), copper)
	_rect(Vector2(  0,  10), Vector2(88,  6), copper)

	# Smokestack
	_rect(Vector2(-18, -94), Vector2(16, 22), iron)
	_rect(Vector2(-18, -98), Vector2(22,  8), copper)

	# Left arm (heavy hammer side)
	_rect(Vector2(-58, -28), Vector2(24, 50), iron)
	_rect(Vector2(-60, +10), Vector2(32, 18), iron)    # hammer head
	_rect(Vector2(-60, +10), Vector2(32, 18), copper)  # copper face

	# Right arm (cannon / launcher side)
	_rect(Vector2( 58, -32), Vector2(24, 44), iron)
	_rect(Vector2( 72, -30), Vector2(20,  8), copper)  # cannon barrel
	_rect(Vector2( 82, -31), Vector2( 8, 10), ember)   # barrel opening glow

	# Heavy legs
	_rect(Vector2(-26,  22), Vector2(28, 42), iron)
	_rect(Vector2( 26,  22), Vector2(28, 42), iron)
	# Boot plates
	_rect(Vector2(-26,  50), Vector2(34, 12), copper)
	_rect(Vector2( 26,  50), Vector2(34, 12), copper)

	# Eye glow (amber, above the slits)
	for ex in [-16.0, 16.0]:
		var eye := ColorRect.new()
		eye.size     = Vector2(10.0, 10.0)
		eye.position = Vector2(ex - 5.0, -76.0)
		eye.color    = ember
		visual.add_child(eye)


func _rect(center: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.size     = size
	r.position = center - size * 0.5
	r.color    = color
	visual.add_child(r)


# ── Lore panel ───────────────────────────────────────────────────────────────────

func _build_lore_panel() -> void:
	_lore_layer = CanvasLayer.new()
	_lore_layer.layer        = 10
	_lore_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_lore_layer.visible      = false
	add_child(_lore_layer)

	_lore_bg = ColorRect.new()
	_lore_bg.position = Vector2(0.0, 615.0)
	_lore_bg.size     = Vector2(1280.0, 105.0)
	_lore_bg.color    = Color(0.04, 0.03, 0.02, 0.90)
	_lore_layer.add_child(_lore_bg)

	_lore_label = Label.new()
	_lore_label.add_theme_font_size_override("font_size", 13)
	_lore_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1.0))
	_lore_label.position             = Vector2(60.0, 624.0)
	_lore_label.size                 = Vector2(1160.0, 90.0)
	_lore_label.autowrap_mode        = TextServer.AUTOWRAP_WORD
	_lore_label.text                 = ""
	_lore_layer.add_child(_lore_label)


func _lore_set_color(corrupted: bool) -> void:
	if corrupted:
		_lore_label.add_theme_color_override("font_color", Color(0.90, 0.55, 0.12, 0.90))
	else:
		_lore_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1.0))


# ── Physics loop ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_apply_gravity(delta)
	state_timer -= delta
	charge_cd    = maxf(charge_cd - delta, 0.0)
	shot_cd      = maxf(shot_cd   - delta, 0.0)
	rain_cd      = maxf(rain_cd   - delta, 0.0)

	match state:
		State.LORE:         _state_lore(delta)
		State.IDLE:         _state_idle()
		State.WALK:         _state_walk()
		State.WINDUP:       _state_windup(delta)
		State.CHARGE:       _state_charge()
		State.EMBER_SHOT:   _state_ember_shot()
		State.EMBER_RAIN:   _state_ember_rain()
		State.SLAM_RISE:    _state_slam_rise()
		State.SLAM_FALL:    _state_slam_fall()
		State.RECOIL:       _state_recoil(delta)
		State.PHASE2_ENTER: _state_phase2_enter()

	_update_facing()
	_animate(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if state == State.SLAM_FALL:
		velocity.y = SLAM_FALL_VEL
	elif not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, TERM_VEL)


# ── Lore state ───────────────────────────────────────────────────────────────────

func _state_lore(delta: float) -> void:
	velocity.x = 0.0

	# All lore lines done — wait then start fighting
	if _lore_line_idx >= LORE_LINES.size():
		_lore_end_timer += delta
		if _lore_end_timer >= LORE_END_PAUSE:
			_lore_layer.visible = false
			AudioManager.play("furnace_roar")
			state       = State.IDLE
			state_timer = IDLE_DUR
		return

	var entry      : Array  = LORE_LINES[_lore_line_idx]
	var line_text  : String = entry[0]
	var corrupted  : bool   = entry[1]
	var char_delay : float  = entry[2]
	var post_pause : float  = entry[3]

	# Blank/pause lines — just wait
	if line_text.length() == 0:
		_lore_pause += delta
		if _lore_pause >= 0.80:
			_lore_pause      = 0.0
			_lore_line_idx  += 1
			_lore_label.text = ""
		return

	# Type out characters
	if _lore_char_idx < line_text.length():
		_lore_char_timer += delta
		if _lore_char_timer >= char_delay:
			_lore_char_timer = 0.0
			_lore_char_idx  += 1
			_lore_set_color(corrupted)
			_lore_label.text = line_text.left(_lore_char_idx)
	else:
		# Line complete — wait post_pause then move on
		_lore_pause += delta
		if _lore_pause >= post_pause:
			_lore_pause      = 0.0
			_lore_line_idx  += 1
			_lore_char_idx   = 0
			_lore_char_timer = 0.0
			_lore_label.text = ""


# ── Combat states ────────────────────────────────────────────────────────────────

func _state_idle() -> void:
	velocity.x = 0.0
	if state_timer <= 0.0:
		_decide_action()


func _decide_action() -> void:
	if not is_instance_valid(player_ref):
		state = State.DORMANT
		set_physics_process(false)
		return

	var diff := player_ref.global_position - global_position
	var dist := abs(diff.x)
	var speed_mult := 1.0 if phase == 1 else 1.30

	# Phase 2 priority: slam if ready and player close
	if phase == 2 and slam_ready and dist < 420.0:
		slam_ready = false
		_pending_action = "slam"
		state       = State.WINDUP
		state_timer = CHARGE_WINDUP_T * speed_mult
		velocity.x  = 0.0
		return

	# Ember rain (phase 2 only)
	if phase == 2 and rain_cd <= 0.0 and dist > 200.0:
		_pending_action = "rain"
		state       = State.WINDUP
		state_timer = RAIN_WINDUP_T / speed_mult
		velocity.x  = 0.0
		return

	# Charge if in range and off cooldown
	if dist < CHARGE_RANGE and charge_cd <= 0.0:
		_pending_action = "charge"
		state       = State.WINDUP
		state_timer = CHARGE_WINDUP_T / speed_mult
		velocity.x  = 0.0
		return

	# Ember shot if off cooldown
	if shot_cd <= 0.0:
		_pending_action = "shot"
		state       = State.WINDUP
		state_timer = SHOT_WINDUP_T / speed_mult
		velocity.x  = 0.0
		return

	# Default: walk toward player
	state       = State.WALK
	state_timer = WALK_MAX_DUR


func _state_walk() -> void:
	if not is_instance_valid(player_ref):
		state       = State.IDLE
		state_timer = IDLE_DUR
		return

	var diff := player_ref.global_position - global_position
	velocity.x = sign(diff.x) * WALK_SPEED

	if state_timer <= 0.0:
		state       = State.IDLE
		state_timer = IDLE_DUR


func _state_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
	if state_timer > 0.0:
		return

	match _pending_action:
		"charge": _begin_charge()
		"shot":   state = State.EMBER_SHOT
		"rain":   state = State.EMBER_RAIN
		"slam":   _begin_slam_rise()


func _begin_charge() -> void:
	var spd : float = CHARGE_SPEED_P2 if phase == 2 else CHARGE_SPEED_P1
	var dir : float = 1.0 if facing_right else -1.0
	atk_col.position   = Vector2(55.0 * dir, 0.0)
	atk_box.monitoring = true
	atk_col.disabled   = false
	velocity.x         = dir * spd
	state              = State.CHARGE
	state_timer        = CHARGE_DUR


func _state_charge() -> void:
	if is_on_wall() or state_timer <= 0.0:
		atk_box.monitoring = false
		atk_col.disabled   = true
		velocity.x         = 0.0
		charge_cd          = CHARGE_COOLDOWN
		state              = State.RECOIL
		state_timer        = RECOIL_TIME


func _state_ember_shot() -> void:
	var count := 3 if phase == 2 else 2
	for i in count:
		_fire_glob(i, count)
	shot_cd    = SHOT_COOLDOWN
	state      = State.RECOIL
	state_timer = RECOIL_TIME


func _fire_glob(idx: int, total: int) -> void:
	if not is_instance_valid(player_ref):
		return
	var glob := EMBER_GLOB_SCENE.instantiate() as Area2D
	var diff := player_ref.global_position - global_position
	# Spread shots slightly around the aimed direction
	var spread_t : float = (float(idx) / float(total - 1) - 0.5) * 0.5 if total > 1 else 0.0
	var aim_angle : float = atan2(diff.y - 80.0, diff.x) + spread_t
	var vel := Vector2(cos(aim_angle), sin(aim_angle)) * GLOB_SPEED
	# Add upward arc bias so it follows a parabola rather than going straight
	vel.y -= 180.0
	glob.global_position = global_position + Vector2((1.0 if facing_right else -1.0) * 50.0, -30.0)
	glob.setup(vel)
	get_parent().add_child(glob)
	AudioManager.play("ember_glob")


func _state_ember_rain() -> void:
	# Fire RAIN_COUNT globs in a wide fan upward — they fall back down as hazards
	for i in RAIN_COUNT:
		var glob := EMBER_GLOB_SCENE.instantiate() as Area2D
		var t    : float = float(i) / float(RAIN_COUNT - 1)   # 0.0 → 1.0
		var angle: float = lerpf(-1.10, -0.08, t)             # fan: upper-left → upper-right
		var speed: float = lerpf(340.0, 420.0, abs(t - 0.5) * 2.0)
		var vel  : Vector2 = Vector2(cos(angle), sin(angle)) * speed
		glob.global_position = global_position + Vector2(0.0, -60.0)
		glob.setup(vel)
		get_parent().add_child(glob)
		AudioManager.play("ember_glob")
	rain_cd    = RAIN_COOLDOWN
	state      = State.RECOIL
	state_timer = RECOIL_TIME * 1.3


func _begin_slam_rise() -> void:
	state      = State.SLAM_RISE
	velocity.y = SLAM_RISE_VEL
	velocity.x = 0.0


func _state_slam_rise() -> void:
	if velocity.y >= 0.0:
		state = State.SLAM_FALL


func _state_slam_fall() -> void:
	if is_on_floor():
		_on_slam_land()
		state       = State.RECOIL
		state_timer = RECOIL_TIME * 1.5
		velocity.x  = 0.0


func _on_slam_land() -> void:
	AudioManager.play("slam")
	slam_ready = true
	if not is_instance_valid(player_ref):
		return
	var dist := abs(player_ref.global_position.x - global_position.x)
	if dist < SLAM_RADIUS and player_ref.is_on_floor() and player_ref.has_method("take_damage"):
		var dir := (player_ref.global_position - global_position).normalized()
		player_ref.take_damage(SLAM_DIRECT_DMG, dir)
	if phase == 2:
		_slam_shockwave()


func _slam_shockwave() -> void:
	await get_tree().create_timer(0.20).timeout
	if not is_instance_valid(self) or state == State.DEAD:
		return
	if not is_instance_valid(player_ref):
		return
	var dist := abs(player_ref.global_position.x - global_position.x)
	if dist >= SLAM_RADIUS and dist < SLAM_RADIUS * 2.0 and player_ref.is_on_floor():
		var dir := (player_ref.global_position - global_position).normalized()
		player_ref.take_damage(SLAM_WAVE_DMG, dir)


func _state_recoil(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
	if state_timer <= 0.0:
		state       = State.IDLE
		state_timer = IDLE_DUR


func _state_phase2_enter() -> void:
	velocity.x = 0.0
	if state_timer <= 0.0:
		state       = State.IDLE
		state_timer = IDLE_DUR
		slam_ready  = true


# ── Facing & animation ───────────────────────────────────────────────────────────

func _update_facing() -> void:
	if velocity.x > 5.0:
		facing_right   = true
		visual.scale.x = 1.0
	elif velocity.x < -5.0:
		facing_right   = false
		visual.scale.x = -1.0
	elif is_instance_valid(player_ref):
		match state:
			State.IDLE, State.DORMANT, State.LORE, State.PHASE2_ENTER:
				facing_right   = player_ref.global_position.x > global_position.x
				visual.scale.x = 1.0 if facing_right else -1.0


func _animate(delta: float) -> void:
	var t_scale_y : float = 1.0
	var t_lean    : float = 0.0
	var facing    : float = 1.0 if facing_right else -1.0

	match state:
		State.LORE:
			t_scale_y = 1.04
		State.WINDUP:
			t_scale_y = 0.88
			t_lean    = 0.10 * facing
		State.CHARGE:
			t_scale_y = 1.12
			t_lean    = 0.18 * facing
		State.SLAM_RISE:
			t_scale_y = 1.22
		State.SLAM_FALL:
			t_scale_y = 0.80
		State.RECOIL:
			t_scale_y = 1.08
			t_lean    = -0.12 * facing
		State.PHASE2_ENTER:
			t_scale_y = 1.20

	# Phase 2: furnace glows brighter — pulse the slit opacity via modulate
	if phase == 2 and state != State.DEAD:
		var t := Time.get_ticks_msec() * 0.004
		visual.modulate.r = 1.0 + 0.12 * sin(t)
		visual.modulate.g = 1.0
		visual.modulate.b = 1.0

	visual.scale.y  = lerpf(visual.scale.y,  t_scale_y, 5.0 * delta)
	visual.rotation = lerpf(visual.rotation, t_lean,    4.0 * delta)


# ── Signals ──────────────────────────────────────────────────────────────────────

func _on_detect_entered(body: Node) -> void:
	if body.is_in_group("player") and state == State.DORMANT:
		player_ref = body
		state      = State.LORE
		_lore_layer.visible = true
		_lore_line_idx  = 0
		_lore_char_idx  = 0
		_lore_end_timer = 0.0
		set_physics_process(true)


func _on_hurtbox_hit(area: Area2D) -> void:
	if area.name == "NailHitbox":
		_take_damage(GameData.get_nail_damage())
	elif area.name == "EmberBolt":
		_take_damage(1)


func _on_atk_body(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		var dmg : int = CHARGE_DMG_P2 if phase == 2 else CHARGE_DMG_P1
		var dir := Vector2(1.0 if facing_right else -1.0, -0.3).normalized()
		body.take_damage(dmg, dir)


# ── Damage & death ───────────────────────────────────────────────────────────────

func _take_damage(amount: int) -> void:
	if state == State.DEAD or state == State.LORE or state == State.PHASE2_ENTER:
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
	visual.modulate = Color(1.8, 0.35, 0.10, 1.0)
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self) and state != State.DEAD:
		visual.modulate = Color.WHITE


func _die() -> void:
	_permanently_dead  = true
	state              = State.DEAD
	atk_box.monitoring = false
	hurtbox.monitoring = false
	detect.monitoring  = false
	body_col.disabled  = true
	collision_layer    = 0
	collision_mask     = 0
	velocity           = Vector2.ZERO
	_lore_layer.visible = false
	set_physics_process(false)

	GameData.gain_embers(EMBERS_DROP)
	AudioManager.play("enemy_die")
	boss_died.emit()

	if _death_tween:
		_death_tween.kill()
	_death_tween = create_tween().set_parallel(true)
	_death_tween.tween_property(visual, "modulate:a", 0.0, 2.0)
	_death_tween.tween_property(visual, "scale:y",    0.0, 2.0)


# ── Reset (resting at a well) ────────────────────────────────────────────────────

func _reset() -> void:
	if state != State.DEAD or _permanently_dead:
		return

	if _death_tween:
		_death_tween.kill()
		_death_tween = null

	visual.modulate = Color.WHITE
	visual.scale    = Vector2(1.0, 1.0)
	visual.rotation = 0.0

	health              = MAX_HEALTH
	phase               = 1
	state               = State.DORMANT
	state_timer         = 0.0
	charge_cd           = 0.0
	shot_cd             = 0.0
	rain_cd             = 0.0
	slam_ready          = true
	_phase2_triggered   = false
	player_ref          = null
	velocity            = Vector2.ZERO
	_lore_line_idx      = 0
	_lore_char_idx      = 0
	_lore_end_timer     = 0.0
	_lore_layer.visible = false
	_lore_label.text    = ""

	body_col.disabled  = false
	collision_layer    = 2
	collision_mask     = 1
	hurtbox.monitoring = true
	detect.monitoring  = true
	atk_box.monitoring = false
	atk_col.disabled   = true
	set_physics_process(false)
	global_position = _spawn_position
