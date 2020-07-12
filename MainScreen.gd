extends Control

const PORT := 8910

onready var connection_panel := $ConnectionPanel
onready var username_field := $ConnectionPanel/VBoxContainer/UsernameField
onready var ip_field := $ConnectionPanel/VBoxContainer/IpField
onready var message_field := $MessagePanel/HBoxContainer/MessageField
onready var message_list := $ScrollableList/Messages
onready var scroll := $ScrollableList
onready var mouse_sfx_player := $SFXs/MouseSFXPlayer
onready var loading_screen := $LoadingScreen
onready var general_sfx_player := $SFXs/GeneralSFXPlayer

export(PackedScene) var message_frame

var username : String
var users_list := Array()

### Network signal handling callbacks

func _ready() -> void:
	OS.window_borderless = true
#	OS.window_maximized = true
	loading_screen.visible = true
	yield(get_tree().create_timer(1), "timeout")
	general_sfx_player.play_stream(general_sfx_player.windows_boot)
	yield(general_sfx_player, "finished")
	loading_screen.visible = false
	
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

func _player_connected(id : int) -> void:
	users_list.append({
		"id": id,
		"username": "not_initialized"
	})
	# everyone already online will send their username to the new player
	rpc_id(id, "set_username", get_tree().get_network_unique_id(), username)

func _player_disconnected(id : int) -> void:
	for i in range(users_list.size()):
		if users_list[i].id == id:
			users_list.remove(i)

func _connected_ok() -> void:
	# the new player will send his username to everyone already online
	rpc("set_username", get_tree().get_network_unique_id(), username)

func _connected_fail() -> void:
	connection_panel.visible = true

func _server_disconnected() -> void:
	get_tree().network_peer = null
	_clear_message_list()
	connection_panel.visible = true

func _clear_message_list() -> void:
	for child in message_list.get_children():
			child.queue_free()


### Network connection starters

func _on_host_button_up() -> void:
	username = username_field.text
	var host = NetworkedMultiplayerENet.new()
	host.compression_mode = NetworkedMultiplayerENet.COMPRESS_RANGE_CODER
	var err = host.create_server(PORT, 32)
	
	if err != OK:
		return
	
	get_tree().network_peer = host
	connection_panel.visible = false

func _on_join_button_up() -> void:
	username = username_field.text
	var ip : String = ip_field.text
	
	if not ip.is_valid_ip_address():
		return
	
	var host = NetworkedMultiplayerENet.new()
	host.compression_mode = NetworkedMultiplayerENet.COMPRESS_RANGE_CODER
	var err = host.create_client(ip, PORT)
	
	if err != OK:
		return
	
	get_tree().network_peer = host
	connection_panel.visible = false

### Chat logic + functions called through RPC

func _on_send_button_up() -> void:
	if message_field.text == "":
		return
	rpc("retrieve_message", get_tree().get_network_unique_id(), message_field.text)
	message_field.text = ""

remote func set_username(peer_id : int, peer_username : String) -> void:
	for i in range(users_list.size()):
		if users_list[i].id == peer_id:
			users_list[i].username = peer_username

remotesync func retrieve_message(id : int, message : String) -> void:
	var owned_by_me := id == get_tree().get_network_unique_id()
	
	var display_name := "Anonymous"
	if owned_by_me:
		display_name = username
	else:
		var user_info := _retrieve_user_info(id)
		display_name = user_info.username

	var message_blob := _create_message_blob(display_name, message, owned_by_me)
	
	message_list.add_child(message_blob)
	
	# scroll size is only recalculated at the end of the frame
	# (so, an updated width is only available on the next frame)
	# yield(get_tree(), "idle_frame") # with latency, sometimes one frame is not enough
	yield(get_tree().create_timer(.5), "timeout")
	scroll.scroll_vertical = message_list.get_child_count() * message_blob.rect_size.y
	general_sfx_player.play_stream(general_sfx_player.msn_received)

## Auxiliary functions

func _retrieve_user_info(id : int) -> Dictionary:
	for i in range(users_list.size()):
		if users_list[i].id == id:
			return users_list[i]
	return {}

func _create_message_blob(display_name : String, message : String, owned_by_me : bool) -> Control:
	var msg_blob : Control = message_frame.instance()
	msg_blob.find_node("Name").text = display_name
	msg_blob.find_node("Message").text = message
	msg_blob.find_node("LeftPointer").visible = not owned_by_me
	msg_blob.find_node("RightPointer").visible = owned_by_me
	return msg_blob

## Extra: close connection and return to panel

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.scancode == KEY_ESCAPE:
		get_tree().network_peer = null
		_clear_message_list()
		connection_panel.visible = true
	if event is InputEventMouseButton and not mouse_sfx_player.playing:
		mouse_sfx_player.pitch_scale = rand_range(.95, 1.15)
		mouse_sfx_player.play()

func _on_exit_button_up() -> void:
	loading_screen.visible = true
	loading_screen.find_node("Message").bbcode_text = "[wave amp=25 freq=4]Exiting[/wave]"
	general_sfx_player.play_stream(general_sfx_player.windows_shutdown)
	yield(general_sfx_player, "finished")
	get_tree().quit()

