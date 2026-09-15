## World — generates the whole scene procedurally from a seed.
##
## Nothing here is hand-placed, so pressing R gives you a different field, a
## different tree, a different group of people and a different conversation. That
## is the point of a blockout: you are looking for whether the *composition rules*
## hold up, not whether one arrangement looks good.
extends Node3D

@export var world_seed: int = 0          ## 0 = pick a new random seed each run.
@export var npc_count_min: int = 4
@export var npc_count_max: int = 6
@export var interact_range: float = 3.4

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var rng := RandomNumberGenerator.new()
var player: Player
var npcs: Array[Npc] = []
var group_center := Vector3.ZERO
## Direction the horseshoe's opening faces — the player walks in along it.
var group_gap_dir := Vector3.FORWARD
var _used_names: Array[String] = []

@onready var generated: Node3D = $Generated
@onready var sun: DirectionalLight3D = $Sun
@onready var dialogue: Dialogue = $UI/Dialogue
@onready var touch: TouchControls = $UI/Touch
@onready var controls_hint: Label = $UI/Controls


func _ready() -> void:
	# The keyboard hint is meaningless on a phone, where TouchControls takes over.
	controls_hint.visible = not DisplayServer.is_touchscreen_available()
	generate()


func generate() -> void:
	rng.seed = world_seed if world_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0)

	for c in generated.get_children():
		c.queue_free()
	npcs.clear()
	if dialogue.is_active():
		dialogue.stop()

	_build_ground()
	_build_group()
	_build_trees()
	_scatter_grass()
	_scatter_rocks()
	_place_player()

	# Sun angled across the group so the figures cast shadows toward camera —
	# long raking light is what gives blockout geometry any drama at all.
	sun.rotation = Vector3(deg_to_rad(-38.0), rng.randf_range(-PI, PI), 0.0)


# --- Terrain -----------------------------------------------------------------

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"

	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	mi.mesh = plane
	# No outline on the ground: its inverted hull would be a 90 m black box.
	mi.material_override = Ink.mat(Ink.GRASS, 0.0, 3)
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(90, 1, 90)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	generated.add_child(body)

	# Colour patches — flat decals that break up the field without adding relief.
	# Discs, not quads: a rectangle on grass reads as a bug, a ragged low-poly
	# disc reads as a patch of different growth.
	for i in range(rng.randi_range(6, 11)):
		var patch := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.height = 0.002
		disc.top_radius = rng.randf_range(1.6, 4.2)
		disc.bottom_radius = disc.top_radius
		disc.radial_segments = rng.randi_range(11, 16)
		disc.rings = 0
		patch.mesh = disc
		var toward_dirt := rng.randf() < 0.3
		patch.material_override = Ink.mat(
			Ink.GRASS.lerp(
				Ink.DIRT if toward_dirt else Ink.GRASS_DARK,
				rng.randf_range(0.12, 0.28) if toward_dirt else rng.randf_range(0.3, 0.6)
			), 0.0, 2
		)
		patch.position = Vector3(rng.randf_range(-26, 26), 0.01 + i * 0.004, rng.randf_range(-26, 26))
		patch.rotation.y = rng.randf_range(0, TAU)
		patch.scale = Vector3(1.0, 1.0, rng.randf_range(0.55, 1.0))
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		generated.add_child(patch)


func _scatter_grass() -> void:
	# MultiMesh so a few hundred blades cost one draw call. No outline — inked
	# grass reads as static noise and fights the characters for attention.
	const BLADE_H := 0.30
	var blade := BoxMesh.new()
	blade.size = Vector3(0.035, BLADE_H, 0.028)

	# Blades come in tufts of 3-5. Evenly scattered single blades read as debris;
	# clustering them reads as growth, and it is the cheapest possible fix.
	var tufts := 1100
	var per_tuft := 4
	var count := tufts * per_tuft

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	mm.instance_count = count

	var i := 0
	for tuft in range(tufts):
		var a := rng.randf_range(0, TAU)
		# sqrt() for uniform area density; without it everything piles at the centre.
		var d := sqrt(rng.randf()) * 26.0
		var centre := Vector3(cos(a) * d, 0.0, sin(a) * d)
		var tone := Ink.GRASS_DARK.lerp(Ink.GRASS, rng.randf_range(0.0, 0.65))

		for b in range(per_tuft):
			var t := Transform3D()
			t = t.rotated(Vector3.UP, rng.randf_range(0, TAU))
			t = t.rotated(Vector3.FORWARD, rng.randf_range(-0.42, 0.42))
			var h := rng.randf_range(0.55, 1.35)
			t = t.scaled(Vector3(rng.randf_range(0.8, 1.2), h, 1.0))
			t.origin = centre + Vector3(
				rng.randf_range(-0.16, 0.16),
				BLADE_H * h * 0.5 - 0.02,
				rng.randf_range(-0.16, 0.16)
			)
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, tone)
			i += 1

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	# White base: the shader multiplies base_color by the per-instance COLOR, so a
	# tinted base would darken every blade twice over.
	mmi.material_override = Ink.mat(Color.WHITE, 0.0, 2)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	generated.add_child(mmi)


func _scatter_rocks() -> void:
	for i in range(rng.randi_range(4, 8)):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := rng.randf_range(0.22, 0.55)
		bm.size = Vector3(s, s * rng.randf_range(0.45, 0.8), s * rng.randf_range(0.7, 1.3))
		mi.mesh = bm
		# Grey-brown, not sand: a light warm box sitting on grass reads as a
		# cardboard carton, which is exactly what the first pass looked like.
		mi.material_override = Ink.mat(
			Ink.STONE.lerp(Color("5f5b52"), rng.randf_range(0.3, 0.7)), 0.8
		)

		# Keep them out of the huddle, so one never ends up parked in the middle
		# of the conversation.
		var pos := Vector3.ZERO
		for attempt in range(12):
			var a := rng.randf_range(0, TAU)
			var d := rng.randf_range(9.0, 28.0)
			pos = Vector3(cos(a) * d, 0, sin(a) * d)
			if pos.distance_to(group_center) > 6.0:
				break

		mi.position = pos + Vector3(0, bm.size.y * 0.32, 0)
		mi.rotation = Vector3(
			rng.randf_range(-0.22, 0.22), rng.randf_range(0, TAU), rng.randf_range(-0.22, 0.22)
		)
		generated.add_child(mi)


# --- The tree ----------------------------------------------------------------

func _build_trees() -> void:
	# The hero tree goes on the far side of the group from where the player walks
	# in, so it frames the huddle instead of standing somewhere off-frame. Left a
	# little to one side — dead centre behind them would look staged.
	var back := atan2(-group_gap_dir.z, -group_gap_dir.x)
	var hero_angle := back + rng.randf_range(-0.55, 0.55)
	_make_tree(
		group_center + Vector3(cos(hero_angle), 0, sin(hero_angle)) * rng.randf_range(5.5, 7.5),
		rng.randf_range(1.05, 1.3)
	)

	for i in range(rng.randi_range(2, 4)):
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(20.0, 32.0)
		_make_tree(Vector3(cos(a) * d, 0, sin(a) * d), rng.randf_range(0.7, 1.05))


func _make_tree(at: Vector3, s: float) -> void:
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = at
	tree.scale = Vector3.ONE * s
	tree.rotation.y = rng.randf_range(0, TAU)
	generated.add_child(tree)

	var bark := Ink.mat(Ink.BARK.lerp(Ink.INK, rng.randf_range(0.0, 0.15)))
	var trunk_h := rng.randf_range(3.0, 4.0)

	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.26
	cm.bottom_radius = 0.48
	cm.height = trunk_h
	cm.radial_segments = 8       # faceted on purpose — smooth cylinders read as CG
	cm.rings = 1
	trunk.mesh = cm
	trunk.position = Vector3(0, trunk_h * 0.5, 0)
	trunk.material_override = bark
	tree.add_child(trunk)

	# Root flare: a few boxes shoved into the ground at the base.
	for i in range(rng.randi_range(3, 5)):
		var root := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.22, 0.4, 0.5)
		root.mesh = rb
		var a := rng.randf_range(0, TAU)
		root.position = Vector3(cos(a) * 0.42, 0.14, sin(a) * 0.42)
		root.rotation = Vector3(rng.randf_range(0.2, 0.5), -a, 0)
		root.material_override = bark
		tree.add_child(root)

	# Branches
	for i in range(rng.randi_range(2, 3)):
		var br := MeshInstance3D.new()
		var bcm := CylinderMesh.new()
		bcm.top_radius = 0.07
		bcm.bottom_radius = 0.16
		bcm.height = rng.randf_range(1.2, 1.9)
		bcm.radial_segments = 6
		bcm.rings = 1
		br.mesh = bcm
		var a := rng.randf_range(0, TAU)
		br.position = Vector3(0, trunk_h * rng.randf_range(0.6, 0.85), 0)
		br.rotation = Vector3(0, a, rng.randf_range(0.7, 1.1))
		br.translate_object_local(Vector3(0, bcm.height * 0.45, 0))
		br.material_override = bark
		tree.add_child(br)

	# Canopy: overlapping low-poly spheres in three leaf tones so the mass has
	# internal shape instead of being one silhouette blob.
	var leaves := [Ink.LEAF_A, Ink.LEAF_B, Ink.LEAF_C]
	var blobs := rng.randi_range(4, 6)
	for i in range(blobs):
		var lb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(1.05, 1.7)
		sm.height = sm.radius * rng.randf_range(1.5, 2.0)
		sm.radial_segments = 8
		sm.rings = 5
		lb.mesh = sm
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(0.0, 1.1)
		lb.position = Vector3(cos(a) * d, trunk_h + rng.randf_range(0.1, 1.0), sin(a) * d)
		lb.material_override = Ink.mat(leaves[i % leaves.size()], 1.0, 3)
		tree.add_child(lb)


# --- People ------------------------------------------------------------------

func _build_group() -> void:
	group_center = Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))

	var n := rng.randi_range(npc_count_min, npc_count_max)
	# The group stands in a horseshoe. The opening faces `gap_dir`, which is where
	# the player walks in from — a closed circle of backs is unreadable and
	# unfriendly to approach.
	var gap_dir := rng.randf_range(0, TAU)
	group_gap_dir = Vector3(cos(gap_dir), 0, sin(gap_dir))
	var radius := 1.75 + n * 0.13
	var arc := TAU * 0.62

	for i in range(n):
		var t := float(i) / float(maxi(n - 1, 1))
		var a := gap_dir + PI - arc * 0.5 + arc * t
		var pos := group_center + Vector3(cos(a) * radius, 0, sin(a) * radius)

		var npc := Npc.create(
			_pick_name(),
			rng.randf_range(0.0, 10.0),
			Ink.SKINS[rng.randi() % Ink.SKINS.size()],
			Ink.SHIRTS[rng.randi() % Ink.SHIRTS.size()],
			Ink.PANTS[rng.randi() % Ink.PANTS.size()],
			Ink.HAIRS[rng.randi() % Ink.HAIRS.size()],
			rng.randf_range(0.88, 1.12)
		)
		npc.position = pos
		# Face the middle of the huddle, with a little slop so they aren't a chorus line.
		var to_center := group_center - pos
		npc.rotation.y = atan2(-to_center.x, -to_center.z) + rng.randf_range(-0.22, 0.22)
		generated.add_child(npc)
		npcs.append(npc)


func _pick_name() -> String:
	for attempt in range(24):
		var n: String = Ink.NAMES[rng.randi() % Ink.NAMES.size()]
		if not _used_names.has(n):
			_used_names.append(n)
			return n
	return "Stranger"


func _place_player() -> void:
	if player == null:
		player = PLAYER_SCENE.instantiate()
		add_child(player)
		player.interact_pressed.connect(_on_interact)

	# Drop the player at the mouth of the horseshoe, far enough out that walking
	# in is a deliberate act.
	player.global_position = group_center + group_gap_dir * 5.5 + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	var face := group_center - player.global_position
	player.rotation.y = atan2(-face.x, -face.z)
	# CamYaw is a child of the player, so its rotation is relative — setting it to
	# the player's yaw would turn the camera twice and put the group off-screen.
	player.cam_yaw.rotation.y = 0.0

	dialogue.camera = player.camera
	touch.player = player
	for n in npcs:
		n.look_at_node(player)


# --- Interaction -------------------------------------------------------------

func _process(_delta: float) -> void:
	if player == null or npcs.is_empty():
		return

	if dialogue.is_active():
		player.input_locked = true
		dialogue.hide_prompt()
		return

	player.input_locked = false
	var near := _nearest_npc()
	if near:
		var verb := "TALK" if player.touch_mode else "E"
		dialogue.show_prompt("%s  —  talk to %s" % [verb, near.npc_name])
	else:
		dialogue.hide_prompt()


func _nearest_npc() -> Npc:
	var best: Npc = null
	var best_d := interact_range
	for n in npcs:
		var d := player.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _on_interact() -> void:
	if dialogue.is_active():
		if not dialogue.skip_typing():
			dialogue.advance()
		return

	var near := _nearest_npc()
	if near == null:
		return
	for n in npcs:
		n.look_at_node(player)
	dialogue.start(_build_conversation(near))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reshuffle"):
		world_seed = 0
		_used_names.clear()
		generate()


# --- Conversation ------------------------------------------------------------

const SCENARIOS := [
	[
		[-1, "Right. Which one of you moved the boundary stone?"],
		[0, "Nobody moved it. It walked."],
		[1, "It did not walk. Stones don't walk."],
		[0, "This one's been walking since March."],
		[-1, "…and none of you thought to mention it."],
		[2, "We assumed you'd notice. You're very observant, normally."],
		[1, "He's being sarcastic. Don't take it in."],
		[-1, "Show me the stone."],
	],
	[
		[-1, "You've been standing under this tree for three days."],
		[0, "Two and a half."],
		[1, "We're waiting."],
		[-1, "For what?"],
		[2, "Nobody wants to be the one who says it out loud."],
		[0, "Say it, then."],
		[2, "…After you."],
		[-1, "I'll be back at sundown. Decide by then."],
	],
	[
		[0, "There he is. We were just talking about you."],
		[-1, "That's rarely good."],
		[1, "It isn't, particularly."],
		[-1, "Go on."],
		[0, "The field's wrong. The grass grows toward the tree instead of the sun."],
		[2, "Show him. Kneel down and look along it."],
		[-1, "…How long has it done that?"],
		[1, "Since you got here, funnily enough."],
	],
	[
		[-1, "Is this everyone?"],
		[0, "This is everyone who'd come."],
		[1, "The others said the field was fine and went back in."],
		[-1, "And you don't think it's fine."],
		[2, "I think the tree is closer than it was yesterday."],
		[0, "Don't start."],
		[2, "I marked it. With a rope. I'm not mad."],
		[-1, "Get the rope."],
	],
]


func _build_conversation(first: Npc) -> Array[Dictionary]:
	var script_lines: Array = SCENARIOS[rng.randi() % SCENARIOS.size()]

	# Map scripted speaker slots onto whoever is actually standing here, with the
	# NPC the player walked up to taking slot 0.
	var cast: Array[Npc] = [first]
	for n in npcs:
		if n != first:
			cast.append(n)

	var out: Array[Dictionary] = []
	for entry in script_lines:
		var who_idx: int = entry[0]
		var text: String = entry[1]
		if who_idx < 0:
			out.append({"who": player, "name": "You", "text": text})
		else:
			var npc: Npc = cast[who_idx % cast.size()]
			out.append({"who": npc, "name": npc.npc_name, "text": text})
	return out
