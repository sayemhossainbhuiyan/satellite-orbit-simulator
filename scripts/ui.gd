extends CanvasLayer
## UI.tscn root script.
##
## Lays out the screen chrome: a header bar with mission title, the
## MissionControl panel docked left, the telemetry panel docked right, and
## an escape-trajectory warning banner. Main.gd calls set_camera() once the
## CameraController exists so MissionControl's camera button can drive it.

var mission_control: PanelContainer
var telemetry_panel: PanelContainer
var _escape_banner: PanelContainer

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_header(root)
	_build_side_panels(root)
	_build_escape_banner(root)

	SimState.telemetry_updated.connect(_on_telemetry)

func set_camera(cam: Camera3D) -> void:
	if mission_control:
		mission_control.set_camera(cam)

func _build_header(root: Control) -> void:
	var header := PanelContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.add_theme_stylebox_override("panel", UITheme.panel_style())
	header.custom_minimum_size = Vector2(0, 52)
	header.offset_left = 16
	header.offset_right = -16
	header.offset_top = 16
	header.offset_bottom = 68
	root.add_child(header)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	header.add_child(margin)

	var inner := HBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(inner)

	var title := Label.new()
	title.text = "SATELLITE ORBIT SIMULATOR"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Constants.SOFT_WHITE)
	inner.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)

	var subtitle := Label.new()
	subtitle.text = "Newtonian Two-Body Propagator · Real-Time Telemetry"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Constants.TEXT_SECONDARY)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(subtitle)

func _build_side_panels(root: Control) -> void:
	var mc_scene := load("res://scenes/MissionControl.tscn")
	mission_control = mc_scene.instantiate()
	mission_control.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	mission_control.offset_left = 16
	mission_control.offset_top = 80
	mission_control.offset_bottom = -16
	mission_control.offset_right = 316
	root.add_child(mission_control)

	var tel_scene := load("res://scenes/TelemetryPanel.tscn")
	telemetry_panel = tel_scene.instantiate()
	telemetry_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	telemetry_panel.offset_right = -16
	telemetry_panel.offset_top = 80
	telemetry_panel.offset_bottom = -16
	telemetry_panel.offset_left = -316
	root.add_child(telemetry_panel)

func _build_escape_banner(root: Control) -> void:
	_escape_banner = PanelContainer.new()
	_escape_banner.add_theme_stylebox_override("panel", UITheme.panel_style(Constants.CRITICAL_RED))
	_escape_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_escape_banner.offset_left = -220
	_escape_banner.offset_right = 220
	_escape_banner.offset_top = 80
	_escape_banner.offset_bottom = 120
	_escape_banner.visible = false
	root.add_child(_escape_banner)

	var label := Label.new()
	label.text = "⚠ ESCAPE TRAJECTORY — SATELLITE HAS LEFT EARTH ORBIT"
	label.add_theme_color_override("font_color", Constants.CRITICAL_RED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	_escape_banner.add_child(label)

func _on_telemetry(t: Dictionary) -> void:
	_escape_banner.visible = (t.get("run_state", 0) == SimState.RunState.ESCAPED)
