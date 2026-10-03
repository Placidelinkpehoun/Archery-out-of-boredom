extends CanvasLayer

# Le menu ne lance rien lui-même : il annonce le choix, main.gd décide quoi faire.
signal bird_mode_chosen
signal static_bird_mode_chosen
signal ballon_mode_chosen

@onready var bird_button: Button = $Root/Center/Panel/MarginContainer/VBoxContainer/Buttons/BirdButton
@onready var static_bird_button: Button = $Root/Center/Panel/MarginContainer/VBoxContainer/Buttons/StaticBirdButton
@onready var ballon_button: Button = $Root/Center/Panel/MarginContainer/VBoxContainer/Buttons/BallonButton
@onready var quit_button: Button = $Root/Center/Panel/MarginContainer/VBoxContainer/QuitButton


func _ready() -> void:
	bird_button.pressed.connect(bird_mode_chosen.emit)
	static_bird_button.pressed.connect(static_bird_mode_chosen.emit)
	ballon_button.pressed.connect(ballon_mode_chosen.emit)
	quit_button.pressed.connect(get_tree().quit)


func open() -> void:
	visible = true


func close() -> void:
	visible = false
