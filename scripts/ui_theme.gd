class_name UITheme
extends RefCounted
## UITheme — shared style-building helpers for the mission-control UI.
## Centralizing StyleBox construction here keeps every panel/button visually
## consistent without needing a hand-authored .tres Theme resource.

static func panel_style(border_color: Color = Constants.PANEL_BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Constants.PANEL_BG
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 12
	return sb

static func button_style(color: Color, pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.16 if not pressed else 0.32)
	sb.border_color = Color(color.r, color.g, color.b, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

static func make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", button_style(color))
	b.add_theme_stylebox_override("hover", button_style(color.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", button_style(color, true))
	b.add_theme_stylebox_override("disabled", button_style(Constants.TEXT_MUTED))
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color.lightened(0.3))
	b.add_theme_color_override("font_disabled_color", Constants.TEXT_MUTED)
	b.add_theme_font_size_override("font_size", 12)
	return b

static func style_option_button(ob: OptionButton) -> void:
	ob.add_theme_stylebox_override("normal", button_style(Constants.ELECTRIC_CYAN))
	ob.add_theme_stylebox_override("hover", button_style(Constants.ELECTRIC_CYAN.lightened(0.15)))
	ob.add_theme_stylebox_override("pressed", button_style(Constants.ELECTRIC_CYAN, true))
	ob.add_theme_color_override("font_color", Constants.TEXT_PRIMARY)
	ob.add_theme_font_size_override("font_size", 12)

static func telemetry_row(parent: VBoxContainer, label_text: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(120, 0)
	name_label.add_theme_color_override("font_color", Constants.TEXT_SECONDARY)
	name_label.add_theme_font_size_override("font_size", 12)
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = "—"
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Constants.SOFT_WHITE)
	value_label.add_theme_font_size_override("font_size", 13)
	row.add_child(value_label)

	return value_label
