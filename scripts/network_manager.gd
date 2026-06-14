class_name NetworkManager
extends Node

signal connected_to_server
signal connection_failed
signal server_disconnected
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

enum Transport {
	ENET,
	WEBSOCKET,
}

@export var port := 24567
@export var max_clients := 8
@export var server_url := "ws://127.0.0.1:24567"
@export var default_transport := Transport.ENET


func _ready() -> void:
	multiplayer.connected_to_server.connect(connected_to_server.emit)
	multiplayer.connection_failed.connect(connection_failed.emit)
	multiplayer.server_disconnected.connect(server_disconnected.emit)
	multiplayer.peer_connected.connect(peer_connected.emit)
	multiplayer.peer_disconnected.connect(peer_disconnected.emit)


func host() -> Error:
	if _should_use_websocket_server():
		return host_websocket()

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


func host_websocket(bind_address := "*") -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var error := peer.create_server(port, bind_address)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


func join(address: String) -> Error:
	if _should_use_websocket_client(address):
		return join_websocket(address)

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


func join_websocket(address: String) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var error := peer.create_client(_normalize_websocket_url(address))
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


func close() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func is_dedicated_server() -> bool:
	for argument in OS.get_cmdline_args():
		if argument == "--server" or argument == "--dedicated-server":
			return true
	return OS.has_feature("dedicated_server")


func get_join_hint() -> String:
	if OS.has_feature("web") or default_transport == Transport.WEBSOCKET:
		return server_url
	return "127.0.0.1"


func get_transport_name() -> String:
	if _should_use_websocket_server():
		return "WebSocket"
	return "ENet"


func _should_use_websocket_server() -> bool:
	return is_dedicated_server() or default_transport == Transport.WEBSOCKET


func _should_use_websocket_client(address: String) -> bool:
	return OS.has_feature("web") or default_transport == Transport.WEBSOCKET or "://" in address


func _normalize_websocket_url(address: String) -> String:
	var clean_address := address.strip_edges()
	if clean_address == "":
		clean_address = server_url
	if "://" in clean_address:
		return clean_address
	return "ws://%s:%s" % [clean_address, port]
