extends PanelContainer
## MissionControl.tscn root script.
##
## The left-hand control panel: mission preset selection, run/pause/reset,
## simulation speed, camera mode cycling, screenshot capture, and telemetry
## CSV export. Talks to SimState (simulation) and to the CameraController
## (assigned by Main after the scene graph is built) — it never touches
## rendering directly.

var camera_ref: Camera3D = null
var _status_label: Label

var mission_option: OptionButton
var launch_btn: Button
var pause_btn: Button
var reset_btn: Button
var camera_btn: Button
var screenshot_btn: Button
var export_btn: Button
var speed_slider: HSlider
var speed_label: Label
var desc_label: Label

func _ready() -> void:
	_build_ui()
	SimState.state_changed.connect(_on_state_changed)
	SimState.mission_loaded.connect(_on_mission_loaded)
	_on_mission_loaded(SimState.current_preset)
	_on_state_changed(false)

func set_camera(cam: Camera3D) -> void:
	camera_ref = cam

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Constants.ELECTRIC_CYAN)
	l.add_theme_font_size_override("font_size", 13)
	return l

func _build_ui() -> void:
	custom_minimum_size = Vector2(300, 0)
	add_theme_stylebox_override("panel", UITheme.panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "MISSION CONTROL"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Constants.SOFT_WHITE)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	vbox.add_child(_section_label("MISSION PRESET"))
	mission_option = OptionButton.new()
	for preset in Constants.MISSION_PRESETS:
		mission_option.add_item(preset.display_name)
	mission_option.item_selected.connect(_on_mission_selected)
	UITheme.style_option_button(mission_option)
	vbox.add_child(mission_option)

	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_color_override("font_color", Constants.TEXT_SECONDARY)
	desc_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc_label)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_section_label("SIMULATION"))

	var run_row := HBoxContainer.new()
	run_row.add_theme_constant_override("separation", 6)
	vbox.add_child(run_row)

	launch_btn = UITheme.make_button("LAUNCH", Constants.MISSION_GREEN)
	launch_btn.pressed.connect(func(): SimState.launch())
	run_row.add_child(launch_btn)

	pause_btn = UITheme.make_button("PAUSE", Constants.WARNING_ORANGE)
	pause_btn.pressed.connect(_on_pause_pressed)
	run_row.add_child(pause_btn)

	reset_btn = UITheme.make_button("RESET", Constants.CRITICAL_RED)
	reset_btn.pressed.connect(func(): SimState.reset())
	run_row.add_child(reset_btn)

	vbox.add_child(_section_label("SIMULATION SPEED"))
	var speed_row := HBoxContainer.new()
	vbox.add_child(speed_row)
	speed_slider = HSlider.new()
	speed_slider.min_value = 1.0
	speed_slider.max_value = 2000.0
	speed_slider.step = 1.0
	speed_slider.value = SimState.sim_speed
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.value_changed.connect(func(v): SimState.set_sim_speed(v))
	speed_row.add_child(speed_slider)
	speed_label = Label.new()
	speed_label.custom_minimum_size = Vector2(70, 0)
	speed_label.add_theme_color_override("font_color", Constants.TEXT_PRIMARY)
	speed_row.add_child(speed_label)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_section_label("VIEW & DATA"))

	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tool_row)

	camera_btn = UITheme.make_button("CAMERA: FREE", Constants.ELECTRIC_CYAN)
	camera_btn.pressed.connect(_on_camera_pressed)
	tool_row.add_child(camera_btn)

	var tool_row2 := HBoxContainer.new()
	tool_row2.add_theme_constant_override("separation", 6)
	vbox.add_child(tool_row2)

	screenshot_btn = UITheme.make_button("SCREENSHOT", Constants.TEXT_PRIMARY)
	screenshot_btn.pressed.connect(_on_screenshot_pressed)
	tool_row2.add_child(screenshot_btn)

	export_btn = UITheme.make_button("EXPORT DATA", Constants.TEXT_PRIMARY)
	export_btn.pressed.connect(_on_export_pressed)
	tool_row2.add_child(export_btn)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Constants.TEXT_MUTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)

func _process(_delta: float) -> void:
	speed_label.text = "%.0fx" % SimState.sim_speed

func _on_mission_selected(idx: int) -> void:
	SimState.load_mission(Constants.MISSION_PRESETS[idx])

func _on_mission_loaded(preset) -> void:
	if preset == null:
		return
	desc_label.text = preset.description
	for i in range(Constants.MISSION_PRESETS.size()):
		if Constants.MISSION_PRESETS[i] == preset:
			mission_option.select(i)
			break

func _on_pause_pressed() -> void:
	if SimState.run_state == SimState.RunState.RUNNING:
		SimState.pause()
	elif SimState.run_state == SimState.RunState.PAUSED:
		SimState.resume()

func _on_state_changed(is_running: bool) -> void:
	pause_btn.text = "PAUSE" if is_running else "RESUME"
	launch_btn.disabled = is_running

func _on_camera_pressed() -> void:
	if camera_ref == null:
		return
	match camera_ref.mode:
		Constants.CameraMode.FREE_ORBIT:
			camera_ref.focus_earth()
			camera_btn.text = "CAMERA: EARTH"
		Constants.CameraMode.FOCUS_EARTH:
			camera_ref.focus_satellite()
			camera_btn.text = "CAMERA: SAT"
		Constants.CameraMode.FOCUS_SATELLITE:
			camera_ref.toggle_cinematic()
			camera_btn.text = "CAMERA: CINE"
		_:
			camera_ref.reset_view()
			camera_btn.text = "CAMERA: FREE"

func _on_screenshot_pressed() -> void:
	var img := get_viewport().get_texture().get_image()
	var dir := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	var filename := "%s/mission_%s.png" % [dir, Time.get_datetime_string_from_system().replace(":", "-")]
	img.save_png(filename)
	_flash_status("Screenshot saved: " + filename)

func _on_export_pressed() -> void:
	var t := SimState.get_telemetry()
	var dir := "user://exports"
	DirAccess.make_dir_recursive_absolute(dir)
	var filename := "%s/telemetry_%s.csv" % [dir, Time.get_datetime_string_from_system().replace(":", "-")]
	var f := FileAccess.open(filename, FileAccess.WRITE)
	if f:
		f.store_line("field,value")
		for key in t.keys():
			if key in ["position", "velocity"]:
				continue
			f.store_line("%s,%s" % [key, str(t[key])])
		f.close()
		_flash_status("Telemetry exported: " + filename)
	else:
		_flash_status("Export failed — check write permissions.")

func _flash_status(msg: String) -> void:
	_status_label.text = msg
