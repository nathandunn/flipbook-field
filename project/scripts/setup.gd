## Setup — who you are, what you are good at, who is coming with you.
##
## Three short pages on one paper panel: pick a job (its costume, its taste,
## its rule), spend four free points on four stats, then pick up to four
## colleagues to start on your side. The nemesis is dealt the same number of
## colleagues, so the party is a plan, not a head start.
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
			_sub.text = "A job is a costume, a taste, and a rule your side gets while you are clapping for it."
			for r in Arch.PLAYABLE:
				var st: Array = Arch.ROLE_STATS[r]
				var b := _button("%s   —   %s   ·   charm %d  guile %d  hustle %d  grit %d" % [
					Arch.ROLE_NAME[r], Arch.ROLE_PERK[r], st[0], st[1], st[2], st[3]], true)
				b.pressed.connect(_pick_role.bind(r))
			_hint.text = "Your nemesis is dealt a job the same way."
		1:
			_title.text = "%s. What are you good at?" % Arch.ROLE_NAME[role]
			_sub.text = "%d point%s left to spend. Tap a stat to add one; tap it again past the cap and it starts over." % [_left(), "" if _left() == 1 else "s"]
			for i in range(4):
				var b := _button("%s  %s   —   %s" % [Arch.STAT_NAME[i], _pips(stats[i]), Arch.STAT_DESC[i]], true)
				b.pressed.connect(_bump.bind(i))
			var go := _button("Done with stats", _left() == 0)
			go.pressed.connect(_next)
			_hint.text = "Base points come from the job; the rest are yours."
		2:
			_title.text = "Who is coming with you?"
			_sub.text = "Up to %d colleagues start on your side. Each brings their rule. Picked: %s" % [
				Arch.PARTY_MAX, _party_line()]
			for r in Arch.PLAYABLE:
				var n := party.count(r)
				var b := _button("%s%s   —   %s" % [Arch.ROLE_NAME[r], (" ×%d" % n) if n > 0 else "", Arch.ROLE_PERK[r]], true)
				b.pressed.connect(_toggle_party.bind(r))
			var go := _button("Begin  —  %d in your party" % party.size(), party.size() > 0)
			go.pressed.connect(_finish)
			var clr := _button("Clear the list", party.size() > 0)
			clr.pressed.connect(_clear_party)
			_hint.text = "The same job twice is allowed. The nemesis gets as many colleagues as you take."


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
	_page = 1
	_show()


func _bump(i: int) -> void:
	var base: int = int(Arch.ROLE_STATS[role][i])
	if _left() > 0 and stats[i] < Arch.STAT_MAX:
		stats[i] += 1
	else:
		# Past the cap or out of points: give this stat's free points back.
		stats[i] = base
	_show()


func _next() -> void:
	if _left() != 0:
		return
	_page = 2
	_show()


func _toggle_party(r: int) -> void:
	if party.size() < Arch.PARTY_MAX:
		party.append(r)
	_show()


func _clear_party() -> void:
	party.clear()
	_show()


func _finish() -> void:
	if party.is_empty():
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
