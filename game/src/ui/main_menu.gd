class_name MainMenu
extends Control

## Main menu screen with Host/Join/Quit options.
## Emits signals for the caller to handle network setup.

signal host_requested(port: int)
signal join_requested(address: String, port: int)

const DEFAULT_PORT: int = 7777
const DEFAULT_ADDRESS: String = "127.0.0.1"

@onready var _host_button: Button = $VBox/HostButton
@onready var _join_button: Button = $VBox/JoinButton
@onready var _quit_button: Button = $VBox/QuitButton
@onready var _host_panel: Control = $HostPanel
@onready var _join_panel: Control = $JoinPanel
@onready var _port_input: LineEdit = $HostPanel/PortInput
@onready var _address_input: LineEdit = $JoinPanel/AddressInput
@onready var _host_confirm: Button = $HostPanel/ConfirmButton
@onready var _join_confirm: Button = $JoinPanel/ConfirmButton


func _ready() -> void:
	_host_panel.hide()
	_join_panel.hide()
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_host_confirm.pressed.connect(_on_host_confirmed)
	_join_confirm.pressed.connect(_on_join_confirmed)
	_port_input.text = str(DEFAULT_PORT)
	_address_input.text = DEFAULT_ADDRESS


func _on_host_pressed() -> void:
	_join_panel.hide()
	_host_panel.show()


func _on_join_pressed() -> void:
	_host_panel.hide()
	_join_panel.show()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_host_confirmed() -> void:
	var port := _parse_port(_port_input.text)
	if port <= 0:
		push_warning("MainMenu: invalid port '%s'" % _port_input.text)
		return
	host_requested.emit(port)


func _on_join_confirmed() -> void:
	var raw: String = _address_input.text.strip_edges()
	var address: String
	var port: int

	if ":" in raw:
		var parts := raw.split(":", false, 1)
		address = parts[0]
		port = _parse_port(parts[1])
	else:
		address = raw
		port = DEFAULT_PORT

	if address.is_empty() or port <= 0:
		push_warning("MainMenu: invalid address/port '%s'" % raw)
		return

	join_requested.emit(address, port)


func _parse_port(value: String) -> int:
	# Returns -1 on invalid input
	if not value.is_valid_int():
		return -1
	var p := value.to_int()
	if p < 1 or p > 65535:
		return -1
	return p
