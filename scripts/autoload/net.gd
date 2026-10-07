extends Node
## Host and join. The only file that touches the network transport (ENet today, Steam later).

signal peer_joined(id: int)
signal peer_left(id: int)
signal joined
signal join_failed
signal host_lost

const PORT: int = 7777
const MAX_CLIENTS: int = 3

var local_name: String = "Robber"


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: joined.emit())
	multiplayer.connection_failed.connect(func() -> void: join_failed.emit())
	multiplayer.server_disconnected.connect(func() -> void: host_lost.emit())


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func join(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func close() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
