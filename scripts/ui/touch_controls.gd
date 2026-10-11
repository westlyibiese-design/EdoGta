extends CanvasLayer
## EdoGTA touch HUD (landscape).
##
## Tracks every finger itself from InputEventScreenTouch / InputEventScreenDrag
## (real multi-touch, finger index -> button) and presses or releases the named
## input action of the button under each finger. Keyboard and touch therefore
## share the same actions. Lays the buttons out from the visible viewport size.
## Also shows a speed readout and, while `show_debug` is on, a small status line.

const PadButton = preload("res://scripts/ui/touch_pad_button.gd")
const CarController = preload("res://scripts/vehicle/car_controller.gd")

## The car whose speed/status is shown. Optional.
@export var vehicle: NodePath
## Button radius as a fraction of the screen height.
@export_range(0.05, 0.2, 0.005) var button_radius_ratio: float = 0.11
## Show the diagnostic status text under the speed readout.
@export var show_debug: bool = true

@onready var _steer_left: PadButton = $SteerLeft
@onready var _steer_right: PadButton = $SteerRight
@onready var _accelerate: PadButton = $Accelerate
@onready var _brake: PadButton = $Brake
@onready var _reset: PadButton = $Reset
@onready var _speed_label: Label = $SpeedLabel
@onready var _debug_label: Label = $DebugLabel

var _car: CarController = null
var _last_kmh: int = -1
var _pads: Array = []
var _finger_pad: Dictionary = {}


func _ready() -> void:
	_pads = [_steer_left, _steer_right, _accelerate, _brake, _reset]
	if not vehicle.is_empty():
		_car = get_node_or_null(vehicle) as CarController
	_speed_label.visible = _car != null
	_debug_label.visible = show_debug and _car != null
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	if _car == null:
		return
	var kmh: int = roundi(_car.linear_velocity.length() * 3.6)
	if kmh != _last_kmh:
		_last_kmh = kmh
		_speed_label.text = "%d km/h" % kmh
	if show_debug:
		_debug_label.text = _car.debug_text()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_finger_pad[touch.index] = _pad_at(event, false)
		else:
			_finger_pad.erase(touch.index)
		_sync_actions()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		var current: Variant = _finger_pad.get(drag.index, null)
		if current != null and (current as PadButton).contains_event(event):
			return
		_finger_pad[drag.index] = _pad_at(event, true)
		_sync_actions()


func _notification(what: int) -> void:
	# Never leave a button stuck down when the app loses focus or pauses.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_finger_pad.clear()
		_sync_actions()


func _pad_at(event: InputEvent, sliding: bool) -> PadButton:
	for entry in _pads:
		var pad: PadButton = entry as PadButton
		if sliding and not pad.slide_in:
			continue
		if pad.contains_event(event):
			return pad
	return null


func _sync_actions() -> void:
	var held: Dictionary = {}
	for pad_variant in _finger_pad.values():
		if pad_variant != null:
			held[pad_variant] = true
	for entry in _pads:
		var pad: PadButton = entry as PadButton
		var should_hold: bool = held.has(pad)
		if should_hold != pad.touch_down:
			pad.touch_down = should_hold
			if should_hold:
				Input.action_press(pad.action)
			else:
				Input.action_release(pad.action)


func _layout() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var r: float = clampf(view.y * button_radius_ratio, 40.0, 110.0)
	var margin: float = maxf(20.0, view.y * 0.05)
	var gap: float = r * 0.3
	var accel_r: float = r * 1.15
	var reset_r: float = r * 0.5

	# Steering: bottom-left, side by side.
	_steer_left.set_radius(r)
	_steer_left.position = Vector2(margin + r, view.y - margin - r)
	_steer_right.set_radius(r)
	_steer_right.position = Vector2(margin + r * 3.0 + gap, view.y - margin - r)

	# Pedals: bottom-right, accelerator on the outside (nearest the thumb).
	_accelerate.set_radius(accel_r)
	_accelerate.position = Vector2(view.x - margin - accel_r, view.y - margin - accel_r)
	_brake.set_radius(r)
	_brake.position = Vector2(_accelerate.position.x - accel_r - gap - r, view.y - margin - r)

	# Reset: small, top-right, out of the way of driving thumbs.
	_reset.set_radius(reset_r)
	_reset.position = Vector2(view.x - margin - reset_r, margin + reset_r)

	_speed_label.position = Vector2(margin, margin * 0.6)
	_debug_label.position = Vector2(margin, margin * 0.6 + 40.0)
