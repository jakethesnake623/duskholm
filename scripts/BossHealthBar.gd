extends CanvasLayer

## Fixed bottom-of-screen health bar for The Warden.
## Hidden until boss first takes damage; hides on boss death or player rest.

const BAR_W := 600.0
const BAR_H := 14.0

var _bar_fill : ColorRect = null


func _ready() -> void:
	layer   = 3
	visible = false
	_build_ui()


func _build_ui() -> void:
	var strip := ColorRect.new()
	strip.position = Vector2(0.0, 690.0)
	strip.size     = Vector2(1280.0, 30.0)
	strip.color    = Color(0.04, 0.03, 0.06, 0.88)
	add_child(strip)

	var title := Label.new()
	title.text = "The Warden"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.76, 0.60, 0.52, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(340.0, 692.0)
	title.size     = Vector2(600.0, 13.0)
	add_child(title)

	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(340.0, 706.0)
	bar_bg.size     = Vector2(BAR_W, BAR_H)
	bar_bg.color    = Color(0.10, 0.08, 0.12, 0.80)
	add_child(bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(340.0, 706.0)
	_bar_fill.size     = Vector2(BAR_W, BAR_H)
	_bar_fill.color    = Color(0.70, 0.18, 0.12, 0.90)
	add_child(_bar_fill)


func on_health_changed(current: int, maximum: int) -> void:
	if not visible:
		visible = true
	_bar_fill.size.x = BAR_W * clampf(float(current) / float(maximum), 0.0, 1.0)


func on_boss_died() -> void:
	visible = false


func deactivate() -> void:
	visible = false
