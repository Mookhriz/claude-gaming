extends Node
## Headless smoke driver. Run: godot --headless --path . res://tests/smoke.tscn -- <scenario>

var main: Main = null
var failures: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() >= 1, "Pass a scenario after --")
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	match args[0]:
		"host_idle":
			await host_idle()
		"host_full":
			await host_full()
		"host_pair":
			await host_pair()
		"join_pair":
			await join_pair()
		"host_busy":
			await host_busy()
		"shots":
			await shots(args[1])
		"host_controls":
			await host_controls()
		"join_watch":
			await join_watch()
	print("SMOKE DONE: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func wait_until(condition: Callable, seconds: float) -> bool:
	var deadline: float = Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func host_idle() -> void:
	main._menu.host_requested.emit()
	var started: float = Time.get_ticks_msec()
	check(await wait_until(func() -> bool: return GameState.world != null and GameState.world.local_player() != null, 10.0), "host spawns the town and the host's player")
	print("  world ready after %d ms" % (Time.get_ticks_msec() - started))
	var world: World = GameState.world
	var player: Player = world.local_player()
	print("  player at ", player.global_position)
	check(world.npcs("civilian").size() == Catalog.CIVILIAN_COUNT, "civilians spawned: %d" % world.npcs("civilian").size())
	check(world.npcs("guard").size() == 2, "level 1 guards spawned: %d" % world.npcs("guard").size())
	var before: Vector3 = world.npcs("civilian")[0].global_position
	await wait(4.0)
	var after: Vector3 = world.npcs("civilian")[0].global_position
	check(before.distance_to(after) > 1.0, "a civilian walked %.1f m in 4 s" % before.distance_to(after))
	check(player.is_on_floor(), "the host's player stands on the ground at %s" % player.global_position)


# --- Host alone: the whole loop -------------------------------------------------------

var god_mode: bool = false


func _process(_delta: float) -> void:
	if god_mode and GameState.world != null:
		var me: Player = GameState.world.local_player()
		if me != null and me.health < me.max_health:
			me.health = me.max_health


func bank() -> Dictionary:
	return GameState.state["bank"]


func act(action: String, args: Array) -> void:
	GameState.request(action, args)
	await get_tree().physics_frame
	await get_tree().physics_frame


func host_full() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.CREW_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.PROFILE_PATH))
	GameState.message_received.connect(func(text: String, _c: Color) -> void: print("  toast: ", text))
	GameState.banner_received.connect(func(title: String, text: String, _c: Color) -> void: print("  banner: ", title, " / ", text))
	main._menu._name.text = "Robber"
	main._menu.host_requested.emit()
	await wait_until(func() -> bool: return GameState.world != null and GameState.world.local_player() != null, 10.0)
	var world: World = GameState.world
	var me: Player = world.local_player()
	check(GameState.cash() == Catalog.START_CASH, "fresh crew starts with %s" % UiTheme.money(GameState.cash()))

	# Scout unmasked in the lobby, in a guard's view.
	me.place(Vector3(-8, 0.05, -12))
	await wait(2.0)
	check(not bank()["alarm"], "scouting the lobby unmasked doesn't alarm the guards")

	# Staff door.
	me.place(Vector3(10, 0.05, -1.6))
	await act("set_mask", [true])
	check(me.masked, "F puts the mask on")
	var rule: Dictionary = Interactions.describe("staff_door", me)
	check(rule["allowed"] and rule["hold"] > 0.0, "staff door prompt: '%s', hold %.1fs" % [rule["text"], rule["hold"]])
	await act("interact", ["staff_door"])
	check(bank()["staff_door"], "picking the lock opens the staff door")
	await wait(1.5)
	check(not bank()["alarm"], "the lock can be picked without being seen at level 1")

	# Drill.
	me.place(Vector3(-0.4, 0.05, 9))
	await wait(0.3)
	await act("interact", ["vault_door"])
	check(bank()["drill"] == "running", "placing the drill starts it")
	check(bank()["alarm"], "the drill trips the alarm")
	check(GameState.wanted() == Catalog.BANK_ALARM_STARS, "the alarm gives %d stars" % GameState.wanted())
	check(GameState.state["cooldowns"].get("police", 0) == Catalog.POLICE_RESPONSE_TIME, "cops are %ds out" % Catalog.POLICE_RESPONSE_TIME)

	god_mode = true
	Engine.time_scale = 4.0
	var jams: int = 0
	var cops_saw_crew: bool = false
	var alarm_at: int = Time.get_ticks_msec()
	var opened: bool = false
	var deadline: float = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		if bank()["vault_open"]:
			opened = true
			break
		for cop: Npc in world.npcs("cop"):
			if cop.sees_crew and not cops_saw_crew:
				cops_saw_crew = true
				print("  a cop spotted the crew at %s, %.0f s after the alarm" % [cop.global_position.snapped(Vector3.ONE), (Time.get_ticks_msec() - alarm_at) / 1000.0 * Engine.time_scale])
		if bank()["drill"] == "jammed":
			jams += 1
			await act("interact", ["vault_door"])
			check(bank()["drill"] == "running", "holding E on the vault door fixes the jam")
		await get_tree().process_frame
	Engine.time_scale = 1.0
	check(opened, "the drill finishes and the vault opens (%d jams)" % jams)
	var cops: int = world.npcs("cop").size()
	check(cops > 0, "cops are on scene: %d" % cops)
	var nearest_cop: float = INF
	for cop: Npc in world.npcs("cop"):
		nearest_cop = minf(nearest_cop, cop.global_position.distance_to(me.global_position))
	print("  closest cop is %.0f m from the vault door; cops seen the crew: %s; wanted %d" % [nearest_cop, cops_saw_crew, GameState.wanted()])
	check(cops_saw_crew, "the cops found the crew at the vault")

	# Loot, throw, pick up, deliver.
	me.place(Vector3(-5, 0.05, 7.2))
	await wait(0.2)
	await act("interact", ["cash_pile_0"])
	check(me.carrying == "cash", "bagging a pile puts a cash bag on your back")
	check(bank()["piles"]["cash_pile_0"] == "", "the pile is gone")
	await act("throw_bag", [Vector3(1, 0.2, 0)])
	check(me.carrying == "" and world.bags().size() == 1, "G throws the bag")
	await wait(1.5)
	var thrown: LootBag = world.bags()[0]
	me.place(thrown.global_position + Vector3(-0.5, 0.05, 0))
	await wait(0.2)
	await act("pick_bag", [String(thrown.name)])
	check(me.carrying == "cash", "a thrown bag can be picked up")
	var cash_before: int = GameState.cash()
	me.place(Vector3(22.5, 0.05, -26))
	await wait(0.3)
	check(GameState.cash() == cash_before + Catalog.BAG_VALUE["cash"][1] and me.carrying == "", "carrying a bag into the van zone banks %s" % UiTheme.money(Catalog.BAG_VALUE["cash"][1]))

	me.place(Vector3(-5, 0.05, 10.8))
	await wait(0.2)
	await act("interact", ["cash_pile_1"])
	me.place(Vector3(18, 0.05, -26))
	await wait(0.2)
	cash_before = GameState.cash()
	await act("throw_bag", [Vector3(1, 0.1, 0)])
	await wait(2.0)
	check(GameState.cash() == cash_before + Catalog.BAG_VALUE["cash"][1], "a bag thrown into the van zone counts too")

	# Lose the cops by hiding in the safehouse; the bank closes.
	me.place(Layout.spawn_point(1))
	Engine.time_scale = 4.0
	await wait_until(func() -> bool: return GameState.wanted() == 0, 60.0)
	Engine.time_scale = 1.0
	check(GameState.wanted() == 0, "out of sight, the stars drop one at a time to zero")
	await wait(0.2)
	check(world.npcs("cop").is_empty(), "the cops go home")
	check(bank()["closed"] > 0 and world.npcs("guard").is_empty() and not bank()["alarm"], "once clear, the bank closes (%ds left)" % bank()["closed"])

	# Reopen one level tougher, walking out anyone behind the staff door.
	god_mode = false
	me.place(Vector3(8, 0.05, 6))
	Engine.time_scale = 8.0
	await wait_until(func() -> bool: return bank()["closed"] == 0, 30.0)
	Engine.time_scale = 1.0
	await wait(0.3)
	check(bank()["level"] == 2, "the bank reopens at security level %d" % bank()["level"])
	check(world.npcs("guard").size() == Catalog.BANK_GUARDS[2], "with %d guards" % world.npcs("guard").size())
	var stocked: Dictionary = {"cash": 0, "gold": 0, "": 0}
	for id: String in bank()["piles"]:
		stocked[bank()["piles"][id]] += 1
	check(stocked["cash"] == Catalog.BANK_CASH_PILES[2] and stocked["gold"] == Catalog.BANK_GOLD_PILES[2], "and more loot: %s" % stocked)
	check(not Layout.behind_staff_door(me.global_position) and me.global_position.distance_to(Layout.spawn_point(1)) < 1.0, "a player left behind the staff door is walked out to the safehouse")
	check(not bank()["staff_door"], "the staff door is shut again")

	# A mask in a guard's view raises the alarm in under a second or so.
	me.place(Vector3(-8, 0.05, -12))
	await wait(0.5)
	await act("set_mask", [true])
	var masked_at: int = Time.get_ticks_msec()
	await wait_until(func() -> bool: return bank()["alarm"], 3.0)
	check(bank()["alarm"], "a guard who sees a mask raises the alarm after %d ms" % (Time.get_ticks_msec() - masked_at))

	# Greasy wipes the stars for test funds; with the alarm up, the bank closes again.
	GameState.state["cash"] = 50000
	GameState.mark_dirty()
	me.place(Vector3(51.5, 0.05, 8))
	await act("set_mask", [true])
	await act("interact", ["greasy"])
	check(GameState.wanted() > 0, "Greasy won't take a bribe from a mask")
	await act("set_mask", [false])
	cash_before = GameState.cash()
	var stars: int = GameState.wanted()
	await act("interact", ["greasy"])
	check(GameState.wanted() == 0 and GameState.cash() == cash_before - stars * Catalog.BRIBE_PER_STAR, "Greasy's bribe wipes %d stars for %s" % [stars, UiTheme.money(stars * Catalog.BRIBE_PER_STAR)])
	await wait(0.2)
	check(bank()["closed"] >= Catalog.BANK_CLOSED_TIME - 1, "bribing after an alarm closes the bank too")

	# Street jobs.
	me.place(Vector3(-54.5, 0.05, -12))
	await act("set_mask", [false])
	cash_before = GameState.cash()
	await act("interact", ["store"])
	check(GameState.cash() == cash_before, "the store can't be robbed unmasked")
	await act("set_mask", [true])
	await act("interact", ["store"])
	check(GameState.cash() == cash_before + Catalog.STORE_PAYOUT and GameState.wanted() == Catalog.STORE_STARS, "robbing Grab-N-Dash pays %s and costs %d stars" % [UiTheme.money(Catalog.STORE_PAYOUT), GameState.wanted()])
	me.place(Vector3(51.5, 0.05, -8))
	cash_before = GameState.cash()
	await act("interact", ["atm_police"])
	check(GameState.cash() == cash_before, "ATMs don't pay without the hacker kit")
	await act("set_mask", [false])
	await act("buy_upgrade", ["hacker_kit"])
	check(GameState.upgrade_level("hacker_kit") == 1, "Fixit Fred sells the hacker kit")
	await act("set_mask", [true])
	cash_before = GameState.cash()
	await act("interact", ["atm_police"])
	check(GameState.cash() == cash_before + Catalog.ATM_PAYOUT, "with the kit the ATM pays %s" % UiTheme.money(Catalog.ATM_PAYOUT))

	# Shops and looks.
	await act("buy_weapon", ["smg"])
	check(not GameState.owns("smg"), "shops refuse a masked player")
	await act("set_mask", [false])
	await act("buy_weapon", ["smg"])
	check(GameState.owns("smg"), "Pew Pew Pawn sells the SMG")
	await act("set_weapon", ["smg"])
	check(me.weapon == "smg", "2 switches to the SMG")
	await act("buy_upgrade", ["armor"])
	await wait(1.2)
	check(me.max_health == Catalog.UPGRADES["armor"]["values"][1], "the armor upgrade raises max health to %d" % me.max_health)
	await act("buy_look", ["clown"])
	world.hud.open_panel("tailor")
	var tailor: ShopPanel = world.hud._panel.get_child(0)
	tailor._wear("mask", "clown")
	await wait(0.1)
	world.hud.close_panel()
	check(GameState.owns("clown") and me.look["mask"] == "clown", "Drip Lord sells the clown mask and you wear it")

	# Casino.
	var results: Array = []
	GameState.casino_result.connect(func(result: Dictionary) -> void: results.append(result))
	cash_before = GameState.cash()
	await act("slots_spin", [100])
	check(results.size() == 1 and GameState.cash() == cash_before - 100 + int(results[0]["payout"]), "slots: %s" % [results[0] if results.size() > 0 else "no result"])
	cash_before = GameState.cash()
	await act("roulette_spin", [100, "red"])
	check(results.size() == 2 and GameState.cash() == cash_before - 100 + int(results[1]["payout"]), "roulette: %s" % [results[1] if results.size() > 1 else "no result"])

	# Quests.
	me.place(Vector3(-54.5, 0.05, 14))
	await act("set_mask", [true])
	await act("interact", ["quest_pizza"])
	check(not GameState.state["quests"].has("pizza"), "Tony won't serve a mask")
	await act("set_mask", [false])
	await act("interact", ["quest_pizza"])
	check(GameState.state["quests"].has("pizza"), "Tony hands out the pizza delivery")
	cash_before = GameState.cash()
	me.place(Vector3(94, 0.05, 69))
	await wait(0.3)
	check(not GameState.state["quests"].has("pizza") and GameState.cash() == cash_before + Catalog.QUESTS["pizza"]["reward"], "delivering the pizza pays %s" % UiTheme.money(Catalog.QUESTS["pizza"]["reward"]))
	me.place(Vector3(80, 0.05, 71.5))
	await act("interact", ["quest_cat"])
	check(GameState.state["quests"].has("cat") and world._cat.visible, "Granny Mabel asks for Biscuit, who appears")
	me.place(Vector3(-26, 0.05, 106))
	await wait(0.3)
	check(GameState.state["quests"]["cat"]["stage"] == 1, "finding Biscuit")
	cash_before = GameState.cash()
	me.place(Vector3(80, 0.05, 70))
	await wait(0.3)
	check(not GameState.state["quests"].has("cat") and GameState.cash() == cash_before + Catalog.QUESTS["cat"]["reward"], "bringing Biscuit home pays")
	me.place(Vector3(-6, 0.05, 71.5))
	await act("interact", ["quest_courier"])
	for stop: Vector3 in Layout.quest_route("courier"):
		me.place(stop + Vector3(0, 0.05, 0))
		await wait(0.3)
	check(not GameState.state["quests"].has("courier"), "Zippy's courier run completes after three drops")

	# Busted: the whole crew (just the host) goes down.
	GameState.world.police.add_stars(2, me.global_position)
	cash_before = GameState.cash()
	me.place(Vector3(0, 0.05, 40))
	world.crew.damage_player(me, 1000)
	await wait(0.3)
	check(GameState.cash() == cash_before - int(cash_before * Catalog.BAIL_RATE), "busted: bail takes 15%")
	check(not me.downed and GameState.wanted() == 0 and me.global_position.distance_to(Layout.spawn_point(1)) < 1.0, "busted: back at the safehouse with no stars")

	# Save, leave, host again.
	await wait(0.3)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.CREW_PATH))
	check(int(saved["cash"]) == GameState.cash() and saved["unlocks"].has("smg"), "the crew save holds cash %s and the SMG" % UiTheme.money(int(saved["cash"])))
	var cash_saved: int = GameState.cash()
	main.leave_game("")
	await wait(0.3)
	check(GameState.world == null and main._menu.visible, "Leave game returns to the menu")
	main._menu.host_requested.emit()
	await wait_until(func() -> bool: return GameState.world != null and GameState.world.local_player() != null, 10.0)
	check(GameState.cash() == cash_saved and GameState.owns("smg") and GameState.upgrade_level("hacker_kit") == 1, "hosting again restores cash, unlocks and upgrades")
	check(GameState.world.local_player().look["mask"] == "clown", "your own look comes back from this machine")
	main.leave_game("")
	await wait(0.3)

	# A damaged save stops hosting with a clear message.
	var file := FileAccess.open(Save.CREW_PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	main._menu.host_requested.emit()
	await wait(0.3)
	check(GameState.world == null and main._menu._status.text.begins_with("The crew save is damaged"), "a damaged save stops hosting: '%s'" % main._menu._status.text)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.CREW_PATH))


# --- Two machines: host and one friend ----------------------------------------------

func _log_messages() -> void:
	GameState.message_received.connect(func(text: String, _c: Color) -> void: print("  toast: ", text))
	GameState.banner_received.connect(func(title: String, text: String, _c: Color) -> void: print("  banner: ", title, " / ", text))


func host_pair() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.CREW_PATH))
	_log_messages()
	main._menu._name.text = "Robber"
	main._menu.host_requested.emit()
	await wait_until(func() -> bool: return GameState.world != null and GameState.world.local_player() != null, 10.0)
	var world: World = GameState.world
	var me: Player = world.local_player()
	GameState.state["cash"] = 20000
	GameState.mark_dirty()
	await act("set_mask", [true])
	me.place(Vector3(-40, 0.05, 40))
	check(await wait_until(func() -> bool: return world.players().size() == 2, 30.0), "a friend joined over ENet")
	var friend: Player = null
	for player: Player in world.players():
		if player != me:
			friend = player
	print("  friend is ", friend.display_name, " peer ", friend.peer_id)
	check(await wait_until(func() -> bool: return friend.masked, 30.0), "the host sees the friend mask up")
	check(await wait_until(func() -> bool: return friend.global_position.distance_to(me.global_position) < 3.0, 90.0), "the friend walked over to the host")
	world.crew.damage_player(me, 1000)
	check(me.downed, "the host goes down")
	check(await wait_until(func() -> bool: return not me.downed, 20.0), "the friend revived the host")
	var cash_before: int = GameState.cash()
	world.spawn_bag("cash", friend.global_position + Vector3(1, 1, 0), Vector3.ZERO)
	check(await wait_until(func() -> bool: return GameState.cash() >= cash_before + Catalog.BAG_VALUE["cash"][1], 40.0), "the friend picked up, threw and delivered a bag")
	me.place(Vector3(100, 0.05, 100))
	cash_before = GameState.cash()
	world.crew.damage_player(friend, 1000)
	check(friend.downed, "the friend goes down")
	check(await wait_until(func() -> bool: return not friend.downed, Catalog.BLEED_OUT_TIME + 5.0), "nobody revived the friend; they bled out")
	check(GameState.cash() == cash_before - int(cash_before * Catalog.BAIL_RATE), "bleeding out busts the crew and costs 15%")
	check(me.global_position.distance_to(Layout.spawn_point(1)) < 1.0, "the host is back at the safehouse too")
	check(await wait_until(func() -> bool: return world.players().size() == 1, 30.0), "the friend left and their player is gone")


func join_pair() -> void:
	_log_messages()
	main._menu._name.text = "Buddy"
	main._menu.join_requested.emit("127.0.0.1")
	check(await wait_until(func() -> bool: return GameState.world != null and GameState.world.local_player() != null, 20.0), "joined the host and spawned")
	var world: World = GameState.world
	var me: Player = world.local_player()
	check(world.players().size() == 2, "both players exist on the friend's machine")
	var host_player: Player = world.player(1)
	check(host_player != null and host_player.display_name == "Robber", "the host's player is here")
	check(await wait_until(func() -> bool: return host_player.masked, 10.0), "the friend sees the host's mask")
	check(await wait_until(func() -> bool: return GameState.cash() == 20000, 10.0), "the crew cash synced: %s" % UiTheme.money(GameState.cash()))
	check(world.npcs("civilian").size() == Catalog.CIVILIAN_COUNT and world.npcs("guard").size() == 2, "NPCs replicated: %d civilians, %d guards" % [world.npcs("civilian").size(), world.npcs("guard").size()])
	var civilian: Npc = world.npcs("civilian")[0]
	var seen_at: Vector3 = civilian.global_position
	await wait(2.0)
	check(civilian.global_position.distance_to(seen_at) > 0.5, "NPC movement streams to the friend")

	GameState.request("set_mask", [true])
	check(await wait_until(func() -> bool: return me.masked, 5.0), "the friend's mask goes through the host and back")
	GameState.request("set_mask", [false])
	await wait_until(func() -> bool: return not me.masked, 5.0)

	me.position = Vector3(-54.5, 0.05, 14)
	await wait(0.5)
	GameState.request("interact", ["quest_pizza"])
	check(await wait_until(func() -> bool: return GameState.state["quests"].has("pizza"), 5.0), "the friend took Tony's pizza job")
	var cash_before: int = GameState.cash()
	me.position = Vector3(94, 0.05, 69)
	check(await wait_until(func() -> bool: return GameState.cash() == cash_before + Catalog.QUESTS["pizza"]["reward"], 5.0), "the friend delivered the pizza; the crew got paid")

	var results: Array = []
	GameState.casino_result.connect(func(result: Dictionary) -> void: results.append(result))
	GameState.request("slots_spin", [50])
	check(await wait_until(func() -> bool: return results.size() == 1, 5.0), "the friend's slot spin came back: %s" % [results])
	GameState.request("buy_weapon", ["shotgun"])
	check(await wait_until(func() -> bool: return GameState.owns("shotgun"), 5.0), "the friend bought a shotgun for the crew")
	GameState.request("set_weapon", ["shotgun"])
	check(await wait_until(func() -> bool: return me.weapon == "shotgun", 5.0), "and switched to it")

	me.position = host_player.global_position + Vector3(1.2, 0, 0)
	check(await wait_until(func() -> bool: return host_player.downed, 20.0), "the friend sees the host go down")
	GameState.request("revive", [1])
	check(await wait_until(func() -> bool: return not host_player.downed, 5.0), "the friend revived the host")

	check(await wait_until(func() -> bool: return world.bags().size() == 1, 10.0), "a bag appeared next to the friend")
	var bag: LootBag = world.bags()[0]
	await wait(1.0)
	me.position = bag.global_position + Vector3(0.5, 0.05, 0)
	await wait(0.3)
	GameState.request("pick_bag", [String(bag.name)])
	check(await wait_until(func() -> bool: return me.carrying == "cash", 5.0), "the friend picked up the bag")
	GameState.request("throw_bag", [Vector3(0, 0.3, 1)])
	check(await wait_until(func() -> bool: return me.carrying == "" and world.bags().size() == 1, 5.0), "the friend threw the bag")
	await wait(1.5)
	bag = world.bags()[0]
	me.position = bag.global_position + Vector3(0.5, 0.05, 0)
	await wait(0.3)
	GameState.request("pick_bag", [String(bag.name)])
	await wait_until(func() -> bool: return me.carrying == "cash", 5.0)
	cash_before = GameState.cash()
	me.position = Vector3(-89, 0.05, 79)
	check(await wait_until(func() -> bool: return GameState.cash() == cash_before + Catalog.BAG_VALUE["cash"][1], 5.0), "the bag reached the safehouse stash; the friend sees the cash")

	check(await wait_until(func() -> bool: return me.downed, 20.0), "the friend goes down")
	check(await wait_until(func() -> bool: return me.bleed < Catalog.BLEED_OUT_TIME - 2, 10.0), "the bleed-out timer counts down on the friend's HUD: %ds" % me.bleed)
	check(await wait_until(func() -> bool: return not me.downed, Catalog.BLEED_OUT_TIME + 5.0), "busted after bleeding out")
	await wait(0.5)
	check(me.global_position.distance_to(Layout.spawn_point(me.peer_id)) < 1.5, "the host sent the friend back to the safehouse: %s" % me.global_position)
	main.leave_game("")
	await wait(0.5)
	check(GameState.world == null and main._menu.visible, "the friend left the game")


# --- Late joiners while the heist is hot ----------------------------------------------

func host_busy() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.CREW_PATH))
	main._menu.host_requested.emit()
	await wait_until(func() -> bool: return GameState.world != null and GameState.world.local_player() != null, 10.0)
	var world: World = GameState.world
	var me: Player = world.local_player()
	god_mode = true
	await wait_until(func() -> bool: return world.players().size() == 2, 30.0)
	me.place(Vector3(10, 0.05, -1.6))
	await act("set_mask", [true])
	await act("interact", ["staff_door"])
	me.place(Vector3(-0.4, 0.05, 9))
	await wait(0.2)
	await act("interact", ["vault_door"])
	check(bank()["alarm"], "the heist is on while friends join")
	check(await wait_until(func() -> bool: return world.players().size() == 3, 40.0), "a second friend joined mid-heist")
	check(await wait_until(func() -> bool: return not world.npcs("cop").is_empty(), 40.0), "cops spawned with friends connected")
	await wait(10.0)
	check(await wait_until(func() -> bool: return world.players().size() == 1, 40.0), "both friends left")


func join_watch() -> void:
	main._menu._name.text = "Late"
	main._menu.join_requested.emit("127.0.0.1")
	check(await wait_until(func() -> bool: return GameState.world != null and GameState.world.local_player() != null, 20.0), "joined and spawned")
	var world: World = GameState.world
	await wait(1.0)
	print("  sees %d players, %d npcs, alarm %s" % [world.players().size(), world.npcs("").size(), GameState.state["bank"]["alarm"]])
	check(await wait_until(func() -> bool: return not world.npcs("cop").is_empty(), 40.0), "cops replicated to this friend")
	check(GameState.state["bank"]["staff_door"] and not world._doors["staff_door"].visible, "the open staff door shows as open")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	await wait(5.0 + (float(args[1]) if args.size() > 1 else 0.0))
	main.leave_game("")
	await wait(0.5)


# --- Screenshots (needs a display: xvfb-run ... --rendering-method gl_compatibility) ----

func snap(dir: String, file: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	print("  saved ", file)


func look(me: Player, pos: Vector3, yaw_degrees: float, pitch_degrees: float) -> void:
	me.place(pos)
	me.rotation.y = deg_to_rad(yaw_degrees)
	me._pitch.rotation.x = deg_to_rad(pitch_degrees)
	await wait(0.6)


func shots(dir: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.CREW_PATH))
	await snap(dir, "01_menu.png")
	main._menu.host_requested.emit()
	await wait_until(func() -> bool: return GameState.world != null and GameState.world.local_player() != null, 10.0)
	var world: World = GameState.world
	var me: Player = world.local_player()
	god_mode = true
	await wait(1.0)
	await snap(dir, "02_safehouse.png")
	await look(me, Vector3(0, 0.05, -40), 180.0, -8.0)
	await snap(dir, "03_bank_street.png")
	await look(me, Vector3(2, 0.05, -12), 180.0, -10.0)
	await snap(dir, "04_bank_lobby.png")
	await act("set_mask", [true])
	me.place(Vector3(10, 0.05, -1.6))
	await act("interact", ["staff_door"])
	me.place(Vector3(-0.3, 0.05, 9))
	await wait(0.2)
	await act("interact", ["vault_door"])
	await look(me, Vector3(4, 0.05, 10), 90.0, -12.0)
	await wait(1.5)
	await snap(dir, "05_drill_alarm.png")
	await look(me, Vector3(-60, 0.05, -42), -45.0, -5.0)
	await snap(dir, "06_town.png")
	await act("set_mask", [false])
	await look(me, Vector3(96, 0.05, -73), 180.0, 0.0)
	world.hud.open_panel("tailor")
	await snap(dir, "07_tailor.png")
	world.hud.close_panel()
	await look(me, Vector3(8, 0.05, -78), 0.0, 0.0)
	world.hud.open_panel("roulette")
	await snap(dir, "08_roulette.png")
	world.hud.close_panel()
	await look(me, Vector3(-2, 0.05, -40), 160.0, -15.0)
	world.crew.damage_player(me, 1000)
	await wait(0.5)
	await snap(dir, "09_busted.png")


# --- The real controls, driven through Input ------------------------------------------------

## Sends a real input event, for code that reads _unhandled_input.
func key_event(action: String) -> void:
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await wait(0.1)


## Presses at the start of a frame, like real input, so just-pressed checks see it.
func tap(action: String) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await wait(0.2)


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await wait(seconds)
	Input.action_release(action)
	await wait(0.2)


func host_controls() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.CREW_PATH))
	main._menu.host_requested.emit()
	await wait_until(func() -> bool: return GameState.world != null and GameState.world.local_player() != null, 10.0)
	var world: World = GameState.world
	var me: Player = world.local_player()

	# Walk.
	me.place(Vector3(0, 0.05, 40))
	me.rotation.y = 0.0
	await wait(0.3)
	var start: Vector3 = me.global_position
	await hold("move_forward", 1.0)
	check(me.global_position.z < start.z - 3.0, "W walks forward %.1f m in 1 s" % (start.z - me.global_position.z))
	start = me.global_position
	Input.action_press("sprint")
	await hold("move_forward", 1.0)
	Input.action_release("sprint")
	check(start.z - me.global_position.z > 6.0, "Shift sprints %.1f m in 1 s" % (start.z - me.global_position.z))

	# Mask, then the hold-E lockpick through the prompt.
	await tap("mask")
	await wait(0.2)
	check(me.masked, "F masks up")
	me.place(Vector3(10, 0.05, -1.6))
	me.rotation.y = 0.0
	await wait(0.3)
	check(world.hud._prompt.visible and world.hud._prompt.text == "[E] Pick the lock", "the prompt reads '%s'" % world.hud._prompt.text)
	Input.action_press("interact")
	await wait(1.0)
	check(world.hud._hold_bar.visible and world.hud._hold_bar.value > 0.2, "holding E fills the hold bar (%.2f)" % world.hud._hold_bar.value)
	check(not bank()["staff_door"], "the lock isn't picked before the hold finishes")
	await wait(Catalog.LOCKPICK_TIME)
	Input.action_release("interact")
	await wait(0.2)
	check(bank()["staff_door"], "holding E for %.0fs picks the lock" % Catalog.LOCKPICK_TIME)

	# Shoot a guard through the crosshair.
	me.place(Vector3(0, 0.05, -10))
	me.rotation.y = 0.0
	me._pitch.rotation.x = 0.0
	await wait(0.3)
	var guard: Npc = world.npcs("guard")[0]
	var center: Vector2 = me.get_viewport().get_visible_rect().size / 2.0
	var aim: Vector3 = me._camera.project_ray_origin(center) + me._camera.project_ray_normal(center) * 9.0
	guard.position = Vector3(aim.x, 0, aim.z)
	await wait(0.3)
	var guard_health: int = guard.health
	await tap("shoot")
	check(guard.health < guard_health, "a click shot the guard under the crosshair (%d -> %d)" % [guard_health, guard.health])
	check(bank()["alarm"], "shooting a guard raises the alarm")
	check(me.ammo_left() == Catalog.WEAPONS["pistol"]["mag"] - 1, "the shot used a round: %d left" % me.ammo_left())
	await tap("reload")
	await wait(Catalog.WEAPONS["pistol"]["reload"] + 0.2)
	check(me.ammo_left() == Catalog.WEAPONS["pistol"]["mag"], "R reloads")

	# Weapons by number key.
	await tap("weapon_2")
	check(me.weapon == "pistol", "2 does nothing until the crew owns the SMG")
	GameState.state["cash"] = 50000
	GameState.mark_dirty()
	await act("set_mask", [false])
	await act("buy_weapon", ["smg"])
	await tap("weapon_2")
	check(me.weapon == "smg", "2 switches to the SMG once owned")

	# The alarmed guards shoot back.
	await act("set_mask", [true])
	var health_before: int = me.health
	me.place(Vector3(4, 0.05, -8))
	await wait_until(func() -> bool: return me.health < health_before, 15.0)
	check(me.health < health_before, "alarmed guards shoot a masked player: health %d -> %d" % [health_before, me.health])

	# Bags with G.
	me.place(Vector3(40, 0.05, 40))
	me.carrying = "gold"
	await wait(0.2)
	await tap("throw")
	check(me.carrying == "" and world.bags().size() == 1 and world.bags()[0].kind == "gold", "G throws the gold bag")
	await wait(1.5)
	var bag: LootBag = world.bags()[0]
	me.place(bag.global_position + Vector3(0.6, 0.05, 0))
	await wait(0.3)
	check(world.hud._prompt.text == "[E] Pick up the gold bag", "the bag prompt reads '%s'" % world.hud._prompt.text)
	await tap("interact")
	check(me.carrying == "gold", "E picks the bag back up")

	# Esc pauses; a panel takes Esc first.
	await key_event("pause")
	check(world.hud._pause.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc opens the pause menu")
	await key_event("pause")
	check(not world.hud._pause.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Esc again resumes")
	world.hud.open_panel("armory")
	await key_event("pause")
	check(world.hud._panel == null and not world.hud._pause.visible, "Esc closes an open shop instead of pausing")
