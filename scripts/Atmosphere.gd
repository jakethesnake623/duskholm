extends Node2D

## Handles all purely visual atmosphere: room backgrounds, screen vignette,
## and ambient floating ember particles. Add once as a child of World.


func _ready() -> void:
	z_index = -10
	_build_backgrounds()
	_build_vignette()
	_build_particles()


# ── Backgrounds ────────────────────────────────────────────────────────────────
# Each room is 1280×720 world units. Layers are stacked semi-transparent rects
# to fake a gradient depth effect without texture assets.

func _build_backgrounds() -> void:
	# Room 0 — The Cradle: primordial dark, before embers, before memory
	_bg(Vector2(-1280,   0), Vector2(1280, 720), Color(0.03, 0.02, 0.05, 1.00))
	_bg(Vector2(-1280,   0), Vector2(1280, 220), Color(0.01, 0.01, 0.03, 0.65))
	_bg(Vector2(-1280, 500), Vector2(1280, 220), Color(0.05, 0.03, 0.09, 0.30))
	# Pillar silhouettes — tall columns of carved stone, older than the rest
	_bg(Vector2(-1196,   0), Vector2(36, 650),  Color(0.01, 0.01, 0.03, 0.95))
	_bg(Vector2(-946,    0), Vector2(30, 590),  Color(0.01, 0.01, 0.03, 0.88))
	_bg(Vector2(-674,    0), Vector2(32, 620),  Color(0.01, 0.01, 0.03, 0.92))
	_bg(Vector2(-390,    0), Vector2(28, 560),  Color(0.01, 0.01, 0.03, 0.85))
	_bg(Vector2(-154,    0), Vector2(26, 530),  Color(0.01, 0.01, 0.03, 0.80))

	# Room 1 — The Entrance: warm charcoal, faint ember glow from below
	_bg(Vector2(0,    0),   Vector2(1280, 720), Color(0.09, 0.08, 0.11, 1.00))
	_bg(Vector2(0,    0),   Vector2(1280, 260), Color(0.05, 0.04, 0.08, 0.55))
	_bg(Vector2(0,    480), Vector2(1280, 240), Color(0.14, 0.07, 0.03, 0.28))

	# Room 2 — The Spire: cooler, elevated, thinner air
	_bg(Vector2(1280, 0),   Vector2(1280, 720), Color(0.08, 0.09, 0.12, 1.00))
	_bg(Vector2(1280, 0),   Vector2(1280, 320), Color(0.04, 0.05, 0.10, 0.55))
	_bg(Vector2(1280, 560), Vector2(1280, 160), Color(0.06, 0.07, 0.10, 0.35))

	# Room 6 — The Hollow: sunken left of Room 3, deeper dark, phosphorescent cold
	_bg(Vector2(-1280,  720), Vector2(1280, 720), Color(0.05, 0.04, 0.08, 1.00))
	_bg(Vector2(-1280,  720), Vector2(1280, 240), Color(0.02, 0.02, 0.06, 0.60))
	_bg(Vector2(-1280, 1180), Vector2(1280, 280), Color(0.03, 0.05, 0.07, 0.45))
	# Stalactite silhouettes hanging from ceiling
	_bg(Vector2(-1200,  720), Vector2(20, 180),   Color(0.02, 0.01, 0.04, 0.95))
	_bg(Vector2(-940,   720), Vector2(16, 130),   Color(0.02, 0.01, 0.04, 0.90))
	_bg(Vector2(-680,   720), Vector2(22, 220),   Color(0.02, 0.01, 0.04, 0.95))
	_bg(Vector2(-420,   720), Vector2(18, 160),   Color(0.02, 0.01, 0.04, 0.88))
	_bg(Vector2(-160,   720), Vector2(14, 100),   Color(0.02, 0.01, 0.04, 0.85))

	# Room 7 — The Ossuary: bone-grey dust, ancient death, amber undertones
	_bg(Vector2(1280,  720), Vector2(1280, 720), Color(0.09, 0.07, 0.05, 1.00))
	_bg(Vector2(1280,  720), Vector2(1280, 240), Color(0.06, 0.05, 0.03, 0.55))
	_bg(Vector2(1280, 1100), Vector2(1280, 340), Color(0.05, 0.04, 0.02, 0.50))

	# Room 3 — The Vault: deep void purple, ancient and cold
	_bg(Vector2(0,    720),  Vector2(1280, 720), Color(0.07, 0.05, 0.11, 1.00))
	_bg(Vector2(0,    720),  Vector2(1280, 260), Color(0.04, 0.02, 0.09, 0.55))
	_bg(Vector2(0,    1100), Vector2(1280, 340), Color(0.03, 0.01, 0.06, 0.55))

	# Room 4 — The Sunken Hall: scorched stone, ancient ember dread
	_bg(Vector2(0,   1440), Vector2(1280, 720), Color(0.10, 0.04, 0.04, 1.00))
	_bg(Vector2(0,   1440), Vector2(1280, 300), Color(0.06, 0.02, 0.02, 0.55))
	_bg(Vector2(0,   1880), Vector2(1280, 280), Color(0.15, 0.05, 0.02, 0.42))

	# Room 5 — The Beyond: void darkness, remnants of the Warden's power
	_bg(Vector2(1280, 1440), Vector2(1280, 720), Color(0.05, 0.03, 0.08, 1.00))
	_bg(Vector2(1280, 1440), Vector2(1280, 280), Color(0.03, 0.01, 0.06, 0.60))
	_bg(Vector2(1280, 1880), Vector2(1280, 280), Color(0.09, 0.03, 0.05, 0.45))


func _bg(pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size     = size
	r.color    = color
	add_child(r)


# ── Vignette ───────────────────────────────────────────────────────────────────
# Fakes a vignette by stacking semi-transparent black bars at screen edges.
# Rendered as a CanvasLayer so it stays fixed to the screen regardless of camera.

func _build_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.layer        = 2
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)

	# Top edge
	_vignette(cl, Vector2(0,    0),   Vector2(1280,  90), 0.38)
	_vignette(cl, Vector2(0,    0),   Vector2(1280,  50), 0.22)

	# Bottom edge
	_vignette(cl, Vector2(0,    630), Vector2(1280,  90), 0.38)
	_vignette(cl, Vector2(0,    670), Vector2(1280,  50), 0.22)

	# Left edge
	_vignette(cl, Vector2(0,    0),   Vector2(80,   720), 0.32)
	_vignette(cl, Vector2(0,    0),   Vector2(44,   720), 0.18)

	# Right edge
	_vignette(cl, Vector2(1200, 0),   Vector2(80,   720), 0.32)
	_vignette(cl, Vector2(1236, 0),   Vector2(44,   720), 0.18)


func _vignette(parent: Node, pos: Vector2, size: Vector2, alpha: float) -> void:
	var r := ColorRect.new()
	r.position     = pos
	r.size         = size
	r.color        = Color(0.0, 0.0, 0.0, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


# ── Ambient ember particles ────────────────────────────────────────────────────
# CPUParticles2D pre-warmed so particles are already floating when the room loads.

func _build_particles() -> void:
	# Room 0 — cold stone dust, barely drifting, ancient and still
	_embers(Vector2(-640, 380), Vector2(480, 300), 7, Color(0.50, 0.52, 0.65, 0.18))

	# Room 1 — sparse warm embers drifting up from the pit
	_embers(Vector2(640,  420), Vector2(560, 280), 14, Color(0.88, 0.38, 0.06, 0.65))

	# Room 2 — cool ashen motes drifting in the height
	_embers(Vector2(1920, 380), Vector2(540, 300), 11, Color(0.70, 0.74, 0.80, 0.45))

	# Room 6 — cold blue-green cave spores, barely visible
	_embers(Vector2(-640, 1080), Vector2(480, 300), 9, Color(0.30, 0.58, 0.55, 0.22))

	# Room 7 — bone-dust motes, warm amber drift
	_embers(Vector2(1920, 1080), Vector2(520, 300), 12, Color(0.72, 0.60, 0.35, 0.32))

	# Room 3 — denser deep-purple embers near the Hearth
	_embers(Vector2(640, 1080), Vector2(540, 300), 20, Color(0.60, 0.18, 0.72, 0.60))

	# Room 4 — dark crimson ash drifting through the boss arena
	_embers(Vector2(640, 1870), Vector2(560, 320), 24, Color(0.65, 0.10, 0.08, 0.55))

	# Room 5 — scattered void-purple embers beyond the Warden's gate
	_embers(Vector2(1920, 1870), Vector2(500, 320), 18, Color(0.50, 0.08, 0.62, 0.52))


func _embers(center: Vector2, extents: Vector2, count: int, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position               = center
	p.emitting               = true
	p.amount                 = count
	p.lifetime               = 9.0
	p.preprocess             = 6.0
	p.direction              = Vector2(0.0, -1.0)
	p.spread                 = 28.0
	p.gravity                = Vector2(0.0, -12.0)
	p.initial_velocity_min   = 3.0
	p.initial_velocity_max   = 10.0
	p.scale_amount_min       = 1.2
	p.scale_amount_max       = 3.0
	p.color                  = color
	p.emission_shape         = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents  = extents
	add_child(p)
