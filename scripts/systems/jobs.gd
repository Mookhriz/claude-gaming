class_name Jobs
extends Node
## Host only. Street jobs: robbing Grab-N-Dash and skimming ATMs with the hacker kit.


func _ready() -> void:
	GameState.register_interact("store", _rob_store)
	for id: String in Layout.ids_with_prefix("atm_"):
		GameState.register_interact(id, _skim_atm.bind(id))


func _rob_store(peer: int) -> void:
	_payout(peer, "store", Catalog.STORE_PAYOUT, Catalog.STORE_COOLDOWN, Catalog.STORE_STARS)


func _skim_atm(peer: int, id: String) -> void:
	_payout(peer, id, Catalog.ATM_PAYOUT, Catalog.ATM_COOLDOWN, Catalog.ATM_STARS)


func _payout(peer: int, id: String, amount: int, cooldown: int, stars: int) -> void:
	GameState.state["cash"] = GameState.cash() + amount
	var cooldowns: Dictionary = GameState.state["cooldowns"]
	cooldowns[id] = cooldown
	GameState.mark_dirty()
	GameState.notify(peer, "+%s" % UiTheme.money(amount), UiTheme.MONEY)
	var pos: Vector3 = Layout.interactable_pos(id)
	GameState.fx("sound", ["cash", pos], 0)
	GameState.world.police.add_stars(stars, pos)
	GameState.world.crowd.panic(pos)
