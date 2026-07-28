class_name OrbitMath
extends RefCounted
## OrbitMath — pure math utility library for two-body Newtonian orbital
## mechanics. No engine/scene dependencies, fully unit-testable in isolation.
##
## Convention: all vectors are in meters / meters-per-second, Earth-centered
## inertial (ECI)-like frame with +Y as the rotation axis (Godot's up).
## Position (x, z) forms the equatorial plane; y is out of the equator.

## Solves Kepler's equation M = E - e*sin(E) for eccentric anomaly E via
## Newton-Raphson iteration.
static func solve_kepler(mean_anomaly: float, eccentricity: float, tolerance: float = 1e-8) -> float:
	var m: float = fposmod(mean_anomaly, TAU)
	var e_anom: float = m if eccentricity < 0.8 else PI
	for i in range(50):
		var f: float = e_anom - eccentricity * sin(e_anom) - m
		var f_prime: float = 1.0 - eccentricity * cos(e_anom)
		var delta: float = f / f_prime
		e_anom -= delta
		if abs(delta) < tolerance:
			break
	return e_anom

## Converts classical orbital elements to a Cartesian position (meters) and
## velocity (m/s) in the ECI-like frame described above.
##
## a: semi-major axis (m), e: eccentricity, i: inclination (rad),
## raan: right ascension of ascending node (rad), argp: argument of
## periapsis (rad), nu: true anomaly (rad), mu: gravitational parameter.
static func elements_to_state(a: float, e: float, i: float, raan: float,
		argp: float, nu: float, mu: float) -> Dictionary:
	var p: float = a * (1.0 - e * e)
	var r: float = p / (1.0 + e * cos(nu))

	# Position / velocity in the orbital (perifocal) plane.
	var r_pf: Vector3 = Vector3(r * cos(nu), 0.0, r * sin(nu))
	var h: float = sqrt(mu * p)
	var v_pf: Vector3 = Vector3(-mu / h * sin(nu), 0.0, mu / h * (e + cos(nu)))

	# Rotate perifocal -> ECI via 3-1-3 Euler sequence (RAAN, inclination, argp),
	# remapped so Y is the polar axis (Godot up) instead of Z.
	var cos_raan := cos(raan); var sin_raan := sin(raan)
	var cos_i := cos(i); var sin_i := sin(i)
	var cos_argp := cos(argp); var sin_argp := sin(argp)

	var r11 := cos_raan * cos_argp - sin_raan * sin_argp * cos_i
	var r12 := -cos_raan * sin_argp - sin_raan * cos_argp * cos_i
	var r13 := sin_raan * sin_i

	var r21 := sin_i * sin_argp
	var r22 := sin_i * cos_argp
	var r23 := cos_i

	var r31 := sin_raan * cos_argp + cos_raan * sin_argp * cos_i
	var r32 := -sin_raan * sin_argp + cos_raan * cos_argp * cos_i
	var r33 := -cos_raan * sin_i

	var pos := Vector3(
		r11 * r_pf.x + r12 * r_pf.z,
		r21 * r_pf.x + r22 * r_pf.z,
		r31 * r_pf.x + r32 * r_pf.z
	)
	var vel := Vector3(
		r11 * v_pf.x + r12 * v_pf.z,
		r21 * v_pf.x + r22 * v_pf.z,
		r31 * v_pf.x + r32 * v_pf.z
	)
	return {"position": pos, "velocity": vel}

## True anomaly (rad) from eccentric anomaly.
static func eccentric_to_true(e_anom: float, e: float) -> float:
	var y: float = sqrt(1.0 + e) * sin(e_anom * 0.5)
	var x: float = sqrt(1.0 - e) * cos(e_anom * 0.5)
	return 2.0 * atan2(y, x)

## Orbital period (s) for an elliptical orbit. Returns INF for e >= 1.
static func period(a: float, mu: float, e: float) -> float:
	if e >= 1.0:
		return INF
	return TAU * sqrt(pow(a, 3) / mu)

static func apoapsis(a: float, e: float) -> float:
	return a * (1.0 + e)

static func periapsis(a: float, e: float) -> float:
	return a * (1.0 - e)

## Local circular-orbit speed at radius r (m/s).
static func circular_speed(r: float, mu: float) -> float:
	return sqrt(mu / r)

## Local escape speed at radius r (m/s).
static func escape_speed(r: float, mu: float) -> float:
	return sqrt(2.0 * mu / r)

## Vis-viva speed (m/s) at radius r for an orbit of semi-major axis a.
## For a hyperbolic escape trajectory pass a < 0.
static func vis_viva_speed(r: float, a: float, mu: float) -> float:
	return sqrt(mu * (2.0 / r - 1.0 / a))

## One RK4 Newtonian gravity integration step. Used for the "escape /
## perturbed" simulation mode where a closed-form ellipse no longer applies.
static func rk4_step(pos: Vector3, vel: Vector3, dt: float, mu: float) -> Dictionary:
	var accel := func(p: Vector3) -> Vector3:
		var r: float = p.length()
		return -mu / (r * r * r) * p

	var k1v = accel.call(pos)
	var k1p = vel

	var k2v = accel.call(pos + k1p * dt * 0.5)
	var k2p = vel + k1v * dt * 0.5

	var k3v = accel.call(pos + k2p * dt * 0.5)
	var k3p = vel + k2v * dt * 0.5

	var k4v = accel.call(pos + k3p * dt)
	var k4p = vel + k3v * dt

	var new_pos = pos + (dt / 6.0) * (k1p + 2.0 * k2p + 2.0 * k3p + k4p)
	var new_vel = vel + (dt / 6.0) * (k1v + 2.0 * k2v + 2.0 * k3v + k4v)
	return {"position": new_pos, "velocity": new_vel}

## Converts a position vector (meters, Y-up ECI-like frame) to
## geodetic latitude/longitude in degrees, accounting for Earth's rotation
## angle (radians) so longitude reflects the ground track correctly.
static func position_to_lat_lon(pos: Vector3, earth_rotation_rad: float) -> Vector2:
	var r: float = pos.length()
	var lat: float = rad_to_deg(asin(clamp(pos.y / r, -1.0, 1.0)))
	var lon_inertial: float = atan2(pos.z, pos.x)
	var lon: float = rad_to_deg(lon_inertial - earth_rotation_rad)
	lon = fmod(lon + 180.0, 360.0)
	if lon < 0.0:
		lon += 360.0
	lon -= 180.0
	return Vector2(lat, lon)
