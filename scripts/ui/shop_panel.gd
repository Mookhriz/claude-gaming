class_name ShopPanel
extends PanelContainer
## Pew Pew Pawn (armory), Fixit Fred's (workshop) and Drip Lord (tailor).
## Buying goes through requests and belongs to the crew. Wearing a look is this player's choice, saved on this machine.

const TITLES: Dictionary = {
	"armory": "PEW PEW PAWN",
	"workshop": "FIXIT FRED'S",
	"tailor": "DRIP LORD",
}

var _ui: String = ""
var _cash: Label = null
var _list: VBoxContainer = null
var _shown: String = ""


func _init(ui: String) -> void:
	assert(TITLES.has(ui), "Unknown shop '%s'" % ui)
	_ui = ui


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL))
	custom_minimum_size = Vector2(620, 500)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UiTheme.label(TITLES[_ui], 32, UiTheme.TEXT))
	_cash = UiTheme.label("", 20, UiTheme.MONEY)
	box.add_child(_cash)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	box.add_child(UiTheme.button("Close (Esc)", func() -> void: GameState.world.hud.close_panel()))
	GameState.state_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	var profile: Dictionary = Save.load_profile()
	var signature: String = str([GameState.cash(), GameState.state["unlocks"], GameState.state["upgrades"], Save.look_of(profile)])
	if signature == _shown:
		return
	_shown = signature
	_cash.text = "Crew cash: %s" % UiTheme.money(GameState.cash())
	for child: Node in _list.get_children():
		child.free()
	match _ui:
		"armory":
			_weapons()
		"workshop":
			_upgrades()
		"tailor":
			_looks(profile)


func _weapons() -> void:
	for i: int in range(Catalog.WEAPON_ORDER.size()):
		var id: String = Catalog.WEAPON_ORDER[i]
		var def: Dictionary = Catalog.WEAPONS[id]
		var text: String = "[%d] %s - %d damage x%d, %d rounds" % [i + 1, def["name"], def["damage"], def["pellets"], def["mag"]]
		if GameState.owns(id):
			_row(text, _tag("Owned"))
		else:
			_row(text, _buy_button(def["price"], func() -> void: GameState.request("buy_weapon", [id])))


func _upgrades() -> void:
	for key: String in Catalog.UPGRADE_ORDER:
		var def: Dictionary = Catalog.UPGRADES[key]
		var level: int = GameState.upgrade_level(key)
		var top: int = Catalog.max_upgrade_level(key)
		var text: String = "%s (%d/%d) - %s" % [def["name"], level, top, def["desc"]]
		if level >= top:
			_row(text, _tag("Maxed"))
		else:
			var price: int = def["prices"][level]
			_row(text, _buy_button(price, func() -> void: GameState.request("buy_upgrade", [key])))


func _looks(profile: Dictionary) -> void:
	for slot: String in Catalog.LOOK_SLOTS:
		_list.add_child(UiTheme.label(slot.to_upper() + "S", 18, UiTheme.MUTED))
		var table: Dictionary = Catalog.look_table(slot)
		for id: String in table:
			var def: Dictionary = table[id]
			var text: String = def["name"]
			if profile[slot] == id:
				_row(text, _tag("Wearing"))
			elif GameState.owns(id):
				_row(text, UiTheme.button("Wear", func() -> void: _wear(slot, id)))
			else:
				_row(text, _buy_button(def["price"], func() -> void: GameState.request("buy_look", [id])))


func _wear(slot: String, id: String) -> void:
	var profile: Dictionary = Save.load_profile()
	profile[slot] = id
	Save.save_profile(profile)
	GameState.request("set_look", [Save.look_of(profile)])
	Sfx.play_ui(self, "click")
	_rebuild()


func _row(text: String, action: Control) -> void:
	var row := HBoxContainer.new()
	var label := UiTheme.label(text, 18, UiTheme.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	action.custom_minimum_size.x = 140
	row.add_child(action)
	_list.add_child(row)


func _tag(text: String) -> Label:
	var label := UiTheme.label(text, 18, UiTheme.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _buy_button(price: int, on_press: Callable) -> Button:
	var button := UiTheme.button("Buy " + UiTheme.money(price), on_press)
	button.disabled = GameState.cash() < price
	return button
