## Fold — the little [–] / [+] tab every panel carries.
##
## Any panel can be tucked down to its title bar and brought back, so the board
## can be watched whole. The camera reframes into whatever the panels leave
## clear (see Game._frame_board).
class_name Fold
extends RefCounted

const PAPER := Color("fbf7ec")
const INK := Color("12101a")
const SIZE := Vector2(26, 22)


## A fold tab parented to [param parent]; [param on_toggle] is called on press.
## The caller places it (top-right of its panel) every frame.
static func button(parent: Control, on_toggle: Callable) -> Button:
	var b := Button.new()
	b.text = "–"
	b.tooltip_text = "Minimise"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.custom_minimum_size = SIZE
	b.size = SIZE
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_stylebox_override("normal", _box(Color(1, 1, 1, 0.6)))
	b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 1.0)))
	b.add_theme_stylebox_override("pressed", _box(Color(0.13, 0.11, 0.18, 0.9)))
	b.pressed.connect(on_toggle)
	parent.add_child(b)
	return b


## Show the right glyph for the state: – folds, + unfolds.
static func mark(b: Button, folded: bool) -> void:
	b.text = "+" if folded else "–"
	b.tooltip_text = "Restore" if folded else "Minimise"


static func _box(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.set_content_margin_all(0)
	return sb
