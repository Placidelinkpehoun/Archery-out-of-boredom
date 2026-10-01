class_name Arrow
extends Area2D

# Physique partagée avec l'aperçu de trajectoire (trajectory_preview.gd).
const GRAVITY := 1200.0 # px/s², vers le bas
const MIN_SPEED := 600.0 # tension minimale : lente et très courbée
const MAX_SPEED := 3000.0 # tension maximale : rapide et presque droite

var velocity := Vector2.ZERO


# Position exacte après un temps t (mouvement à accélération constante).
static func position_at(start: Vector2, start_velocity: Vector2, t: float) -> Vector2:
	return start + start_velocity * t + 0.5 * Vector2(0, GRAVITY) * t * t


func launch(start: Vector2, start_velocity: Vector2) -> void:
	global_position = start
	velocity = start_velocity
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	# Même formule que position_at : la flèche suit exactement l'aperçu.
	global_position += velocity * delta + 0.5 * Vector2(0, GRAVITY) * delta * delta
	velocity.y += GRAVITY * delta
	rotation = velocity.angle()

	# Filet de sécurité : sortie par le haut puis retombée hors de l'écran.
	if global_position.y > get_viewport_rect().end.y + 200:
		queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	# Sortie par le haut : la gravité va la faire revenir, on la garde.
	if global_position.y < get_viewport_rect().position.y:
		return
	queue_free()
