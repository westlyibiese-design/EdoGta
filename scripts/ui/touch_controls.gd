extends CanvasLayer
## EdoGTA Phase 1B touch HUD (landscape).
##
## Lays out the round buttons from the visible viewport size, so it adapts to any
## landscape aspect ratio (the project uses canvas_items stretch with "expand").
## The buttons drive the named input actions through TouchScreenButton, so
## keyboard and touch share one path. Also shows a small speed readout.

const PadButton = preload("res://scripts/ui/touch_pad_button.gd")

## The car whose speed is shown. Optional: leave empty to hide the readout.
@export var vehicle: NodePath
## Button radius as a fraction of the screen height.
@export_range(0.05, 0.2, 0.005) var button_radius_ratio: float = 0.11

@onready var _steer_left: PadButton = $SteerLeft
@onready var _steer_right: PadButton = $SteerRight
@onready var _accelerate: PadButton = $Accelerate
@onready var _brake: PadButton = $Brake
@onready var _reset: PadButton = $Reset
@onready var _speed_label: Label = $SpeedLabel

var _car: VehicleBody3D = null
var _last_kmh: int = -1


func _ready() -> void:
	if not vehicle.is_empty():
		_car = get_node_or_null(vehicle) as VehicleBody3D
	_speed_label.visible = _car != null
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	if _car == null:
		return
	var kmh: int = roundi(_car.linear_velocity.length() * 3.6)
	if kmh != _last_kmh:
		_last_kmh = kmh
		_speed_label.text = "%d km/h" % kmh


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
