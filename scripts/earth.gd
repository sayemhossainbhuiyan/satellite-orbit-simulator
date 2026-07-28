extends Node3D
## Earth.tscn root script.
##
## Builds the Earth mesh (procedural shader, no texture assets), an
## additive atmosphere shell for the limb glow, and keeps rotation in sync
## with SimState.earth_rotation_rad so the ground track drawn by
## OrbitRenderer lines up with the visible surface.

@export var earth_radius_units: float = 6.371   # matches EARTH_RADIUS scaled by RENDER_UNITS_PER_METER
@export var subdivisions: int = 64

var _surface_mesh: MeshInstance3D
var _atmosphere_mesh: MeshInstance3D
var _surface_material: ShaderMaterial
var _atmosphere_material: ShaderMaterial

func _ready() -> void:
	_build_surface()
	_build_atmosphere()
	SimState.telemetry_updated.connect(_on_telemetry)

func _build_surface() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = earth_radius_units
	sphere.height = earth_radius_units * 2.0
	sphere.radial_segments = subdivisions
	sphere.rings = subdivisions / 2

	_surface_material = ShaderMaterial.new()
	_surface_material.shader = load("res://shaders/earth.gdshader")

	_surface_mesh = MeshInstance3D.new()
	_surface_mesh.mesh = sphere
	_surface_mesh.material_override = _surface_material
	_surface_mesh.name = "Surface"
	add_child(_surface_mesh)

func _build_atmosphere() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = earth_radius_units * 1.035
	sphere.height = earth_radius_units * 1.035 * 2.0
	sphere.radial_segments = subdivisions
	sphere.rings = subdivisions / 2

	_atmosphere_material = ShaderMaterial.new()
	_atmosphere_material.shader = load("res://shaders/atmosphere.gdshader")

	_atmosphere_mesh = MeshInstance3D.new()
	_atmosphere_mesh.mesh = sphere
	_atmosphere_mesh.material_override = _atmosphere_material
	_atmosphere_mesh.name = "AtmosphereGlow"
	add_child(_atmosphere_mesh)

func _process(_delta: float) -> void:
	rotation.y = SimState.earth_rotation_rad

func set_sun_direction(dir: Vector3) -> void:
	if _surface_material:
		_surface_material.set_shader_parameter("sun_direction", dir)
	if _atmosphere_material:
		_atmosphere_material.set_shader_parameter("sun_direction", dir)

func _on_telemetry(_data: Dictionary) -> void:
	pass
