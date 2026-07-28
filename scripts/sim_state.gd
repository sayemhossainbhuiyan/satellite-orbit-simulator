extends Node
## SimState — Autoload singleton.
##
## Owns the single source of truth for the simulation: which mission is
## loaded, the satellite's orbital elements and Cartesian state, mission
## elapsed time, Earth's rotation angle, and run/pause/speed control.
## Scenes (Satellite, OrbitRenderer, UI) read from here and never compute
## physics themselves — this keeps physics correct even if only some
## visuals are present, and matches how real mission-analysis tools
## separate the propagator from the display layer.

signal telemetry_updated(data: Dictionary)
signal mission_loaded(preset)
signal state_changed(is_running: bool)
signal satellite_launched()
signal satellite_reset()

enum RunState { IDLE, RUNNING, PAUSED, ESCAPED }

var run_state: int = RunState.IDLE
var sim_speed: float = 60.0            # simulated seconds per real second
const MAX_SIM_SPEED: float = 2000.0
const MIN_SIM_SPEED: float = 1.0

var mission_time_s: float = 0.0
var earth_rotation_rad: float = 0.0
const EARTH_ANGULAR_RATE: float = TAU / Constants.EARTH_SIDEREAL_DAY

# Orbital elements (SI units / radians)
var semi_major_axis: float = 0.0
var eccentricity: float = 0.0
var inclination: float = 0.0
var raan: float = 0.0
var arg_periapsis: float = 0.0
var true_anomaly: float = 0.0
var mean_anomaly: float = 0.0
var mean_motion: float = 0.0

var is_hyperbolic: bool = false
var cartesian_pos: Vector3 = Vector3.ZERO   # meters
var cartesian_vel: Vector3 = Vector3.ZERO   # m/s

var satellite_mass_kg: float = 1450.0
var current_preset = null
var orbit_trail: PackedVector3Array = PackedVector3Array()
const TRAIL_MAX_POINTS: int = 600
var _trail_accum: float = 0.0

func _ready() -> void:
	load_mission(Constants.MISSION_PRESETS[0])

# ---------------------------------------------------------------------------
# Mission control
# ---------------------------------------------------------------------------
func load_mission(preset) -> void:
	current_preset = preset
	satellite_mass_kg = _default_mass_for(preset.orbit_type)
	var r0: float = Constants.EARTH_RADIUS + preset.altitude_km * 1000.0
	eccentricity = preset.eccentricity
	semi_major_axis = r0 / (1.0 - eccentricity) if eccentricity > 0.0 else r0
	inclination = deg_to_rad(preset.inclination_deg)
	raan = deg_to_rad(15.0)
	arg_periapsis = 0.0
	true_anomaly = 0.0
	is_hyperbolic = preset.orbit_type == Constants.OrbitType.ESCAPE
	mean_motion = sqrt(Constants.EARTH_MU / pow(abs(semi_major_axis), 3))
	mean_anomaly = 0.0
	mission_time_s = 0.0
	earth_rotation_rad = 0.0
	run_state = RunState.IDLE
	orbit_trail.clear()
	_sync_cartesian_from_elements()
	mission_loaded.emit(preset)
	_emit_telemetry()

func _default_mass_for(orbit_type: int) -> float:
	match orbit_type:
		Constants.OrbitType.GEO: return 3200.0
		Constants.OrbitType.MEO: return 1660.0
		Constants.OrbitType.MOLNIYA: return 1750.0
		_: return 1050.0

func launch() -> void:
	if run_state == RunState.IDLE or run_state == RunState.PAUSED:
		run_state = RunState.RUNNING
		satellite_launched.emit()
		state_changed.emit(true)

func pause() -> void:
	if run_state == RunState.RUNNING:
		run_state = RunState.PAUSED
		state_changed.emit(false)

func resume() -> void:
	if run_state == RunState.PAUSED:
		run_state = RunState.RUNNING
		state_changed.emit(true)

func reset() -> void:
	if current_preset:
		load_mission(current_preset)
	satellite_reset.emit()

func set_sim_speed(v: float) -> void:
	sim_speed = clamp(v, MIN_SIM_SPEED, MAX_SIM_SPEED)

# ---------------------------------------------------------------------------
# Physics step
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if run_state != RunState.RUNNING:
		return
	var dt_sim: float = delta * sim_speed
	mission_time_s += dt_sim
	earth_rotation_rad = fposmod(earth_rotation_rad + EARTH_ANGULAR_RATE * dt_sim, TAU)

	if is_hyperbolic or eccentricity >= 1.0:
		var stepped := OrbitMath.rk4_step(cartesian_pos, cartesian_vel, dt_sim, Constants.EARTH_MU)
		cartesian_pos = stepped.position
		cartesian_vel = stepped.velocity
		if cartesian_pos.length() > Constants.EARTH_RADIUS * 60.0:
			run_state = RunState.ESCAPED
	else:
		mean_anomaly = fposmod(mean_anomaly + mean_motion * dt_sim, TAU)
		var e_anom: float = OrbitMath.solve_kepler(mean_anomaly, eccentricity)
		true_anomaly = OrbitMath.eccentric_to_true(e_anom, eccentricity)
		_sync_cartesian_from_elements()

	_update_trail(dt_sim)
	_emit_telemetry()

func _sync_cartesian_from_elements() -> void:
	var state := OrbitMath.elements_to_state(
		semi_major_axis, eccentricity, inclination, raan, arg_periapsis,
		true_anomaly, Constants.EARTH_MU)
	cartesian_pos = state.position
	cartesian_vel = state.velocity
	if is_hyperbolic:
		# Escape mode kicks off from a real circular state, boosted to
		# escape speed, then handed to the RK4 integrator above.
		var r: float = cartesian_pos.length()
		var dir: Vector3 = cartesian_vel.normalized()
		var v_escape: float = OrbitMath.escape_speed(r, Constants.EARTH_MU) * 1.03
		cartesian_vel = dir * v_escape

func _update_trail(dt_sim: float) -> void:
	_trail_accum += dt_sim
	if _trail_accum < 15.0:
		return
	_trail_accum = 0.0
	orbit_trail.append(cartesian_pos)
	if orbit_trail.size() > TRAIL_MAX_POINTS:
		orbit_trail.remove_at(0)

# ---------------------------------------------------------------------------
# Telemetry
# ---------------------------------------------------------------------------
func _emit_telemetry() -> void:
	telemetry_updated.emit(get_telemetry())

func get_telemetry() -> Dictionary:
	var r: float = cartesian_pos.length()
	var altitude_km: float = (r - Constants.EARTH_RADIUS) / 1000.0
	var speed_mps: float = cartesian_vel.length()
	var latlon := OrbitMath.position_to_lat_lon(cartesian_pos, earth_rotation_rad)

	var period_s: float = INF
	var apo_km: float = 0.0
	var peri_km: float = 0.0
	if not is_hyperbolic and eccentricity < 1.0:
		period_s = OrbitMath.period(semi_major_axis, Constants.EARTH_MU, eccentricity)
		apo_km = (OrbitMath.apoapsis(semi_major_axis, eccentricity) - Constants.EARTH_RADIUS) / 1000.0
		peri_km = (OrbitMath.periapsis(semi_major_axis, eccentricity) - Constants.EARTH_RADIUS) / 1000.0

	return {
		"run_state": run_state,
		"mission_time_s": mission_time_s,
		"altitude_km": altitude_km,
		"speed_mps": speed_mps,
		"period_s": period_s,
		"apogee_km": apo_km,
		"perigee_km": peri_km,
		"eccentricity": eccentricity,
		"inclination_deg": rad_to_deg(inclination),
		"latitude": latlon.x,
		"longitude": latlon.y,
		"mass_kg": satellite_mass_kg,
		"orbit_type": current_preset.orbit_type if current_preset else Constants.OrbitType.CUSTOM,
		"mission_name": current_preset.display_name if current_preset else "—",
		"position": cartesian_pos,
		"velocity": cartesian_vel,
		"sim_speed": sim_speed,
	}
