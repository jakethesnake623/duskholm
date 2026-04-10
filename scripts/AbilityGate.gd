## Blocks passage until the player owns the required upgrade.
## When the upgrade is purchased, the gate opens permanently.
extends StaticBody2D

@export var required_ability: String = "double_jump"

@onready var blocker : CollisionShape2D = $Blocker
@onready var visual  : ColorRect        = $Visual


func _ready() -> void:
	GameData.upgrade_purchased.connect(func(_key: String): _refresh())
	_refresh()


func _process(_delta: float) -> void:
	if visual.visible:
		var pulse: float = 0.06 + 0.04 * sin(Time.get_ticks_msec() * 0.0006)
		visual.color.a = pulse


func _refresh() -> void:
	var locked := GameData.get_upgrade_level(required_ability) == 0
	blocker.disabled = not locked
	visual.visible   = locked
