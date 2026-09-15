## Npc — a block character standing in the group.
##
## No navigation, no AI. It idles, turns its head toward whoever has the floor,
## and gestures while it is the one speaking.
class_name Npc
extends StaticBody3D

var npc_name: String = "Someone"
var rig: BlockFigure

var _talk_amt: float = 0.0
var _talk_decay: float = 1.0
var _look_target: Node3D = null
var _idle_seed: float = 0.0


static func create(
	p_name: String, p_seed: float,
	skin: Color, shirt: Color, pants: Color, hair: Color, height: float
) -> Npc:
	var n := Npc.new()
	n.name = "Npc_" + p_name
	n.npc_name = p_name
	n._idle_seed = p_seed

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.5
	shape.shape = cap
	shape.position = Vector3(0, 0.75, 0)
	n.add_child(shape)

	n.rig = BlockFigure.create(skin, shirt, pants, hair, height, p_seed)
	n.rig.name = "Rig"
	n.add_child(n.rig)
	return n


func _process(delta: float) -> void:
	_talk_amt = move_toward(_talk_amt, 0.0, delta * _talk_decay)
	# Idle "listening" shuffle — small, but a group of perfectly still figures
	# looks like a shop display.
	var sway: float = sin((Time.get_ticks_msec() / 1000.0 + _idle_seed) * 0.7) * 0.03
	rig.animate(delta, absf(sway) * 2.0, _talk_amt)

	if is_instance_valid(_look_target):
		rig.look_at_point(_look_target.global_position + Vector3(0, 1.55, 0))
	else:
		rig.look_at_point(global_position + global_transform.basis.z * -2.0)


## Called by the conversation while this NPC has a line on screen.
func start_talking(duration: float = 2.5) -> void:
	_talk_amt = 1.0
	_talk_decay = 1.0 / maxf(duration, 0.1)


func look_at_node(n: Node3D) -> void:
	_look_target = n


func speech_anchor() -> Vector3:
	return global_position + Vector3(0, 1.62 * rig.figure_height, 0)
