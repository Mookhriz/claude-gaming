class_name Hud
extends CanvasLayer
## Everything on screen during play: crew cash, stars and the evade meter, bank and quest status, health, ammo,
## the interaction prompt with its hold bar, hints, toasts, banners, the downed overlay, the shop and casino
## panels, and the pause menu.

const MAX_TOASTS: int = 6

var _cash: Label = null
var _status: Label = null
var _stars: StarRow = null
var _evade: ProgressBar = null
var _health_bar: ProgressBar = null
var _health_label: Label = null
var _ammo: Label = null
var _carry: Label = null
var _prompt: Label = null
var _hold_bar: ProgressBar = null
var _hint: Label = null
var _hint_time: float = 0.0
var _toasts: VBoxContainer = null
var _banner: VBoxContainer = null
var _banner_title: Label = null
var _banner_text: Label = null
var _banner_time: float = 0.0
var _damage: ColorRect = null
var _downed: ColorRect = null
var _downed_label: Label = null
var _panel: Control = null
var _pause: Control = null


## Draws the five wanted stars.
class StarRow extends Control:
	var count: int = 0:
		set(value):
			if value != count:
				count = value
				queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(5 * 30, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i: int in range(Catalog.MAX_STARS):
			var points := PackedVector2Array()
			for k: int in range(10):
				var radius: float = 12.0 if k % 2 == 0 else 5.4
				var angle: float = -PI / 2.0 + k * PI / 5.0
				points.append(Vector2(15 + i * 30, 14) + Vector2(cos(angle), sin(angle)) * radius)
			if i < count:
				draw_colored_polygon(points, UiTheme.WARN)
			else:
				points.append(points[0])
				draw_polyline(points, UiTheme.MUTED, 2.0)


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_damage = _overlay(root, Color(1, 0, 0, 0))
	_downed = _overlay(root, Color(0.5, 0, 0, 0.35))
	_downed_label = UiTheme.label("", 30, UiTheme.TEXT)
	_downed_label.set_anchors_preset(Control.PRESET_CENTER)
	_downed_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_downed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed.add_child(_downed_label)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(20, 16)
	root.add_child(top_left)
	_cash = UiTheme.label("", 34, UiTheme.MONEY)
	top_left.add_child(_cash)
	_status = UiTheme.label("", 18, UiTheme.TEXT)
	top_left.add_child(_status)

	var top_right := VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right.position = Vector2(-20, 16)
	top_right.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(top_right)
	_stars = StarRow.new()
	top_right.add_child(_stars)
	_evade = _bar(Color(0.5, 0.7, 1.0))
	top_right.add_child(_evade)

	var bottom_left := VBoxContainer.new()
	bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_left.position = Vector2(20, -20)
	root.add_child(bottom_left)
	_health_label = UiTheme.label("", 20, UiTheme.TEXT)
	bottom_left.add_child(_health_label)
	_health_bar = _bar(UiTheme.GOOD)
	_health_bar.custom_minimum_size = Vector2(260, 14)
	bottom_left.add_child(_health_bar)

	var bottom_right := VBoxContainer.new()
	bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bottom_right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_right.position = Vector2(-20, -20)
	root.add_child(bottom_right)
	_carry = UiTheme.label("", 18, UiTheme.MONEY)
	_carry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_carry)
	_ammo = UiTheme.label("", 24, UiTheme.TEXT)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_ammo)

	var crosshair := UiTheme.label("+", 24, Color(1, 1, 1, 0.8))
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(crosshair)

	var prompt_box := VBoxContainer.new()
	prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_box.position.y = -170
	prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(prompt_box)
	_prompt = UiTheme.label("", 22, UiTheme.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_box.add_child(_prompt)
	_hold_bar = _bar(UiTheme.WARN)
	_hold_bar.custom_minimum_size = Vector2(240, 10)
	_hold_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prompt_box.add_child(_hold_bar)
	_hint = UiTheme.label("", 20, UiTheme.WARN)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_box.add_child(_hint)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_toasts.position = Vector2(20, -40)
	root.add_child(_toasts)

	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.position.y = 110
	_banner.visible = false
	root.add_child(_banner)
	_banner_title = UiTheme.label("", 52, UiTheme.TEXT)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_text = UiTheme.label("", 22, UiTheme.TEXT)
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_text)

	_pause = _build_pause(root)

	GameState.message_received.connect(_toast)
	GameState.banner_received.connect(_show_banner)


func _overlay(root: Control, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = color.a > 0.0
	root.add_child(rect)
	return rect


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("background", background)
	return bar


func _build_pause(root: Control) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL))
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := UiTheme.label("PAUSED", 32, UiTheme.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note := UiTheme.label("The game keeps running for your crew.", 14, UiTheme.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	box.add_child(UiTheme.button("Resume", func() -> void: _set_paused(false)))
	box.add_child(UiTheme.button("Leave game", func() -> void: (get_tree().current_scene as Main).leave_game("")))
	box.add_child(UiTheme.button("Quit to desktop", func() -> void: get_tree().quit()))
	return shade


# --- Input ------------------------------------------------------------------------

## True while a panel or the pause menu has the mouse, so the player ignores game controls.
func captures_input() -> bool:
	return _panel != null or _pause.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _panel != null:
			close_panel()
		else:
			_set_paused(not _pause.visible)
	elif event is InputEventMouseButton and event.is_pressed() and not captures_input():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_paused(paused: bool) -> void:
	_pause.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func open_panel(ui: String) -> void:
	close_panel()
	var panel: Control
	match ui:
		"armory", "workshop", "tailor":
			panel = ShopPanel.new(ui)
		"slots", "roulette":
			panel = CasinoPanel.new(ui)
		_:
			assert(false, "Unknown panel '%s'" % ui)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	add_child(center)
	_panel = center
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_ui(self, "click")


func close_panel() -> void:
	if _panel == null:
		return
	_panel.queue_free()
	_panel = null
	if not _pause.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Messages ---------------------------------------------------------------------

func set_focus(text: String, allowed: bool, progress: float) -> void:
	_prompt.visible = text != ""
	_prompt.text = "[E] " + text if allowed else text
	_prompt.add_theme_color_override("font_color", UiTheme.TEXT if allowed else UiTheme.MUTED)
	_hold_bar.visible = progress > 0.0
	_hold_bar.value = progress


func flash_hint(text: String) -> void:
	_hint.text = text
	_hint_time = 2.0


func flash_damage() -> void:
	_damage.color.a = 0.35
	_damage.visible = true


func _toast(text: String, color: Color) -> void:
	var label := UiTheme.label(text, 18, color)
	_toasts.add_child(label)
	while _toasts.get_child_count() > MAX_TOASTS:
		_toasts.get_child(0).free()
	var tween := label.create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
	Sfx.play_ui(self, "notify")


func _show_banner(title: String, text: String, color: Color) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_text.text = text
	_banner.visible = true
	_banner_time = 4.0


# --- Every frame --------------------------------------------------------------------

func _process(delta: float) -> void:
	_hint_time = maxf(0.0, _hint_time - delta)
	_hint.visible = _hint_time > 0.0
	_banner_time = maxf(0.0, _banner_time - delta)
	_banner.visible = _banner_time > 0.0
	_damage.color.a = maxf(0.0, _damage.color.a - delta)
	_damage.visible = _damage.color.a > 0.0
	if GameState.state.is_empty():
		return
	_draw_crew()
	var player: Player = GameState.world.local_player()
	if player != null:
		_draw_player(player)


func _draw_crew() -> void:
	_cash.text = UiTheme.money(GameState.cash())
	var stars: int = GameState.wanted()
	_stars.count = stars
	_evade.visible = stars > 0
	_evade.value = float(GameState.state["evade"]) / Catalog.EVADE_TIME
	var lines := PackedStringArray()
	var bank: Dictionary = GameState.state["bank"]
	var closed: int = bank["closed"]
	var bank_line: String = "First National - security level %d" % bank["level"]
	if closed > 0:
		bank_line += " - CLOSED " + UiTheme.clock(closed)
	elif bank["alarm"]:
		bank_line += " - ALARM"
	if bank["drill"] == "running" or bank["drill"] == "jammed":
		bank_line += " - drill %d%%%s" % [int(float(bank["drill_progress"]) * 100.0), " JAMMED" if bank["drill"] == "jammed" else ""]
	lines.append(bank_line)
	var cooldowns: Dictionary = GameState.state["cooldowns"]
	if cooldowns.has("police"):
		lines.append("Cops arrive in %ds" % cooldowns["police"])
	var quests: Dictionary = GameState.state["quests"]
	for quest: String in quests:
		var progress: Dictionary = quests[quest]
		var line: String = "%s - stop %d of %d" % [Catalog.QUESTS[quest]["title"], int(progress["stage"]) + 1, Layout.quest_route(quest).size()]
		if progress["time"] > 0:
			line += " - %ds" % progress["time"]
		lines.append(line)
	_status.text = "\n".join(lines)


func _draw_player(player: Player) -> void:
	_health_bar.value = float(player.health) / player.max_health
	_health_label.text = "%s  %d / %d" % [player.display_name, player.health, player.max_health]
	var weapon_name: String = Catalog.WEAPONS[player.weapon]["name"]
	_ammo.text = "%s  %s" % [weapon_name, "RELOADING" if player.reloading() else "%d / %d" % [player.ammo_left(), Catalog.WEAPONS[player.weapon]["mag"]]]
	var lines := PackedStringArray()
	lines.append("MASK ON" if player.masked else "Mask off (F)")
	if player.carrying != "":
		lines.append("Carrying %s - G to throw" % player.carrying)
	_carry.text = "\n".join(lines)
	_carry.add_theme_color_override("font_color", UiTheme.BAD if player.masked else UiTheme.MUTED)
	_downed.visible = player.downed
	_downed_label.text = "YOU'RE DOWN\nA crewmate can hold E on you to revive you - %ds" % player.bleed
