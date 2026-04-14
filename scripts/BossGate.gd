extends StaticBody2D

## Stone gate sealing the passage from Room 4 to Room 5.
## Crumbles after the Warden is defeated.

const GATE_W := 24.0
const GATE_H := 320.0

@onready var visual : Node2D           = $Visual
@onready var col    : CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	var stone  := Color(0.24, 0.19, 0.16, 1.0)
	var mortar := Color(0.12, 0.09, 0.08, 1.0)

	# Stone fill
	var bg := ColorRect.new()
	bg.position = Vector2(-GATE_W * 0.5, -GATE_H * 0.5)
	bg.size     = Vector2(GATE_W, GATE_H)
	bg.color    = stone
	visual.add_child(bg)

	# Horizontal mortar lines — stacked block appearance
	var rows := 10
	for i in rows:
		var line := ColorRect.new()
		line.position = Vector2(-GATE_W * 0.5, -GATE_H * 0.5 + (GATE_H / rows) * i)
		line.size     = Vector2(GATE_W, 1.5)
		line.color    = mortar
		visual.add_child(line)

	# Vertical centre crack
	var split := ColorRect.new()
	split.position = Vector2(-0.75, -GATE_H * 0.5)
	split.size     = Vector2(1.5, GATE_H)
	split.color    = mortar
	visual.add_child(split)


func crumble() -> void:
	col.disabled = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "modulate:a", 0.0, 1.0)
	tween.tween_property(visual, "scale:y",    0.05, 0.75).set_trans(Tween.TRANS_BACK)
	tween.tween_property(visual, "position:y", visual.position.y + 80.0, 0.75)
