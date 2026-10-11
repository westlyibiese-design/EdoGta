extends Node3D
## EdoGTA Phase 2: hooks the Camry model's wheel meshes up to the car's VehicleWheel3D nodes.
##
## The model (res://assets/vehicles/camry_2006/camry_2006_game.glb, instanced as the child
## "Model") has four separate meshes, Wheel_FL / Wheel_FR / Wheel_RL / Wheel_RR, each centred on
## its own origin. At start-up each one is moved under the matching VehicleWheel3D, so Godot's
## vehicle code steers, spins and moves it with the suspension (same as the placeholder cylinders).
## Attached to the "Visual" node, whose parent is the VehicleBody3D.

const WHEEL_MAP: Dictionary = {
	"Wheel_FL": "WheelFrontLeft",
	"Wheel_FR": "WheelFrontRight",
	"Wheel_RL": "WheelRearLeft",
	"Wheel_RR": "WheelRearRight",
}


func _ready() -> void:
	var car: Node = get_parent()
	var model: Node = get_node_or_null("Model")
	if model == null:
		push_warning("CamryVisuals: no 'Model' child; wheels were not attached.")
		return
	for mesh_name in WHEEL_MAP:
		var mesh: Node3D = model.find_child(String(mesh_name), true, false) as Node3D
		var wheel: Node3D = car.get_node_or_null(NodePath(String(WHEEL_MAP[mesh_name]))) as Node3D
		if mesh == null or wheel == null:
			push_warning("CamryVisuals: could not attach %s to %s." % [mesh_name, WHEEL_MAP[mesh_name]])
			continue
		mesh.reparent(wheel, false)
		mesh.transform = Transform3D.IDENTITY
