extends Node
## Constants.gd — Autoload singleton.
##
## Single source of truth for physical constants, the mission-control color
## palette, and mission presets. Mirrors the structure of the original
## Python `constants.py` / `missions.py` so behavior stays consistent
## between the reference implementation and this rebuild.
##
## Units: physics is done in SI (meters, seconds, kg) and converted to
## simulation units (1 sim unit = 1000 km) only at the render boundary,
## so the physics never depends on the visual scale.

# ---------------------------------------------------------------------------
# PHYSICAL CONSTANTS (SI units)
# ---------------------------------------------------------------------------
const G: float = 6.67430e-11                    # m^3 kg^-1 s^-2
const EARTH_MASS: float = 5.972e24               # kg
const EARTH_RADIUS: float = 6_371_000.0          # m
const EARTH_MU: float = G * EARTH_MASS           # standard gravitational parameter
const EARTH_SIDEREAL_DAY: float = 86164.0905     # s
const EARTH_J2: float = 1.08263e-3               # oblateness (reserved for perturbations)
const KARMAN_LINE: float = 100_000.0             # m

# ---------------------------------------------------------------------------
# SIMULATION / RENDER SCALE
# ---------------------------------------------------------------------------
# 1 render unit = this many meters. Keeps the Earth a manageable ~6.371
# units in radius while orbits at GEO altitude (~42,000 km) stay on-screen.
const RENDER_UNITS_PER_METER: float = 1.0 / 1_000_000.0

func to_render(meters: float) -> float:
	return meters * RENDER_UNITS_PER_METER

func to_meters(render_units: float) -> float:
	return render_units / RENDER_UNITS_PER_METER

# ---------------------------------------------------------------------------
# COLOR PALETTE — Aerospace / Mission Control dark theme
# ---------------------------------------------------------------------------
const DEEP_SPACE_BLACK  := Color(5.0/255, 7.0/255, 12.0/255)
const MIDNIGHT_BLUE      := Color(10.0/255, 16.0/255, 32.0/255)
const DARK_NAVY          := Color(14.0/255, 22.0/255, 43.0/255)
const PANEL_BG           := Color(12.0/255, 20.0/255, 38.0/255, 0.72)
const PANEL_BG_SOLID     := Color(12.0/255, 20.0/255, 38.0/255)
const PANEL_BORDER       := Color(60.0/255, 200.0/255, 255.0/255, 0.55)
const PANEL_BORDER_BRIGHT:= Color(110.0/255, 230.0/255, 255.0/255, 0.9)

const ELECTRIC_CYAN  := Color(64.0/255, 220.0/255, 255.0/255)
const SOFT_WHITE      := Color(230.0/255, 240.0/255, 250.0/255)
const MISSION_GREEN   := Color(60.0/255, 230.0/255, 150.0/255)
const WARNING_ORANGE   := Color(255.0/255, 170.0/255, 60.0/255)
const CRITICAL_RED     := Color(255.0/255, 70.0/255, 70.0/255)

const TEXT_PRIMARY   := Color(225.0/255, 238.0/255, 248.0/255)
const TEXT_SECONDARY := Color(140.0/255, 165.0/255, 190.0/255)
const TEXT_MUTED     := Color(90.0/255, 108.0/255, 130.0/255)

const ORBIT_LINE     := Color(64.0/255, 220.0/255, 255.0/255, 0.7)
const GROUND_TRACK   := Color(255.0/255, 170.0/255, 60.0/255, 0.65)

# ---------------------------------------------------------------------------
# ENUMS
# ---------------------------------------------------------------------------
enum OrbitType { LEO, MEO, GEO, POLAR, SSO, MOLNIYA, ESCAPE, CUSTOM }
enum SatelliteType { COMMUNICATION, OBSERVATION, GPS, WEATHER }
enum CameraMode { FREE_ORBIT, FOCUS_EARTH, FOCUS_SATELLITE, CINEMATIC }

# ---------------------------------------------------------------------------
# MISSION PRESETS
# Physically-representative altitude / inclination / eccentricity values.
# ---------------------------------------------------------------------------
class MissionPreset:
	var id: String
	var display_name: String
	var orbit_type: int
	var altitude_km: float
	var inclination_deg: float
	var eccentricity: float
	var description: String

	func _init(p_id: String, p_name: String, p_type: int, p_alt: float,
			p_incl: float, p_ecc: float, p_desc: String) -> void:
		id = p_id
		display_name = p_name
		orbit_type = p_type
		altitude_km = p_alt
		inclination_deg = p_incl
		eccentricity = p_ecc
		description = p_desc

	func circular_velocity_mps() -> float:
		var r: float = Constants.EARTH_RADIUS + altitude_km * 1000.0
		return sqrt(Constants.EARTH_MU / r)

var MISSION_PRESETS: Array = []

func _init_presets() -> void:
	MISSION_PRESETS = [
		MissionPreset.new("leo", "Low Earth Orbit (ISS-class)", OrbitType.LEO,
			420.0, 51.6, 0.001,
			"~420 km circular, ISS-like inclination. Period ~93 min."),
		MissionPreset.new("meo", "Medium Earth Orbit (GPS-class)", OrbitType.MEO,
			20200.0, 55.0, 0.001,
			"Navigation constellation altitude, ~12 hr period."),
		MissionPreset.new("geo", "Geostationary Orbit", OrbitType.GEO,
			35786.0, 0.0, 0.0002,
			"Matches Earth's rotation — appears fixed over one longitude."),
		MissionPreset.new("polar", "Polar Orbit", OrbitType.POLAR,
			780.0, 90.0, 0.001,
			"Near-90° inclination, passes over both poles each orbit."),
		MissionPreset.new("sso", "Sun-Synchronous Orbit", OrbitType.SSO,
			705.0, 98.2, 0.001,
			"Slightly retrograde so it crosses the equator at a fixed local time."),
		MissionPreset.new("molniya", "Molniya (highly elliptical)", OrbitType.MOLNIYA,
			600.0, 63.4, 0.74,
			"Long dwell time over high latitudes; period ~12 hr."),
		MissionPreset.new("escape", "Escape Trajectory", OrbitType.ESCAPE,
			420.0, 28.5, 1.0,
			"Velocity at/above local escape speed — satellite departs Earth orbit."),
	]

func _ready() -> void:
	_init_presets()

func orbit_type_name(t: int) -> String:
	match t:
		OrbitType.LEO: return "LEO"
		OrbitType.MEO: return "MEO"
		OrbitType.GEO: return "GEO"
		OrbitType.POLAR: return "POLAR"
		OrbitType.SSO: return "SSO"
		OrbitType.MOLNIYA: return "MOLNIYA"
		OrbitType.ESCAPE: return "ESCAPE"
		_: return "CUSTOM"
