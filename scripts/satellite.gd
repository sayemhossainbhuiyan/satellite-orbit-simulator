extends Node3D
## Satellite.tscn root script.
##
## Procedurally assembles an original communications-satellite model
## (not a copy of any real spacecraft) from primitive meshes: a hexagonal
## metallic bus, two articulated solar panel wings, a parabolic dish
## antenna, whip antennas, and small thruster nozzles. Position/orientation
## each frame come from SimState's Cartesian propagation.

@export var model_scale: float = 0.09
var _visual_root: Node3D
var _trail_points: PackedVector3Array = PackedVector3Array()
var _trail_mesh: MeshInstance3D
var _trail_material: StandardMaterial3D

func _ready() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "SatelliteModel"
	_visual_root.scale = Vector3.ONE * model_scale
	add_child(_visual_root)

	_build_bus()
	_build_solar_panels()
	_build_antennas()
	_build_thrusters()
	_build_trail()

	SimState.mission_loaded.connect(func(_p): _trail_points.clear())

func _metal_material(color: Color, metallic: float = 0.85, rough: float = 0.32) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	m.metallic_specular = 0.6
	return m

func _emissive_material(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color * 0.3
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.metallic = 0.1
	m.roughness = 0.4
	return m

func _build_bus() -> void:
	# Hexagonal-ish metallic body — box core plus beveled cap via a
	# CylinderMesh with 6 sides for that satellite-bus silhouette.
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.1
	mesh.bottom_radius = 1.1
	mesh.height = 2.2
	mesh.radial_segments = 6
	body.mesh = mesh
	body.material_override = _metal_material(Color(0.72, 0.74, 0.78), 0.9, 0.28)
	body.rotation_degrees = Vector3(0, 0, 90)
	body.name = "Bus"
	_visual_root.add_child(body)

	# Gold MLI thermal-blanket wrap accent near the base.
	var wrap := MeshInstance3D.new()
	var wmesh := CylinderMesh.new()
	wmesh.top_radius = 1.14
	wmesh.bottom_radius = 1.14
	wmesh.height = 0.5
	wmesh.radial_segments = 6
	wrap.mesh = wmesh
	wrap.material_override = _metal_material(Color(0.85, 0.63, 0.18), 0.7, 0.4)
	wrap.rotation_degrees = Vector3(0, 0, 90)
	wrap.position = Vector3(-0.6, 0, 0)
	wrap.name = "ThermalWrap"
	_visual_root.add_child(wrap)

func _build_solar_panels() -> void:
	var panel_mat := _metal_material(Color(0.06, 0.10, 0.28), 0.2, 0.15)
	var cell_mat := _emissive_material(Color(0.15, 0.35, 0.9), 0.35)

	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CylinderMesh.new()
		arm_mesh.top_radius = 0.08
		arm_mesh.bottom_radius = 0.08
		arm_mesh.height = 1.0
		arm.mesh = arm_mesh
		arm.material_override = _metal_material(Color(0.6, 0.62, 0.65))
		arm.rotation_degrees = Vector3(0, 0, 90)
		arm.position = Vector3(0, 0, side * 1.6)
		_visual_root.add_child(arm)

		var wing := MeshInstance3D.new()
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(2.6, 0.05, 5.2)
		wing.mesh = wing_mesh
		wing.material_override = panel_mat
		wing.position = Vector3(0, 0, side * 5.7)
		wing.name = "SolarPanel%d" % int(side)
		_visual_root.add_child(wing)

		# Cell grid glint lines (thin emissive strips) for detail.
		for i in range(-2, 3):
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(2.5, 0.06, 0.06)
			strip.mesh = strip_mesh
			strip.material_override = cell_mat
			strip.position = Vector3(0, 0.03, side * 5.7 + i * 0.9)
			_visual_root.add_child(strip)

func _build_antennas() -> void:
	# Parabolic dish (a flattened, hollowed cone approximation).
	var dish := MeshInstance3D.new()
	var dish_mesh := CylinderMesh.new()
	dish_mesh.top_radius = 0.05
	dish_mesh.bottom_radius = 0.85
	dish_mesh.height = 0.5
	dish_mesh.radial_segments = 24
	dish.mesh = dish_mesh
	dish.material_override = _metal_material(Color(0.88, 0.88, 0.9), 0.4, 0.35)
	dish.rotation_degrees = Vector3(0, 0, -90)
	dish.position = Vector3(1.55, 0, 0)
	dish.name = "DishAntenna"
	_visual_root.add_child(dish)

	var feed := MeshInstance3D.new()
	var feed_mesh := CylinderMesh.new()
	feed_mesh.top_radius = 0.04
	feed_mesh.bottom_radius = 0.04
	feed_mesh.height = 0.7
	feed.mesh = feed_mesh
	feed.material_override = _metal_material(Color(0.5, 0.52, 0.55))
	feed.rotation_degrees = Vector3(0, 0, -90)
	feed.position = Vector3(1.9, 0, 0)
	_visual_root.add_child(feed)

	# Two whip antennas.
	for wside in [-1.0, 1.0]:
		var whip := MeshInstance3D.new()
		var whip_mesh := CylinderMesh.new()
		whip_mesh.top_radius = 0.015
		whip_mesh.bottom_radius = 0.025
		whip_mesh.height = 1.4
		whip.mesh = whip_mesh
		whip.material_override = _metal_material(Color(0.2, 0.2, 0.22), 0.6, 0.5)
		whip.position = Vector3(-1.2, 0.6 * wside, 0.3)
		whip.rotation_degrees = Vector3(20 * wside, 0, 15 * wside)
		_visual_root.add_child(whip)

func _build_thrusters() -> void:
	for offset in [Vector3(0, 0.7, 0.7), Vector3(0, -0.7, 0.7), Vector3(0, 0.7, -0.7), Vector3(0, -0.7, -0.7)]:
		var nozzle := MeshInstance3D.new()
		var noz_mesh := CylinderMesh.new()
		noz_mesh.top_radius = 0.16
		noz_mesh.bottom_radius = 0.09
		noz_mesh.height = 0.32
		nozzle.mesh = noz_mesh
		nozzle.material_override = _metal_material(Color(0.15, 0.15, 0.16), 0.75, 0.55)
		nozzle.position = Vector3(-1.25, 0, 0) + offset * 0.4
		nozzle.rotation_degrees = Vector3(0, 0, 90)
		_visual_root.add_child(nozzle)

	var main_engine := MeshInstance3D.new()
	var me_mesh := CylinderMesh.new()
	me_mesh.top_radius = 0.35
	me_mesh.bottom_radius = 0.22
	me_mesh.height = 0.55
	main_engine.mesh = me_mesh
	main_engine.material_override = _metal_material(Color(0.12, 0.12, 0.13), 0.8, 0.5)
	main_engine.position = Vector3(-1.5, 0, 0)
	main_engine.rotation_degrees = Vector3(0, 0, 90)
	_visual_root.add_child(main_engine)

func _build_trail() -> void:
	_trail_material = StandardMaterial3D.new()
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.albedo_color = Constants.ELECTRIC_CYAN

	_trail_mesh = MeshInstance3D.new()
	_trail_mesh.material_override = _trail_material
	_trail_mesh.name = "SatelliteTrail"
	add_child(_trail_mesh)

func _process(_delta: float) -> void:
	var pos_m: Vector3 = SimState.cartesian_pos
	var vel_m: Vector3 = SimState.cartesian_vel
	var pos_units := pos_m * Constants.RENDER_UNITS_PER_METER
	global_position = pos_units

	if vel_m.length() > 0.001:
		var fwd := vel_m.normalized()
		var up := pos_m.normalized()
		var right := fwd.cross(up).normalized()
		var true_up := right.cross(fwd).normalized()
		var basis := Basis(right, true_up, -fwd).orthonormalized()
		_visual_root.global_transform.basis = basis

	if SimState.run_state == SimState.RunState.RUNNING:
		_trail_points.append(pos_units)
		if _trail_points.size() > 400:
			_trail_points.remove_at(0)
		_update_trail_mesh()

func _update_trail_mesh() -> void:
	if _trail_points.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	var n := _trail_points.size()
	for i in range(n):
		var t: float = float(i) / float(max(n - 1, 1))
		st.set_color(Color(Constants.ELECTRIC_CYAN.r, Constants.ELECTRIC_CYAN.g, Constants.ELECTRIC_CYAN.b, t * 0.85))
		st.add_vertex(_trail_points[i] - global_position)
	_trail_mesh.mesh = st.commit()
