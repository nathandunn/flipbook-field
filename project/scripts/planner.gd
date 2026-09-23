## Planner — your hand, laid out as cards, one move at a time.
##
## Each move is a choice from a short list where every card says what it will
## do right now: which desk, how many in the room want that; the stream and how
## many are curious there; who you could buy and with what; or present. The
## other side's last move can grey a card out. Perfect information about the
## board, hidden information about the hands - which is the card-game shape.
##
## Pure UI. It draws what [Game] hands it and reports which card was pressed.
class_name Planner
extends Control

## A card was pressed. [param opt] is the option dictionary as it was offered.
signal picked(opt: Dictionary)

const PAPER := Color("fbf7ec")
const INK := Color("12101a")

## "off" | "offer" | "run"
var _mode: String = "off"

var _title: Label
var _sub: Label
var _hint: Label
var _box: VBoxContainer
## The rows scroll when there are more cards than window: a phone in
## landscape gets the same cards as a desktop, just with a thumb involved.
var _scroll: ScrollContainer
var _panel_rect := Rect2()
## Room left for the roster on the left and the floor plan at the top right.
var left_margin: float = 0.0
var top_margin: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_title = _label(24, INK)
	_sub = _label(15, Color(0.13, 0.11, 0.18, 0.85))
	_hint = _label(14, Color(0.13, 0.11, 0.18, 0.70))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# --- offering a move ---------------------------------------------------------

## [param opts] is a list of dictionaries with at least:
##   label (String), sub (String), enabled (bool), why (String, when disabled)
## Anything else on the dictionary comes back untouched in [signal picked].
func offer(round_no: int, move_no: int, moves: int, opts: Array, hand_line: String) -> void:
	_mode = "offer"
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = "Round %d  ·  move %d of %d" % [round_no, move_no, moves]
	_sub.text = hand_line
	_clear()
	for o in opts:
		var text: String = "%s   —   %s" % [o["label"], o["sub"]]
		if not o.get("enabled", true):
			text = "%s   —   %s" % [o["label"], o.get("why", "not now")]
		var b := _button(text, o.get("enabled", true))
		if o.get("enabled", true):
			b.pressed.connect(_pick.bind(o))
	_hint.text = "A card can be a slide at the rock, or spent to buy somebody who wants it."


func _pick(o: Dictionary) -> void:
	close()
	picked.emit(o)


# --- watching ----------------------------------------------------------------

## Slim bar shown while a move is walked: where we are.
func running(step: int, total: int, text: String) -> void:
	_mode = "run"
	visible = true
	_title.text = text if total <= 1 else "Walking — %d of %d" % [step, total]
	_sub.text = ""
	_hint.text = ""
	_clear()


func close() -> void:
	_mode = "off"
	visible = false
	_clear()


# --- widgets -----------------------------------------------------------------

func _clear() -> void:
	for c in _box.get_children():
		# Removed before freeing, not just queued: a rebuild happens inside one
		# frame and a deferred free would leave the old row still taking space.
		_box.remove_child(c)
		c.queue_free()


## Paper cards with an ink border, matching the talk panel.
func _button(text: String, enabled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(560, 26)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	var face := INK if enabled else Color(0.13, 0.11, 0.18, 0.45)
	b.add_theme_color_override("font_color", face)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_disabled_color", face)
	b.add_theme_stylebox_override("normal", _card(Color(1, 1, 1, 0.55)))
	b.add_theme_stylebox_override("hover", _card(Color(1, 1, 1, 0.95)))
	b.add_theme_stylebox_override("pressed", _card(Color(0.13, 0.11, 0.18, 0.9)))
	b.add_theme_stylebox_override("disabled", _card(Color(1, 1, 1, 0.22)))
	_box.add_child(b)
	return b


func _card(fill: Color, left: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(3)
	# Kept tight: with the tricks on the table this can be fifteen rows, and
	# they all have to fit a short browser window.
	sb.set_content_margin_all(3)
	sb.content_margin_left = left
	return sb


func _process(_delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size

	# Cover the screen explicitly rather than trusting the anchor preset. A
	# Control added from code can end up 0x0, and a 0x0 panel with
	# MOUSE_FILTER_STOP blocks nothing: a click that misses a row falls straight
	# through to the player, which captures the pointer and kills the panel.
	position = Vector2.ZERO
	size = vp

	var lo: float = left_margin + 12.0
	var w: float = minf(940.0, vp.x - lo - 20.0)
	var pad := 20.0

	# Measured, not guessed: row height comes from the theme font and the card
	# margins, and a guessed height once left the last rows off the screen.
	var head := _title.get_minimum_size().y + 4.0 + _sub.get_minimum_size().y + 8.0
	var rows := _box.get_combined_minimum_size().y
	var foot := 0.0 if _mode == "run" else 28.0
	var h: float = minf(pad * 2.0 + head + rows + foot, vp.y - top_margin - 22.0 - 12.0)
	_panel_rect = Rect2(
		Vector2(roundf(lo + (vp.x - lo - 20.0 - w) * 0.5), roundf(vp.y - h - 22.0)), Vector2(w, h)
	)

	var x := _panel_rect.position.x + pad
	var y := _panel_rect.position.y + pad

	_title.size = _title.get_minimum_size()
	_title.position = Vector2(x, y)
	y += _title.size.y + 4

	_sub.size = _sub.get_minimum_size()
	_sub.position = Vector2(x, y)
	y += _sub.size.y + 8

	# The scroll area gets whatever is left between the header and the hint.
	var avail: float = _panel_rect.end.y - pad - foot - y
	_scroll.position = Vector2(x, y)
	_scroll.size = Vector2(_panel_rect.size.x - pad * 2.0, maxf(avail, 30.0))
	for c in _box.get_children():
		(c as Control).custom_minimum_size.x = _panel_rect.size.x - pad * 2.0 - 12.0

	_hint.size = Vector2(_panel_rect.size.x - pad * 2.0, 22)
	_hint.position = Vector2(x, _panel_rect.end.y - pad - 16.0)

	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.06, 0.1, 0.18), true)
	draw_rect(
		Rect2(_panel_rect.position + Vector2(8, 9), _panel_rect.size),
		Color(0.07, 0.06, 0.1, 0.30), true
	)
	draw_rect(_panel_rect, PAPER, true)
	draw_rect(_panel_rect, INK, false, 3.0)
