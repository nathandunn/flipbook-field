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

var skin: Color
var shirt: Color
var pants: Color
var hair: Color
var figure_height: float = 1.0

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
	p_height: float = 1.0, p_seed: float = 0.0
) -> BlockFigure:
	var f := BlockFigure.new()
	f.skin = p_skin
	f.shirt = p_shirt
	f.pants = p_pants
	f.hair = p_hair
	f.figure_height = p_height
	f._seed_offset = p_seed
	f._build()
	return f


func _build() -> void:
	scale = Vector3.ONE * figure_height

	var skin_mat := Ink.mat(skin)
	var shirt_mat := Ink.mat(shirt)
	var pants_mat := Ink.mat(pants)
	var hair_mat := Ink.mat(hair)
	var eye_mat := Ink.mat(Ink.INK, 0.0)

	# Torso
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, HIP_Y, 0)
	add_child(torso)
	_box(torso, Vector3(TORSO_W, TORSO_H, TORSO_D), Vector3(0, TORSO_H * 0.5, 0), shirt_mat, "TorsoBox")

	# Head, pivoting at the neck so it can turn to look at people.
	head_pivot = Node3D.new()
	head_pivot.name = "Head"
	head_pivot.position = Vector3(0, TORSO_H + 0.06, 0)
	torso.add_child(head_pivot)
	_box(head_pivot, HEAD, Vector3(0, HEAD.y * 0.5, 0), skin_mat, "HeadBox")

	# Hair: a cap slab plus a fringe, enough to tell figures apart at a glance.
	_box(head_pivot, Vector3(HEAD.x + 0.02, 0.10, HEAD.z + 0.02),
		Vector3(0, HEAD.y - 0.02, 0), hair_mat, "HairCap")
	_box(head_pivot, Vector3(HEAD.x + 0.02, 0.09, 0.06),
		Vector3(0, HEAD.y - 0.11, HEAD.z * 0.5), hair_mat, "HairFringe")

	# Eyes on -Z: -Z is forward in Godot, so this is also the "which way am I
	# facing" readout while you're moving nodes around.
	var eye := Vector3(0.06, 0.06, 0.03)
	_box(head_pivot, eye, Vector3(-0.09, HEAD.y * 0.58, -HEAD.z * 0.5), eye_mat, "EyeL")
	_box(head_pivot, eye, Vector3(0.09, HEAD.y * 0.58, -HEAD.z * 0.5), eye_mat, "EyeR")

	# Arms
	arm_l = _limb(torso, Vector3(-(TORSO_W * 0.5 + ARM_W * 0.5), TORSO_H - 0.06, 0),
		Vector3(ARM_W, ARM_LEN, ARM_W), shirt_mat, "ArmL")
	arm_r = _limb(torso, Vector3(TORSO_W * 0.5 + ARM_W * 0.5, TORSO_H - 0.06, 0),
		Vector3(ARM_W, ARM_LEN, ARM_W), shirt_mat, "ArmR")
	# Hands, so the arm ends in something.
	_box(arm_l, Vector3(ARM_W + 0.01, 0.12, ARM_W + 0.01), Vector3(0, -ARM_LEN + 0.06, 0), skin_mat, "HandL")
	_box(arm_r, Vector3(ARM_W + 0.01, 0.12, ARM_W + 0.01), Vector3(0, -ARM_LEN + 0.06, 0), skin_mat, "HandR")

	# Legs
	leg_l = _limb(self, Vector3(-0.13, HIP_Y, 0), Vector3(LEG_W, LEG_LEN, LEG_W), pants_mat, "LegL")
	leg_r = _limb(self, Vector3(0.13, HIP_Y, 0), Vector3(LEG_W, LEG_LEN, LEG_W), pants_mat, "LegR")
	var shoe_mat := Ink.mat(Ink.INK.lerp(pants, 0.25))
	_box(leg_l, Vector3(LEG_W + 0.02, 0.10, LEG_W + 0.10),
		Vector3(0, -LEG_LEN + 0.05, -0.03), shoe_mat, "ShoeL")
	_box(leg_r, Vector3(LEG_W + 0.02, 0.10, LEG_W + 0.10),
		Vector3(0, -LEG_LEN + 0.05, -0.03), shoe_mat, "ShoeR")


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


## A limb pivot at [param at], with the box hanging below it so rotation.x swings
## from the joint rather than the middle.
func _limb(parent: Node3D, at: Vector3, size: Vector3, mat: Material, n: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = n
	pivot.position = at
	parent.add_child(pivot)
	_box(pivot, size, Vector3(0, -size.y * 0.5, 0), mat, n + "Box")
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
