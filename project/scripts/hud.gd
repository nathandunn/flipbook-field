## Hud — round, score, action budget, station prompt, toasts, banners.
##
## Built in code rather than a .tscn: it is all driven by game state anyway, and
## one file is easier to restyle than a tree of Controls.
class_name Hud
extends Control

const PAPER := Color("fbf7ec")
const INK := Color("12101a")

var _round_label: Label
var _score_label: Label
var _props_label: Label
## What the room wants, and the other side's hand size. The board, in numbers.
var _demand_label: Label
var _prompt: Label
var _toast: Label
var _banner: Label
var _hint: Label

var _actions_left: int = 0
var _actions_max: int = 4
var _toast_t: float = 0.0
var _banner_t: float = 0.0
var _prompt_visible: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Toasts and banners go over the planner, the roster and the board: a
	# toast under a panel is a message nobody reads.
	z_index = 5

	_round_label = _mk(20, INK)
	_score_label = _mk(17, INK)
	_props_label = _mk(15, INK)
	_demand_label = _mk(15, Color(0.13, 0.11, 0.18, 0.85))
	_prompt = _mk(18, PAPER)
	_toast = _mk(20, PAPER)
	_banner = _mk(30, PAPER)
	_hint = _mk(13, Color(0.13, 0.11, 0.18, 0.62))
	_hint.text = ""

	_prompt.visible = false
	_toast.visible = false
	_banner.visible = false


func _mk(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func set_round(n: int, total: int) -> void:
	_round_label.text = "ROUND %d / %d" % [n, total]


func set_score(you_people: int, them_people: int, you_pts: int, them_pts: int) -> void:
	_score_label.text = "YOU  %d people · %d pts        THEM  %d people · %d pts" % [
		you_people, you_pts, them_people, them_pts
	]


func set_props(props: Array) -> void:
	if props.is_empty():
		_props_label.text = "hand: empty"
		return
	# Tastes only: the names are on the cards, and four names do not fit here.
	var counts := {}
	for p in props:
		counts[p["taste"]] = int(counts.get(p["taste"], 0)) + 1
	var parts: Array[String] = []
	for t in range(4):
		if counts.has(t):
			parts.append("%s ×%d" % [Arch.TASTE_NAME[t], counts[t]] if counts[t] > 1 else Arch.TASTE_NAME[t])
	_props_label.text = "hand: " + ", ".join(parts)


## [param demand] maps taste -> how many people likely at your talk want it.
## Shown always, because a card game where you cannot see the table is a guess.
## [param flags] is what has been done to you and by you this round - a
## rigged projector, a pinched card - so sabotage is never a surprise.
func set_demand(demand: Dictionary, their_hand: int, flags: String = "") -> void:
	var parts: Array[String] = []
	for t in range(4):
		parts.append("%s %d" % [Arch.TASTE_NAME[t], int(demand.get(t, 0))])
	_demand_label.text = "room wants:  " + "  ·  ".join(parts) + "        their hand: %d" % their_hand
	if flags != "":
		_demand_label.text += "        " + flags


func set_actions(left: int, total: int) -> void:
	_actions_left = left
	_actions_max = total
	queue_redraw()


func show_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = true
	_prompt_visible = true


func hide_prompt() -> void:
	_prompt.visible = false
	_prompt_visible = false


func toast(text: String, seconds: float = 2.4) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_t = seconds


func banner(text: String, seconds: float = 2.2) -> void:
	_banner.text = text
	_banner.visible = true
	_banner_t = seconds


func set_hint(text: String) -> void:
	_hint.text = text


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size

	_round_label.size = _round_label.get_minimum_size()
	_round_label.position = Vector2(20, 16)

	_score_label.size = _score_label.get_minimum_size()
	_score_label.position = Vector2(20, 44)

	_props_label.size = _props_label.get_minimum_size()
	_props_label.position = Vector2(20, 70)

	_demand_label.size = _demand_label.get_minimum_size()
	_demand_label.position = Vector2(20, 92)

	_hint.size = _hint.get_minimum_size()
	_hint.position = Vector2(20, vp.y - 26)

	if _prompt_visible:
		_prompt.size = _prompt.get_minimum_size()
		_prompt.position = Vector2(roundf(vp.x * 0.5 - _prompt.size.x * 0.5), roundf(vp.y - 128.0))

	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.size = _toast.get_minimum_size()
		_toast.position = Vector2(roundf(vp.x * 0.5 - _toast.size.x * 0.5), roundf(vp.y * 0.27))
		if _toast_t <= 0.0:
			_toast.visible = false

	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.size = _banner.get_minimum_size()
		_banner.position = Vector2(roundf(vp.x * 0.5 - _banner.size.x * 0.5), roundf(vp.y * 0.16))
		if _banner_t <= 0.0:
			_banner.visible = false

	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size

	# Panel behind the status block. Nothing to say yet (the setup screen is
	# up), nothing to draw.
	if _round_label.text != "":
		var top := Rect2(Vector2(12, 8), Vector2(
			maxf(maxf(_score_label.size.x, _props_label.size.x), _demand_label.size.x) + 32, 110))
		draw_rect(top, Color(0.98, 0.96, 0.90, 0.82), true)
		draw_rect(top, INK, false, 3.0)

	# Action pips: one ink-outlined square per move, filled while unspent. In
	# the status block beside the round, not over the cards.
	var pip := 16.0
	var gap := 7.0
	var x0 := _round_label.position.x + _round_label.size.x + 22.0
	var y0 := _round_label.position.y + 6.0
	for i in range(_actions_max if _round_label.text != "" else 0):
		var r := Rect2(Vector2(x0 + i * (pip + gap), y0), Vector2(pip, pip))
		draw_rect(r, Color(0.13, 0.11, 0.18, 0.85) if i < _actions_left else Color(1, 1, 1, 0.4), true)
		draw_rect(r, INK, false, 2.0)

	if _prompt_visible:
		var pr := Rect2(_prompt.position - Vector2(14, 8), _prompt.size + Vector2(28, 16))
		draw_rect(pr, Color(0.07, 0.06, 0.1, 0.82), true)
		draw_rect(pr, PAPER, false, 2.0)

	if _toast.visible:
		var tr := Rect2(_toast.position - Vector2(18, 10), _toast.size + Vector2(36, 20))
		draw_rect(tr, Color(0.07, 0.06, 0.1, 0.86), true)
		draw_rect(tr, PAPER, false, 3.0)

	if _banner.visible:
		var br := Rect2(
			Vector2(0, _banner.position.y - 16),
			Vector2(vp.x, _banner.size.y + 32)
		)
		draw_rect(br, Color(0.07, 0.06, 0.1, 0.88), true)
