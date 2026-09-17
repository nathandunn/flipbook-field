## Dialogue — comic speech balloon drawn in screen space.
##
## The balloon is anchored to the speaker's projected head position and grows a
## tail toward them, so in a group you can always tell who has the floor without
## a portrait or a name plate doing the work. Everything is drawn in [method _draw]
## rather than assembled from StyleBoxes because the tail has to move.
class_name Dialogue
extends Control

signal finished

const BUBBLE_MAX_W := 430.0
const BUBBLE_MIN_W := 150.0
const PAD := Vector2(24, 18)
const BORDER := 4.0
const PAPER := Color("fbf7ec")
const INK := Color("12101a")
const SHADOW := Color(0.07, 0.06, 0.1, 0.22)
const TAIL_HALF_BASE := 16.0
const GAP_ABOVE_HEAD := 26.0

@onready var body: Label = $Body
@onready var speaker_tag: Label = $Speaker
@onready var prompt: Label = $Prompt

var camera: Camera3D

var _lines: Array[Dictionary] = []
var _idx: int = -1
var _active: bool = false

var _speaker_node: Node3D = null
var _bubble := Rect2()
var _tag_rect := Rect2()
var _tail_apex := Vector2.ZERO
var _tail_ok: bool = false
var _blink: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.visible = false
	speaker_tag.visible = false
	prompt.visible = false


func is_active() -> bool:
	return _active


## [param lines] is an array of { who: Node3D, name: String, text: String }.
func start(lines: Array[Dictionary]) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_idx = -1
	_active = true
	body.visible = true
	speaker_tag.visible = true
	prompt.visible = false
	advance()


func advance() -> void:
	if not _active:
		return
	_idx += 1
	if _idx >= _lines.size():
		stop()
		return

	var line: Dictionary = _lines[_idx]
	_speaker_node = line.get("who", null)
	speaker_tag.text = str(line.get("name", ""))
	body.text = str(line.get("text", ""))
	body.visible_ratio = 0.0

	var dur: float = clampf(body.text.length() * 0.022, 0.5, 2.6)
	var tw := create_tween()
	tw.tween_property(body, "visible_ratio", 1.0, dur)

	if _speaker_node is Person:
		(_speaker_node as Person).start_talking(dur + 1.2)


## True if the current line was still typing itself out (in which case the first
## press completes it rather than skipping the line).
func skip_typing() -> bool:
	if _active and body.visible_ratio < 1.0:
		body.visible_ratio = 1.0
		return true
	return false


func stop() -> void:
	_active = false
	_speaker_node = null
	body.visible = false
	speaker_tag.visible = false
	queue_redraw()
	finished.emit()


func show_prompt(text: String) -> void:
	prompt.text = text
	prompt.visible = true


func hide_prompt() -> void:
	prompt.visible = false


func _process(delta: float) -> void:
	_blink += delta
	_layout_prompt()
	if _active:
		_layout()
	queue_redraw()


func _layout_prompt() -> void:
	if not prompt.visible:
		return
	prompt.size = prompt.get_minimum_size()
	var vp := get_viewport_rect().size
	prompt.position = Vector2(
		roundf(vp.x * 0.5 - prompt.size.x * 0.5),
		roundf(vp.y - 92.0)
	)


func _layout() -> void:
	var vp := get_viewport_rect().size

	# Text block size. Label re-wraps on the frame after text is set, so this
	# settles one frame late — invisible at 60 fps, and worth it to avoid
	# reimplementing wrapping.
	# Shrink-to-fit: a one-line quip in a 430 px balloon looks like a UI bug, and a
	# wide balloon covers the very group you are talking to.
	var font := body.get_theme_font("font")
	var font_size := body.get_theme_font_size("font_size")
	var natural := BUBBLE_MAX_W
	if font:
		natural = font.get_string_size(
			body.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x + 2.0
	# Cap against the viewport too — 430 px is wider than a phone in portrait.
	var max_w := minf(BUBBLE_MAX_W, maxf(BUBBLE_MIN_W, vp.x - 56.0))
	var text_w: float = clampf(natural, minf(BUBBLE_MIN_W, max_w), max_w)

	body.size.x = text_w
	var line_h: float = body.get_line_height()
	var text_h: float = maxf(line_h, body.get_line_count() * line_h)

	var bubble_size := Vector2(text_w, text_h) + PAD * 2.0

	# Where is the speaker on screen?
	var anchor_screen := Vector2(vp.x * 0.5, vp.y * 0.62)
	_tail_ok = false
	if camera and is_instance_valid(_speaker_node):
		var world_point: Vector3 = _speaker_node.global_position + Vector3(0, 1.7, 0)
		if _speaker_node.has_method("speech_anchor"):
			world_point = _speaker_node.call("speech_anchor")
		if not camera.is_position_behind(world_point):
			anchor_screen = camera.unproject_position(world_point)
			_tail_ok = true

	var pos := Vector2(
		anchor_screen.x - bubble_size.x * 0.5,
		anchor_screen.y - GAP_ABOVE_HEAD - bubble_size.y
	)
	var margin := 26.0
	pos.x = clampf(pos.x, margin, maxf(margin, vp.x - bubble_size.x - margin))
	pos.y = clampf(pos.y, margin + 26.0, maxf(margin, vp.y - bubble_size.y - margin))

	_bubble = Rect2(pos, bubble_size)
	_tail_apex = anchor_screen

	body.position = pos + PAD
	body.size = Vector2(text_w, text_h)

	var tag_size: Vector2 = speaker_tag.get_minimum_size() + Vector2(18, 6)
	speaker_tag.size = speaker_tag.get_minimum_size()
	_tag_rect = Rect2(pos + Vector2(14, -tag_size.y + 2), tag_size)
	speaker_tag.position = _tag_rect.position + Vector2(9, 3)


func _draw() -> void:
	if prompt.visible:
		var pr := Rect2(prompt.position - Vector2(14, 8), prompt.size + Vector2(28, 16))
		draw_rect(pr, Color(0.07, 0.06, 0.1, 0.8), true)
		draw_rect(pr, PAPER, false, 2.0)

	if not _active:
		return

	# Tail base sits on the bubble's bottom edge, nudged toward the speaker.
	var base_x := clampf(
		_tail_apex.x,
		_bubble.position.x + TAIL_HALF_BASE + BORDER,
		_bubble.end.x - TAIL_HALF_BASE - BORDER
	)
	var base_y := _bubble.end.y
	var base_l := Vector2(base_x - TAIL_HALF_BASE, base_y)
	var base_r := Vector2(base_x + TAIL_HALF_BASE, base_y)
	var apex := _tail_apex
	# If the speaker is above the balloon, fold the tail back down so it never
	# stabs upward through the text.
	if apex.y < base_y + 12.0:
		apex = Vector2(base_x, base_y + 26.0)

	draw_rect(Rect2(_bubble.position + Vector2(6, 7), _bubble.size), SHADOW, true)
	draw_rect(_bubble, PAPER, true)

	if _tail_ok:
		draw_colored_polygon(PackedVector2Array([base_l, base_r, apex]), PAPER)

	draw_rect(_bubble, INK, false, BORDER)

	if _tail_ok:
		# Erase the border where the tail joins, then ink the tail's two sides.
		draw_line(base_l + Vector2(BORDER, 0), base_r - Vector2(BORDER, 0), PAPER, BORDER + 2.0)
		draw_line(base_l, apex, INK, BORDER)
		draw_line(apex, base_r, INK, BORDER)

	# Speaker name tag: ink bar with reversed-out text.
	draw_rect(_tag_rect, INK, true)

	# Continue caret.
	if body.visible_ratio >= 1.0 and fmod(_blink, 1.0) < 0.6:
		var c := Vector2(_bubble.end.x - 22.0, _bubble.end.y - 16.0)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-7, -5), c + Vector2(7, -5), c + Vector2(0, 5)
		]), INK)
