extends VehicleBody3D
## EdoGTA Phase 1B driving controller (Godot 4.4, attached to PlaceholderCar).
##
## Reads the named input actions below. Steering uses VehicleBody3D.steering
## (the VehicleWheel3D children give grip, suspension and visual wheel motion).
## Forward thrust and braking are applied as real forces in m/s^2 with
## apply_central_force (engine_force and brake are kept at 0): their units are
## easy to get wrong, and the first Phase 1B build barely moved because of it.
## Thrust only applies while at least one wheel touches the ground.
##
## Input actions (defined in project.godot; touch buttons feed the same actions):
##   accelerate    W / Up      -> forward throttle
##   brake_reverse S / Down    -> brake while moving forward, reverse once slow
##   steer_left    A / Left
##   steer_right   D / Right
##   reset_vehicle R           -> put the car back at the spawn point
##
## Brake / reverse rules (forward speed measured along the car's own -Z axis):
##   * Brake held while rolling forward faster than reverse_engage_speed -> brakes.
##   * Brake held at or below that speed -> engine reverses (up to max_reverse_speed).
##   * Accelerator held while rolling backwards faster than reverse_engage_speed
##     -> brakes first, then drives forward.
##   * Both held at once -> brake (the car stops, it does not reverse).
##   * Nothing held -> light "coast" braking (rolling resistance / engine braking).

## Emitted after reset_vehicle() so the camera can snap instead of swooping.
signal reset_performed

@export_group("Drive")
## Full-throttle acceleration in m/s^2 (4 is roughly 0-80 km/h in 6-7 seconds).
@export_range(0.5, 15.0, 0.1) var acceleration: float = 4.0
## Reverse acceleration as a fraction of `acceleration`.
@export_range(0.1, 1.0, 0.05) var reverse_acceleration_scale: float = 0.6
## Forward speed limit in metres per second (22 m/s is about 79 km/h).
@export_range(1.0, 80.0, 0.5) var max_forward_speed: float = 22.0
## Reverse speed limit in metres per second.
@export_range(1.0, 30.0, 0.5) var max_reverse_speed: float = 7.0
## Thrust fades out over this fraction of the speed limit, so top speed is approached smoothly.
@export_range(0.05, 0.6, 0.01) var top_speed_taper: float = 0.15
## How quickly throttle builds (units per second, 1.0 = full throttle).
@export var throttle_rise_rate: float = 3.0
## How quickly throttle drops when released or reduced.
@export var throttle_fall_rate: float = 6.0

@export_group("Braking and resistance")
## Full-brake deceleration in m/s^2.
@export_range(0.0, 30.0, 0.5) var brake_deceleration: float = 9.0
## Light deceleration with no pedal held (rolling resistance and engine braking), in m/s^2.
@export_range(0.0, 10.0, 0.1) var coast_deceleration: float = 1.0
## How fast braking ramps up or down (m/s^2 per second).
@export var brake_response: float = 60.0
## Below this forward speed (m/s) the brake pedal selects reverse instead of braking.
@export_range(0.1, 5.0, 0.1) var reverse_engage_speed: float = 1.0

@export_group("Steering")
## Maximum wheel angle in degrees at low speed.
@export_range(5.0, 60.0, 0.5) var max_steer_angle_deg: float = 32.0
## The steering angle never drops below this many degrees, even at top speed.
@export_range(0.5, 20.0, 0.1) var min_steer_angle_deg: float = 2.5
## Cornering limit in m/s^2. Steering angle shrinks with speed so the car turns no harder than this.
@export_range(2.0, 20.0, 0.5) var max_lateral_acceleration: float = 10.0
## Distance between front and rear axles in metres (matches the wheel positions in the scene).
@export var wheelbase: float = 2.7
## Radians per second the wheels turn towards the target angle.
@export var steer_speed: float = 2.5
## Radians per second the wheels return towards centre.
@export var steer_return_speed: float = 4.0

@export_group("Spawn and reset")
## Marker the car starts at and returns to on reset. Empty = the car's starting transform.
@export var spawn_marker: NodePath
## Metres above the spawn point the car is placed, so the wheels settle onto the road.
@export var spawn_lift: float = 0.2
## If the car falls below this height it is reset automatically.
@export var fall_reset_height: float = -10.0

## Signed speed along the car's forward direction in m/s (negative = reversing).
var forward_speed: float = 0.0

var _throttle: float = 0.0
var _decel: float = 0.0
var _spawn_transform: Transform3D = Transform3D.IDENTITY
var _wheels: Array = []
var _last_accel_in: float = 0.0
var _last_brake_in: float = 0.0
var _last_thrust: float = 0.0
var _wheels_grounded: int = 0


func _ready() -> void:
	_spawn_transform = global_transform
	if not spawn_marker.is_empty():
		var marker: Node3D = get_node_or_null(spawn_marker) as Node3D
		if marker != null:
			_spawn_transform = marker.global_transform
	var start: Transform3D = _spawn_transform
	start.origin.y += spawn_lift
	global_transform = start
	_decel = coast_deceleration
	engine_force = 0.0
	brake = 0.0
	for child in get_children():
		if child is VehicleWheel3D:
			_wheels.append(child)


func _physics_process(delta: float) -> void:
	if global_position.y < fall_reset_height or Input.is_action_just_pressed("reset_vehicle"):
		reset_vehicle()
		return
	forward_speed = linear_velocity.dot(-global_transform.basis.z)
	_update_drive(delta)
	_update_steering(delta)


## Puts the car back at the spawn point, stopped and with the wheels straight.
func reset_vehicle() -> void:
	var start: Transform3D = _spawn_transform
	start.origin.y += spawn_lift
	var body: RID = get_rid()
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, start)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	_throttle = 0.0
	_decel = coast_deceleration
	forward_speed = 0.0
	engine_force = 0.0
	brake = 0.0
	steering = 0.0
	reset_performed.emit()


func _update_drive(delta: float) -> void:
	var accel_in: float = Input.get_action_strength("accelerate")
	var brake_in: float = Input.get_action_strength("brake_reverse")
	_last_accel_in = accel_in
	_last_brake_in = brake_in

	var target_throttle: float = 0.0
	var target_decel: float = coast_deceleration
	var braking: bool = false

	if accel_in > 0.0 and brake_in > 0.0:
		target_decel = brake_deceleration
		braking = true
	elif accel_in > 0.0:
		if forward_speed < -reverse_engage_speed:
			target_decel = brake_deceleration * accel_in
			braking = true
		else:
			target_throttle = accel_in
			target_decel = 0.0
	elif brake_in > 0.0:
		if forward_speed > reverse_engage_speed:
			target_decel = brake_deceleration * brake_in
			braking = true
		else:
			target_throttle = -brake_in
			target_decel = 0.0

	if braking:
		_throttle = 0.0
	else:
		var rate: float = throttle_fall_rate
		if absf(target_throttle) > absf(_throttle):
			rate = throttle_rise_rate
		_throttle = move_toward(_throttle, target_throttle, rate * delta)

	var thrust: float = 0.0
	if _throttle > 0.0:
		var taper_fwd: float = clampf((max_forward_speed - forward_speed) / (max_forward_speed * top_speed_taper), 0.0, 1.0)
		thrust = _throttle * acceleration * taper_fwd
	elif _throttle < 0.0:
		var taper_rev: float = clampf((max_reverse_speed + forward_speed) / (max_reverse_speed * top_speed_taper), 0.0, 1.0)
		thrust = _throttle * acceleration * reverse_acceleration_scale * taper_rev

	_decel = move_toward(_decel, target_decel, brake_response * delta)

	_wheels_grounded = 0
	for wheel in _wheels:
		if (wheel as VehicleWheel3D).is_in_contact():
			_wheels_grounded += 1

	_last_thrust = 0.0
	if _wheels_grounded > 0:
		var force: float = thrust * mass
		if _decel > 0.0 and absf(forward_speed) > 0.001:
			# Never decelerate by more than what stops the car within this physics step.
			var decel_now: float = minf(_decel, absf(forward_speed) / delta)
			force -= signf(forward_speed) * decel_now * mass
		apply_central_force(-global_transform.basis.z * force)
		_last_thrust = thrust


func _update_steering(delta: float) -> void:
	# Positive VehicleBody3D.steering turns left, so left input is +1.
	var steer_in: float = Input.get_axis("steer_right", "steer_left")
	var abs_speed: float = absf(forward_speed)

	var limit: float = deg_to_rad(max_steer_angle_deg)
	if abs_speed > 1.0:
		var speed_limit: float = atan(wheelbase * max_lateral_acceleration / (abs_speed * abs_speed))
		limit = minf(limit, speed_limit)
	limit = maxf(limit, deg_to_rad(min_steer_angle_deg))

	var target: float = steer_in * limit
	var rate: float = steer_speed
	if absf(target) < absf(steering):
		rate = steer_return_speed
	steering = move_toward(steering, target, rate * delta)


## One-line-per-field status text for the on-screen diagnostic readout.
func debug_text() -> String:
	return "gas %.1f  brake %.1f  steer %.2f\nthrottle %.2f  thrust %.1f m/s2  speed %.1f m/s\nwheels on ground %d/4" % [
		_last_accel_in, _last_brake_in, steering, _throttle, _last_thrust, forward_speed, _wheels_grounded]
