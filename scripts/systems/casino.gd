class_name Casino
extends Node
## Host only. The Lucky Rat: slots and roulette. Bets and winnings are crew cash, which is play money only.


func _ready() -> void:
	GameState.register_action("slots_spin", _slots)
	GameState.register_action("roulette_spin", _roulette)


func _bet_ok(peer: int, bet: int) -> bool:
	assert(Catalog.BET_STEPS.has(bet), "Bet %d is not one of %s" % [bet, Catalog.BET_STEPS])
	if GameState.world.player(peer).masked:
		GameState.notify(peer, "The Lucky Rat doesn't serve masks", UiTheme.BAD)
		return false
	if GameState.cash() < bet:
		GameState.notify(peer, "The crew can't cover that bet", UiTheme.BAD)
		return false
	return true


func _slots(peer: int, bet: int) -> void:
	if not _bet_ok(peer, bet):
		return
	var reels: Array = [_reel(), _reel(), _reel()]
	var payout: int = bet * slot_multiplier(reels)
	_settle(peer, bet, payout, {"game": "slots", "reels": reels, "bet": bet, "payout": payout})


func _reel() -> String:
	var total: int = 0
	for weight: int in Catalog.SLOT_WEIGHTS:
		total += weight
	var roll: int = randi_range(1, total)
	for i: int in range(Catalog.SLOT_SYMBOLS.size()):
		roll -= Catalog.SLOT_WEIGHTS[i]
		if roll <= 0:
			return Catalog.SLOT_SYMBOLS[i]
	assert(false, "Slot weights don't add up")
	return ""


## Total return as a multiple of the bet, 0 for a loss.
static func slot_multiplier(reels: Array) -> int:
	if reels[0] == reels[1] and reels[1] == reels[2]:
		return Catalog.SLOT_TRIPLE_PAYS[reels[0]]
	if reels.count("CHERRY") == 2:
		return Catalog.SLOT_TWO_CHERRIES_PAYS
	return 0


func _roulette(peer: int, bet: int, choice: String) -> void:
	if not _bet_ok(peer, bet):
		return
	var number: int = randi_range(0, 36)
	var payout: int = bet * roulette_multiplier(choice, number)
	_settle(peer, bet, payout, {"game": "roulette", "number": number, "color": roulette_color(number), "choice": choice, "bet": bet, "payout": payout})


static func roulette_color(number: int) -> String:
	if number == 0:
		return "green"
	return "red" if Catalog.ROULETTE_REDS.has(number) else "black"


## Total return as a multiple of the bet. Choices: red, black, odd, even, low, high, or a number "0"-"36".
static func roulette_multiplier(choice: String, number: int) -> int:
	var won: bool = false
	match choice:
		"red", "black":
			won = roulette_color(number) == choice
		"odd":
			won = number != 0 and number % 2 == 1
		"even":
			won = number != 0 and number % 2 == 0
		"low":
			won = number >= 1 and number <= 18
		"high":
			won = number >= 19
		_:
			assert(choice.is_valid_int() and int(choice) >= 0 and int(choice) <= 36, "Bad roulette choice '%s'" % choice)
			return Catalog.ROULETTE_NUMBER_PAYS if int(choice) == number else 0
	return Catalog.ROULETTE_OUTSIDE_PAYS if won else 0


func _settle(peer: int, bet: int, payout: int, result: Dictionary) -> void:
	GameState.state["cash"] = GameState.cash() - bet + payout
	GameState.mark_dirty()
	GameState.send_casino_result(peer, result)
