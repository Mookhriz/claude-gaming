# Get The Bag

A co-op bank-heist sandbox for 1–4 friends, built in Godot 4.4. Scout First National, mask up, pick the staff door, drill the vault, bag the cash and gold, and get it to the van before the cops close in. Between heists: rob Grab-N-Dash, skim ATMs, run side quests, bribe a crooked cop, gamble at the Lucky Rat, and spend the crew's money on guns, upgrades and looks.

The art is placeholder boxes and capsules. All sounds are synthesised in code.

## Running it

1. Install **Godot 4.4 or newer**, the standard build (not .NET).
2. In the project manager choose **Import**, pick `project.godot`, then press **F5**.
3. Click **Host a crew**.

**Two players on one PC:** Debug → Customize Run Instances → tick *Enable Multiple Instances*, set it to 2 and press F5. Host in one window and join `127.0.0.1` in the other.

**Friends over the internet (for now):** the host shares their IP and friends click **Join**. The host forwards **UDP port 7777**, or everyone joins a virtual LAN such as Tailscale. Steam lobbies will replace this.

**Saves:** the crew's cash, unlocks and upgrades are saved on the host in `user://crew_save.json`. Each player's name and look are saved on their own machine in `user://profile.cfg`. With Godot's default settings `user://` is:

| OS | Folder |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Get The Bag\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Get The Bag/` |
| Linux | `~/.local/share/godot/app_userdata/Get The Bag/` |

If hosting stops with "The crew save is damaged", the message names the file, line and problem.

## Controls

| Input | Action |
|---|---|
| WASD, Shift, Space | Move, sprint, jump |
| Mouse, left click | Look, shoot |
| F | Mask on or off. Weapons and crimes need it; shops, the casino and quest givers won't serve a mask. |
| E | Interact. Hold it for timed jobs: lockpicking, drilling, bagging loot, reviving. |
| G | Throw the bag you're carrying |
| 1–4, R | Switch weapon, reload |
| Esc | Pause menu (Resume, Leave game, Quit to desktop), or close a shop |

## How a run plays

| Phase | What happens |
|---|---|
| Scout | You spawn in the safehouse. Walk into First National unmasked to see where the guards stand. |
| Mask up | A guard who sees a mask for under a second (0.8 s) raises the alarm. So does gunfire inside the bank. |
| Break in | Hold E to pick the staff door, then place the drill on the vault. The drill trips the alarm and the cops arrive 15 seconds later from the nearest station. It jams now and then; hold E on the vault door to fix it. |
| Loot | When the vault opens, bag the cash and gold. Carrying slows you down, so throw bags to crewmates. Bags that reach the green zone by the getaway van, or the safehouse stash, count for the whole crew. |
| Escape | Stars drop one at a time while no cop or alarmed guard can see anyone. The meter only runs once the cops have arrived. |
| Escalate | Once you're clear, the bank closes for 2 minutes and reopens one security level tougher, up to level 5: more guards, more loot, gold. Anyone still behind the staff door is walked out. |
| Down or busted | A crewmate revives a downed player by holding E on them. If nobody comes within 30 seconds, or the whole crew goes down, you're busted: everyone returns to the safehouse and bail takes 15% of the crew's cash. |

Everything bought is shared by the crew and saved on the host. The casino is play money only.

## The town

240 m across, 9 blocks. North is up.

```
+------------------+------------------+------------------+
| Pew Pew Pawn     | Lucky Rat        | Fixit Fred's     |
|   weapons        |   casino, ATM    | Drip Lord        |
+---- road --------+---- road --------+---- road --------+
| Grab-N-Dash      | FIRST NATIONAL   | Police HQ, ATM   |
| Tony's Pizza     | BANK, van, ATM   | Officer Greasy   |
+---- road --------+---- road --------+---- road --------+
| SAFEHOUSE        | Park             | Houses           |
|   spawn, stash   |   Zippy, pond    |   Granny Mabel   |
+------------------+------------------+------------------+
```

## How the code fits together

**The host owns the truth.** The host is the server and owns `GameState.state`: cash, unlocks, upgrades, wanted, evade, bank, quests and cooldowns. Only the host writes it. Every change takes one path:

```
client    GameState.request("<action>", [args])
host      runs the one handler registered with GameState.register_action("<action>", handler)
handler   changes GameState.state, then GameState.mark_dirty()
sync      _receive_state.rpc(state) to every player, then Save.persist(state)
```

Every timer runs from a once-a-second clock on the host (`GameState.tick`).

**Interactables** are entries in `Layout.INTERACTABLES`. A non-empty `ui` (armory, workshop, tailor, slots, roulette) opens a panel on the client; everything else is handled on the host by `GameState.register_interact(id, handler)`. `Interactions.describe()` holds the rule for each one: the client draws the prompt from it and the host checks it again before acting. IDs starting `cash_pile_`, `atm_` and `quest_` are registered in loops.

**Actors.** `world.gd` builds the town from `Layout` identically on every machine. Players, NPCs and loot bags are spawned by a `MultiplayerSpawner`. Each player's own machine moves it, aims and decides its hits; the host owns health, downs, mask, weapon, bag and look, and replicates them with a `MultiplayerSynchronizer`. NPC AI runs on the host only.

**Networking.** `net.gd` is the only file that touches the transport (ENet today). The move to Steam changes its `host()` and `join()`.

| Path | Responsibility |
|---|---|
| `project.godot`, `main.tscn` | Project config (autoloads `Net` and `GameState`) and the only scene |
| `scripts/main.gd` | Boot, input map, menu, hosting and joining, the level spawner, returning to the menu |
| `scripts/autoload/net.gd` | Host and join; the only transport code |
| `scripts/autoload/game_state.gd` | Crew state, the `request()` path, action and interactable registration, sync and save, messages, effects |
| `scripts/data/catalog.gd` | Every price, stat, odd and unlock |
| `scripts/data/layout.gd` | Every position: buildings, bank interior, guard posts, interactables, spawns, zones, quest routes |
| `scripts/world/` | `world.gd` builds and runs the level; `build.gd` and `interactable.gd` turn layout data into geometry |
| `scripts/actors/` | `player.gd`, `npc.gd` (civilians, guards, cops), `loot_bag.gd` |
| `scripts/systems/` | Host-only rules: heist, police, crew, jobs, quests, shops, casino, crowd; plus `interactions.gd` and `save.gd` |
| `scripts/ui/` | Menu, HUD, `ShopPanel`, `CasinoPanel`, `UiTheme` |
| `scripts/audio/sfx.gd` | Every sound, synthesised in code |
| `tests/` | Compile check and headless smoke tests (not part of the game) |

### Rules the code relies on

1. Every `GameState.request("x", [...])` has exactly one `register_action("x", handler)` taking the peer plus the same number of args.
2. Only the host writes `GameState.state`.
3. Every host-side interactable has a `register_interact` handler; every quest in `Catalog.QUESTS` has a `quest_<id>` interactable.
4. Every state key the code reads exists in `GameState.new_state()`.
5. Every sound name exists in `sfx.gd`.
6. Typed GDScript: `:=` never infers from a Variant.
7. Tabs only.
8. Balance numbers live only in `catalog.gd`; positions only in `layout.gd`.
9. Bad data fails fast with an assert naming the item.
10. `net.gd` is the only file that touches the transport.
11. The casino stays play money only.

### Adding content

| To add | Do this |
|---|---|
| A look | Add it to `Catalog.MASKS`, `OUTFITS` or `HATS`. Masks and hats also need a model in `player.gd` (`_add_head`, `_add_hat`). |
| A weapon | Add it to `Catalog.WEAPONS` and `WEAPON_ORDER`. More than 4 weapons also needs more number keys in `main.gd`. |
| An interactable | Add it to `Layout.INTERACTABLES`, its rule to `Interactions.describe()`, and a handler with `GameState.register_interact()` in a system. |
| A side quest | Add it to `Catalog.QUESTS`, give it a route in `Layout.quest_route()`, and add a `quest_<id>` interactable. |
| A client action | Call `GameState.request("name", args)` on the client and `GameState.register_action("name", handler)` in a system. |
| A balance change | Edit `catalog.gd` only. |

## Testing

Point `GODOT` at a Godot 4.4+ binary and run from the project folder.

```sh
"$GODOT" --headless --path . --import

# Every script compiles, with the autoloads loaded. -d also prints analyzer warnings.
"$GODOT" --headless -d --path . res://tests/compile_check.tscn

# Host alone, the whole loop: heist, cops, deliveries, bank reopening, jobs, shops, casino, quests, busted, save.
"$GODOT" --headless --path . res://tests/smoke.tscn -- host_full

# The real controls through Input. Needs a display (on Linux: xvfb-run).
"$GODOT" --path . res://tests/smoke.tscn -- host_controls

# Host and a friend as two processes.
"$GODOT" --headless --path . res://tests/smoke.tscn -- host_pair &
sleep 3; "$GODOT" --headless --path . res://tests/smoke.tscn -- join_pair

# Two friends joining mid-heist (the second one leaves 3 s later).
"$GODOT" --headless --path . res://tests/smoke.tscn -- host_busy &
sleep 3; "$GODOT" --headless --path . res://tests/smoke.tscn -- join_watch &
sleep 8; "$GODOT" --headless --path . res://tests/smoke.tscn -- join_watch 3
```

Each scenario prints `PASS`/`FAIL` lines and ends with `SMOKE DONE: <n> failures`. The smoke tests use this machine's `user://` folder and delete `crew_save.json` before they start.

`--check-only --script` can't see the autoloads, so it reports "Identifier not found: GameState" for scripts that are fine. Use `compile_check.tscn` instead.

Exclude `tests/*` in the export filters so the tests don't ship.

## Known gaps

- **No Steam yet.** Connections are direct IP over ENet, UDP 7777.
- **No voice chat.** Proximity voice is the biggest gameplay gap for a friend-slop game.
- **Placeholder art.** Boxes and capsules, no animations, no ragdolls.
- **Hits are decided by the shooter.** Fine among friends; public lobbies could be cheated.
- **Progress lives with the host.** Only each player's look is stored on their own machine.
- **Engine messages you may see** (both harmless, from Godot itself):
  - If two friends disconnect in the same instant, the host logs `Unable to send packet on channel 0, max channels: 0`. ENet resets a leaving peer before Godot reports it gone.
  - Quitting while a sound is mid-play logs `ObjectDB instances leaked at exit` for that sound.

## Shipping on Steam

| Step | Detail |
|---|---|
| Steamworks | Sign up at partner.steamgames.com and pay the Steam Direct fee to get an App ID. |
| Lobbies and voice | Add GodotSteam's MultiplayerPeer and swap it into `net.gd`; test with App ID 480 in `steam_appid.txt` next to the executable. Play each player's voice through an `AudioStreamPlayer3D` on their character. |
| Export | Editor → Manage Export Templates → Download. Then Project → Export → add Windows Desktop (and Linux for Steam Deck). |
| Upload | SteamPipe: steamcmd with an app build script, or the GUI uploader in the Steamworks SDK. |
| Store page | Capsule art, screenshots, a trailer and a description. Declare the simulated gambling in the content survey. |
| Timing | The store page must be public as Coming Soon for at least two weeks before launch. Check the current Steamworks terms. |
