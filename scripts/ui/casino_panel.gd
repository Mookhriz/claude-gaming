class_name CasinoPanel
extends PanelContainer
## The Lucky Rat's slots and roulette tables. Play money only: bets and winnings are crew cash.

const OUTSIDE_BETS: Array = [["Red", "red"], ["Black", "black"], ["Odd", "odd"], ["Even", "even"], ["1-18", "low"], ["19-36", "high"]]

var _game: String = ""
var _bet_index: int = 2
var _waiting: bool = false
var _cash: Label = null
var _bet: Label = null
var _display: Label = null
var _result: Label = null
var _number: SpinBox = null
var _buttons: Array[Button] = []


func _init(game: String) -> void:
	assert(game == "slots" or game == "roulette", "Unknown casino game '%s'" % game)
	_game = game


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL))
	custom_minimum_size = Vector2(560, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(UiTheme.label("THE LUCKY RAT - %s" % _game.to_upper(), 30, UiTheme.TEXT))
	box.add_child(UiTheme.label("Play money only.", 14, UiTheme.MUTED))
	_cash = UiTheme.label("", 20, UiTheme.MONEY)
	box.add_child(_cash)

	var bet_row := HBoxContainer.new()
	bet_row.add_child(UiTheme.label("Bet", 20, UiTheme.TEXT))
	bet_row.add_child(UiTheme.button(" - ", func() -> void: _change_bet(-1)))
	_bet = UiTheme.label("", 22, UiTheme.WARN)
	_bet.custom_minimum_size.x = 100
	_bet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet_row.add_child(_bet)
	bet_row.add_child(UiTheme.button(" + ", func() -> void: _change_bet(1)))
	box.add_child(bet_row)

	_display = UiTheme.label("", 34, UiTheme.TEXT)
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_display)
	if _game == "slots":
		_display.text = "? | ? | ?"
		_add_button(box, "SPIN", func() -> void: _play("slots_spin", []))
		box.add_child(UiTheme.label("3 of a kind pays 5x to 50x. Two cherries pay 3x.", 14, UiTheme.MUTED))
	else:
		_display.text = "Place a bet"
		var grid := GridContainer.new()
		grid.columns = 3
		box.add_child(grid)
		for bet: Array in OUTSIDE_BETS:
			var choice: String = bet[1]
			_add_button(grid, bet[0], func() -> void: _play("roulette_spin", [choice]))
		var number_row := HBoxContainer.new()
		_number = SpinBox.new()
		_number.min_value = 0
		_number.max_value = 36
		number_row.add_child(_number)
		_add_button(number_row, "Bet on number", func() -> void: _play("roulette_spin", [str(int(_number.value))]))
		box.add_child(number_row)
		box.add_child(UiTheme.label("Outside bets pay 2x. A single number pays 36x.", 14, UiTheme.MUTED))

	_result = UiTheme.label("", 20, UiTheme.TEXT)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result)
	box.add_child(UiTheme.button("Close (Esc)", func() -> void: GameState.world.hud.close_panel()))
	GameState.state_changed.connect(_refresh)
	GameState.casino_result.connect(_on_result)
	_refresh()


func _add_button(parent: Control, text: String, on_press: Callable) -> void:
	var button := UiTheme.button(text, on_press)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	_buttons.append(button)


func _bet_amount() -> int:
	return Catalog.BET_STEPS[_bet_index]


func _change_bet(step: int) -> void:
	_bet_index = clampi(_bet_index + step, 0, Catalog.BET_STEPS.size() - 1)
	Sfx.play_ui(self, "click")
	_refresh()


func _refresh() -> void:
	_cash.text = "Crew cash: %s" % UiTheme.money(GameState.cash())
	_bet.text = UiTheme.money(_bet_amount())
	for button: Button in _buttons:
		button.disabled = _waiting or GameState.cash() < _bet_amount()


func _play(action: String, extra: Array) -> void:
	_waiting = true
	_result.text = ""
	Sfx.play_ui(self, "spin")
	GameState.request(action, [_bet_amount()] + extra)
	_refresh()


func _on_result(result: Dictionary) -> void:
	_waiting = false
	if result["game"] == "refused":
		_refresh()
		return
	match result["game"]:
		"slots":
			var reels: Array = result["reels"]
			_display.text = " | ".join(PackedStringArray(reels))
		"roulette":
			_display.text = "%d %s" % [result["number"], String(result["color"]).to_upper()]
	var payout: int = result["payout"]
	var bet: int = result["bet"]
	if payout > 0:
		_result.text = "You win %s!" % UiTheme.money(payout)
		_result.add_theme_color_override("font_color", UiTheme.MONEY)
		Sfx.play_ui(self, "win")
	else:
		_result.text = "You lose %s" % UiTheme.money(bet)
		_result.add_theme_color_override("font_color", UiTheme.BAD)
		Sfx.play_ui(self, "lose")
	_refresh()
