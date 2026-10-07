class_name Layout
extends RefCounted
## Every position in town. The town is 240 m across in a 3x3 grid of blocks. North is -Z.
## Rects are Rect2(x, z, width, depth) on the ground plane.

const HALF_SIZE: float = 120.0
const WALL_HEIGHT: float = 4.0
const DOOR_HEIGHT: float = 2.6
const BLOCK_CENTERS: Array = [-80.0, 0.0, 80.0]
const BLOCK_HALF: float = 34.0
## Blocks drawn as grass instead of paving, by [column, row].
const GRASS_BLOCKS: Array = [[1, 2], [2, 2]]

# Doors are [side, offset along the wall from its west or north end, width]. Sides are n, s, e, w.
const BUILDINGS: Array = [
	{"name": "Pew Pew Pawn", "rect": Rect2(-96, -90, 32, 24), "height": 6.0, "color": Color(0.55, 0.25, 0.2), "doors": [["s", 16.0, 3.0]], "sign": "PEW PEW PAWN"},
	{"name": "Lucky Rat", "rect": Rect2(-18, -96, 36, 32), "height": 8.0, "color": Color(0.4, 0.2, 0.45), "doors": [["s", 18.0, 4.0]], "sign": "LUCKY RAT CASINO"},
	{"name": "Fixit Fred's", "rect": Rect2(52, -96, 24, 26), "height": 6.0, "color": Color(0.35, 0.4, 0.45), "doors": [["s", 12.0, 3.0]], "sign": "FIXIT FRED'S"},
	{"name": "Drip Lord", "rect": Rect2(84, -96, 24, 26), "height": 6.0, "color": Color(0.85, 0.5, 0.6), "doors": [["s", 12.0, 3.0]], "sign": "DRIP LORD"},
	{"name": "Grab-N-Dash", "rect": Rect2(-76, -20, 24, 16), "height": 5.0, "color": Color(0.9, 0.55, 0.15), "doors": [["e", 8.0, 3.0]], "sign": "GRAB-N-DASH"},
	{"name": "Tony's Pizza", "rect": Rect2(-76, 6, 24, 16), "height": 5.0, "color": Color(0.7, 0.15, 0.12), "doors": [["e", 8.0, 3.0]], "sign": "TONY'S PIZZA"},
	{"name": "First National", "rect": Rect2(-18, -14, 36, 28), "height": 7.0, "color": Color(0.75, 0.72, 0.62), "doors": [["n", 18.0, 4.0]], "sign": "FIRST NATIONAL BANK"},
	{"name": "Police HQ", "rect": Rect2(56, -16, 40, 28), "height": 7.0, "color": Color(0.2, 0.27, 0.45), "doors": [["w", 14.0, 4.0]], "sign": "POLICE"},
	{"name": "Safehouse", "rect": Rect2(-96, 60, 28, 24), "height": 5.0, "color": Color(0.35, 0.3, 0.25), "doors": [["n", 14.0, 3.0]], "sign": "SAFEHOUSE"},
	{"name": "House", "rect": Rect2(60, 56, 12, 10), "height": 4.5, "color": Color(0.75, 0.7, 0.5), "doors": [["s", 6.0, 2.0]], "sign": ""},
	{"name": "Blue House", "rect": Rect2(88, 56, 12, 10), "height": 4.5, "color": Color(0.3, 0.45, 0.8), "doors": [["s", 6.0, 2.0]], "sign": ""},
	{"name": "House", "rect": Rect2(60, 92, 12, 10), "height": 4.5, "color": Color(0.8, 0.55, 0.45), "doors": [["n", 6.0, 2.0]], "sign": ""},
	{"name": "House", "rect": Rect2(88, 92, 12, 10), "height": 4.5, "color": Color(0.5, 0.7, 0.5), "doors": [["n", 6.0, 2.0]], "sign": ""},
]

# --- First National interior ----------------------------------------------------

const BANK_RECT: Rect2 = Rect2(-18, -14, 36, 28)
## Everything south of this line inside the bank is staff only.
const BANK_DIVIDER_Z: float = 0.0
# Gaps are [offset from "from", width].
const INTERIOR_WALLS: Array = [
	{"from": Vector2(-18, 0), "to": Vector2(18, 0), "gaps": [[28.0, 1.8]], "color": Color(0.65, 0.62, 0.55)},
	{"from": Vector2(-18, 4), "to": Vector2(-2, 4), "gaps": [], "color": Color(0.4, 0.42, 0.45)},
	{"from": Vector2(-2, 4), "to": Vector2(-2, 14), "gaps": [[5.0, 2.4]], "color": Color(0.4, 0.42, 0.45)},
]
## Doors that open and close with the crew state.
const DOORS: Dictionary = {
	"staff_door": {"center": Vector3(10, 1.3, 0), "size": Vector3(1.8, 2.6, 0.2), "color": Color(0.45, 0.3, 0.2)},
	"vault_door": {"center": Vector3(-2, 1.3, 9), "size": Vector3(0.5, 2.6, 2.4), "color": Color(0.55, 0.58, 0.62)},
}
const DRILL_POS: Vector3 = Vector3(-1.5, 1.0, 9)
const ALARM_LIGHT_POS: Vector3 = Vector3(0, 6, 0)
const CLOSED_SIGN_POS: Vector3 = Vector3(0, 3.6, -14.4)
## [position, yaw in degrees]. Yaw 0 faces north (-Z), 90 faces west, -90 faces east.
const GUARD_POSTS: Array = [
	[Vector3(-14, 0, -10), -30.0],
	[Vector3(14, 0, -8), 45.0],
	[Vector3(12, 0, 7), 90.0],
	[Vector3(3, 0, 12), 0.0],
	[Vector3(-10, 0, 2), -90.0],
	[Vector3(5, 0, -17), 0.0],
]

# --- Static props -------------------------------------------------------------

## Solid boxes: [center, size, color].
const PROPS: Array = [
	[Vector3(-7, 0.55, -3), Vector3(18, 1.1, 0.8), Color(0.45, 0.32, 0.2)],
	[Vector3(26, 1.2, -26), Vector3(2.4, 2.4, 5.0), Color(0.9, 0.9, 0.88)],
	[Vector3(0, 0.25, 58), Vector3(3, 0.5, 0.8), Color(0.45, 0.32, 0.2)],
	[Vector3(-14, 0.25, 92), Vector3(0.8, 0.5, 3), Color(0.45, 0.32, 0.2)],
]
const TREES: Array = [
	Vector3(-20, 0, 60), Vector3(-24, 0, 80), Vector3(20, 0, 62), Vector3(24, 0, 106),
	Vector3(-10, 0, 104), Vector3(28, 0, 80), Vector3(-30, 0, 108), Vector3(-22, 0, 100),
	Vector3(66, 0, 80), Vector3(94, 0, 80), Vector3(-40, 0, 50), Vector3(40, 0, -50),
]
const POND_CENTER: Vector3 = Vector3(10, 0, 88)
const POND_RADIUS: float = 8.0

# --- Spawns and zones ---------------------------------------------------------

const SAFEHOUSE_SPAWNS: Array = [Vector3(-86, 0.1, 66), Vector3(-82, 0.1, 66), Vector3(-78, 0.1, 66), Vector3(-74, 0.1, 66)]
## Bags that reach either zone count for the crew.
const VAN_ZONE: Rect2 = Rect2(21, -32, 10, 12)
const STASH_ZONE: Rect2 = Rect2(-94, 76, 10, 6)
const COP_SPAWNS: Array = [Vector3(50, 0, -2), Vector3(0, 0, 117), Vector3(-117, 0, 0), Vector3(117, 0, -40), Vector3(40, 0, -117)]

# --- Interactables ------------------------------------------------------------
# A non-empty "ui" opens that panel on the client. Everything else is handled on the host.

const INTERACTABLES: Dictionary = {
	"armory": {"pos": Vector3(-80, 0, -74), "ui": "armory", "label": "Pew Pew Pawn", "prop": "clerk"},
	"slots": {"pos": Vector3(-8, 0, -80), "ui": "slots", "label": "Slots", "prop": "slots"},
	"roulette": {"pos": Vector3(8, 0, -80), "ui": "roulette", "label": "Roulette", "prop": "roulette"},
	"workshop": {"pos": Vector3(64, 0, -76), "ui": "workshop", "label": "Fixit Fred's", "prop": "clerk"},
	"tailor": {"pos": Vector3(96, 0, -76), "ui": "tailor", "label": "Drip Lord", "prop": "clerk"},
	"store": {"pos": Vector3(-56, 0, -12), "ui": "", "label": "Grab-N-Dash register", "prop": "register"},
	"staff_door": {"pos": Vector3(10, 0, -0.9), "ui": "", "label": "Staff door", "prop": "none"},
	"vault_door": {"pos": Vector3(-1.0, 0, 9), "ui": "", "label": "Vault door", "prop": "none"},
	"cash_pile_0": {"pos": Vector3(-5, 0, 6), "ui": "", "label": "Loot", "prop": "none"},
	"cash_pile_1": {"pos": Vector3(-5, 0, 12), "ui": "", "label": "Loot", "prop": "none"},
	"cash_pile_2": {"pos": Vector3(-9, 0, 6), "ui": "", "label": "Loot", "prop": "none"},
	"cash_pile_3": {"pos": Vector3(-9, 0, 12), "ui": "", "label": "Loot", "prop": "none"},
	"cash_pile_4": {"pos": Vector3(-13, 0, 6), "ui": "", "label": "Loot", "prop": "none"},
	"cash_pile_5": {"pos": Vector3(-13, 0, 12), "ui": "", "label": "Loot", "prop": "none"},
	"cash_pile_6": {"pos": Vector3(-16, 0, 7.5), "ui": "", "label": "Loot", "prop": "none"},
	"cash_pile_7": {"pos": Vector3(-16, 0, 10.5), "ui": "", "label": "Loot", "prop": "none"},
	"atm_casino": {"pos": Vector3(6, 0, -61), "ui": "", "label": "ATM", "prop": "atm"},
	"atm_bank": {"pos": Vector3(-6, 0, -16), "ui": "", "label": "ATM", "prop": "atm"},
	"atm_police": {"pos": Vector3(53, 0, -8), "ui": "", "label": "ATM", "prop": "atm"},
	"greasy": {"pos": Vector3(53, 0, 8), "ui": "", "label": "Officer Greasy", "prop": "cop"},
	"quest_pizza": {"pos": Vector3(-56, 0, 14), "ui": "", "label": "Tony", "prop": "person"},
	"quest_courier": {"pos": Vector3(-6, 0, 70), "ui": "", "label": "Zippy", "prop": "person"},
	"quest_cat": {"pos": Vector3(80, 0, 70), "ui": "", "label": "Granny Mabel", "prop": "person"},
}


static func ids_with_prefix(prefix: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in INTERACTABLES:
		if id.begins_with(prefix):
			ids.append(id)
	ids.sort()
	return ids


static func interactable_pos(id: String) -> Vector3:
	assert(INTERACTABLES.has(id), "Unknown interactable '%s'" % id)
	return INTERACTABLES[id]["pos"]


static func spawn_point(peer: int) -> Vector3:
	return SAFEHOUSE_SPAWNS[peer % SAFEHOUSE_SPAWNS.size()]


static func in_bank(pos: Vector3) -> bool:
	return BANK_RECT.has_point(Vector2(pos.x, pos.z))


static func behind_staff_door(pos: Vector3) -> bool:
	return in_bank(pos) and pos.z > BANK_DIVIDER_Z


static func in_delivery_zone(pos: Vector3) -> bool:
	var flat := Vector2(pos.x, pos.z)
	return VAN_ZONE.has_point(flat) or STASH_ZONE.has_point(flat)


## Sidewalk points around every block, for civilians and searching cops.
static func walk_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var edge: float = BLOCK_HALF + 3.0
	for cx: float in BLOCK_CENTERS:
		for cz: float in BLOCK_CENTERS:
			for dx: float in [-edge, 0.0, edge]:
				for dz: float in [-edge, 0.0, edge]:
					if dx != 0.0 or dz != 0.0:
						points.append(Vector3(cx + dx, 0, cz + dz))
	return points


## The stops a side quest visits, in order, after its giver hands it out.
static func quest_route(id: String) -> Array[Vector3]:
	match id:
		"pizza":
			return [Vector3(94, 0, 69)]
		"cat":
			return [Vector3(-26, 0, 106), Vector3(80, 0, 70)]
		"courier":
			return [Vector3(-80, 0, -62), Vector3(96, 0, -66), Vector3(46, 0, 30)]
	assert(false, "No route for quest '%s'" % id)
	return []
