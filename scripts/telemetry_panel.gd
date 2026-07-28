extends PanelContainer
## Right-hand telemetry panel: live mission data readout, formatted the way
## a mission-analysis HUD would (fixed units, monospace-style alignment via
## right-aligned value labels).

var _rows: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)
	add_theme_stylebox_override("panel", UITheme.panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "TELEMETRY"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Constants.SOFT_WHITE)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var mission_title := Label.new()
	mission_title.add_theme_font_size_override("font_size", 13)
	mission_title.add_theme_color_override("font_color", Constants.ELECTRIC_CYAN)
	vbox.add_child(mission_title)
	_rows["mission"] = mission_title

	for field in [
		["orbit_type", "Orbit Type"],
		["run_state", "Status"],
		["mission_time", "Mission Time"],
		["altitude", "Altitude"],
		["velocity", "Velocity"],
		["period", "Orbital Period"],
		["apogee", "Apogee"],
		["perigee", "Perigee"],
		["eccentricity", "Eccentricity"],
		["inclination", "Inclination"],
		["latitude", "Latitude"],
		["longitude", "Longitude"],
		["mass", "Satellite Mass"],
	]:
		_rows[field[0]] = UITheme.telemetry_row(vbox, field[1])

	SimState.telemetry_updated.connect(_on_telemetry)
	_on_telemetry(SimState.get_telemetry())

func _on_telemetry(t: Dictionary) -> void:
	_rows["mission"].text = t.get("mission_name", "—")
	_rows["orbit_type"].text = Constants.orbit_type_name(t.get("orbit_type", -1))
	_rows["run_state"].text = _state_name(t.get("run_state", 0))
	_rows["mission_time"].text = _format_duration(t.get("mission_time_s", 0.0))
	_rows["altitude"].text = "%.1f km" % t.get("altitude_km", 0.0)
	_rows["velocity"].text = "%.2f km/s" % (t.get("speed_mps", 0.0) / 1000.0)

	var period_s: float = t.get("period_s", INF)
	_rows["period"].text = _format_duration(period_s) if is_finite(period_s) else "∞ (escaping)"
	_rows["apogee"].text = "%.1f km" % t.get("apogee_km", 0.0)
	_rows["perigee"].text = "%.1f km" % t.get("perigee_km", 0.0)
	_rows["eccentricity"].text = "%.4f" % t.get("eccentricity", 0.0)
	_rows["inclination"].text = "%.2f°" % t.get("inclination_deg", 0.0)
	_rows["latitude"].text = "%.2f°" % t.get("latitude", 0.0)
	_rows["longitude"].text = "%.2f°" % t.get("longitude", 0.0)
	_rows["mass"].text = "%.0f kg" % t.get("mass_kg", 0.0)

func _state_name(s: int) -> String:
	match s:
		SimState.RunState.IDLE: return "IDLE"
		SimState.RunState.RUNNING: return "ACTIVE"
		SimState.RunState.PAUSED: return "PAUSED"
		SimState.RunState.ESCAPED: return "ESCAPED"
		_: return "—"

func _format_duration(seconds: float) -> String:
	if not is_finite(seconds):
		return "∞"
	var s: int = int(seconds)
	var days: int = s / 86400
	var hours: int = (s % 86400) / 3600
	var mins: int = (s % 3600) / 60
	var secs: int = s % 60
	if days > 0:
		return "%dd %02dh %02dm" % [days, hours, mins]
	elif hours > 0:
		return "%dh %02dm %02ds" % [hours, mins, secs]
	else:
		return "%dm %02ds" % [mins, secs]
