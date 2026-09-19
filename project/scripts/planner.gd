## Planner — queue the turn's actions up front, then watch the route play out.
##
## The turn's real decision is where in the funnel to spend, and that decision is
## made before you take a single step. Committing to a route and then watching it
## execute makes the decision legible: you see what four actions actually cost in
## walking, and you see the board react without your hands on it. Walking it by
## hand is still there — this is a second way to take a turn, not a replacement.
##
## Pure UI. It knows the names of the three verbs and nothing else; [Game] owns
## what they do.
class_name Planner
extends Control

## [param plan] is an ordered Array of [enum Office.St] values with the skipped
## slots already removed. An empty plan means "go straight to the rock".
signal plan_ready(plan: Array)
## The player would rather drive.
signal manual()
## Pressed mid-route: stop the autopilot, hand back the controls, keep whatever
## actions are left.
signal took_over()

const PAPER := Color("fbf7ec")
const INK := Color("12101a")

## What a slot cycles through on each tap. -1 is "skip this action".
const CYCLE: Array = [Office.St.DESK, Office.St.STREAM, Office.St.BREAK, -1]
const SKIP := -1

var _slots: Array = []
## "off" | "plan" | "run"
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

	_title = _label(26, INK)
	_sub = _label(16, Color(0.13, 0.11, 0.18, 0.85))
	_hint = _label(15, Color(0.13, 0.11, 0.18, 0.70))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 7)
	add_child(_box)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# --- the three verbs, as the planner names them ------------------------------

static func verb_name(v: int) -> String:
	match v:
		Office.St.DESK:
			return "Desk"
		Office.St.STREAM:
			return "Stream"
		Office.St.BREAK:
			return "Break room"
	return "Skip"


static func verb_blurb(v: int) -> String:
	match v:
		Office.St.DESK:
			return "take a prop; the three nearest neutrals get curious"
		Office.St.STREAM:
			return "close curious neutrals standing nearby into followers"
		Office.St.BREAK:
			return "rally: a wage slave drifts in, your people hold their nerve"
	return "spend nothing and keep the walk short"


# --- planning ----------------------------------------------------------------

## Gather, gather, close, rally — the same legible line the nemesis plays, so
## pressing Go without touching anything is a real turn rather than a trap.
func _default_plan(budget: int) -> Array:
	var base: Array = [Office.St.DESK, Office.St.DESK, Office.St.STREAM, Office.St.BREAK]
	var out: Array = []
	for i in range(budget):
		out.append(base[i] if i < base.size() else Office.St.DESK)
	return out


func open(round_no: int, budget: int) -> void:
	_mode = "plan"
	if _slots.size() != budget:
		_slots = _default_plan(budget)
	visible = true
	# The pointer is captured for camera look during play; the planner needs it back.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = "Round %d — plan your turn" % round_no
	_sub.text = "Tap a line to change it, then watch it play out."
	_rebuild()


func _rebuild() -> void:
	_clear()
	for i in range(_slots.size()):
		var v: int = int(_slots[i])
		var b := _button("%d.    %s  —  %s" % [i + 1, verb_name(v), verb_blurb(v)])
		b.pressed.connect(_cycle.bind(i))
	_button("GO  —  walk the route, then present").pressed.connect(_go)
	_button("Play it myself").pressed.connect(_by_hand)
	_hint.text = _route_line()


func _route_line() -> String:
	var steps: Array[String] = []
	for v in _slots:
		if int(v) != SKIP:
			steps.append(verb_name(int(v)).to_lower())
	steps.append("the rock")
	var spent := _slots.size()
	for v in _slots:
		if int(v) == SKIP:
			spent -= 1
	return "Route:  %s        %d of %d actions spent" % [
		" >  ".join(steps), spent, _slots.size()
	]


func _cycle(i: int) -> void:
	var at: int = CYCLE.find(int(_slots[i]))
	_slots[i] = CYCLE[(at + 1) % CYCLE.size()]
	_rebuild()


func _go() -> void:
	var plan: Array = []
	for v in _slots:
		if int(v) != SKIP:
			plan.append(int(v))
	_clear()
	plan_ready.emit(plan)


func _by_hand() -> void:
	close()
	manual.emit()


# --- watching ----------------------------------------------------------------

## Slim bar shown while the route plays: where we are, and one way out.
func running(step: int, total: int, text: String) -> void:
	_mode = "run"
	visible = true
	_title.text = "Walking the route — %d of %d" % [step, total]
	_sub.text = text
	_hint.text = ""
	_clear()
	_button("Take over — stop here, keep what is left").pressed.connect(_take_over)


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


## Paper cards with an ink border, matching the talk panel, so the whole UI reads
## as printed on the same page as the world.
func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size = Vector2(560, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_stylebox_override("normal", _card(Color(1, 1, 1, 0.55)))
	b.add_theme_stylebox_override("hover", _card(Color(1, 1, 1, 0.95)))
	b.add_theme_stylebox_override("pressed", _card(Color(0.13, 0.11, 0.18, 0.9)))
	_box.add_child(b)
	return b


func _card(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(3)
	# Kept tight on purpose: six rows of cards have to fit a short browser window
	# without the last two sliding off the bottom of the screen.
	sb.set_content_margin_all(6)
	sb.content_margin_left = 16
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

	# A bottom bar rather than a centred dialog: the office has to stay visible
	# while you plan a route through it.
	var w: float = minf(920.0, vp.x - 40.0)
	var pad := 22.0

	# Measured, not guessed. Button height comes from the theme font and the card
	# margins, so a hardcoded row height leaves the last rows hanging off the
	# bottom of the screen where they cannot be clicked at all.
	var head := _title.get_minimum_size().y + 4.0 + _sub.get_minimum_size().y + 10.0
	var rows := _box.get_combined_minimum_size().y
	var foot := 0.0 if _mode == "run" else 30.0
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
	y += _sub.size.y + 10

	_box.position = Vector2(x, y)
	_box.size = Vector2(_panel_rect.size.x - pad * 2.0, 0)
	for c in _box.get_children():
		(c as Control).custom_minimum_size.x = _panel_rect.size.x - pad * 2.0

	_hint.size = Vector2(_panel_rect.size.x - pad * 2.0, 22)
	_hint.position = Vector2(x, _panel_rect.end.y - pad - 18.0)

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
