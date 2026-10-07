class_name UiTheme
extends RefCounted
## Shared colours and helpers for every piece of UI.

const PANEL: Color = Color(0.09, 0.1, 0.12, 0.94)
const PANEL_LIGHT: Color = Color(0.16, 0.17, 0.2, 1.0)
const TEXT: Color = Color(0.94, 0.94, 0.9)
const MUTED: Color = Color(0.62, 0.64, 0.68)
const MONEY: Color = Color(0.35, 0.88, 0.45)
const GOOD: Color = Color(0.45, 0.9, 0.55)
const BAD: Color = Color(1.0, 0.4, 0.34)
const WARN: Color = Color(1.0, 0.8, 0.3)
const INFO: Color = Color(0.6, 0.78, 1.0)


static func money(amount: int) -> String:
	var digits: String = str(absi(amount))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	var sign_text: String = "-" if amount < 0 else ""
	return "%s$%s%s" % [sign_text, digits, grouped]


## Seconds as m:ss.
static func clock(seconds: int) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]


static func label(text: String, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	node.add_theme_constant_override("outline_size", 4)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func button(text: String, on_press: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_size_override("font_size", 18)
	node.custom_minimum_size = Vector2(0, 36)
	node.pressed.connect(on_press)
	return node


static func panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	return style

