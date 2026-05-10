extends Control

signal confirmed
signal canceled

const UINavigation = preload("res://assets/scripts/ui_navigation.gd")

@onready var title_label: Label = $DialogCenter/DialogPanel/DialogContent/DialogTitle
@onready var body_label: Label = $DialogCenter/DialogPanel/DialogContent/DialogBody
@onready var confirm_button: Button = $DialogCenter/DialogPanel/DialogContent/DialogButtons/ConfirmButton
@onready var cancel_button: Button = $DialogCenter/DialogPanel/DialogContent/DialogButtons/CancelButton


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_button.pressed.connect(func() -> void: confirmed.emit())
	cancel_button.pressed.connect(func() -> void: canceled.emit())
	confirm_button.mouse_entered.connect(confirm_button.grab_focus)
	cancel_button.mouse_entered.connect(cancel_button.grab_focus)


func show_dialog(
	title_text: String,
	body_text: String,
	confirm_text: String = "CONFIRM",
	cancel_text: String = "CANCEL"
) -> void:
	title_label.text = title_text
	body_label.text = body_text
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text
	visible = true
	confirm_button.grab_focus()


func hide_dialog() -> void:
	visible = false


func is_open() -> bool:
	return visible


func handle_navigation_input(event: InputEvent) -> bool:
	if not visible:
		return false

	return UINavigation.handle_linear_navigation_input(event, [confirm_button, cancel_button])
