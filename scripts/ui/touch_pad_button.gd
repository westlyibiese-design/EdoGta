extends TouchScreenButton
## One round on-screen button for the Phase 1B touch HUD.
##
## A TouchScreenButton with its `action` set presses/releases that named input
## action for as long as a finger is on it, with real multi-touch, so steering and
## pedals can be held at the same time. The circle is the hit area; this script
## only draws it (no textures needed) and keeps the hit shape in sync with the radius.

enum Glyph { LEFT, RIGHT, ACCELERATE, BRAKE, RESET }

## Arrow shown on the button.
@export var glyph: Glyph = Glyph.LEFT
## Small text under the arrow (for RESET it is drawn in the centre).
@export var caption: String = ""

var radius: float = 70.0

var _lit: bool = false


func _ready() -> void:
	shape_visible = false
	set_radius(radius)


func set_radius(value: float) -> void:
	radius = value
	var circle: CircleShape2D = shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape = circle
	circle.radius = radius
	queue_redraw()


func _process(_delta: float) -> void:
	# Also lights up when the matching keyboard key is held.
	var lit: bool = is_pressed() or Input.is_action_pressed(action)
	if lit != _lit:
		_lit = lit
		queue_redraw()


func _draw() -> void:
	var fill: Color = Color(0.0, 0.0, 0.0, 0.35)
	var ring: Color = Color(1.0, 1.0, 1.0, 0.55)
	var ink: Color = Color(1.0, 1.0, 1.0, 0.8)
	if _lit:
		fill = Color(1.0, 1.0, 1.0, 0.42)
		ring = Color(1.0, 1.0, 1.0, 0.9)
		ink = Color(1.0, 1.0, 1.0, 1.0)
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ring, 3.0, true)

	var s: float = radius * 0.38
	var offset: Vector2 = Vector2.ZERO
	if caption != "":
		offset = Vector2(0.0, -radius * 0.14)
	var points: PackedVector2Array = PackedVector2Array()
	match glyph:
		Glyph.LEFT:
			points = PackedVector2Array([Vector2(-s, 0.0), Vector2(s * 0.8, -s), Vector2(s * 0.8, s)])
		Glyph.RIGHT:
			points = PackedVector2Array([Vector2(s, 0.0), Vector2(-s * 0.8, -s), Vector2(-s * 0.8, s)])
		Glyph.ACCELERATE:
			points = PackedVector2Array([Vector2(0.0, -s), Vector2(-s, s * 0.8), Vector2(s, s * 0.8)])
		Glyph.BRAKE:
			points = PackedVector2Array([Vector2(0.0, s), Vector2(-s, -s * 0.8), Vector2(s, -s * 0.8)])
		_:
			points = PackedVector2Array()
	if points.size() == 3:
		for i in range(3):
			points[i] += offset
		draw_colored_polygon(points, ink)

	if caption != "":
		var font: Font = ThemeDB.fallback_font
		var font_size: int = maxi(int(radius * 0.26), 10)
		var y: float = radius * 0.62
		if glyph == Glyph.RESET:
			y = float(font_size) * 0.35
		draw_string(font, Vector2(-radius, y), caption, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, ink)
