## Ink — material factory + shared palette.
##
## Every toon material in the scene is a duplicate of materials/toon_base.tres with
## a different base_color, so tweaking band count / shadow tint / ink weight in that
## one .tres restyles the whole scene. Duplicates are cached per colour so the group
## of characters doesn't compile a shader variant each.
class_name Ink
extends RefCounted

const TOON_BASE := "res://materials/toon_base.tres"
## Ink weight at outline = 1.0. Angular, not world-space — see outline.gdshader.
const OUTLINE_BASE := 0.0045

static var _cache: Dictionary = {}

## A toon material tinted [param color].
## [param outline] multiplies the ink weight — 0.0 drops the outline entirely
## (use that for the ground plane, whose inverted hull would be a giant box).
static func mat(color: Color, outline: float = 1.0, bands: int = 3) -> ShaderMaterial:
	var key := "%s|%.3f|%d" % [color.to_html(), outline, bands]
	if _cache.has(key):
		return _cache[key]

	var base: ShaderMaterial = load(TOON_BASE)
	var m: ShaderMaterial = base.duplicate(true)
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("band_count", bands)

	if outline <= 0.0:
		m.next_pass = null
	else:
		var op := m.next_pass as ShaderMaterial
		if op:
			op.set_shader_parameter("thickness", OUTLINE_BASE * outline)

	_cache[key] = m
	return m


# --- Scene palette -----------------------------------------------------------
# Warm paper, cool shadows, desaturated fills. Nothing fully saturated: printed
# colour never is, and it's what keeps the ink lines reading as the darkest thing
# on screen.

const PAPER := Color("efe7d6")
const INK := Color("12101a")

const GRASS := Color("7d9560")
const GRASS_DARK := Color("62784b")
const DIRT := Color("b9a07c")
const BARK := Color("8a6f55")
const LEAF_A := Color("7fa35f")
const LEAF_B := Color("93b46d")
const LEAF_C := Color("6d8f52")
const STONE := Color("b3ada2")

const SKINS: Array[Color] = [
	Color("e8c4a0"), Color("d4a276"), Color("a9714b"),
	Color("8d5524"), Color("f2d5b8"), Color("6b4429"),
]
const SHIRTS: Array[Color] = [
	Color("c4614f"), Color("5b7fa6"), Color("d8a94b"),
	Color("7a9b6e"), Color("9a6a99"), Color("c9c0aa"), Color("4f6b72"),
]
const PANTS: Array[Color] = [
	Color("4a5468"), Color("6b5a4a"), Color("3f4a52"),
	Color("87796a"), Color("5a4e63"),
]
const HAIRS: Array[Color] = [
	Color("2b2320"), Color("4a3226"), Color("7a5637"),
	Color("b08347"), Color("8f8f8f"), Color("a8442f"),
]

const NAMES: Array[String] = [
	"Wren", "Bosch", "Marguerite", "Tully", "Okonkwo", "Pip",
	"Halvard", "Nim", "Aster", "Crane", "Bramble", "Rook",
	"Sable", "Fen", "Quill", "Oleander",
]
