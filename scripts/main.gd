class_name Main
extends Node
## Boot: the input map, the menu, hosting and joining, the spawner that sends the level to every player,
## and returning to the menu.

## Keyboard actions by physical key, so WASD stays WASD on every keyboard layout.
const KEYS: Dictionary = {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"sprint": KEY_SHIFT,
	"jump": KEY_SPACE,
	"interact": KEY_E,
	"mask": KEY_F,
	"throw": KEY_G,
	"reload": KEY_R,
	"pause": KEY_ESCAPE,
	"weapon_1": KEY_1,
	"weapon_2": KEY_2,
	"weapon_3": KEY_3,
	"weapon_4": KEY_4,
}

@onready var _level: Node = $Level
@onready var _level_spawner: MultiplayerSpawner = $LevelSpawner

var _menu: Menu = null


func _ready() -> void:
	_setup_input()
	_level_spawner.spawn_function = _spawn_level
	_menu = Menu.new()
	add_child(_menu)
	_menu.host_requested.connect(_host)
	_menu.join_requested.connect(_join)
	_menu.quit_requested.connect(quit_game)
	get_tree().auto_accept_quit = false
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)
	Net.host_lost.connect(func() -> void: leave_game("The host ended the game."))


func _setup_input() -> void:
	for action: String in KEYS:
		assert(not InputMap.has_action(action), "Input action '%s' already exists" % action)
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = KEYS[action]
		InputMap.action_add_event(action, key)
	InputMap.add_action("shoot")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", click)


func _spawn_level(_data: Variant) -> Node:
	var world := World.new()
	world.name = "World"
	return world


func _remember_name() -> void:
	var profile: Dictionary = Save.load_profile()
	profile["name"] = _menu.player_name()
	Save.save_profile(profile)
	Net.local_name = _menu.player_name()


func _host() -> void:
	_remember_name()
	var problem: String = Save.crew_problem()
	if problem != "":
		_menu.show_status(problem, UiTheme.BAD)
		return
	var err: Error = Net.host()
	if err != OK:
		_menu.show_status("Couldn't host on UDP port %d: %s" % [Net.PORT, error_string(err)], UiTheme.BAD)
		return
	GameState.start_host(Save.load_state())
	_menu.hide()
	_level_spawner.spawn("town")


func _join(address: String) -> void:
	_remember_name()
	var err: Error = Net.join(address)
	if err != OK:
		_menu.show_status("Couldn't connect to %s: %s" % [address, error_string(err)], UiTheme.BAD)
		return
	_menu.show_status("Connecting to %s..." % address, UiTheme.INFO)


func _on_joined() -> void:
	_menu.hide()


func _on_join_failed() -> void:
	Net.close()
	_menu.show_status("Couldn't reach the host. Check the address, and that UDP port %d is open on their side." % Net.PORT, UiTheme.BAD)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Leaves the game before quitting. Quitting with the world still up tears it down while the network
## is open, and every connected friend gets despawns for actors they already lost with the world.
func quit_game() -> void:
	_quit.call_deferred()


func _quit() -> void:
	_leave("")
	get_tree().quit()


## Back to the menu. Deferred so it never frees the world from inside one of the world's own callbacks.
func leave_game(message: String) -> void:
	_leave.call_deferred(message)


func _leave(message: String) -> void:
	for child: Node in _level.get_children():
		_level.remove_child(child)
		child.free()
	Net.close()
	GameState.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu.show()
	_menu.show_status(message, UiTheme.INFO)
