## Presentation — the three-slide talk, the hecklers, and the scoreboard.
##
## Pure UI and arithmetic: it never touches the world. It is handed an audience
## and a satchel of props, and it emits a result that [Game] applies.
class_name Presentation
extends Control

signal finished(result: Dictionary)
## Emitted when the end-of-round card is dismissed. [param again] is true when the
## match is over and the player asked for a rematch.
signal round_closed(again: bool)

const PAPER := Color("fbf7ec")
const INK := Color("12101a")
const GOOD := Color("7a9b6e")
const BAD := Color("c4614f")

var _side: int = Arch.Side.PLAYER
var _props: Array = []
var _audience: Array = []      ## Array[Person]
var _spectators: Array = []    ## Array[Person] - curious neutrals, the prize

var _slide_idx: int = 0
var _claps: float = 0.0
var _boos: float = 0.0
var _played: Array = []
var _lost_follower: Person = null

var _title: Label
var _sub: Label
var _tally: Label
var _log: Label
var _box: VBoxContainer
var _panel_rect := Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_title = _label(28, INK)
	_sub = _label(17, Color(0.13, 0.11, 0.18, 0.85))
	_tally = _label(20, INK)
	_log = _label(15, Color(0.13, 0.11, 0.18, 0.70))
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## [param audience] are the people who will clap or boo; [param spectators] are
## curious neutrals who convert on the claps-to-boos ratio.
func begin(side: int, props: Array, audience: Array, spectators: Array) -> void:
	_side = side
	_props = props.duplicate()
	_audience = audience
	_spectators = spectators
	_slide_idx = 0
	_claps = 0.0
	_boos = 0.0
	_played.clear()
	_lost_follower = null

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if side == Arch.Side.PLAYER:
		_ask_slide()
	else:
		_auto_run()


# --- player flow -------------------------------------------------------------

func _ask_slide() -> void:
	if _slide_idx >= Arch.SLIDES_PER_TALK or _props.is_empty():
		_wrap_up()
		return

	_title.text = "Slide %d of %d" % [_slide_idx + 1, Arch.SLIDES_PER_TALK]
	_sub.text = _crowd_line()
	_refresh_tally()
	_clear_buttons()

	for i in range(_props.size()):
		var p: Dictionary = _props[i]
		var want := _wanting(p["taste"])
		var b := _button("%s  —  %s   (%d in the crowd want %s)" % [
			p["name"], Arch.TASTE_NAME[p["taste"]], want, Arch.TASTE_NAME[p["taste"]]
		])
		b.pressed.connect(_on_slide_picked.bind(i))


func _on_slide_picked(i: int) -> void:
	if i < 0 or i >= _props.size():
		return
	var p: Dictionary = _props[i]
	_props.remove_at(i)
	_played.append(p)

	var res := _score_slide(p["taste"])
	_claps += res[0]
	_boos += res[1]
	_slide_idx += 1

	_log.text = "%s landed: +%d claps, +%d boos." % [p["name"], int(res[0]), int(res[1])]

	# Heckle between slides, never after the last one - the talk should end on
	# your material, not on somebody shouting.
	if _slide_idx < Arch.SLIDES_PER_TALK and _hecklers() > 0:
		_ask_heckle()
	else:
		_ask_slide()


func _ask_heckle() -> void:
	_title.text = "Heckler!"
	_sub.text = "Someone at the back is holding a fistful of pinecones."
	_refresh_tally()
	_clear_buttons()

	_button("Ignore it  —  they get a laugh, you keep your nerve").pressed.connect(
		_on_heckle.bind(false)
	)
	_button("Clap back  —  land it and the room roars, miss and you lose someone").pressed.connect(
		_on_heckle.bind(true)
	)


func _on_heckle(clap_back: bool) -> void:
	if not clap_back:
		_boos += 3.0
		_log.text = "You let it go. Scattered laughter. +3 boos."
		_ask_slide()
		return

	# Lovers in the room are the ones who laugh first, which is what makes a
	# comeback land. Every lover is a better chance.
	var lovers := 0
	for p in _audience:
		if p.kind == Arch.Kind.LOVER:
			lovers += 1
	var chance: float = clampf(0.45 + lovers * 0.12, 0.0, 0.9)

	if randf() < chance:
		_claps += 9.0
		_log.text = "It lands. The room roars. +9 claps."
	else:
		_boos += 6.0
		_log.text = "It does not land. +6 boos, and somebody quietly leaves."
		_lost_follower = _pick_flippable()
	_ask_slide()


# --- nemesis flow ------------------------------------------------------------

func _auto_run() -> void:
	_title.text = "Their turn at the rock"
	_clear_buttons()
	_props.shuffle()
	for i in range(mini(Arch.SLIDES_PER_TALK, _props.size())):
		var p: Dictionary = _props[i]
		_played.append(p)
		var res := _score_slide(p["taste"])
		_claps += res[0]
		_boos += res[1]
	_sub.text = _crowd_line()
	_refresh_tally()
	_log.text = "They got through it."
	_clear_buttons()
	_button("See the numbers").pressed.connect(_wrap_up)


# --- arithmetic --------------------------------------------------------------

## How many people in the crowd were hoping for this kind of slide.
func _wanting(taste: int) -> int:
	var n := 0
	for p in _audience:
		if not Arch.boos(p.kind) and p.taste == taste:
			n += 1
	for p in _spectators:
		if p.taste == taste:
			n += 1
	return n


func _hecklers() -> int:
	var n := 0
	for p in _audience:
		if Arch.boos(p.kind):
			n += 1
	return n


## Returns [claps, boos] for one slide.
func _score_slide(taste: int) -> Array:
	var claps := 0.0
	var boos := 0.0
	for p in _audience:
		if Arch.boos(p.kind):
			boos += Arch.BOO_BULLY if p.kind == Arch.Kind.BULLY else Arch.BOO_BASE
		elif Arch.claps(p.kind):
			claps += Arch.CLAP_MATCH if p.taste == taste else Arch.CLAP_LOYAL
		# Wage slaves attend and say nothing. That is the joke and the mechanic:
		# they are crowd size, which is what draws spectators, and nothing else.
	for p in _spectators:
		if p.taste == taste:
			claps += 1.0
	return [claps, boos]


func _pick_flippable() -> Person:
	var pool: Array = []
	for p in _audience:
		if Arch.flippable(p.kind) and not p.resolve:
			pool.append(p)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


func _crowd_line() -> String:
	var claps_n := 0
	var quiet := 0
	var boo_n := _hecklers()
	for p in _audience:
		if Arch.claps(p.kind):
			claps_n += 1
		elif p.kind == Arch.Kind.WAGE_SLAVE:
			quiet += 1
	return "%d on your side · %d just here · %d here to boo · %d watching from the grass" % [
		claps_n, quiet, boo_n, _spectators.size()
	]


func _refresh_tally() -> void:
	_tally.text = "claps %d          boos %d" % [int(_claps), int(_boos)]


# --- wrap up -----------------------------------------------------------------

func _wrap_up() -> void:
	var total: float = maxf(_claps + _boos, 1.0)
	var ratio: float = _claps / total

	# Spectators convert on how the room sounded, not on what you said.
	var converted: int = int(floor(float(_spectators.size()) * ratio))
	var won: Array = []
	var pool := _spectators.duplicate()
	pool.shuffle()
	for i in range(mini(converted, pool.size())):
		won.append(pool[i])

	# Boo pressure, net of applause, peels people off. This is the whole reason
	# haters matter: without it, boos are decoration and a lead never reverses.
	var pressure: float = _boos - _claps * 0.6
	var flips: int = int(floor(maxf(pressure, 0.0) / 14.0))
	var lost: Array = []
	var shields := 0
	for p in _audience:
		if p.kind == Arch.Kind.LOVER:
			shields += 1
	for i in range(flips):
		if shields > 0:
			shields -= 1
			continue
		var victim := _pick_flippable()
		if victim and not lost.has(victim):
			lost.append(victim)

	# A bully in the room always takes one, shields or not - that is what they
	# are for.
	for p in _audience:
		if p.kind == Arch.Kind.BULLY:
			var victim := _pick_flippable()
			if victim and not lost.has(victim):
				lost.append(victim)
			break

	if _lost_follower and not lost.has(_lost_follower):
		lost.append(_lost_follower)

	var result := {
		"side": _side,
		"claps": int(_claps),
		"boos": int(_boos),
		"won": won,
		"lost": lost,
		"slides": _played,
	}
	_show_card(result)


func _show_card(result: Dictionary) -> void:
	var who := "You" if _side == Arch.Side.PLAYER else "Your nemesis"
	_title.text = "%s finished." % who
	var verdict := "The rock has seen worse."
	var r: float = float(result["claps"]) / maxf(float(result["claps"] + result["boos"]), 1.0)
	if r > 0.8:
		verdict = "They are still clapping."
	elif r > 0.6:
		verdict = "That went well."
	elif r < 0.35:
		verdict = "That was rough."
	_sub.text = verdict
	_tally.text = "claps %d     boos %d     won over %d     lost %d" % [
		result["claps"], result["boos"], result["won"].size(), result["lost"].size()
	]

	var names: Array[String] = []
	for p in result["slides"]:
		names.append(str(p["name"]))
	_log.text = "Slides: " + (", ".join(names) if names.size() > 0 else "none")

	_clear_buttons()
	_button("Continue").pressed.connect(_close.bind(result))


func _close(result: Dictionary) -> void:
	visible = false
	_clear_buttons()
	finished.emit(result)


# --- end-of-round card -------------------------------------------------------

## The head-to-head readout after both sides have presented: claps, boos, and
## people gained, side by side, which is the only way to tell whether a loud
## round was actually a good one.
func show_round(rno: int, total: int, you: Dictionary, them: Dictionary, final: bool) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_title.text = "Match over" if final else "End of round %d of %d" % [rno, total]

	var dp: int = int(you["people"]) - int(them["people"])
	if final:
		if dp > 0:
			_sub.text = "You win the office by %d." % dp
		elif dp < 0:
			_sub.text = "They win the office by %d." % -dp
		else:
			_sub.text = "Dead heat on people — claps decide it."
	else:
		if dp > 0:
			_sub.text = "You are %d ahead going into the next round." % dp
		elif dp < 0:
			_sub.text = "You are %d behind. The rock is still there." % -dp
		else:
			_sub.text = "Level."

	_tally.text = "YOU     %d people   ·   %d claps   ·   %d boos   ·   %+d this round\nTHEM   %d people   ·   %d claps   ·   %d boos   ·   %+d this round" % [
		you["people"], you["claps"], you["boos"], int(you["gained"]) - int(you["lost"]),
		them["people"], them["claps"], them["boos"], int(them["gained"]) - int(them["lost"]),
	]

	var notes: Array[String] = []
	if int(you["lost"]) > 0:
		notes.append("%d of yours walked out" % you["lost"])
	if int(them["lost"]) > 0:
		notes.append("%d of theirs walked out" % them["lost"])
	if int(you["boos"]) > int(you["claps"]):
		notes.append("you were booed more than clapped — expect to lose people")
	_log.text = ("Notes: " + ", ".join(notes) + ".") if notes.size() > 0 else ""

	_clear_buttons()
	if final:
		_button("Play again").pressed.connect(_close_round.bind(true))
	else:
		_button("Next round").pressed.connect(_close_round.bind(false))


func _close_round(again: bool) -> void:
	visible = false
	_clear_buttons()
	round_closed.emit(again)


# --- widgets -----------------------------------------------------------------

func _clear_buttons() -> void:
	for c in _box.get_children():
		c.queue_free()


## Buttons styled as paper cards with an ink border, so the panel reads as part
## of the same printed world rather than a dark-mode dialog dropped on top of it.
func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(560, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_constant_override("h_separation", 12)
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
	sb.set_content_margin_all(12)
	sb.content_margin_left = 18
	return sb


func _process(_delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	# A bottom bar, not a centred box: the crowd line and the slide choices are
	# about who turned up, so the stage has to stay visible while you read them.
	var w: float = minf(920.0, vp.x - 40.0)
	var h: float = minf(330.0, vp.y * 0.52)
	_panel_rect = Rect2(
		Vector2(roundf(vp.x * 0.5 - w * 0.5), roundf(vp.y - h - 22.0)), Vector2(w, h)
	)

	var pad := 22.0
	var x := _panel_rect.position.x + pad
	var y := _panel_rect.position.y + pad

	_title.size = _title.get_minimum_size()
	_title.position = Vector2(x, y)
	y += _title.size.y + 6

	_sub.size = _sub.get_minimum_size()
	_sub.position = Vector2(x, y)
	y += _sub.size.y + 10

	_tally.size = _tally.get_minimum_size()
	_tally.position = Vector2(x, y)
	y += _tally.size.y + 12

	_box.position = Vector2(x, y)
	_box.size = Vector2(_panel_rect.size.x - pad * 2.0, 0)
	for c in _box.get_children():
		(c as Control).custom_minimum_size.x = _panel_rect.size.x - pad * 2.0

	_log.size = Vector2(_panel_rect.size.x - pad * 2.0, 40)
	_log.position = Vector2(x, _panel_rect.end.y - pad - 34)

	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	# Dim only the strip behind the panel; the stage above stays fully lit.
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.06, 0.1, 0.18), true)
	# Drop shadow then paper, the same treatment as a speech balloon.
	draw_rect(Rect2(_panel_rect.position + Vector2(8, 9), _panel_rect.size), Color(0.07, 0.06, 0.1, 0.30), true)
	draw_rect(_panel_rect, PAPER, true)
	draw_rect(_panel_rect, INK, false, 4.0)
