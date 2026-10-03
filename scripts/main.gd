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

	# Le jeu démarre sur le menu : rien n'apparaît tant qu'un mode n'est pas choisi.
	mode_menu.bird_mode_chosen.connect(start_bird_mode)
	mode_menu.obstacle_mode_chosen.connect(start_obstacle_mode)
	mode_menu.open()


func _unhandled_input(event: InputEvent) -> void:
	# Échap : quitter immédiatement.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
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
	add_child(arrow)
	arrow.launch(bow.arrow_global_position(), launch_velocity())


func launch_velocity() -> Vector2:
	return direction * lerpf(Arrow.MIN_SPEED, Arrow.MAX_SPEED, power)


func start_bird_mode() -> void:
	mode_menu.close()
	spawn_bird()


func start_obstacle_mode() -> void:
	pass # mode pas encore créé : le menu reste ouvert


func spawn_bird() -> void:
	bird = BIRD_SCENE.instantiate()
	add_child(bird)
	move_child(bird, 0) # derrière l'arc, l'aperçu et les flèches
	bird.fly(get_viewport_rect(), last_bird_position, has_last_bird)
	bird.hit.connect(_on_bird_gone)
	bird.escaped.connect(_on_bird_gone)


func _on_bird_gone(at: Vector2) -> void:
	last_bird_position = at
	has_last_bird = true
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(spawn_bird)
