extends Node2D

## Loot chest — press E to open. Gives embers, throwables, or health once.
## Resets when the player rests at a well.

@export var reward_type   : String = "embers"  # embers | flask | shard | health
@export var reward_amount : int    = 100

var _opened        := false
var _player_nearby := false
var _player_ref    : CharacterBody2D = null

var _lid    : Node2D   = null
var _glow   : ColorRect = null
var _prompt : Label     = null

@onready var detect : Area2D = $DetectZone


func _ready() -> void:
	_build_visual()
	_build_prompt()
	detect.body_entered.connect(_on_body_entered)
	detect.body_exited.connect(_on_body_exited)
	GameData.rested.connect(_on_rested)


# ── Visual ─────────────────────────────────────────────────────────────────────

func _build_visual() -> void:
	var wood  := Color(0.30, 0.18, 0.09, 1.0)
	var plank := Color(0.38, 0.24, 0.12, 1.0)
	var iron  := Color(0.22, 0.20, 0.18, 1.0)
	var gold  := Color(0.82, 0.65, 0.10, 1.0)

	# Body
	_rect(self, Vector2(0, 7),  Vector2(30, 14), wood)
	_rect(self, Vector2(0, 5),  Vector2(30,  3), iron)

	# Lid — separate node so it can be animated independently
	_lid          = Node2D.new()
	_lid.name     = "Lid"
	add_child(_lid)
	_rect(_lid, Vector2(0, -7),  Vector2(32, 12), plank)
	_rect(_lid, Vector2(0, -13), Vector2(32,  3), iron)
	_rect(_lid, Vector2(0,  -3), Vector2( 6,  8), gold)   # latch

	# Inner glow (visible when open)
	_glow          = ColorRect.new()
	_glow.size     = Vector2(22.0, 6.0)
	_glow.position = Vector2(-11.0, 2.0)
	_glow.color    = Color(0.90, 0.65, 0.10, 0.0)
	add_child(_glow)


func _rect(parent: Node, center: Vector2, size: Vector2, color: Color) -> void:
	var r      := ColorRect.new()
	r.size      = size
	r.position  = center - size * 0.5
	r.color     = color
	parent.add_child(r)


func _build_prompt() -> void:
	_prompt                         = Label.new()
	_prompt.text                    = "[ E ]  Open"
	_prompt.add_theme_font_size_override("font_size", 12)
	_prompt.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75, 1.0))
	_prompt.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position                = Vector2(-60.0, -48.0)
	_prompt.size                    = Vector2(120.0, 18.0)
	_prompt.visible                 = false
	add_child(_prompt)


# ── Input ──────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _player_nearby and not _opened and Input.is_action_just_pressed("interact"):
		_open()


# ── Open ───────────────────────────────────────────────────────────────────────

func _open() -> void:
	_opened         = true
	_prompt.visible = false

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_lid, "position:y", -18.0, 0.28).set_ease(Tween.EASE_OUT)
	tween.tween_property(_lid, "rotation",   -0.55, 0.24)

	var tween_g := create_tween()
	tween_g.tween_property(_glow, "color:a", 0.85, 0.12)
	tween_g.tween_property(_glow, "color:a", 0.0,  0.65)

	_give_reward()


func _give_reward() -> void:
	var label_text : String
	var label_col  : Color

	match reward_type:
		"embers":
			GameData.gain_embers(reward_amount)
			label_text = "+%d Embers" % reward_amount
			label_col  = Color(0.92, 0.70, 0.14, 1.0)
		"flask":
			GameData.add_throwables("flask", reward_amount)
			label_text = "+%d Flask" % reward_amount
			label_col  = Color(0.90, 0.44, 0.08, 1.0)
		"shard":
			GameData.add_throwables("shard", reward_amount)
			label_text = "+%d Shard" % reward_amount
			label_col  = Color(0.50, 0.72, 0.92, 1.0)
		"health":
			if is_instance_valid(_player_ref):
				_player_ref.heal(reward_amount)
			label_text = "+%d Health" % reward_amount
			label_col  = Color(0.78, 0.30, 0.30, 1.0)

	AudioManager.play("orb_collect")
	_float_text(label_text, label_col)


func _float_text(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position             = Vector2(-60.0, -62.0)
	lbl.size                 = Vector2(120.0, 20.0)
	add_child(lbl)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 38.0, 1.1)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.1)
	tween.finished.connect(lbl.queue_free)


# ── Reset ──────────────────────────────────────────────────────────────────────

func _on_rested() -> void:
	_opened         = false
	_prompt.visible = _player_nearby and not _opened
	if _lid:
		_lid.position = Vector2.ZERO
		_lid.rotation = 0.0
	if _glow:
		_glow.color = Color(0.90, 0.65, 0.10, 0.0)


# ── Detection ──────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_player_ref    = body as CharacterBody2D
		if not _opened:
			_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby  = false
		_player_ref     = null
		_prompt.visible = false
