extends Node2D

const STEP := 0.015 # secondes entre deux points
const DURATION := 0.25 # longueur de l'aperçu, en secondes de vol
const DOT_SIZE := 2.5
const DOT_COLOR := Color(1, 1, 1, 0.8)
const OUTLINE_COLOR := Color(0, 0, 0, 0.5) # lisible sur fond clair

var start := Vector2.ZERO
var start_velocity := Vector2.ZERO


func show_trajectory(from: Vector2, with_velocity: Vector2) -> void:
	start = from
	start_velocity = with_velocity
	visible = true
	queue_redraw()


func _draw() -> void:
	var t := STEP * 2 # les premiers points seraient cachés sous la flèche
	while t <= DURATION:
		var p := Arrow.position_at(start, start_velocity, t)
		draw_circle(p, DOT_SIZE / 2 + 1, OUTLINE_COLOR, true, -1.0, true)
		draw_circle(p, DOT_SIZE / 2, DOT_COLOR, true, -1.0, true)
		t += STEP
