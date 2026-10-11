extends Node3D
## EdoGTA Phase 1B third-person follow camera (attached to CameraRig).
##
## The rig follows the target's position and heading with exponential smoothing.
## The child Camera3D keeps its local offset from Phase 1A (3.2 m up, 7.5 m
## behind, pitched 12 degrees down), so the car and the road ahead stay in view.
## This is the only Camera3D in the scene and it is `current`.

## The node to follow (the player's car).
@export var target_path: NodePath
## How quickly the rig catches up with the car's position (higher = tighter).
@export_range(1.0, 30.0, 0.5) var position_follow_speed: float = 10.0
## How quickly the rig swings round to the car's heading (higher = tighter).
@export_range(0.5, 15.0, 0.1) var heading_follow_speed: float = 3.5

var _target: Node3D = null
var _snap_pending: bool = false


func _ready() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_warning("FollowCamera: target_path does not point to a Node3D; the camera will not follow.")
		return
	if _target.has_signal("reset_performed"):
		_target.connect("reset_performed", _on_target_reset)
	_snap_to_target()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	if _snap_pending:
		# The car's node transform updates after the physics step that moved it.
		_snap_pending = false
		_snap_to_target()
		return
	var pos_weight: float = 1.0 - exp(-position_follow_speed * delta)
	var yaw_weight: float = 1.0 - exp(-heading_follow_speed * delta)
	global_position = global_position.lerp(_target.global_position, pos_weight)
	rotation.y = lerp_angle(rotation.y, _target_yaw(), yaw_weight)


func _target_yaw() -> float:
	var forward: Vector3 = -_target.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return rotation.y
	return atan2(-forward.x, -forward.z)


func _snap_to_target() -> void:
	global_position = _target.global_position
	rotation = Vector3(0.0, _target_yaw(), 0.0)


func _on_target_reset() -> void:
	_snap_pending = true
