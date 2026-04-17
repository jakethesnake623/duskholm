extends Area2D

## Gravity-affected ember projectile fired by FORGE-7.
## Arcs through the air and damages the player on contact.
## Also despawns on world geometry contact.

const GRAVITY  := 700.0
const DAMAGE   := 2
const LIFETIME := 3.5

var _vel      : Vector2 = Vector2.ZERO
var _lifetime : float   = LIFETIME

@onready var _visual : ColorRect = $Visual


func setup(vel: Vector2) -> void:
	_vel = vel


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_vel.y   += GRAVITY * delta
	global_position += _vel * delta
	_lifetime -= delta

	# Rotate to face travel direction
	rotation = _vel.angle()

	# Ember pulse glow
	var t := Time.get_ticks_msec() * 0.014
	_visual.modulate.a = 0.75 + 0.25 * sin(t)

	if _lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		var dir := Vector2(sign(_vel.x), -0.25).normalized()
		body.take_damage(DAMAGE, dir)
	queue_free()   # despawn on any contact (player or world)
