extends Area2D

## Dropped soul orb — Dark Souls bloodstain mechanic.
## Spawned at the player's last safe position on death.
## Collected by touching it; destroyed forever if the player dies again first.

signal collected

var soul_amount: int = 0
var player_ref : CharacterBody2D = null

@onready var visual: Node2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(amount: int, player: CharacterBody2D) -> void:
	soul_amount = amount
	player_ref  = player


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	# Float gently up and down
	visual.position.y = sin(t * 2.2) * 7.0
	# Pulse the glow brightness
	visual.modulate.a = 0.65 + 0.35 * abs(sin(t * 2.8))


func _on_body_entered(body: Node) -> void:
	if is_instance_valid(player_ref) and body == player_ref:
		player_ref.retrieve_souls(soul_amount)
		collected.emit()
		queue_free()
