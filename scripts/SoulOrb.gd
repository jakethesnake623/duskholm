extends Area2D

## Dropped ember orb — spawned at the player's last safe position on death.
## Collected by walking into it. Destroyed if the player dies again first.

signal collected

var soul_amount: int = 0   # named soul_amount internally; displayed as embers

@onready var visual: Node2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(amount: int) -> void:
	soul_amount = amount


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	visual.position.y = sin(t * 2.2) * 7.0
	visual.modulate.a = 0.65 + 0.35 * abs(sin(t * 2.8))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameData.gain_embers(soul_amount)
		collected.emit()
		queue_free()
