extends VehicleBody3D
## EdoGTA Phase 1B driving controller (Godot 4.4, attached to PlaceholderCar).
##
## Reads the named input actions below and drives the VehicleBody3D's
## engine_force / brake / steering. The wheels are VehicleWheel3D children,
## so the visual wheels steer, roll and ride the suspension by themselves.
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
## engine_force per driven (rear) wheel. Godot docs suggest 25-50 for a 1000 kg car.
@export_range(0.0, 200.0, 0.5) var acceleration_force: float = 45.0
## Reverse engine force as a fraction of acceleration_force.
@export_range(0.1, 1.0, 0.05) var reverse_force_scale: float = 0.7
## Forward speed limit in metres per second (22 m/s is about 79 km/h).
@export_range(1.0, 80.0, 0.5) var max_forward_speed: float = 22.0
## Reverse speed limit in metres per second.
@export_range(1.0, 30.0, 0.5) var max_reverse_speed: float = 7.0
## Engine force fades out over this fraction of the speed limit, so top speed is approached smoothly.
@export_range(0.05, 0.6, 0.01) var top_speed_taper: float = 0.15
## How quickly throttle builds (units per second, 1.0 = full throttle).
@export var throttle_rise_rate: float = 3.0
## How quickly throttle drops when released or reduced.
@export var throttle_fall_rate: float = 6.0

@export_group("Braking and resistance")
## brake value for full braking. Godot docs suggest 25-30 for hard braking on a 1000 kg car.
@export_range(0.0, 60.0, 0.5) var brake_strength: float = 22.0
## Light braking applied when no pedal is held: rolling resistance and engine braking.
@export_range(0.0, 20.0, 0.1) var coast_brake: float = 5.0
## How fast the brake value ramps (brake units per second).
@export var brake_response: float = 150.0
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
var _brake_value: float = 0.0
var _spawn_transform: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	_spawn_transform = global_transform
	if not spawn_marker.is_empty():
		var marker: Node3D = get_node_or_null(spawn_marker) as Node3D
		if marker != null:
			_spawn_transform = marker.global_transform
	var start: Transform3D = _spawn_transform
	start.origin.y += spawn_lift
	global_transform = start
	_brake_value = coast_brake
	brake = coast_brake


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
	_brake_value = coast_brake
	forward_speed = 0.0
	engine_force = 0.0
	brake = coast_brake
	steering = 0.0
	reset_performed.emit()


func _update_drive(delta: float) -> void:
	var accel_in: float = Input.get_action_strength("accelerate")
	var brake_in: float = Input.get_action_strength("brake_reverse")

	var target_throttle: float = 0.0
	var target_brake: float = coast_brake
	var braking: bool = false

	if accel_in > 0.0 and brake_in > 0.0:
		target_brake = brake_strength
		braking = true
	elif accel_in > 0.0:
		if forward_speed < -reverse_engage_speed:
			target_brake = brake_strength * accel_in
			braking = true
		else:
			target_throttle = accel_in
			target_brake = 0.0
	elif brake_in > 0.0:
		if forward_speed > reverse_engage_speed:
			target_brake = brake_strength * brake_in
			braking = true
		else:
			target_throttle = -brake_in
			target_brake = 0.0

	if braking:
		_throttle = 0.0
	else:
		var rate: float = throttle_fall_rate
		if absf(target_throttle) > absf(_throttle):
			rate = throttle_rise_rate
		_throttle = move_toward(_throttle, target_throttle, rate * delta)

	var engine: float = 0.0
	if _throttle > 0.0:
		var taper_fwd: float = clampf((max_forward_speed - forward_speed) / (max_forward_speed * top_speed_taper), 0.0, 1.0)
		engine = _throttle * acceleration_force * taper_fwd
	elif _throttle < 0.0:
		var taper_rev: float = clampf((max_reverse_speed + forward_speed) / (max_reverse_speed * top_speed_taper), 0.0, 1.0)
		engine = _throttle * acceleration_force * reverse_force_scale * taper_rev
	engine_force = engine

	_brake_value = move_toward(_brake_value, target_brake, brake_response * delta)
	brake = _brake_value


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
