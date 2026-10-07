class_name Menu
extends Control
## The title menu: your name, Host a crew, Join by address, Quit.

signal host_requested
signal join_requested(address: String)

const CONTROLS: String = "WASD move  ·  Shift sprint  ·  Space jump  ·  Mouse look, click to shoot\nF mask  ·  E interact (hold for jobs)  ·  G throw bag  ·  1-4 weapons  ·  R reload  ·  Esc pause"

var _name: LineEdit = null
var _address: LineEdit = null
var _status: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.07, 0.09, 0.08)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := UiTheme.label("GET THE BAG", 64, UiTheme.MONEY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tagline := UiTheme.label("Rob First National with up to 3 friends.", 18, UiTheme.MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tagline)

	box.add_child(UiTheme.label("Your name", 16, UiTheme.MUTED))
	_name = LineEdit.new()
	_name.max_length = 16
	_name.text = Save.load_profile()["name"]
	box.add_child(_name)
	box.add_child(UiTheme.button("Host a crew", func() -> void: host_requested.emit()))

	box.add_child(UiTheme.label("Host address", 16, UiTheme.MUTED))
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	box.add_child(_address)
	box.add_child(UiTheme.button("Join", func() -> void: join_requested.emit(_address.text.strip_edges())))
	box.add_child(UiTheme.button("Quit", func() -> void: get_tree().quit()))

	_status = UiTheme.label("", 16, UiTheme.TEXT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	var controls := UiTheme.label(CONTROLS, 14, UiTheme.MUTED)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(controls)


func player_name() -> String:
	return _name.text.strip_edges()


func show_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
