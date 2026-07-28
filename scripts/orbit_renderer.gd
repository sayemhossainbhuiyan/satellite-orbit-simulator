extends Node3D
## OrbitRenderer.tscn root script.
##
## Draws the full analytic orbit ellipse (recomputed whenever a mission
## loads or the elements otherwise change) as a glowing line, independent
## of the satellite's current trail. This is the standard "predicted path"
## display seen in mission-analysis tools — it shows the whole orbit, not
## just where the satellite has already been.

const SEGMENTS: int = 256

var _orbit_mesh: MeshInstance3D
var _orbit_material: StandardMaterial3D

func _ready() -> void:
	_orbit_material = StandardMaterial3D.new()
	_orbit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orbit_material.vertex_color_use_as_albedo = true
	_orbit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_orbit_material.albedo_color = Constants.ORBIT_LINE

	_orbit_mesh = MeshInstance3D.new()
	_orbit_mesh.material_override = _orbit_material
	_orbit_mesh.name = "OrbitPath"
	add_child(_orbit_mesh)

	SimState.mission_loaded.connect(func(_p): _rebuild())
	_rebuild()

func _rebuild() -> void:
	if SimState.is_hyperbolic:
		_orbit_mesh.visible = false
		return
	_orbit_mesh.visible = true

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(SEGMENTS + 1):
		var nu: float = TAU * float(i) / float(SEGMENTS)
		var state := OrbitMath.elements_to_state(
			SimState.semi_major_axis, SimState.eccentricity, SimState.inclination,
			SimState.raan, SimState.arg_periapsis, nu, Constants.EARTH_MU)
		var pos_units: Vector3 = state.position * Constants.RENDER_UNITS_PER_METER
		st.set_color(Constants.ORBIT_LINE)
		st.add_vertex(pos_units)
	_orbit_mesh.mesh = st.commit()

func _process(_delta: float) -> void:
	# Re-highlight the point nearest current true anomaly with a brighter
	# marker isn't essential; keep this light — the satellite itself marks
	# current position. Nothing per-frame needed unless elements change,
	# which mission_loaded already handles.
	pass
