extends WorldEnvironment
## EdoGTA Phase 2: road / desert sky switcher (attached to Main/WorldEnvironment).
##
## Swaps the HDRI panorama, fog colour, ground colour and roadside scenery.
## Press E, or tap the ENV button, to toggle. The road sky is the default.

## HDRI used for the road / city scene.
@export var road_sky: Texture2D
## HDRI used for the desert scene.
@export var desert_sky: Texture2D
## The ground MeshInstance3D whose colour turns to sand in the desert.
@export var ground_mesh_path: NodePath
## Trees and buildings; hidden in the desert.
@export var scenery_path: NodePath
@export var road_fog_color: Color = Color(0.65, 0.78, 0.9)
@export var desert_fog_color: Color = Color(0.86, 0.74, 0.58)
@export var desert_ground_color: Color = Color(0.78, 0.66, 0.46)
@export var start_in_desert: bool = false

var is_desert: bool = false

var _ground: MeshInstance3D = null
var _scenery: Node3D = null
var _sky_material: PanoramaSkyMaterial = null
var _sand_material: StandardMaterial3D = null


func _ready() -> void:
	_ground = get_node_or_null(ground_mesh_path) as MeshInstance3D
	_scenery = get_node_or_null(scenery_path) as Node3D
	if environment != null and environment.sky != null:
		_sky_material = environment.sky.sky_material as PanoramaSkyMaterial
	_sand_material = StandardMaterial3D.new()
	_sand_material.albedo_color = desert_ground_color
	_sand_material.roughness = 1.0
	apply_environment(start_in_desert)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_environment"):
		apply_environment(not is_desert)


func apply_environment(desert: bool) -> void:
	is_desert = desert
	var sky_texture: Texture2D = desert_sky if desert else road_sky
	if _sky_material != null and sky_texture != null:
		_sky_material.panorama = sky_texture
	if environment != null:
		environment.fog_light_color = desert_fog_color if desert else road_fog_color
	if _ground != null:
		_ground.material_override = _sand_material if desert else null
	if _scenery != null:
		_scenery.visible = not desert
