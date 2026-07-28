extends Camera3D
## CameraController.tscn root script.
##
## An orbit/pan/zoom camera rig in the style of mission-visualization
## tools: left-drag orbits around the focus point, right-drag pans the
## focus point, wheel zooms, and named focus targets (Earth / Satellite)
## smoothly re-center and re-frame. All motion is critically-damped via
## lerp/slerp toward target values rather than snapping, for a polished,
## "professional software" feel rather than a game-camera feel.

@export var min_distance: float = 8.0
@export var max_distance: float = 220.0
@export var orbit_sensitivity: float = 0.006
@export var pan_sensitivity: float = 0.01
@export var zoom_sensitivity: float = 0.12
@export var smoothing: float = 6.0

var focus_point: Vector3 = Vector3.ZERO
var _target_focus: Vector3 = Vector3.ZERO
var distance: float = 26.0
var _target_distance: float = 26.0
var yaw: float = -0.6
var _target_yaw: float = -0.6
var pitch: float = 0.35
var _target_pitch: float = 0.35

var mode: int = Constants.CameraMode.FREE_ORBIT

var _dragging_orbit: bool = false
var _dragging_pan: bool = false

func _ready() -> void:
	current = true
	fov = 45.0
	_apply_immediate()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging_orbit = event.pressed
				if event.pressed:
					mode = Constants.CameraMode.FREE_ORBIT
			MOUSE_BUTTON_RIGHT:
				_dragging_pan = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_target_distance = clamp(_target_distance * (1.0 - zoom_sensitivity), min_distance, max_distance)
			MOUSE_BUTTON_WHEEL_DOWN:
				_target_distance = clamp(_target_distance * (1.0 + zoom_sensitivity), min_distance, max_distance)
	elif event is InputEventMouseMotion:
		if _dragging_orbit:
			mode = Constants.CameraMode.FREE_ORBIT
			_target_yaw -= event.relative.x * orbit_sensitivity
			_target_pitch = clamp(_target_pitch - event.relative.y * orbit_sensitivity, -1.5, 1.5)
		elif _dragging_pan:
			mode = Constants.CameraMode.FREE_ORBIT
			var right: Vector3 = global_transform.basis.x
			var up: Vector3 = global_transform.basis.y
			var pan_scale: float = distance * pan_sensitivity
			_target_focus -= right * event.relative.x * pan_scale * 0.02
			_target_focus += up * event.relative.y * pan_scale * 0.02

func focus_earth() -> void:
	mode = Constants.CameraMode.FOCUS_EARTH
	_target_focus = Vector3.ZERO
	_target_distance = clamp(distance, 16.0, 40.0)

func focus_satellite() -> void:
	mode = Constants.CameraMode.FOCUS_SATELLITE
	_target_distance = clamp(_target_distance, min_distance, 14.0)

func reset_view() -> void:
	mode = Constants.CameraMode.FREE_ORBIT
	_target_focus = Vector3.ZERO
	_target_distance = 26.0
	_target_yaw = -0.6
	_target_pitch = 0.35

func toggle_cinematic() -> void:
	if mode == Constants.CameraMode.CINEMATIC:
		mode = Constants.CameraMode.FREE_ORBIT
	else:
		mode = Constants.CameraMode.CINEMATIC

func _process(delta: float) -> void:
	if mode == Constants.CameraMode.FOCUS_SATELLITE:
		_target_focus = SimState.cartesian_pos * Constants.RENDER_UNITS_PER_METER
	elif mode == Constants.CameraMode.CINEMATIC:
		_target_yaw += delta * 0.05

	var t: float = clamp(delta * smoothing, 0.0, 1.0)
	focus_point = focus_point.lerp(_target_focus, t)
	distance = lerp(distance, _target_distance, t)
	yaw = lerp_angle(yaw, _target_yaw, t)
	pitch = lerp(pitch, _target_pitch, t)
	_apply_immediate()

func _apply_immediate() -> void:
	var offset := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)
	) * distance
	global_position = focus_point + offset
	look_at(focus_point, Vector3.UP)
