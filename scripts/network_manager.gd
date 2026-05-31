class_name NetworkManager
extends Node

signal connected_to_server
signal connection_failed
signal server_disconnected
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

@export var port := 24567
@export var max_clients := 8


func _ready() -> void:
	multiplayer.connected_to_server.connect(connected_to_server.emit)
	multiplayer.connection_failed.connect(connection_failed.emit)
	multiplayer.server_disconnected.connect(server_disconnected.emit)
	multiplayer.peer_connected.connect(peer_connected.emit)
	multiplayer.peer_disconnected.connect(peer_disconnected.emit)


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


func join(ip_address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip_address.strip_edges(), port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


func close() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
