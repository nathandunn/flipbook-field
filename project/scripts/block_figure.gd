## BlockFigure — a hand-assembled box character, ~1.75 m tall.
##
## Deliberately built from primitives and node transforms rather than an imported
## mesh: this is the stand-in rig. When you swap in real hand-drawn skins, the
## joint names and local axes here are what the replacement has to match —
## arms and legs pivot at shoulder/hip, X rotation swings forward.
##
## Animation is quantised to FLIPBOOK_FPS. That single line is most of the
## graphic-novel feel: smooth interpolation reads as 3D, stepped poses read as
## drawn frames.
##
## Since the classes arrived the figure is a paper doll: every part is a slim
## slab with a drawing on its front and another on its back, so the costume
## reads from any side and the walk still swings at the joints. The drawings
## come from art/bodygen.py; the head's front is one of Nathan's, its back is
## inferred from it.
class_name BlockFigure
extends Node3D

const FLIPBOOK_FPS := 12.0

const HIP_Y := 0.76
const TORSO_H := 0.58
const TORSO_W := 0.50
const TORSO_D := 0.28
const SHOULDER_Y := 1.28
const ARM_LEN := 0.56
const ARM_W := 0.15
const LEG_LEN := 0.74
const LEG_W := 0.18
const HEAD := Vector3(0.38, 0.40, 0.36)
## The face card is wider and taller than a skull because the drawings include
## the hair, and in these drawings the hair is most of the person.
const CARD := 0.62

var skin: Color
var shirt: Color
var pants: Color
var hair: Color
var figure_height: float = 1.0
## Which drawing this figure wears. See Ink.face_mat.
var face: int = 0
## Which costume. See Arch.Role and Ink.body_mat.
var role: int = Arch.Role.STAFF
## How thick a paper part is: enough to read from the side, no more.
const SLAB := 0.12

var head_pivot: Node3D
var torso: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D

var _phase: float = 0.0
var _seed_offset: float = 0.0


static func create(
	p_skin: Color, p_shirt: Color, p_pants: Color, p_hair: Color,
	p_height: float = 1.0, p_seed: float = 0.0, p_face: int = 0,
	p_role: int = Arch.Role.STAFF
) -> BlockFigure:
	var f := BlockFigure.new()
	f.skin = p_skin
	f.shirt = p_shirt
	f.pants = p_pants
	f.hair = p_hair
	f.figure_height = p_height
	f._seed_offset = p_seed
	f.face = p_face
	f.role = p_role
	f._build()
	return f


func _build() -> void:
	scale = Vector3.ONE * figure_height
	var key: String = Arch.ROLE_KEY.get(role, "staff")
	var tint := Ink.mat(Arch.role_tint(role).lerp(Ink.PAPER, 0.35))
	var skin_mat := Ink.mat(skin)

	# Torso: a slab in the costume's wash with the drawn front and back on it.
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, HIP_Y, 0)
	add_child(torso)
	_paper_part(torso, Vector2(TORSO_W, TORSO_H), Vector3(0, TORSO_H * 0.5, 0), tint,
		Ink.body_mat(key, "torso_f"), Ink.body_mat(key, "torso_b"), "TorsoBox")

	# Head, pivoting at the neck so it can turn to look at people. The front is
	# one of the drawings; the back is inferred from it; a slab between them
	# gives the head mass from the side.
	head_pivot = Node3D.new()
	head_pivot.name = "Head"
	head_pivot.position = Vector3(0, TORSO_H + 0.06, 0)
	torso.add_child(head_pivot)
	_box(head_pivot, Vector3(HEAD.x * 0.78, HEAD.y * 0.88, HEAD.z * 0.46),
		Vector3(0, HEAD.y * 0.50, 0.0), skin_mat, "HeadBack")
	var front := _card(head_pivot, Vector2(CARD, CARD),
		Vector3(0, HEAD.y * 0.46, -HEAD.z * 0.23 - 0.014), Ink.face_mat(face), "FaceCard")
	front.rotation.y = PI
	_card(head_pivot, Vector2(CARD, CARD),
		Vector3(0, HEAD.y * 0.46, HEAD.z * 0.23 + 0.014), Ink.back_mat(face), "BackCard")

	# Arms and legs: pivots at shoulder and hip, a drawn strip hanging from each.
	arm_l = _limb(torso, Vector3(-(TORSO_W * 0.5 + ARM_W * 0.5), TORSO_H - 0.06, 0),
		Vector2(ARM_W, ARM_LEN), tint, Ink.body_mat(key, "arm"), "ArmL")
	arm_r = _limb(torso, Vector3(TORSO_W * 0.5 + ARM_W * 0.5, TORSO_H - 0.06, 0),
		Vector2(ARM_W, ARM_LEN), tint, Ink.body_mat(key, "arm"), "ArmR")
	leg_l = _limb(self, Vector3(-0.13, HIP_Y, 0), Vector2(LEG_W, LEG_LEN), tint,
		Ink.body_mat(key, "leg"), "LegL")
	leg_r = _limb(self, Vector3(0.13, HIP_Y, 0), Vector2(LEG_W, LEG_LEN), tint,
		Ink.body_mat(key, "leg"), "LegR")


## A slab with a drawing on each face. [param size] is width x height; the
## slab is centred on [param offset] and faces -Z.
func _paper_part(parent: Node3D, size: Vector2, offset: Vector3, slab_mat: Material,
		front: Material, back: Material, n: String) -> void:
	_box(parent, Vector3(size.x * 0.92, size.y * 0.98, SLAB), offset, slab_mat, n)
	var f := _card(parent, size, offset + Vector3(0, 0, -SLAB * 0.5 - 0.01), front, n + "Front")
	f.rotation.y = PI
	_card(parent, size, offset + Vector3(0, 0, SLAB * 0.5 + 0.01), back, n + "Back")


## A flat drawing. Faces +Z as built; rotate it PI to face forward (-Z).
func _card(parent: Node3D, size: Vector2, offset: Vector3, mat: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.position = offset
	mi.material_override = mat
	# The inverted-hull outline belongs on solid shapes; on a flat card it would
	# draw a black rectangle behind the drawing.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, offset: Vector3, mat: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = offset
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A limb pivot at [param at], with the drawn strip hanging below it so
## rotation.x swings from the joint rather than the middle. The same drawing is
## on both faces: a sleeve is a sleeve from behind.
func _limb(parent: Node3D, at: Vector3, size: Vector2, slab_mat: Material, drawing: Material, n: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = n
	pivot.position = at
	parent.add_child(pivot)
	_paper_part(pivot, size, Vector3(0, -size.y * 0.5, 0), slab_mat, drawing, drawing, n + "Box")
	return pivot


## Drive the rig. [param move_amt] is 0..1 (idle..full stride), [param talk_amt]
## adds a gesture on top so a speaking figure has its hands moving.
func animate(delta: float, move_amt: float, talk_amt: float = 0.0) -> void:
	_phase += delta * lerpf(1.1, 2.4, clampf(move_amt, 0.0, 1.0))

	# Quantise to the flipbook cadence.
	var t: float = floor((_phase + _seed_offset) * FLIPBOOK_FPS) / FLIPBOOK_FPS
	var s: float = sin(t * TAU * 1.5)

	var swing: float = s * (0.42 * move_amt + 0.06)
	var gesture: float = sin(t * TAU * 0.9 + _seed_offset * 3.0) * 0.30 * talk_amt

	arm_l.rotation.x = swing + gesture
	arm_r.rotation.x = -swing + gesture * 0.7
	arm_l.rotation.z = -gesture * 0.5
	arm_r.rotation.z = gesture * 0.5

	leg_l.rotation.x = -swing * 1.05
	leg_r.rotation.x = swing * 1.05

	# Weight shift + breathing bob.
	position.y = absf(s) * 0.05 * move_amt
	torso.rotation.y = s * 0.09 * move_amt
	torso.rotation.z = s * 0.03 * move_amt
	head_pivot.rotation.x = -s * 0.05 * move_amt + sin(t * TAU * 0.5) * 0.04


## Turn the head toward a world point, clamped so nobody snaps their neck.
func look_at_point(world_point: Vector3, weight: float = 1.0) -> void:
	# Measured in figure space, not head space — measuring in head space would feed
	# the head's own rotation back in and make it drift.
	var local := to_local(world_point)
	var yaw := atan2(-local.x, -local.z)
	yaw = clampf(yaw, -0.9, 0.9)
	head_pivot.rotation.y = lerp_angle(head_pivot.rotation.y, yaw * weight, 0.15)
