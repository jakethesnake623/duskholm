extends CharacterBody2D

const THROWABLE_SCENE   = preload("res://scenes/Throwable.tscn")
const EMBER_BOLT_SCENE  = preload("res://scenes/EmberBolt.tscn")

signal health_changed(current: int, maximum: int)
signal died(death_pos: Vector2, ember_amount: int)
signal respawned

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

# --- Ember Launcher ---
const FIRE_RATE      = 0.12    # seconds between shots
const HEAT_PER_SHOT  = 0.125   # 8 shots fills the bar
const HEAT_COOL_RATE = 0.30    # heat lost per second when not firing
const OVERHEAT_DUR   = 2.2     # seconds locked after overheating

var debug_invincible  := false

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
var _on_zipline   := false

# --- Ember Launcher state ---
var active_weapon    := "nail"   # "nail" or "launcher"
var _heat            := 0.0
var _overheating     := false
var _overheat_timer  := 0.0
var _fire_timer      := 0.0
var _fired_this_frame := false

# Launcher HUD refs (built at runtime)
var _launcher_barrel : ColorRect = null
var _launcher_hud    : CanvasLayer = null
var _heat_fill       : ColorRect   = null
var _heat_bg         : ColorRect   = null
var _weapon_lbl      : Label       = null
var _overheat_lbl    : Label       = null

# --- Procedural animation ---
const LAND_SQUASH_TIME := 0.18
var _was_on_floor := true
var _land_timer   := 0.0
var _walk_phase   := 0.0
var _slash_angle  := -1.20   # current rotation of the nail hitbox (drives the arc)
var _slash_target :=  1.20   # target rotation — move_toward converges here each frame

@onready var visual        : Node2D           = $Visual
@onready var nail_hitbox   : Area2D           = $NailHitbox
@onready var nail_collision: CollisionShape2D = $NailHitbox/NailCollision
@onready var nail_visual   : ColorRect        = $NailHitbox/NailVisual


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2   # own layer — world is 1, so enemy mask=1 won't detect us
	collision_mask  = 1   # only collide with world geometry
	spawn_position     = global_position
	last_safe_position = global_position
	health = GameData.get_max_health()
	nail_hitbox.area_entered.connect(_on_nail_area_entered)
	_build_launcher_visual()
	_build_launcher_hud()
	GameData.upgrade_purchased.connect(func(_k: String): _on_upgrade_purchased())


# ── Launcher visual & HUD setup ────────────────────────────────────────────────

func _build_launcher_visual() -> void:
	# Brass barrel — child of Visual so it flips with facing direction
	_launcher_barrel = ColorRect.new()
	_launcher_barrel.size     = Vector2(18.0, 5.0)
	_launcher_barrel.position = Vector2(6.0, -12.0)
	_launcher_barrel.color    = Color(0.68, 0.50, 0.18, 1.0)
	_launcher_barrel.visible  = false
	visual.add_child(_launcher_barrel)

	# Small copper band at the base of the barrel
	var band := ColorRect.new()
	band.size     = Vector2(5.0, 7.0)
	band.position = Vector2(4.0, -13.0)
	band.color    = Color(0.55, 0.38, 0.12, 1.0)
	band.visible  = false
	visual.add_child(band)
	# Stow a reference so we can toggle it alongside the barrel
	_launcher_barrel.set_meta("band", band)


func _build_launcher_hud() -> void:
	_launcher_hud = CanvasLayer.new()
	_launcher_hud.layer = 3
	add_child(_launcher_hud)

	# Weapon label  e.g. "[T] LAUNCHER"
	_weapon_lbl = Label.new()
	_weapon_lbl.add_theme_font_size_override("font_size", 10)
	_weapon_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65, 0.90))
	_weapon_lbl.position = Vector2(8.0, 660.0)
	_weapon_lbl.size     = Vector2(140.0, 14.0)
	_launcher_hud.add_child(_weapon_lbl)

	# Heat bar background
	_heat_bg = ColorRect.new()
	_heat_bg.position = Vector2(8.0, 676.0)
	_heat_bg.size     = Vector2(100.0, 6.0)
	_heat_bg.color    = Color(0.10, 0.08, 0.06, 0.80)
	_launcher_hud.add_child(_heat_bg)

	# Heat bar fill
	_heat_fill = ColorRect.new()
	_heat_fill.position = Vector2(8.0, 676.0)
	_heat_fill.size     = Vector2(0.0, 6.0)
	_heat_fill.color    = Color(0.95, 0.50, 0.08, 1.0)
	_launcher_hud.add_child(_heat_fill)

	# Overheat label
	_overheat_lbl = Label.new()
	_overheat_lbl.text = "VENTING..."
	_overheat_lbl.add_theme_font_size_override("font_size", 9)
	_overheat_lbl.add_theme_color_override("font_color", Color(1.0, 0.20, 0.10, 0.90))
	_overheat_lbl.position = Vector2(112.0, 672.0)
	_overheat_lbl.visible  = false
	_launcher_hud.add_child(_overheat_lbl)

	_refresh_launcher_hud_visibility()


func _on_upgrade_purchased() -> void:
	_refresh_launcher_hud_visibility()


func _refresh_launcher_hud_visibility() -> void:
	var owned := GameData.has_launcher()
	_launcher_hud.visible = owned
	if owned:
		_update_launcher_hud()


# ── Launcher per-frame ─────────────────────────────────────────────────────────

func _handle_launcher(delta: float) -> void:
	_fired_this_frame = false

	if _overheating:
		_overheat_timer -= delta
		if _overheat_timer <= 0.0:
			_overheating    = false
			_heat           = 0.0
			_overheat_timer = 0.0
	else:
		_fire_timer = maxf(_fire_timer - delta, 0.0)

		if Input.is_action_pressed("attack") and _fire_timer <= 0.0:
			_fire_bolt()
			_heat += HEAT_PER_SHOT
			_fire_timer = FIRE_RATE
			_fired_this_frame = true

			if _heat >= 1.0:
				_heat = 1.0
				_overheating    = true
				_overheat_timer = OVERHEAT_DUR
				AudioManager.play("overheat")

	# Cool down when not actively firing
	if not _fired_this_frame and not _overheating:
		_heat = maxf(_heat - HEAT_COOL_RATE * delta, 0.0)

	_update_launcher_hud()


func _fire_bolt() -> void:
	var bolt := EMBER_BOLT_SCENE.instantiate() as Area2D
	var dir   : float = 1.0 if facing_right else -1.0
	bolt.global_position = global_position + Vector2(dir * 14.0, -12.0)
	bolt.setup(dir)
	get_parent().add_child(bolt)
	AudioManager.play("ember_shot", -4.0)


func _update_launcher_hud() -> void:
	if _weapon_lbl == null:
		return

	_weapon_lbl.text = "[T] LAUNCHER" if active_weapon == "launcher" else "[T] NAIL"

	var bar_width : float = _heat * 100.0
	_heat_fill.size.x = bar_width

	# Colour shifts amber → red as heat rises
	var r := lerpf(0.95, 1.0,  _heat)
	var g := lerpf(0.50, 0.10, _heat)
	_heat_fill.color = Color(r, g, 0.06, 1.0)

	_heat_bg.visible       = (active_weapon == "launcher")
	_heat_fill.visible     = (active_weapon == "launcher")
	_overheat_lbl.visible  = _overheating


func _set_active_weapon(weapon: String) -> void:
	active_weapon = weapon
	var launcher_on := (weapon == "launcher")
	_launcher_barrel.visible = launcher_on
	if _launcher_barrel.has_meta("band"):
		(_launcher_barrel.get_meta("band") as ColorRect).visible = launcher_on
	_update_launcher_hud()


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
	if active_weapon == "launcher" and GameData.has_launcher():
		_handle_launcher(delta)
	else:
		_handle_attack()
	_handle_throw()
	_update_visuals(delta)
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
		nail_hitbox.rotation    = 0.0
		nail_collision.disabled = true
		nail_visual.visible     = false
		nail_visual.rotation    = 0.0


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
			AudioManager.play("jump")
		elif extra_jumps > 0:
			# Air jump — double jump
			velocity.y        = JUMP_VELOCITY * 0.90
			extra_jumps      -= 1
			jump_buffer_timer = 0.0
			AudioManager.play("jump", -5.0)

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


# ── Throw ──────────────────────────────────────────────────────────────────────

func _handle_throw() -> void:
	if Input.is_action_just_pressed("cycle_throwable"):
		GameData.cycle_throwable()
	if Input.is_action_just_pressed("throw") and not is_dashing:
		_throw_item()


func _throw_item() -> void:
	if not GameData.use_throwable():
		return
	AudioManager.play("throw")
	var proj := THROWABLE_SCENE.instantiate() as Area2D
	get_parent().add_child(proj)
	var dir    : float   = 1.0 if facing_right else -1.0
	var offset : Vector2 = Vector2(dir * 10.0, -16.0)
	proj.global_position = global_position + offset
	proj.setup(GameData.active_throwable, dir)


func _swing_nail() -> void:
	is_attacking = true
	attack_timer = ATTACK_COOLDOWN
	AudioManager.play("swing")

	var range  : float = GameData.get_nail_range()

	# The arc sweeps from up-forward to down-forward (a downward slash).
	# For facing left the sweep mirrors: upper-left → lower-left.
	# Both arcs span 2.4 radians and the hitbox rotates around the player's centre.
	if facing_right:
		_slash_angle  = -1.20
		_slash_target =  1.20
	else:
		_slash_angle  =  PI - 1.20   # upper-left  (≈ 1.94 rad)
		_slash_target =  PI + 1.20   # lower-left  (≈ 4.34 rad)

	# Hitbox lives at the player's origin and rotates as a whole.
	# The blade extends in local +X so the rotation sweeps it through the arc.
	nail_hitbox.position = Vector2.ZERO
	nail_hitbox.rotation = _slash_angle

	var col_shape := nail_collision.shape as RectangleShape2D
	col_shape.size             = Vector2(range, 10.0)
	nail_collision.position    = Vector2(range * 0.5 + 8.0, 0.0)

	# Visual: a strip starting 8 px from the player centre, extending to range.
	# No individual rotation — the parent hitbox handles it.
	nail_visual.position      = Vector2(8.0, -3.5)
	nail_visual.size          = Vector2(range, 7.0)
	nail_visual.pivot_offset  = Vector2(0.0, 3.5)
	nail_visual.rotation      = 0.0

	nail_hitbox.monitoring  = true
	nail_collision.disabled = false
	nail_visual.visible     = true


# ── Health ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_Y and event.pressed and not event.echo:
		debug_invincible = not debug_invincible

	if event.is_action_pressed("switch_weapon") and GameData.has_launcher():
		_set_active_weapon("launcher" if active_weapon == "nail" else "nail")


func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if debug_invincible or i_frames_timer > 0.0 or is_dashing:
		return

	health = max(health - amount, 0)
	i_frames_timer = I_FRAMES
	AudioManager.play("player_hit")

	if knockback_dir != Vector2.ZERO:
		velocity.x = knockback_dir.normalized().x * KNOCKBACK_FORCE
		velocity.y = -200.0

	health_changed.emit(health, GameData.get_max_health())

	if health <= 0:
		_die()


func heal(amount: int) -> void:
	health = mini(health + amount, GameData.get_max_health())
	health_changed.emit(health, GameData.get_max_health())


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
	AudioManager.play("player_die")
	died.emit(last_safe_position, GameData.drop_all())
	set_physics_process(false)
	visual.modulate.a = 0.0
	# World listens to `died` and shows the death screen; respawn() is called from there.


func start_zip(end_world_pos: Vector2, duration: float) -> void:
	if _on_zipline:
		return
	_on_zipline    = true
	velocity       = Vector2.ZERO
	i_frames_timer = duration + 0.3   # invincible for the full ride
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "global_position", end_world_pos, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_end_zip)


func _end_zip() -> void:
	_on_zipline = false
	velocity    = Vector2.ZERO
	set_physics_process(true)


func respawn() -> void:
	health          = GameData.get_max_health()
	global_position = spawn_position
	velocity        = Vector2.ZERO
	i_frames_timer  = I_FRAMES
	is_dashing      = false
	_heat           = 0.0
	_overheating    = false
	_overheat_timer = 0.0
	_fire_timer     = 0.0
	visual.modulate.a = 1.0
	set_physics_process(true)
	health_changed.emit(health, GameData.get_max_health())
	respawned.emit()


# ── Visuals ────────────────────────────────────────────────────────────────────

func _update_visuals(delta: float) -> void:
	var on_floor := is_on_floor()

	# ── Landing detection ──────────────────────────────────────────────────────
	if on_floor and not _was_on_floor:
		_land_timer = LAND_SQUASH_TIME
		AudioManager.play("land")
	_was_on_floor  = on_floor
	_land_timer    = max(_land_timer - delta, 0.0)

	# ── Walk oscillation phase ─────────────────────────────────────────────────
	if on_floor and abs(velocity.x) > 30.0:
		_walk_phase += delta * 9.0

	# ── Choose target scale & rotation ────────────────────────────────────────
	var t_scale := Vector2.ONE
	var t_rot   := 0.0

	if is_dashing:
		# Wide flat streak during dash
		t_scale = Vector2(1.28, 0.70)
	elif _land_timer > 0.0:
		# Landing squash: wide + flat, springs back as timer expires
		var p := _land_timer / LAND_SQUASH_TIME   # 1.0 (just landed) → 0.0 (recovered)
		t_scale = Vector2(1.0 + 0.28 * p, 1.0 - 0.26 * p)
	elif not on_floor:
		# Air: stretch on ascent, slight squash on descent
		var t := clampf(-velocity.y / 480.0, -0.8, 1.0)
		t_scale = Vector2(1.0 - 0.12 * t, 1.0 + 0.16 * t)
		# Lean forward in the direction of horizontal travel
		t_rot = clampf(velocity.x / 520.0, -0.22, 0.22)
	elif abs(velocity.x) > 30.0:
		# Walking: gentle vertical bob + directional lean
		var bob := sin(_walk_phase) * 0.022
		t_scale = Vector2(1.0, 0.98 + bob)
		t_rot   = clampf(velocity.x / 520.0, -0.10, 0.10)

	# Bake facing sign into the scale target so the lerp always converges
	# correctly. Without this, a positive t_scale.x would fight a negative
	# scale.x (facing left) each frame, oscillating near 0 and making the
	# character appear flat/invisible when moving left.
	var face: float = 1.0 if facing_right else -1.0
	visual.scale    = visual.scale.lerp(Vector2(t_scale.x * face, t_scale.y), 14.0 * delta)
	visual.rotation = lerpf(visual.rotation, t_rot, 10.0 * delta)

	# ── Modulate (colour effects) ──────────────────────────────────────────────
	if debug_invincible:
		visual.modulate = Color(0.40, 1.0, 1.0, 0.85)
	elif is_dashing:
		visual.modulate = Color(1.4, 1.4, 2.0, 0.85)
	elif i_frames_timer > 0.0:
		visual.modulate.a = 0.25 + 0.75 * abs(sin(Time.get_ticks_msec() * 0.015))
		visual.modulate.r = 1.0
		visual.modulate.g = 1.0
		visual.modulate.b = 1.0
	else:
		var cf := GameData.get_corruption_factor()
		if cf <= 0.0:
			visual.modulate = Color.WHITE
		else:
			# Shift from white toward void-purple-black as embers accumulate.
			# At full corruption the player looks like a hollow silhouette.
			var t := Time.get_ticks_msec() * 0.006
			# Heavy corruption (cf ≥ 0.75) adds a slow dark pulse
			var pulse := 0.0
			if cf >= 0.75:
				pulse = (0.5 + 0.5 * sin(t)) * ((cf - 0.75) / 0.25) * 0.18
			visual.modulate = Color(
				lerpf(1.0, 0.38 - pulse, cf),   # red   — drains away
				lerpf(1.0, 0.16,         cf),   # green — drains fastest
				lerpf(1.0, 0.50 + pulse, cf)    # blue  — shifts toward void-purple
			)

	# ── Nail slash arc ─────────────────────────────────────────────────────────
	if is_attacking:
		_slash_angle         = move_toward(_slash_angle, _slash_target, 16.0 * delta)
		nail_hitbox.rotation = _slash_angle
