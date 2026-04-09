extends Node2D

@onready var player    : CharacterBody2D = $Player
@onready var hud       : CanvasLayer     = $HUD
@onready var death_zone: Area2D          = $DeathZone


func _ready() -> void:
	hud.setup(player.MAX_HEALTH)
	player.health_changed.connect(hud.on_health_changed)
	death_zone.body_entered.connect(_on_death_zone_entered)


func _on_death_zone_entered(body: Node) -> void:
	if body == player:
		player.kill()
