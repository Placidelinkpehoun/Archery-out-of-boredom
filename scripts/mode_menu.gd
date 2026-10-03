extends CanvasLayer

# Le menu ne lance rien lui-même : il annonce le choix, main.gd décide quoi faire.
signal bird_mode_chosen
signal static_bird_mode_chosen
signal ballon_mode_chosen

@onready var bird_button: Button = $Root/Center/Panel/MarginContainer/VBoxContainer/Buttons/BirdButton
@onready var static_bird_button: Button = $Root/Center/Panel/MarginContainer/VBoxContainer/Buttons/StaticBirdButton
@onready var ballon_button: Button = $Root/Center/Panel/MarginContainer/VBoxContainer/Buttons/BallonButton
@onready var quit_button: Button = $Root/Center/Panel/MarginContainer/VBoxContainer/QuitButton
@onready var root: Control = $Root
@onready var panel: Control = $Root/Center/Panel

var open_tween: Tween


func _ready() -> void:
	bird_button.pressed.connect(bird_mode_chosen.emit)
	static_bird_button.pressed.connect(static_bird_mode_chosen.emit)
	ballon_button.pressed.connect(ballon_mode_chosen.emit)
	quit_button.pressed.connect(get_tree().quit)


func open() -> void:
	visible = true

	# Apparition : fondu de l'ensemble + le panneau grossit de 0,8 à 1 avec un rebond.
	if open_tween:
		open_tween.kill()
	# Le panneau grandit depuis son centre (sa taille minimale est connue même avant l'affichage).
	panel.pivot_offset = panel.get_combined_minimum_size() / 2.0
	panel.scale = Vector2.ONE * 0.8
	root.modulate.a = 0.0
	open_tween = create_tween().set_parallel()
	open_tween.tween_property(root, "modulate:a", 1.0, 0.15)
	open_tween.tween_property(panel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	visible = false
