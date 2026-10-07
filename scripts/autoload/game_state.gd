extends Node
## The crew state. The host owns it and is the only one who writes it.
## Every change takes one path: request() -> the host runs the registered handler -> mark_dirty() -> sync to everyone, then save.

signal state_changed
signal message_received(text: String, color: Color)
signal banner_received(title: String, text: String, color: Color)
signal casino_result(result: Dictionary)
## Host only: the once-a-second clock every timer in the game runs from.
signal tick

var state: Dictionary = {}
var world: World = null

var _actions: Dictionary = {}
var _interacts: Dictionary = {}
var _dirty: bool = false
var _clock: Timer = null


func _ready() -> void:
	Net.peer_joined.connect(_on_peer_joined)


## A fresh crew. Every key the game reads exists here.
func new_state() -> Dictionary:
	var upgrades: Dictionary = {}
	for key: String in Catalog.UPGRADE_ORDER:
		upgrades[key] = 0
	var piles: Dictionary = {}
	for id: String in Layout.ids_with_prefix("cash_pile_"):
		piles[id] = ""
	return {
		"cash": Catalog.START_CASH,
		"unlocks": Catalog.STARTING_UNLOCKS.duplicate(),
		"upgrades": upgrades,
		"wanted": 0,
		"evade": 0,
		"bank": {
			"level": 1,
			"alarm": false,
			"staff_door": false,
			"drill": "none",
			"drill_progress": 0.0,
			"vault_open": false,
			"piles": piles,
			"closed": 0,
		},
		"quests": {},
		"cooldowns": {},
	}


func start_host(saved: Dictionary) -> void:
	state = new_state()
	for key: String in saved:
		state[key] = saved[key]
	_clock = Timer.new()
	_clock.wait_time = 1.0
	_clock.timeout.connect(_on_clock)
	add_child(_clock)
	_clock.start()
	register_action("interact", _interact)


func stop() -> void:
	state = {}
	world = null
	_actions.clear()
	_interacts.clear()
	_dirty = false
	if _clock != null:
		_clock.queue_free()
		_clock = null


# --- Requests -----------------------------------------------------------------

## Client side: the only way to ask for a change.
func request(action: String, args: Array) -> void:
	if multiplayer.is_server():
		_run(1, action, args)
	else:
		_request.rpc_id(1, action, args)


@rpc("any_peer", "call_remote", "reliable")
func _request(action: String, args: Array) -> void:
	assert(multiplayer.is_server(), "Requests run on the host only")
	_run(multiplayer.get_remote_sender_id(), action, args)


func _run(peer: int, action: String, args: Array) -> void:
	print(action, args)
	assert(_actions.has(action), "No handler registered for action '%s'" % action)
	var handler: Callable = _actions[action]
	assert(handler.get_argument_count() == args.size() + 1, "Action '%s' takes %d args, got %d" % [action, handler.get_argument_count() - 1, args.size()])
	handler.callv([peer] + args)


## Called by a system to own a client action. The handler gets the asking peer first, then the args.
func register_action(action: String, handler: Callable) -> void:
	assert(not _actions.has(action), "Action '%s' already has a handler" % action)
	_actions[action] = handler


## Called by a system to handle an interactable on the host. The handler gets the asking peer.
func register_interact(id: String, handler: Callable) -> void:
	assert(Layout.INTERACTABLES.has(id), "Unknown interactable '%s'" % id)
	assert(not _interacts.has(id), "Interactable '%s' already has a handler" % id)
	assert(handler.get_argument_count() == 1, "Interact handler for '%s' must take only the peer" % id)
	_interacts[id] = handler


func _interact(peer: int, id: String) -> void:
	assert(_interacts.has(id), "No handler registered for interactable '%s'" % id)
	var player: Player = world.player(peer)
	assert(player != null, "Peer %d interacted before joining the crew" % peer)
	if player.global_position.distance_to(Layout.interactable_pos(id)) > Catalog.INTERACT_RANGE + 1.0:
		return
	var rule: Dictionary = Interactions.describe(id, player)
	if not rule["allowed"]:
		notify(peer, rule["text"], UiTheme.BAD)
		return
	var handler: Callable = _interacts[id]
	handler.call(peer)


# --- Sync ---------------------------------------------------------------------

## Flags the state for the next sync: broadcast to every player, then save.
func mark_dirty() -> void:
	assert(multiplayer.is_server(), "Only the host writes the crew state")
	if _dirty:
		return
	_dirty = true
	_flush.call_deferred()


func _flush() -> void:
	if not _dirty:
		return
	_dirty = false
	_receive_state.rpc(state)
	state_changed.emit()
	Save.persist(state)


@rpc("authority", "call_remote", "reliable")
func _receive_state(synced: Dictionary) -> void:
	state = synced
	state_changed.emit()


func _on_peer_joined(peer: int) -> void:
	if multiplayer.is_server() and not state.is_empty():
		_receive_state.rpc_id(peer, state)


func _on_clock() -> void:
	var cooldowns: Dictionary = state["cooldowns"]
	if not cooldowns.is_empty():
		for key: String in cooldowns.keys():
			var left: int = cooldowns[key] - 1
			if left <= 0:
				cooldowns.erase(key)
			else:
				cooldowns[key] = left
		mark_dirty()
	tick.emit()


# --- Messages and effects -------------------------------------------------------

## Sends a message to one player's HUD.
func notify(peer: int, text: String, color: Color) -> void:
	_receive_message.rpc_id(peer, text, color)


## Sends a message to every player's HUD.
func notify_all(text: String, color: Color) -> void:
	_receive_message.rpc(text, color)


## Shows a big banner on every player's screen.
func announce(title: String, text: String, color: Color) -> void:
	_receive_banner.rpc(title, text, color)


## Plays an effect on every player's screen except skip_peer (0 skips nobody).
func fx(kind: String, args: Array, skip_peer: int) -> void:
	_receive_fx.rpc(kind, args, skip_peer)


func send_casino_result(peer: int, result: Dictionary) -> void:
	_receive_casino.rpc_id(peer, result)


@rpc("authority", "call_local", "reliable")
func _receive_message(text: String, color: Color) -> void:
	message_received.emit(text, color)


@rpc("authority", "call_local", "reliable")
func _receive_banner(title: String, text: String, color: Color) -> void:
	banner_received.emit(title, text, color)


@rpc("authority", "call_local", "unreliable")
func _receive_fx(kind: String, args: Array, skip_peer: int) -> void:
	if world == null or multiplayer.get_unique_id() == skip_peer:
		return
	world.play_fx(kind, args)


@rpc("authority", "call_local", "reliable")
func _receive_casino(result: Dictionary) -> void:
	casino_result.emit(result)


# --- Read helpers -------------------------------------------------------------

func cash() -> int:
	return state["cash"]


func wanted() -> int:
	return state["wanted"]


func owns(id: String) -> bool:
	var unlocks: Array = state["unlocks"]
	return unlocks.has(id)


func upgrade_level(key: String) -> int:
	var upgrades: Dictionary = state["upgrades"]
	assert(upgrades.has(key), "Unknown upgrade '%s'" % key)
	return upgrades[key]


func upgrade_value(key: String) -> float:
	var values: Array = Catalog.UPGRADES[key]["values"]
	return values[upgrade_level(key)]
