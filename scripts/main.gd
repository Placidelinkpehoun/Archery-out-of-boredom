extends Node2D

const ARROW_SCENE := preload("res://scenes/arrow.tscn")
const BIRD_SCENE := preload("res://scenes/bird.tscn")
# Pause entre la disparition d'un oiseau et l'arrivée du suivant.
const RESPAWN_DELAY := 0.8
# Distance de glissé (px écran) qui donne la tension maximale.
const MAX_DRAG := 150.0
# En dessous de cette tension, on annule le tir (simple clic).
const MIN_POWER := 0.08

@onready var bow: Node2D = $Bow
@onready var trajectory_preview: Node2D = $TrajectoryPreview
@onready var mode_menu: CanvasLayer = $ModeMenu
@onready var hud: CanvasLayer = $HUD
@onready var hud_box: Control = $HUD/MarginContainer
@onready var play_button: Button = $HUD/MarginContainer/HBoxContainer/PlayButton
@onready var menu_button: Button = $HUD/MarginContainer/HBoxContainer/MenuButton

# Une partie est en cours (un mode a été choisi dans le menu).
var playing := false
# Pause : le jeu est figé et les clics traversent la fenêtre, sauf sur le HUD.
var paused := false

var aiming := false
var anchor := Vector2.ZERO
var direction := Vector2.RIGHT
var power := 0.0

var bird: Bird = null
# Où l'oiseau précédent a disparu : le suivant arrive loin de là.
var last_bird_position := Vector2.ZERO
var has_last_bird := false


func _ready() -> void:
	# Fond transparent : on voit le bureau à travers la fenêtre.
	get_viewport().transparent_bg = true
	bow.visible = false
	trajectory_preview.visible = false
	# Main (et donc le HUD) continue de tourner pendant la pause, pour Échap et les boutons.
	# Les oiseaux et les flèches, eux, sont figés (PROCESS_MODE_PAUSABLE à leur création).
	process_mode = Node.PROCESS_MODE_ALWAYS

	mode_menu.bird_mode_chosen.connect(start_bird_mode)
	mode_menu.static_bird_mode_chosen.connect(start_static_bird_mode)
	mode_menu.ballon_mode_chosen.connect(start_ballon_mode)
	play_button.pressed.connect(toggle_pause)
	menu_button.pressed.connect(open_menu)

	# Le jeu démarre sur le menu : rien n'apparaît tant qu'un mode n'est pas choisi.
	open_menu()


func _unhandled_input(event: InputEvent) -> void:
	# Échap : quitter immédiatement.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif not playing or paused:
		return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_aiming(event.position)
		elif aiming:
			release()
	elif event is InputEventMouseMotion and aiming:
		update_aim(event.position)


func _process(_delta: float) -> void:
	# L'oiseau bouge : s'il entre dans la zone pendant la visée, le tir est annulé.
	if aiming and is_bird_too_close(anchor):
		cancel_aim()
		bird.refuse_shot()


func is_bird_too_close(point: Vector2) -> bool:
	return is_instance_valid(bird) and not bird.dead and bird.is_in_no_shoot_zone(point)


func start_aiming(at: Vector2) -> void:
	if is_bird_too_close(at):
		bird.refuse_shot()
		return

	aiming = true
	anchor = at
	power = 0.0
	bow.position = at
	bow.aim(direction, 0.0)
	bow.set_arrow_visible(true)
	bow.visible = true


func update_aim(mouse: Vector2) -> void:
	# Lance-pierre : on tire vers l'arrière, la flèche part à l'opposé.
	var pull := (mouse - anchor).limit_length(MAX_DRAG)
	power = pull.length() / MAX_DRAG
	if pull.length() > 0.0:
		direction = -pull.normalized()
	bow.aim(direction, power)

	if power >= MIN_POWER:
		trajectory_preview.show_trajectory(bow.arrow_global_position(), launch_velocity())
	else:
		trajectory_preview.visible = false


func cancel_aim() -> void:
	aiming = false
	bow.visible = false
	trajectory_preview.visible = false


func release() -> void:
	cancel_aim()
	if power < MIN_POWER:
		return

	var arrow: Arrow = ARROW_SCENE.instantiate()
	arrow.process_mode = Node.PROCESS_MODE_PAUSABLE
	arrow.add_to_group("arrows")
	add_child(arrow)
	arrow.launch(bow.arrow_global_position(), launch_velocity())


func launch_velocity() -> Vector2:
	return direction * lerpf(Arrow.MIN_SPEED, Arrow.MAX_SPEED, power)


func open_menu() -> void:
	# On arrête proprement la partie en cours avant d'afficher le menu.
	set_paused(false)
	playing = false
	cancel_aim()
	if is_instance_valid(bird):
		bird.queue_free()
	bird = null
	get_tree().call_group("arrows", "queue_free")
	hud.visible = false
	mode_menu.open()


func start_game() -> void:
	mode_menu.close()
	hud.visible = true
	playing = true


func toggle_pause() -> void:
	set_paused(not paused)


func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	cancel_aim()
	play_button.text = "▶" if paused else "❚❚"
	update_mouse_passthrough()


func update_mouse_passthrough() -> void:
	# Tableau vide : toute la fenêtre capte la souris (jeu normal).
	if not paused:
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
		return
	# Sinon, seule la zone du HUD capte la souris ; ailleurs les clics vont aux autres applis.
	# Le polygone est en pixels de la fenêtre : on applique l'étirement de l'affichage.
	var rect := hud_box.get_global_rect().grow(6)
	var to_window := get_viewport().get_final_transform()
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([
		to_window * rect.position,
		to_window * Vector2(rect.end.x, rect.position.y),
		to_window * rect.end,
		to_window * Vector2(rect.position.x, rect.end.y),
	]))


func start_bird_mode() -> void:
	start_game()
	spawn_bird()


func start_static_bird_mode() -> void:
	pass


func start_ballon_mode() -> void:
	pass # mode pas encore créé : le menu reste ouvert


func spawn_bird() -> void:
	if not playing: # le minuteur a sonné après le retour au menu
		return
	bird = BIRD_SCENE.instantiate()
	bird.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bird)
	move_child(bird, 0) # derrière l'arc, l'aperçu et les flèches
	bird.fly(get_viewport_rect(), last_bird_position, has_last_bird)
	bird.hit.connect(_on_bird_gone)
	bird.escaped.connect(_on_bird_gone)


func _on_bird_gone(at: Vector2) -> void:
	last_bird_position = at
	has_last_bird = true
	# false : le minuteur s'arrête pendant la pause.
	get_tree().create_timer(RESPAWN_DELAY, false).timeout.connect(spawn_bird)
