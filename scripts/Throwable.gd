extends Area2D

## Throwable consumable projectile.
## setup() must be called immediately after instantiation.
## Handles two types:
##   "flask" — arcs with gravity, 2 damage on impact
##   "shard" — straight fast shot, 1 damage on impact

const GRAVITY         := 950.0
const FLASK_SPEED_X   := 360.0
const FLASK_SPEED_Y   := -160.0
const SHARD_SPEED     := 580.0
const LIFETIME        := 5.0
const EXPLODE_RADIUS  := 80.0

var _type   : String  = "flask"
var _damage : int     = 1
var _vel    : Vector2 = Vector2.ZERO
var _timer  : float   = 0.0
var _hit    : bool    = false

@onready var col : CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	monitoring  = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(throw_type: String, dir: float) -> void:
	_type = throw_type
	var shape := col.shape as RectangleShape2D
	if throw_type == "flask":
		_damage  = 2
		_vel     = Vector2(dir * FLASK_SPEED_X, FLASK_SPEED_Y)
		shape.size = Vector2(12.0, 12.0)
		_build_flask_visual()
	else:  # shard
		_damage  = 1
		_vel     = Vector2(dir * SHARD_SPEED, 0.0)
		shape.size = Vector2(18.0, 6.0)
		_build_shard_visual()


func _physics_process(delta: float) -> void:
	if _hit:
		return
	_timer += delta
	if _timer >= LIFETIME:
		queue_free()
		return
	if _type == "flask":
		_vel.y = minf(_vel.y + GRAVITY * delta, 900.0)
	position += _vel * delta


# ── Collision handlers ─────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if _hit or body.is_in_group("player"):
		return
	if body is StaticBody2D:
		if _type == "flask":
			_flask_explode()
		else:
			_impact_shard()


func _on_area_entered(area: Area2D) -> void:
	if _hit:
		return
	if area.name == "Hurtbox":
		if _type == "flask":
			# Explosion handles all damage — don't deal direct hit here
			_flask_explode()
		else:
			var parent := area.get_parent()
			if parent.has_method("_take_damage"):
				parent._take_damage(_damage)
			_impact_shard()


# ── Flask explosion ────────────────────────────────────────────────────────────

func _flask_explode() -> void:
	_hit       = true
	monitoring = false

	# Synchronous AoE scan — find every Hurtbox within EXPLODE_RADIUS
	var space  : PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius              = EXPLODE_RADIUS
	params.shape               = circle
	params.transform           = Transform2D(0.0, global_position)
	params.collide_with_areas  = true
	params.collide_with_bodies = false
	params.collision_mask      = 1
	params.exclude             = [get_rid()]
	var hits : Array[Dictionary] = space.intersect_shape(params)

	# Damage each enemy once (guard against multiple Hurtbox shapes per enemy)
	var damaged : Array[Node] = []
	for hit in hits:
		var collider : Object = hit.get("collider")
		if collider is Area2D and (collider as Area2D).name == "Hurtbox":
			var parent : Node = (collider as Node).get_parent()
			if parent not in damaged and parent.has_method("_take_damage"):
				damaged.append(parent)
				parent._take_damage(_damage)

	AudioManager.play("explode")
	_spawn_explosion()

	# Snap the flask itself out immediately
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.06)
	tween.tween_callback(queue_free)


func _spawn_explosion() -> void:
	var boom := Node2D.new()
	boom.global_position = global_position
	get_parent().add_child(boom)

	var tw := boom.create_tween().set_parallel(true)

	# Central flash — bright white-orange square that scales up and fades
	var flash := ColorRect.new()
	flash.size     = Vector2(22.0, 22.0)
	flash.position = Vector2(-11.0, -11.0)
	flash.color    = Color(1.0, 0.92, 0.55, 1.0)
	boom.add_child(flash)
	tw.tween_property(flash, "scale",       Vector2(2.8, 2.8), 0.20)
	tw.tween_property(flash, "modulate:a",  0.0,               0.22)

	# Mid-ring: slightly slower orange halo
	var ring := ColorRect.new()
	ring.size     = Vector2(14.0, 14.0)
	ring.position = Vector2(-7.0, -7.0)
	ring.color    = Color(0.95, 0.45, 0.05, 0.80)
	boom.add_child(ring)
	tw.tween_property(ring, "scale",      Vector2(4.5, 4.5), 0.28)
	tw.tween_property(ring, "modulate:a", 0.0,               0.30)

	# Sparks — 8 fragments that fly outward
	for i in 8:
		var angle : float  = (TAU / 8.0) * i + randf_range(-0.3, 0.3)
		var dist  : float  = randf_range(EXPLODE_RADIUS * 0.42, EXPLODE_RADIUS * 0.88)
		var sz    : float  = randf_range(4.0, 9.0)
		var spark := ColorRect.new()
		spark.size     = Vector2(sz, sz)
		spark.position = Vector2(-sz * 0.5, -sz * 0.5)
		spark.color    = Color(
			randf_range(0.88, 1.00),
			randf_range(0.25, 0.55),
			0.04, 1.0
		)
		boom.add_child(spark)
		var end_pos : Vector2 = Vector2(cos(angle), sin(angle)) * dist
		tw.tween_property(spark, "position", end_pos + Vector2(-sz * 0.5, -sz * 0.5), 0.30)
		tw.tween_property(spark, "modulate:a", 0.0, 0.30)

	tw.tween_callback(boom.queue_free).set_delay(0.34)


# ── Shard impact ───────────────────────────────────────────────────────────────

func _impact_shard() -> void:
	_hit       = true
	monitoring = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.tween_callback(queue_free)


# ── Procedural visuals ─────────────────────────────────────────────────────────

func _build_flask_visual() -> void:
	# Glowing amber bottle
	var body := ColorRect.new()
	body.size     = Vector2(10.0, 13.0)
	body.position = Vector2(-5.0, -6.5)
	body.color    = Color(0.90, 0.42, 0.06, 1.0)
	add_child(body)

	# Inner glow
	var glow := ColorRect.new()
	glow.size     = Vector2(6.0, 8.0)
	glow.position = Vector2(-3.0, -4.0)
	glow.color    = Color(1.0, 0.80, 0.20, 0.72)
	add_child(glow)

	# Neck
	var neck := ColorRect.new()
	neck.size     = Vector2(4.0, 4.0)
	neck.position = Vector2(-2.0, -10.5)
	neck.color    = Color(0.72, 0.32, 0.04, 1.0)
	add_child(neck)


func _build_shard_visual() -> void:
	# Thin silver-blue sliver
	var body := ColorRect.new()
	body.size     = Vector2(18.0, 4.0)
	body.position = Vector2(-9.0, -2.0)
	body.color    = Color(0.78, 0.86, 0.94, 1.0)
	add_child(body)

	# Brighter edge highlight
	var edge := ColorRect.new()
	edge.size     = Vector2(18.0, 1.0)
	edge.position = Vector2(-9.0, -2.0)
	edge.color    = Color(1.0, 1.0, 1.0, 0.70)
	add_child(edge)
