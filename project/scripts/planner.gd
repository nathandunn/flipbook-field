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
## The player would rather walk to a station and press E.
signal manual()
## Pressed while a move is being walked: stop and hand the controls back.
signal took_over()

const PAPER := Color("fbf7ec")
const INK := Color("12101a")

## "off" | "offer" | "run"
var _mode: String = "off"

var _title: Label
var _sub: Label
var _hint: Label
var _box: VBoxContainer
var _panel_rect := Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_title = _label(24, INK)
	_sub = _label(15, Color(0.13, 0.11, 0.18, 0.85))
	_hint = _label(14, Color(0.13, 0.11, 0.18, 0.70))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)


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
	_button("Play it myself — walk to a station and press E", true).pressed.connect(_by_hand)
	_hint.text = "A card can be a slide at the rock, or spent to buy somebody who wants it."


func _pick(o: Dictionary) -> void:
	close()
	picked.emit(o)


func _by_hand() -> void:
	close()
	manual.emit()


# --- watching ----------------------------------------------------------------

## Slim bar shown while a move is walked: where we are, and one way out.
func running(step: int, total: int, text: String) -> void:
	_mode = "run"
	visible = true
	_title.text = text if total <= 1 else "Walking — %d of %d" % [step, total]
	_sub.text = ""
	_hint.text = ""
	_clear()
	_button("Take over — stop here and walk it yourself", true).pressed.connect(_take_over)


func _take_over() -> void:
	close()
	took_over.emit()


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
	b.add_theme_font_size_override("font_size", 14)
	b.custom_minimum_size = Vector2(560, 30)
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
	sb.set_content_margin_all(4)
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

	var w: float = minf(940.0, vp.x - 40.0)
	var pad := 20.0

	# Measured, not guessed: row height comes from the theme font and the card
	# margins, and a guessed height once left the last rows off the screen.
	var head := _title.get_minimum_size().y + 4.0 + _sub.get_minimum_size().y + 8.0
	var rows := _box.get_combined_minimum_size().y
	var foot := 0.0 if _mode == "run" else 28.0
	var h: float = minf(pad * 2.0 + head + rows + foot, vp.y - 44.0)
	_panel_rect = Rect2(
		Vector2(roundf(vp.x * 0.5 - w * 0.5), roundf(vp.y - h - 22.0)), Vector2(w, h)
	)

	var x := _panel_rect.position.x + pad
	var y := _panel_rect.position.y + pad

	_title.size = _title.get_minimum_size()
	_title.position = Vector2(x, y)
	y += _title.size.y + 4

	_sub.size = _sub.get_minimum_size()
	_sub.position = Vector2(x, y)
	y += _sub.size.y + 8

	_box.position = Vector2(x, y)
	_box.size = Vector2(_panel_rect.size.x - pad * 2.0, 0)
	for c in _box.get_children():
		(c as Control).custom_minimum_size.x = _panel_rect.size.x - pad * 2.0

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
