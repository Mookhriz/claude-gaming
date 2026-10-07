class_name Shops
extends Node
## Host only. Pew Pew Pawn (weapons), Fixit Fred's (upgrades) and Drip Lord (looks).
## Everything bought belongs to the whole crew.


func _ready() -> void:
	GameState.register_action("buy_weapon", _buy_weapon)
	GameState.register_action("buy_upgrade", _buy_upgrade)
	GameState.register_action("buy_look", _buy_look)


func _buy_weapon(peer: int, id: String) -> void:
	assert(Catalog.WEAPONS.has(id), "Unknown weapon '%s'" % id)
	var def: Dictionary = Catalog.WEAPONS[id]
	if GameState.owns(id) or not _can_pay(peer, def["price"]):
		return
	_pay(def["price"])
	_unlock(id)
	_announce_purchase(peer, def["name"])


func _buy_upgrade(peer: int, key: String) -> void:
	assert(Catalog.UPGRADES.has(key), "Unknown upgrade '%s'" % key)
	var def: Dictionary = Catalog.UPGRADES[key]
	var level: int = GameState.upgrade_level(key)
	if level >= Catalog.max_upgrade_level(key):
		return
	var price: int = def["prices"][level]
	if not _can_pay(peer, price):
		return
	_pay(price)
	var upgrades: Dictionary = GameState.state["upgrades"]
	upgrades[key] = level + 1
	_announce_purchase(peer, "%s level %d" % [def["name"], level + 1])


func _buy_look(peer: int, id: String) -> void:
	var slot: String = Catalog.look_slot(id)
	assert(slot != "", "Unknown look '%s'" % id)
	var def: Dictionary = Catalog.look_table(slot)[id]
	if GameState.owns(id) or not _can_pay(peer, def["price"]):
		return
	_pay(def["price"])
	_unlock(id)
	_announce_purchase(peer, def["name"])


func _can_pay(peer: int, price: int) -> bool:
	if GameState.world.player(peer).downed:
		return false
	if GameState.world.player(peer).masked:
		GameState.notify(peer, "Shops don't serve masks", UiTheme.BAD)
		return false
	if GameState.cash() < price:
		GameState.notify(peer, "The crew can't afford that (%s)" % UiTheme.money(price), UiTheme.BAD)
		return false
	return true


func _pay(price: int) -> void:
	GameState.state["cash"] = GameState.cash() - price
	GameState.mark_dirty()


func _unlock(id: String) -> void:
	var unlocks: Array = GameState.state["unlocks"]
	unlocks.append(id)
	GameState.mark_dirty()


func _announce_purchase(peer: int, what: String) -> void:
	GameState.notify_all("%s bought %s for the crew" % [GameState.world.player(peer).display_name, what], UiTheme.MONEY)
	GameState.fx("jingle", ["buy"], 0)
