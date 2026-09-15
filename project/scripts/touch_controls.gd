## TouchControls — thumbstick + look-drag + a TALK button, for phones.
##
## Only appears when a touchscreen is present, so the desktop build is unchanged.
## The stick is "floating": it springs up wherever the thumb lands in the left
## zone rather than sitting in a fixed spot, which is the difference between a
## control you have to look at and one you don't.
class_name TouchControls
extends Control

const STICK_RADIUS := 92.0
const KNOB_RADIUS := 38.0
const DEAD_ZONE := 0.12
const LOOK_SENSITIVITY := 0.0042
const BUTTON_RADIUS := 52.0
const BUTTON_MARGIN := Vector2(34.0, 46.0)
## A touch that moves less than this and lifts quickly counts as a tap, not a drag.
const TAP_SLOP := 18.0
const TAP_TIME := 0.35

const PAPER := Color("fbf7ec")
const INK := Color("12101a")

var player: Player

var _enabled: bool = false
var _stick_touch: int = -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO

var _look_touch: int = -1
var _look_start := Vector2.ZERO
var _look_time: float = 0.0
var _look_moved: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_enabled = DisplayServer.is_touchscreen_available()
	visible = _enabled
	set_process_input(_enabled)
	set_process(_enabled)


func _button_centre() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(vp.x - BUTTON_MARGIN.x - BUTTON_RADIUS, vp.y - BUTTON_MARGIN.y - BUTTON_RADIUS)


func _in_stick_zone(p: Vector2) -> bool:
	var vp := get_viewport_rect().size
	return p.x < vp.x * 0.45 and p.y > vp.y * 0.28


func _input(event: InputEvent) -> void:
	if not _enabled or player == null:
		return

	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.distance_to(_button_centre()) <= BUTTON_RADIUS * 1.25:
				player.interact_pressed.emit()
				return
			if _stick_touch == -1 and _in_stick_zone(t.position):
				_stick_touch = t.index
				_stick_origin = t.position
				_stick_pos = t.position
			elif _look_touch == -1:
				_look_touch = t.index
				_look_start = t.position
				_look_time = 0.0
				_look_moved = 0.0
		else:
			if t.index == _stick_touch:
				_stick_touch = -1
				player.touch_move = Vector2.ZERO
			elif t.index == _look_touch:
				# A quick tap that didn't drag is "next line" — so you can advance
				# a conversation without hunting for the button.
				if _look_moved < TAP_SLOP and _look_time < TAP_TIME:
					player.interact_pressed.emit()
				_look_touch = -1
			queue_redraw()

	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_touch:
			var off := d.position - _stick_origin
			if off.length() > STICK_RADIUS:
				# Drag the origin along instead of clamping hard, so a thumb that
				# wanders doesn't lose the stick.
				_stick_origin = d.position - off.normalized() * STICK_RADIUS
				off = off.normalized() * STICK_RADIUS
			_stick_pos = _stick_origin + off

			var v := off / STICK_RADIUS
			player.touch_move = Vector2.ZERO if v.length() < DEAD_ZONE else v
			queue_redraw()
		elif d.index == _look_touch:
			_look_moved += d.relative.length()
			player.touch_look += d.relative * LOOK_SENSITIVITY


func _process(delta: float) -> void:
	if _look_touch != -1:
		_look_time += delta


func _draw() -> void:
	if not _enabled:
		return

	if _stick_touch != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(PAPER.r, PAPER.g, PAPER.b, 0.16))
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48, Color(INK.r, INK.g, INK.b, 0.5), 3.0, true)
		draw_circle(_stick_pos, KNOB_RADIUS, Color(PAPER.r, PAPER.g, PAPER.b, 0.75))
		draw_arc(_stick_pos, KNOB_RADIUS, 0.0, TAU, 32, INK, 3.0, true)

	var c := _button_centre()
	draw_circle(c, BUTTON_RADIUS, Color(PAPER.r, PAPER.g, PAPER.b, 0.78))
	draw_arc(c, BUTTON_RADIUS, 0.0, TAU, 40, INK, 4.0, true)
	var font := ThemeDB.fallback_font
	if font:
		var label := "TALK"
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
		draw_string(font, c + Vector2(-w * 0.5, 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
