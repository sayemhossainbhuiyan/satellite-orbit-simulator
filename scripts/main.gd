extends Node3D
## Main.tscn root script — top-level orchestrator.
##
## Assembles the scene: sun light, Earth, Satellite, OrbitRenderer,
## CameraController, and UI. Deliberately thin — all simulation state lives
## in the SimState autoload and all visuals live in their own scenes, so
## this file only wires things together.

var sun: DirectionalLight3D
var earth
var satellite
var orbit_renderer
var camera
var ui

const SUN_DIRECTION := Vector3(1.0, 0.2, 0.35)

func _ready() -> void:
	_build_lighting()
	_build_scenes()
	_wire_up()

func _build_lighting() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 2.4
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	# Position the light on the sun's side and aim it at Earth, so its
	# direction of travel (local -Z) ends up pointing opposite
	# SUN_DIRECTION — i.e. from the sun toward the planet.
	sun.look_at_from_position(SUN_DIRECTION.normalized() * 30.0, Vector3.ZERO, Vector3.UP)
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "EarthshineFill"
	fill.light_energy = 0.15
	fill.light_color = Color(0.4, 0.55, 0.9)
	fill.omni_range = 60.0
	fill.position = Vector3(-15, 5, -10)
	add_child(fill)

func _build_scenes() -> void:
	earth = load("res://scenes/Earth.tscn").instantiate()
	add_child(earth)
	earth.set_sun_direction(SUN_DIRECTION)

	orbit_renderer = load("res://scenes/OrbitRenderer.tscn").instantiate()
	add_child(orbit_renderer)

	satellite = load("res://scenes/Satellite.tscn").instantiate()
	add_child(satellite)

	camera = load("res://scenes/CameraController.tscn").instantiate()
	add_child(camera)

	ui = load("res://scenes/UI.tscn").instantiate()
	add_child(ui)

func _wire_up() -> void:
	ui.set_camera(camera)
