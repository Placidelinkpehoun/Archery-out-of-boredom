class_name Bird
extends Area2D

signal hit(at: Vector2)
signal escaped(at: Vector2)

const SPRITE_SCALE := 0.25 # 256 px -> 64 px à l'écran

# Chemin
const MIN_SPEED := 220.0
const MAX_SPEED := 320.0
const OFFSCREEN_MARGIN := 80.0 # l'oiseau naît et disparaît hors de l'écran
const EDGE_PADDING := 0.1 # évite les coins de l'écran (fraction)
const ENTRY_CANDIDATES := 12 # plus il y en a, plus l'entrée est loin de la sortie précédente
const DIRECT_PATH_CHANCE := 0.3 # vol presque en ligne droite
const MAX_WOBBLE := 40.0 # ondulation perpendiculaire au chemin (px)

# Animation
const MAX_TILT := PI / 7
const FLAP_SPEED := 14.0
const FLAP_SQUASH := 0.08
const FLAP_BOB := 3.0

# Zone où l'on ne peut pas poser l'arc
const NO_SHOOT_RADIUS := 220.0
const ZONE_REVEAL_DISTANCE := 1.6 # la zone apparaît quand la souris s'approche (x rayon)
const ZONE_COLOR := Color(1, 1, 1, 0.35)
const ZONE_REFUSED_COLOR := Color(1, 0.25, 0.25, 0.9)
const ZONE_DASHES := 24
const ZONE_WIDTH := 3.0
const ZONE_SPIN := 0.4

@onready var sprite: Sprite2D = $Sprite

var curve := Curve2D.new()
var speed := 300.0
var progress := 0.0
var wobble_amplitude := 0.0
var wobble_frequency := 1.0
var time := 0.0
var dead := false
var zone_alpha := 0.0
var refused_flash := 0.0


# avoid : endroit où l'oiseau précédent a disparu (ignoré si has_avoid est faux).
func fly(screen: Rect2, avoid: Vector2, has_avoid: bool) -> void:
	# Entrée : le meilleur candidat loin de la sortie précédente, avec un peu de hasard.
	var entry_edge := 0
	var entry := Vector2.ZERO
	var best := -1.0
	for i in ENTRY_CANDIDATES:
		var edge := randi() % 4
		var p := _point_on_edge(screen, edge)
		var score := (p.distance_to(avoid) if has_avoid else 1.0) * randf_range(0.8, 1.0)
		if score > best:
			best = score
			entry_edge = edge
			entry = p

	# Sortie : un autre bord, en préférant un long trajet.
	var exit := Vector2.ZERO
	best = -1.0
	for i in 3:
		var p := _point_on_edge(screen, (entry_edge + 1 + randi() % 3) % 4)
		if p.distance_to(entry) > best:
			best = p.distance_to(entry)
			exit = p

	# Courbe de Bézier : les points de contrôle au centre de l'écran donnent des virages variés.
	var inner := Rect2(screen.position + screen.size * 0.15, screen.size * 0.7)
	var c1 := _random_point_in(inner)
	var c2 := _random_point_in(inner)
	if randf() < DIRECT_PATH_CHANCE:
		c1 = entry.lerp(exit, 0.33)
		c2 = entry.lerp(exit, 0.66)
	curve.clear_points()
	curve.add_point(entry, Vector2.ZERO, c1 - entry)
	curve.add_point(exit, c2 - exit, Vector2.ZERO)

	speed = randf_range(MIN_SPEED, MAX_SPEED)
	wobble_amplitude = randf_range(0.0, MAX_WOBBLE)
	wobble_frequency = randf_range(0.8, 2.0)
	progress = 0.0
	global_position = entry


func is_in_no_shoot_zone(point: Vector2) -> bool:
	return global_position.distance_to(point) < NO_SHOOT_RADIUS


func refuse_shot() -> void:
	refused_flash = 1.0


func _process(delta: float) -> void:
	time += delta
	_update_zone(delta)
	if dead:
		return

	var length := curve.get_baked_length()
	progress += speed * delta
	if progress >= length:
		escaped.emit(global_position)
		queue_free()
		return

	var p := curve.sample_baked(progress)
	var tangent := (curve.sample_baked(minf(progress + 4.0, length)) - p).normalized()
	var target := p + tangent.orthogonal() * sin(time * TAU * wobble_frequency) * wobble_amplitude
	var motion := target - global_position
	global_position = target
	_animate(motion, delta)


func _animate(motion: Vector2, delta: float) -> void:
	# Regarde dans le sens du vol et s'incline selon la pente.
	if absf(motion.x) > 0.01:
		sprite.flip_h = motion.x < 0
	var tilt := clampf(atan2(motion.y, absf(motion.x)), -MAX_TILT, MAX_TILT)
	if sprite.flip_h:
		tilt = -tilt
	sprite.rotation = lerp_angle(sprite.rotation, tilt, 1.0 - exp(-10.0 * delta))

	# Battement d'ailes : petit rebond + étirement.
	var flap := sin(time * FLAP_SPEED)
	sprite.position.y = flap * FLAP_BOB
	sprite.scale = SPRITE_SCALE * Vector2(1.0 + flap * FLAP_SQUASH, 1.0 - flap * FLAP_SQUASH)


func _update_zone(delta: float) -> void:
	# La zone se dévoile quand la souris approche, et clignote en rouge si on clique dedans.
	var distance := get_global_mouse_position().distance_to(global_position)
	var reveal := clampf(inverse_lerp(NO_SHOOT_RADIUS * ZONE_REVEAL_DISTANCE, NO_SHOOT_RADIUS, distance), 0.0, 1.0)
	zone_alpha = move_toward(zone_alpha, reveal, delta * 4.0)
	refused_flash = move_toward(refused_flash, 0.0, delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var alpha := maxf(zone_alpha, refused_flash)
	if alpha <= 0.0:
		return
	var color := ZONE_COLOR.lerp(ZONE_REFUSED_COLOR, refused_flash)
	color.a *= alpha
	var radius := NO_SHOOT_RADIUS * (1.0 + 0.04 * refused_flash * sin(time * 50.0))
	var step := TAU / ZONE_DASHES
	for i in ZONE_DASHES:
		var a := i * step + time * ZONE_SPIN
		draw_arc(Vector2.ZERO, radius, a, a + step * 0.5, 6, color, ZONE_WIDTH)


func _on_area_entered(area: Area2D) -> void:
	if dead or not area is Arrow:
		return
	dead = true
	hit.emit(global_position)
	queue_free() # provisoire : remplacé par l'animation de mort (juice)


func _point_on_edge(screen: Rect2, edge: int) -> Vector2:
	var x := randf_range(screen.position.x + screen.size.x * EDGE_PADDING, screen.end.x - screen.size.x * EDGE_PADDING)
	var y := randf_range(screen.position.y + screen.size.y * EDGE_PADDING, screen.end.y - screen.size.y * EDGE_PADDING)
	match edge:
		0: return Vector2(screen.position.x - OFFSCREEN_MARGIN, y) # gauche
		1: return Vector2(screen.end.x + OFFSCREEN_MARGIN, y) # droite
		2: return Vector2(x, screen.position.y - OFFSCREEN_MARGIN) # haut
		_: return Vector2(x, screen.end.y + OFFSCREEN_MARGIN) # bas


func _random_point_in(rect: Rect2) -> Vector2:
	return rect.position + Vector2(randf() * rect.size.x, randf() * rect.size.y)
