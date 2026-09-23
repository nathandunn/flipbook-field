## Roster — who is on each side, what each of them is worth, and who is
## heckling whom.
##
## One line per person with a name: their job, what they want on a slide,
## the upside their job gives the side and the downside that comes with it.
## A job whose rule is already on (the presenter's own, or a second of the
## same) is marked so, because losing that person costs nothing. Hecklers are
## listed on the side that sent them, with who they are heckling.
class_name Roster
extends Control

const PAPER := Color("fbf7ec")
const INK := Color("12101a")
const SOFT := Color(0.13, 0.11, 0.18, 0.72)
const W := 360.0

## The game node; read-only from here.
var game: Node
var _scroll: ScrollContainer
var _box: VBoxContainer
var _sig: String = ""
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 1)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)


func _process(delta: float) -> void:
	if not visible or game == null:
		return
	var vp := get_viewport_rect().size
	position = Vector2(12, 128)
	size = Vector2(W, vp.y - 128 - 34)
	_scroll.position = Vector2(12, 10)
	_scroll.size = size - Vector2(20, 20)
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		_rebuild()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(6, 7), size), Color(0.07, 0.06, 0.1, 0.25), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.98, 0.96, 0.90, 0.92), true)
	draw_rect(Rect2(Vector2.ZERO, size), INK, false, 3.0)


func _rebuild() -> void:
	var lines := _lines()
	var sig := ""
	for l in lines:
		sig += str(l[0]) + "|" + str(l[1]) + "\n"
	if sig == _sig:
		return
	_sig = sig
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	for l in lines:
		var lab := Label.new()
		lab.text = l[0]
		lab.add_theme_font_size_override("font_size", int(l[1]))
		lab.add_theme_color_override("font_color", l[2])
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(W - 40, 0)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(lab)


## [text, font size, colour] rows for both sides.
func _lines() -> Array:
	var out: Array = []
	for side in [Arch.Side.PLAYER, Arch.Side.NEMESIS]:
		_side_lines(side, out)
		out.append(["", 6, SOFT])
	return out


func _side_lines(side: int, out: Array) -> void:
	var you := side == Arch.Side.PLAYER
	var me_role: int = game.roles[side]
	var who := "YOU" if you else "THEM"
	out.append(["%s  -  %s  ·  %d clapping  ·  %d step%s a move" % [
		who, Arch.ROLE_NAME[me_role], game._count(side), game._steps(side),
		"" if game._steps(side) == 1 else "s"], 15, Arch.side_color(side).darkened(0.35)])
	out.append(["   + %s    - %s" % [Arch.PERK_SHORT[me_role], Arch.DOWN_SHORT[me_role]], 12, SOFT])

	var seen := {me_role: true}
	var slaves := 0
	var hecklers: Array = []
	for p in game.people:
		if p.side != side:
			continue
		if p.kind == Arch.Kind.WAGE_SLAVE:
			slaves += 1
			continue
		if Arch.boos(p.kind):
			hecklers.append(p)
			continue
		if not Arch.claps(p.kind):
			continue
		var tags: Array[String] = []
		if p.kind == Arch.Kind.LOVER:
			tags.append("true believer")
		elif p.kind == Arch.Kind.INFLUENCER:
			tags.append("influencer")
		if p.resolve:
			tags.append("shielded")
		out.append(["● %s  ·  %s  ·  wants %s%s" % [p.person_name, Arch.ROLE_NAME[p.role],
			Arch.TASTE_NAME[p.taste], ("  ·  " + ", ".join(tags)) if tags.size() > 0 else ""], 13, INK])
		if p.role == Arch.Role.STAFF:
			out.append(["     no job rule - one clap, one body", 11, SOFT])
		elif seen.has(p.role):
			out.append(["     %s rule already on - losing them costs only the clap" % Arch.ROLE_NAME[p.role], 11, SOFT])
		else:
			out.append(["     + %s    - %s" % [Arch.PERK_SHORT[p.role], Arch.DOWN_SHORT[p.role]], 11, SOFT])
		seen[p.role] = true

	for h in hecklers:
		var target := "THEIR" if you else "YOUR"
		var what := "BULLY at the front of %s talk" % target if h.kind == Arch.Kind.BULLY else "heckling %s talks" % target
		out.append(["✕ %s  ·  %s  ·  %s" % [h.person_name, Arch.ROLE_NAME[h.role], what], 13, Color("8a2a2a")])
	if slaves > 0:
		out.append(["   + %d wage slave%s: crowd size, no claps" % [slaves, "" if slaves == 1 else "s"], 11, SOFT])
