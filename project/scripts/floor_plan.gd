## FloorPlan — the Clue board, drawn in the corner.
##
## Rooms as paper boxes, corridors as ink lines with their step cost, a token
## for each presenter, and - while you are choosing - the rooms you can reach
## this move lit up. The 3D office is the picture; this is the board.
class_name FloorPlan
extends Control

const PAPER := Color("fbf7ec")
const INK := Color("12101a")

var board: Board
## room id -> steps, for the rooms the player can reach right now.
var reach: Dictionary = {}
var you: String = ""
var them: String = ""
var steps: int = 0

const W := 300.0
const H := 230.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_d: float) -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	# Top right: the HUD has the top left, the planner has the bottom.
	position = Vector2(vp.x - W - 16.0, 16.0)
	size = Vector2(W, H)
	queue_redraw()


## A room's drawn place, from its plan coordinate.
func _pt(id: String) -> Vector2:
	var p: Vector2 = board.rooms[id]["plan"]
	return Vector2(30.0 + p.x * (W - 60.0), 18.0 + p.y * (H - 46.0))


func _draw() -> void:
	if board == null:
		return
	draw_rect(Rect2(Vector2(6, 7), Vector2(W, H)), Color(0.07, 0.06, 0.1, 0.3), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), PAPER, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), INK, false, 3.0)

	var font := ThemeDB.fallback_font
	# Corridors first, then rooms on top.
	for e in board.edges:
		var a := _pt(e[0])
		var b := _pt(e[1])
		draw_line(a, b, Color(0.13, 0.11, 0.18, 0.55), 2.0)
		var mid := (a + b) * 0.5
		draw_circle(mid, 7.0, PAPER)
		draw_string(font, mid + Vector2(-3.5, 4.0), str(e[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)

	for id in board.rooms:
		var c := _pt(id)
		var r := Rect2(c - Vector2(27, 11), Vector2(54, 22))
		var fill := Color(1, 1, 1, 0.7)
		if id == them:
			fill = Color(0.36, 0.5, 0.65, 0.8)
		elif reach.has(id):
			fill = Color(0.95, 0.85, 0.55, 0.95)
		draw_rect(r, fill, true)
		draw_rect(r, INK, false, 2.0)
		var label: String = board.rooms[id]["short"]
		draw_string(font, r.position + Vector2(5, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
		if reach.has(id) and id != you:
			draw_string(font, r.position + Vector2(r.size.x - 12, 15), str(reach[id]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)

	# Tokens: yours warm, theirs cool, same as the pips.
	if board.rooms.has(you):
		var c := _pt(you) + Vector2(-20, -16)
		draw_circle(c, 7.0, Color("c4614f"))
		draw_arc(c, 7.0, 0, TAU, 16, INK, 2.0)
	if board.rooms.has(them):
		var c := _pt(them) + Vector2(20, -16)
		draw_circle(c, 7.0, Color("5b7fa6"))
		draw_arc(c, 7.0, 0, TAU, 16, INK, 2.0)

	draw_string(font, Vector2(8, H - 8), "%d steps a move" % steps if steps > 0 else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.13, 0.11, 0.18, 0.7))
