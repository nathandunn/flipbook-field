## Person — one block figure in the office, with an archetype and an allegiance.
##
## Replaces the old Npc. Everyone in the world is one of these, including the
## nemesis's people; what separates them is [member side] and [member kind].
class_name Person
extends CharacterBody3D

signal arrived

const WALK_SPEED := 2.4
## Summoned to a talk, people move like they are late, because otherwise the
## crowd is still crossing the field when the first slide goes up.
const HURRY_SPEED := 5.2
const ARRIVE_DIST := 0.45

var person_name: String = "Someone"
var kind: int = Arch.Kind.NEUTRAL
var side: int = Arch.Side.NONE
var taste: int = Arch.Taste.DATA

## 0..3. Cold neutrals shrug at the stream; curious ones can be closed there.
var curiosity: float = 0.0
## Whose things they have been looking at. A neutral is curious about one side
## at a time: the other side can restart their interest, but cannot walk up to
## the stream and close somebody you warmed.
var curious_for: int = Arch.Side.NONE
## Set by a break-room rally: resists one flip this round.
var resolve: bool = false

var rig: BlockFigure
## Which drawing this person wears. Left at -1 it is drawn from their seed;
## [Game] sets it explicitly so no two people in a match share a face.
var face_index: int = -1
## The job, which is the costume, the taste and the rule. See Arch.Role.
var role: int = Arch.Role.STAFF
var home_pos := Vector3.ZERO
## A colleague who is a piece on the board (see Arch.ABILITY): the room they
## stand in, their morale, and moves until their ability is ready again.
var unit: bool = false
var room: String = ""
var morale: int = 0
var cooldown: int = 0

var _target: Vector3 = Vector3.INF
var _hurry: bool = false
var _look_at: Node3D = null
var _idle_seed: float = 0.0
var _talk: float = 0.0
var _talk_decay: float = 1.0
var _pip: MeshInstance3D
var _gravity: float = 18.0


static func create(p_name: String, p_kind: int, p_side: int, seed_val: float) -> Person:
	var p := Person.new()
	p.name = "Person_" + p_name.replace(" ", "_")
	p.person_name = p_name
	p.kind = p_kind
	p.side = p_side
	p._idle_seed = seed_val
	return p


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * 1.8

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.5
	shape.shape = cap
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)

	if rig == null:
		_make_rig()

	_pip = MeshInstance3D.new()
	_pip.name = "Pip"
	_pip.mesh = BoxMesh.new()
	add_child(_pip)
	refresh()


func _make_rig() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_idle_seed * 10000.0) + 7
	rig = BlockFigure.create(
		Ink.SKINS[rng.randi() % Ink.SKINS.size()],
		Arch.side_color(side).lerp(Ink.SHIRTS[rng.randi() % Ink.SHIRTS.size()], 0.35),
		Ink.PANTS[rng.randi() % Ink.PANTS.size()],
		Ink.HAIRS[rng.randi() % Ink.HAIRS.size()],
		rng.randf_range(0.88, 1.12),
		_idle_seed,
		face_index if face_index >= 0 else int(rng.randi() % Ink.FACE_COUNT),
		role
	)
	rig.name = "Rig"
	add_child(rig)


## Change job: a new costume on the same person.
func dress(p_role: int) -> void:
	role = p_role
	if rig:
		remove_child(rig)
		rig.queue_free()
	_make_rig()
	refresh()


## Rebuild the shirt tint and the floating pip after kind or side changes.
func refresh() -> void:
	if rig == null or _pip == null:
		return

	var shape_data := Arch.pip_shape(kind)
	var bm := _pip.mesh as BoxMesh
	bm.size = shape_data[0]
	_pip.position = Vector3(0, 1.86 * rig.figure_height + shape_data[1], 0)

	var base := Arch.side_color(side)
	if kind == Arch.Kind.HATER or kind == Arch.Kind.BULLY:
		# Haters read as the other side's colour gone sour, not as a third team.
		base = Arch.side_color(side).lerp(Ink.INK, 0.45)
	var pip_col: Color = base * float(shape_data[2])
	pip_col.a = 1.0
	_pip.material_override = Ink.mat(pip_col, 0.9, 2)

	# Cold neutrals wear a washed-out shirt; warming them tints it toward whoever
	# has been showing them things, which is the only tell you get before a close.
	if kind == Arch.Kind.NEUTRAL:
		var warmth: float = clampf(curiosity / Arch.CURIOSITY_MAX, 0.0, 1.0)
		_pip.scale = Vector3.ONE * (1.0 + warmth * 0.6)
	else:
		_pip.scale = Vector3.ONE


func set_kind_side(p_kind: int, p_side: int) -> void:
	kind = p_kind
	side = p_side
	curiosity = 0.0
	curious_for = Arch.Side.NONE
	refresh()


## Warm this neutral toward [param by]. Warmth for the other side is replaced,
## not added to: a desk visit near somebody the other side has been courting
## takes them off the other side's list and starts them on yours.
func warm(amount: float, by: int = Arch.Side.NONE) -> void:
	if kind != Arch.Kind.NEUTRAL:
		return
	var r := Person.warm_rule(curiosity, curious_for, amount, by)
	curiosity = r[0]
	curious_for = r[1]
	refresh()


## Talk somebody down: their interest drops, and at nothing they are nobody's.
## Unlike [method warm] it never carries over to the side doing the talking -
## a rumour cools, it does not recruit.
func cool(amount: float) -> void:
	if kind != Arch.Kind.NEUTRAL:
		return
	curiosity = maxf(curiosity - amount, 0.0)
	if curiosity <= 0.0:
		curious_for = Arch.Side.NONE
	refresh()


## The arithmetic of warming, as a pure function so a card can show exactly
## what a visit would do. Interest is a tug of war: the other side's warmth is
## worn down first, and only once it is gone does the neutral start on you.
## Returns [curiosity, curious_for].
static func warm_rule(cur: float, who: int, amount: float, by: int) -> Array:
	if by == Arch.Side.NONE or who == Arch.Side.NONE or by == who:
		return [clampf(cur + amount, 0.0, Arch.CURIOSITY_MAX), by if by != Arch.Side.NONE else who]
	var left := cur - amount
	if left > 0.0:
		return [left, who]
	return [clampf(-left, 0.0, Arch.CURIOSITY_MAX), by]


func is_curious() -> bool:
	return kind == Arch.Kind.NEUTRAL and curiosity >= Arch.CURIOUS_AT


## Curious, and about [param side] in particular.
func is_curious_for(p_side: int) -> bool:
	return is_curious() and curious_for == p_side


func goto(p: Vector3, hurry: bool = false) -> void:
	_target = Vector3(p.x, global_position.y, p.z)
	_hurry = hurry


func stop_walking() -> void:
	_target = Vector3.INF
	_hurry = false
	velocity.x = 0.0
	velocity.z = 0.0


func look_at_node(n: Node3D) -> void:
	_look_at = n


func start_talking(duration: float = 2.0) -> void:
	_talk = 1.0
	_talk_decay = 1.0 / maxf(duration, 0.1)


func speech_anchor() -> Vector3:
	return global_position + Vector3(0, 1.62 * (rig.figure_height if rig else 1.0), 0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var moving := 0.0
	if _target != Vector3.INF:
		var to := _target - global_position
		to.y = 0.0
		if to.length() <= ARRIVE_DIST:
			_target = Vector3.INF
			velocity.x = 0.0
			velocity.z = 0.0
			arrived.emit()
		else:
			var dir := to.normalized()
			var spd: float = HURRY_SPEED if _hurry else WALK_SPEED
			velocity.x = dir.x * spd
			velocity.z = dir.z * spd
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(10.0 * delta, 0.0, 1.0))
			moving = 1.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)

	move_and_slide()

	_talk = move_toward(_talk, 0.0, delta * _talk_decay)
	if rig:
		# A hair of idle sway, so a standing crowd doesn't look like a shop display.
		var sway: float = absf(sin((Time.get_ticks_msec() / 1000.0 + _idle_seed) * 0.7)) * 0.06
		rig.animate(delta, maxf(moving, sway), _talk)

		if is_instance_valid(_look_at):
			rig.look_at_point(_look_at.global_position + Vector3(0, 1.55, 0))
