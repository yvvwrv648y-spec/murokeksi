class_name PUWCoopNetworkManager
extends Node
## Private 2-Player Co-Op Multiplayer Manager (Godot 4.7.2 ENetMultiplayerPeer).
## Syncs player transforms, facing, active party followers, and shared Kanto world events.

signal peer_connected_coop(peer_id: int)
signal peer_disconnected_coop(peer_id: int)

const DEFAULT_PORT: int = 24560
const MAX_COOP_PLAYERS: int = 2

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var remote_players: Dictionary = {} # peer_id -> Dictionary

func host_private_session(port: int = DEFAULT_PORT) -> Error:
	var err: Error = peer.create_server(port, MAX_COOP_PLAYERS - 1)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return err

func join_private_session(host_ip: String, port: int = DEFAULT_PORT) -> Error:
	var err: Error = peer.create_client(host_ip, port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
	return err

func _on_peer_connected(id: int) -> void:
	remote_players[id] = {"map_id": "kanto_pallet_town", "position": Vector3.ZERO, "facing": "down"}
	peer_connected_coop.emit(id)

func _on_peer_disconnected(id: int) -> void:
	remote_players.erase(id)
	peer_disconnected_coop.emit(id)

@rpc("any_peer", "unreliable_ordered")
func sync_player_state(map_id: String, pos: Vector3, facing: String, active_followers: PackedStringArray) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	remote_players[sender] = {"map_id": map_id, "position": pos, "facing": facing, "followers": active_followers}

# --- STRICT CO-OP TANDEM VISIBILITY, CONSENT HANDSHAKE & PASSENGER CAMERA/CONTROL LOCK ---
var is_coop_connected: bool = false
var tandem_active: bool = false
var tandem_driver_peer_id: int = -1
var tandem_passenger_peer_id: int = -1
var passenger_input_locked: bool = false
var passenger_camera_follow_driver: bool = false

func is_tandem_ui_visible() -> bool:
	# Strictly invisible offline — single-player never sees tandem bikes or second-rider options!
	return is_coop_connected

func request_tandem_ride(driver_id: int, passenger_id: int) -> Dictionary:
	if not is_coop_connected:
		return {"ok": false, "reason": "COOP_OFFLINE_TANDEM_HIDDEN"}
	return {"ok": true, "status": "AWAITING_PASSENGER_ACCEPTANCE", "driver_id": driver_id, "passenger_id": passenger_id}

func respond_tandem_invite(accepted: bool, driver_id: int, passenger_id: int) -> Dictionary:
	if not accepted:
		tandem_active = false
		passenger_input_locked = false
		passenger_camera_follow_driver = false
		return {"tandem_mounted": false, "fallback": "BOTH_PLAYERS_USE_SINGULAR_BIKES"}
	tandem_active = true
	tandem_driver_peer_id = driver_id
	tandem_passenger_peer_id = passenger_id
	passenger_input_locked = true
	passenger_camera_follow_driver = true
	return {"tandem_mounted": true, "driver_in_control": driver_id, "passenger_locked_and_synced": passenger_id}

func dismount_tandem() -> void:
	tandem_active = false
	tandem_driver_peer_id = -1
	tandem_passenger_peer_id = -1
	passenger_input_locked = false
	passenger_camera_follow_driver = false


# --- CO-OP TELEPORT OFFER FLOW (Worker C, Part A, 2026-11-23) ---
## When one player uses a transport field action, the OTHER
## player is OFFERED the choice to come along -- never forced.
## Systems-level flow (messages + state), testable headless:
## offer_teleport() records a pending offer and appends an
## "offer" message to teleport_message_log (the transport the
## live game sends over the existing sync channel);
## respond_teleport_offer() resolves it: accept -> the peer is
## marked to travel (their own follower controller transports
## their team with transport_followers_to); decline or no
## answer -> they stay (a pending offer changes nothing).
## The prompt's visual presentation needs a live two-client
## pass and is NOT proven headless.
var teleport_pending_offer: Dictionary = {}
var teleport_message_log: Array = []
var remote_follower_states: Dictionary = {} # peer_id -> Array of follower sync records


func offer_teleport(from_peer_id: int, to_peer_id: int, dest_map_id: String, dest_pos: Vector3) -> Dictionary:
	teleport_pending_offer = {
		"from_peer": from_peer_id, "to_peer": to_peer_id,
		"dest_map_id": dest_map_id, "dest_pos": dest_pos,
		"status": "awaiting_choice",
	}
	teleport_message_log.append({"kind": "teleport_offer", "from": from_peer_id, "to": to_peer_id, "dest_map_id": dest_map_id})
	return teleport_pending_offer.duplicate()


func respond_teleport_offer(to_peer_id: int, accepted: bool) -> Dictionary:
	if teleport_pending_offer.is_empty() or int(teleport_pending_offer.get("to_peer", -1)) != to_peer_id:
		return {"ok": false, "reason": "no_pending_offer"}
	var offer: Dictionary = teleport_pending_offer
	teleport_pending_offer = {}
	if accepted:
		teleport_message_log.append({"kind": "teleport_accept", "peer": to_peer_id})
		return {"ok": true, "travel": true, "dest_map_id": str(offer.get("dest_map_id", "")), "dest_pos": offer.get("dest_pos", Vector3.ZERO)}
	teleport_message_log.append({"kind": "teleport_decline", "peer": to_peer_id})
	return {"ok": true, "travel": false}


## Store a remote player's follower sync state (both teams are
## present in the shared world state; see Part B.1).
func apply_remote_follower_state(peer_id: int, follower_records: Array) -> void:
	remote_follower_states[peer_id] = follower_records.duplicate(true)


func get_remote_follower_state(peer_id: int) -> Array:
	var value: Variant = remote_follower_states.get(peer_id, [])
	if value is Array:
		var records: Array = value
		return records
	return []
