extends Node2D

# Pointes de l'arc, en pixels de arc.png, relatives au centre de la texture.
const TIP_TOP_PX := Vector2(-13, -11)
const TIP_BOTTOM_PX := Vector2(11, 13)
# Recul de l'encoche à tension maximale (pixels locaux).
const MAX_PULL := 14.0
# Distance entre le centre du sprite de la flèche et son encoche (arrière).
const ARROW_NOCK_OFFSET := 13.0
const STRING_COLOR := Color(0.85, 0.85, 0.85)
const STRING_WIDTH := 1.0

@onready var sprite: Sprite2D = $Sprite
@onready var nocked_arrow: Sprite2D = $NockedArrow

var tip_top: Vector2
var tip_bottom: Vector2
var rest_nock: Vector2
var nock: Vector2


func _ready() -> void:
	# Les pointes suivent la rotation (45°) appliquée au sprite dans la scène.
	tip_top = sprite.transform * TIP_TOP_PX
	tip_bottom = sprite.transform * TIP_BOTTOM_PX
	rest_nock = (tip_top + tip_bottom) / 2.0
	aim(Vector2.RIGHT, 0.0)


# direction : sens du tir. power : tension entre 0 et 1.
func aim(direction: Vector2, power: float) -> void:
	rotation = direction.angle()
	# +X local = sens du tir, donc on tire la corde vers -X.
	nock = rest_nock + Vector2.LEFT * MAX_PULL * power
	nocked_arrow.position = nock + Vector2.RIGHT * ARROW_NOCK_OFFSET
	queue_redraw()


func arrow_global_position() -> Vector2:
	return nocked_arrow.global_position


func set_arrow_visible(value: bool) -> void:
	nocked_arrow.visible = value


func _draw() -> void:
	draw_line(tip_top, nock, STRING_COLOR, STRING_WIDTH)
	draw_line(nock, tip_bottom, STRING_COLOR, STRING_WIDTH)
