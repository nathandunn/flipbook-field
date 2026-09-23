## Setup — who you are, what you are good at, who is coming with you.
##
## Three short pages on one paper panel: pick a job (its costume, its taste,
## its upside and its downside), buy and sell stat points, then pick exactly
## four colleagues - one of each job, not your own. The nemesis is dealt the
## same, so the party is a plan, not a head start.
##
## Pure UI, same as the planner: it draws, it reports.
class_name Setup
extends Control

## Setup finished. [param config] = { role, stats: [c, g, h, r], party: [roles] }
signal done(config: Dictionary)

const PAPER := Color("fbf7ec")
const INK := Color("12101a")

var role: int = Arch.Role.ENGINEER
var stats: Array[int] = [0, 0, 0, 0]
var party: Array[int] = []
var _page: int = 0

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
	_sub = _label(15, Color(0.13, 0.11, 0.18, 0.85))
	_hint = _label(14, Color(0.13, 0.11, 0.18, 0.70))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 5)
	add_child(_box)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_page = 0
	_show()


func _show() -> void:
	_clear()
	match _page:
		0:
			_title.text = "Who are you?"
			_sub.text = "Every job has an upside and a downside - both on while that job is on your side."
			for r in Arch.PLAYABLE:
				var b := _button("%s   +  %s   -  %s" % [Arch.ROLE_NAME[r], Arch.ROLE_PERK[r], Arch.ROLE_DOWNSIDE[r]], true)
				b.pressed.connect(_pick_role.bind(r))
			_hint.text = "Your nemesis is dealt a job the same way."
		1:
			_title.text = "%s. Buy and sell your stats." % Arch.ROLE_NAME[role]
			_sub.text = "%d point%s to spend. Sell a point below your job's start to spend it elsewhere." % [_left(), "" if _left() == 1 else "s"]
			for i in range(4):
				_stat_row(i)
			var go := _button("Done  -  every point spent" if _left() == 0 else "Spend every point to go on (%d left)" % _left(), _left() == 0)
			go.pressed.connect(_next)
			_hint.text = "Charm, guile, hustle and grit each change a number you will see on a card."
		2:
			_title.text = "Pick your party: exactly %d, one of each job" % Arch.PARTY_SIZE
			_sub.text = "Picked %d of %d: %s" % [party.size(), Arch.PARTY_SIZE, _party_line()]
			for r in Arch.PLAYABLE:
				if r == role:
					_button("%s   -  that is you" % Arch.ROLE_NAME[r], false)
					continue
				var on := party.has(r)
				var b := _button("%s %s   +  %s   -  %s" % ["[x]" if on else "[  ]", Arch.ROLE_NAME[r], Arch.PERK_SHORT[r], Arch.DOWN_SHORT[r]],
					on or party.size() < Arch.PARTY_SIZE)
				b.pressed.connect(_toggle_party.bind(r))
			var go := _button("Begin" if party.size() == Arch.PARTY_SIZE else "Pick %d more" % (Arch.PARTY_SIZE - party.size()),
				party.size() == Arch.PARTY_SIZE)
			go.pressed.connect(_finish)
			_hint.text = "Tap a job to add or drop it. The nemesis gets %d too, none twice." % Arch.PARTY_SIZE


## One stat: its pips, what it does, and a sell and a buy button.
func _stat_row(i: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var minus := _small("-  sell", stats[i] > 0)
	minus.pressed.connect(_sell.bind(i))
	row.add_child(minus)
	var plus := _small("+  buy", _left() > 0 and stats[i] < Arch.STAT_MAX)
	plus.pressed.connect(_buy.bind(i))
	row.add_child(plus)
	var l := Label.new()
	l.text = "%s  %s   %s" % [Arch.STAT_NAME[i], _pips(stats[i]), Arch.STAT_DESC[i]]
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	_box.add_child(row)


func _small(text: String, enabled: bool) -> Button:
	var b := _button(text, enabled)
	_box.remove_child(b)
	b.custom_minimum_size = Vector2(84, 30)
	b.size_flags_horizontal = 0
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


func _left() -> int:
	var spent := 0
	for v in stats:
		spent += v
	var base := 0
	for v in Arch.ROLE_STATS[role]:
		base += int(v)
	return Arch.FREE_POINTS - (spent - base)


func _pips(n: int) -> String:
	var out := ""
	for i in range(Arch.STAT_MAX):
		out += "●" if i < n else "○"
	return out


func _party_line() -> String:
	if party.is_empty():
		return "nobody yet"
	var names: Array[String] = []
	for r in party:
		names.append(Arch.ROLE_NAME[r])
	return ", ".join(names)


func _pick_role(r: int) -> void:
	role = r
	stats = [0, 0, 0, 0]
	for i in range(4):
		stats[i] = int(Arch.ROLE_STATS[r][i])
	party.clear()
	_page = 1
	_show()


func _buy(i: int) -> void:
	if _left() > 0 and stats[i] < Arch.STAT_MAX:
		stats[i] += 1
	_show()


func _sell(i: int) -> void:
	if stats[i] > 0:
		stats[i] -= 1
	_show()


func _next() -> void:
	if _left() != 0:
		return
	_page = 2
	_show()


func _toggle_party(r: int) -> void:
	if party.has(r):
		party.erase(r)
	elif party.size() < Arch.PARTY_SIZE and r != role:
		party.append(r)
	_show()


func _finish() -> void:
	if party.size() != Arch.PARTY_SIZE:
		return
	visible = false
	_clear()
	done.emit({"role": role, "stats": stats.duplicate(), "party": party.duplicate()})


# --- widgets (same paper as the planner) -------------------------------------

func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


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


func _card(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.set_content_margin_all(4)
	sb.content_margin_left = 16
	return sb


func _process(_delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	var w: float = minf(960.0, vp.x - 40.0)
	var pad := 20.0
	var head := _title.get_minimum_size().y + 4.0 + _sub.get_minimum_size().y + 8.0
	var rows := _box.get_combined_minimum_size().y
	var h: float = minf(pad * 2.0 + head + rows + 28.0, vp.y - 44.0)
	_panel_rect = Rect2(Vector2(roundf(vp.x * 0.5 - w * 0.5), roundf(vp.y * 0.5 - h * 0.5)), Vector2(w, h))
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
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.06, 0.1, 0.35), true)
	draw_rect(Rect2(_panel_rect.position + Vector2(8, 9), _panel_rect.size), Color(0.07, 0.06, 0.1, 0.30), true)
	draw_rect(_panel_rect, PAPER, true)
	draw_rect(_panel_rect, INK, false, 3.0)
