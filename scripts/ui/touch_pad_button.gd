extends Node2D
## One round on-screen button for the touch HUD.
##
## This node only draws itself and answers "is this touch inside me?".
## touch_controls.gd tracks the fingers and presses/releases `action`.

enum Glyph { LEFT, RIGHT, ACCELERATE, BRAKE, RESET }

## Arrow shown on the button.
@export var glyph: Glyph = Glyph.LEFT
## Small text under the arrow (for RESET it is drawn in the centre).
@export var caption: String = ""
## The named input action this button presses while a finger is on it.
@export var action: String = ""
## If true, a finger that slides in from another button presses this one too.
@export var slide_in: bool = true

var radius: float = 70.0
## Set by touch_controls.gd: true while a finger holds this button.
var touch_down: bool = false

var _lit: bool = false


func set_radius(value: float) -> void:
	radius = value
	queue_redraw()


## True if a touch/drag event is inside the circle (small extra margin for thumbs).
func contains_event(event: InputEvent) -> bool:
	var local_event: InputEvent = make_input_local(event)
	var point: Vector2 = Vector2.INF
	if local_event is InputEventScreenTouch:
		point = (local_event as InputEventScreenTouch).position
	elif local_event is InputEventScreenDrag:
		point = (local_event as InputEventScreenDrag).position
	return point.length() <= radius * 1.05


func _process(_delta: float) -> void:
	# Lights up for touch and for the matching keyboard key.
	var lit: bool = action != "" and Input.is_action_pressed(action)
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
