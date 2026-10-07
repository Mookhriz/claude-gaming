class_name Catalog
extends RefCounted
## Every price, stat, odd and unlock. Balance changes happen here and nowhere else.

# --- Crew ---------------------------------------------------------------------

const START_CASH: int = 1000
## Ids the crew owns from the start: the free weapon and the free look in each slot.
const STARTING_UNLOCKS: Array = ["pistol", "classic", "street", "none"]
## Share of crew cash lost when the crew gets busted.
const BAIL_RATE: float = 0.15

# --- Players ------------------------------------------------------------------

const WALK_SPEED: float = 4.5
const SPRINT_SPEED: float = 7.5
const JUMP_VELOCITY: float = 4.8
const MOUSE_SENSITIVITY: float = 0.0025
const INTERACT_RANGE: float = 2.4
## Fraction of speed lost while carrying each kind of bag (before the duffel upgrade).
const CARRY_PENALTY: Dictionary = {"cash": 0.2, "gold": 0.4}
const THROW_SPEED: float = 8.0

# --- Health and revives ------------------------------------------------------

const BLEED_OUT_TIME: int = 30
const REVIVE_TIME: float = 3.0
const REVIVE_HEALTH: int = 40

# --- Weapons ------------------------------------------------------------------

const WEAPON_ORDER: Array = ["pistol", "smg", "shotgun", "rifle"]
const WEAPONS: Dictionary = {
	"pistol": {"name": "Pistol", "price": 0, "damage": 25, "interval": 0.3, "mag": 12, "reload": 1.2, "pellets": 1, "spread": 0.01, "range": 60.0, "auto": false},
	"smg": {"name": "SMG", "price": 2500, "damage": 14, "interval": 0.08, "mag": 30, "reload": 1.8, "pellets": 1, "spread": 0.035, "range": 45.0, "auto": true},
	"shotgun": {"name": "Shotgun", "price": 4000, "damage": 12, "interval": 0.8, "mag": 6, "reload": 2.4, "pellets": 8, "spread": 0.08, "range": 25.0, "auto": false},
	"rifle": {"name": "Rifle", "price": 7500, "damage": 34, "interval": 0.13, "mag": 25, "reload": 2.0, "pellets": 1, "spread": 0.015, "range": 80.0, "auto": true},
}

# --- Upgrades (Fixit Fred's) --------------------------------------------------
# "values" holds the effect at each level, starting at level 0. "prices" holds the cost of each next level.

const UPGRADE_ORDER: Array = ["armor", "drill", "lockpick", "hacker_kit", "sneakers", "duffel"]
const UPGRADES: Dictionary = {
	"armor": {"name": "Kevlar Vest", "desc": "Max health for the whole crew", "prices": [1500, 3500, 7000], "values": [100, 130, 165, 200]},
	"drill": {"name": "Diamond Bit", "desc": "The vault drill runs faster", "prices": [2000, 5000], "values": [1.0, 1.4, 1.9]},
	"lockpick": {"name": "Pro Picks", "desc": "Pick locks faster", "prices": [800, 2000], "values": [1.0, 0.7, 0.45]},
	"hacker_kit": {"name": "Hacker Kit", "desc": "Skim cash from ATMs", "prices": [3000], "values": [0, 1]},
	"sneakers": {"name": "Getaway Sneakers", "desc": "Sprint faster", "prices": [1200, 3000], "values": [1.0, 1.12, 1.25]},
	"duffel": {"name": "Reinforced Duffel", "desc": "Bags slow you down less", "prices": [1500, 4000], "values": [1.0, 0.6, 0.3]},
}

# --- Looks (Drip Lord) --------------------------------------------------------

const LOOK_SLOTS: Array = ["mask", "outfit", "hat"]
const MASKS: Dictionary = {
	"classic": {"name": "Classic", "price": 0, "color": Color(0.92, 0.92, 0.88)},
	"clown": {"name": "Clown", "price": 600, "color": Color(0.95, 0.95, 0.95)},
	"skull": {"name": "Skull", "price": 900, "color": Color(0.85, 0.82, 0.7)},
	"pig": {"name": "Pig", "price": 1200, "color": Color(0.96, 0.6, 0.7)},
}
const OUTFITS: Dictionary = {
	"street": {"name": "Street", "price": 0, "color": Color(0.3, 0.38, 0.5)},
	"tracksuit": {"name": "Tracksuit", "price": 500, "color": Color(0.15, 0.6, 0.3)},
	"suit": {"name": "Sharp Suit", "price": 1500, "color": Color(0.1, 0.1, 0.12)},
	"hazmat": {"name": "Hazmat", "price": 2500, "color": Color(0.95, 0.8, 0.1)},
}
const HATS: Dictionary = {
	"none": {"name": "No hat", "price": 0, "color": Color(0, 0, 0)},
	"beanie": {"name": "Beanie", "price": 300, "color": Color(0.75, 0.2, 0.2)},
	"cowboy": {"name": "Cowboy", "price": 800, "color": Color(0.5, 0.33, 0.18)},
	"crown": {"name": "Crown", "price": 4000, "color": Color(1.0, 0.82, 0.2)},
}

# --- First National -----------------------------------------------------------
# Arrays indexed by security level 1-5; index 0 is unused.

const BANK_MAX_LEVEL: int = 5
const BANK_GUARDS: Array = [0, 2, 3, 4, 5, 6]
const BANK_CASH_PILES: Array = [0, 3, 4, 4, 5, 5]
const BANK_GOLD_PILES: Array = [0, 0, 1, 2, 2, 3]
const BAG_VALUE: Dictionary = {
	"cash": [0, 1500, 1900, 2400, 3000, 3800],
	"gold": [0, 4000, 4800, 5800, 7000, 8500],
}
const DRILL_TIME: Array = [0, 40, 50, 60, 70, 80]
## Chance per second that a running drill jams.
const DRILL_JAM_CHANCE: Array = [0.0, 0.03, 0.04, 0.05, 0.06, 0.07]
const LOCKPICK_TIME: float = 3.0
const DRILL_PLACE_TIME: float = 1.0
const DRILL_FIX_TIME: float = 2.5
const BAG_TIME: float = 1.5
const BANK_CLOSED_TIME: int = 120
const BANK_ALARM_STARS: int = 3

# --- Police -------------------------------------------------------------------

const MAX_STARS: int = 5
const POLICE_RESPONSE_TIME: int = 15
const COPS_BY_STARS: Array = [0, 2, 3, 4, 6, 8]
## Seconds nobody may be seen by a cop or guard before one star drops.
const EVADE_TIME: int = 10
const BRIBE_PER_STAR: int = 500

# --- NPCs ---------------------------------------------------------------------

const NPC_HEALTH: Dictionary = {"civilian": 30, "guard": 60, "cop": 80}
const NPC_SPEED: Dictionary = {"civilian": 1.5, "guard": 3.5, "cop": 4.2}
const NPC_DAMAGE: Dictionary = {"guard": 7, "cop": 9}
const NPC_FIRE_INTERVAL: Dictionary = {"guard": 1.1, "cop": 0.9}
const NPC_SIGHT_RANGE: float = 24.0
const NPC_FOV_DEGREES: float = 120.0
const NPC_SHOOT_RANGE: float = 20.0
## Hit chance at point blank and at NPC_SHOOT_RANGE.
const NPC_HIT_CHANCE_NEAR: float = 0.6
const NPC_HIT_CHANCE_FAR: float = 0.15
## Seconds a guard must see a mask before raising the alarm.
const GUARD_DETECT_TIME: float = 0.8
const CIVILIAN_COUNT: int = 14
const CIVILIAN_RUN_SPEED: float = 4.5
const CIVILIAN_PANIC_RADIUS: float = 25.0
const CIVILIAN_PANIC_TIME: float = 8.0
const CIVILIAN_RESPAWN_TIME: int = 20
const CIVILIAN_KILL_STARS: int = 1

# --- Street jobs --------------------------------------------------------------

const STORE_PAYOUT: int = 900
const STORE_STARS: int = 2
const STORE_COOLDOWN: int = 120
const STORE_TIME: float = 2.5
const ATM_PAYOUT: int = 500
const ATM_STARS: int = 1
const ATM_COOLDOWN: int = 180
const ATM_TIME: float = 4.0

# --- Side quests --------------------------------------------------------------
# time_limit 0 means no time limit.

const QUEST_STOP_RADIUS: float = 3.0
const QUESTS: Dictionary = {
	"pizza": {"giver": "Tony", "title": "Pizza delivery", "brief": "Get this pie to the blue house before it goes cold!", "reward": 450, "time_limit": 45, "cooldown": 60},
	"cat": {"giver": "Granny Mabel", "title": "Find Biscuit", "brief": "My cat Biscuit ran off toward the park. Bring him home, dear.", "reward": 700, "time_limit": 0, "cooldown": 120},
	"courier": {"giver": "Zippy", "title": "Courier run", "brief": "Three drops. Don't open the package. Clock's ticking.", "reward": 1100, "time_limit": 100, "cooldown": 90},
}

# --- The Lucky Rat (play money only) -------------------------------------------

const BET_STEPS: Array = [10, 25, 50, 100, 250, 500, 1000]
## Slots: three reels drawn with these weights. Return to player is about 94.5%.
const SLOT_SYMBOLS: Array = ["CHERRY", "LEMON", "BELL", "BAR", "SEVEN"]
const SLOT_WEIGHTS: Array = [5, 5, 4, 3, 2]
## Total return as a multiple of the bet for three of a kind.
const SLOT_TRIPLE_PAYS: Dictionary = {"CHERRY": 5, "LEMON": 8, "BELL": 12, "BAR": 20, "SEVEN": 50}
## Total return for exactly two cherries.
const SLOT_TWO_CHERRIES_PAYS: int = 3
## Roulette: single zero wheel, 0-36. Return to player is 36/37, about 97.3%.
const ROULETTE_REDS: Array = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const ROULETTE_OUTSIDE_PAYS: int = 2
const ROULETTE_NUMBER_PAYS: int = 36


static func look_table(slot: String) -> Dictionary:
	match slot:
		"mask":
			return MASKS
		"outfit":
			return OUTFITS
		"hat":
			return HATS
	assert(false, "Unknown look slot '%s'" % slot)
	return {}


## The slot an id belongs to, or "" when the id isn't a look.
static func look_slot(id: String) -> String:
	for slot: String in LOOK_SLOTS:
		if look_table(slot).has(id):
			return slot
	return ""


static func assert_look(look: Dictionary) -> void:
	assert(look.size() == LOOK_SLOTS.size(), "A look needs exactly %s, got %s" % [LOOK_SLOTS, look])
	for slot: String in LOOK_SLOTS:
		assert(look.has(slot), "Look is missing '%s': %s" % [slot, look])
		assert(look_table(slot).has(look[slot]), "Unknown %s '%s'" % [slot, look[slot]])


static func max_upgrade_level(key: String) -> int:
	var prices: Array = UPGRADES[key]["prices"]
	return prices.size()
