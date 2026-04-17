extends Area2D

## A single ember bolt fired by the Ember Launcher.
## Travels horizontally in _dir, detects enemy Hurtboxes via area_entered.
## Self-destructs on hit or after LIFETIME seconds.

const SPEED    := 680.0
const LIFETIME := 0.36   # ~245 px max range
const DAMAGE   := 1

var _dir      : float = 1.0
var _lifetime : float = LIFETIME

@onready var _visual : ColorRect = $Visual


func setup(direction: float) -> void:
	_dir = direction


func _process(delta: float) -> void:
	global_position.x += _dir * SPEED * delta
	_lifetime -= delta

	# Subtle pulse to sell the ember glow
	var t := Time.get_ticks_msec() * 0.018
	_visual.modulate.a = 0.80 + 0.20 * sin(t)

	if _lifetime <= 0.0:
		queue_free()


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area.name == "Hurtbox":
		var parent := area.get_parent()
		if parent.has_method("_take_damage"):
			parent._take_damage(DAMAGE)
		AudioManager.play("enemy_hit")
		queue_free()
