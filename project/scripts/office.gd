## Office — the outdoor office, built out of natural elements.
##
## Slab-stone desks on stump legs with slate monitors, a break room under a
## canopy, a stream standing in for the water cooler, and a flat rock to present
## from with a slate slab behind it for a screen. Everything is generated, so the
## layout is a set of rules rather than a hand-placed scene.
class_name Office
extends Node3D

enum St { DESK, STREAM, BREAK, ROCK }

const STREAM_Z := 10.5
const ROCK_POS := Vector3(0, 0, -11.0)
const BREAK_POS := Vector3(9.5, 0, 2.5)
const DESK_CLUSTER := Vector3(-8.5, 0, 0.0)

## Each entry: { kind, pos, label, radius }
var stations: Array[Dictionary] = []
var desk_points: Array[Vector3] = []
## Parallel to desk_points: which taste each desk gathers, or -1 for a mixed
## desk that hands out whatever is on it. Typed desks are what make gathering
## a choice - you go to the Story desk because the room wants stories.
var desk_tastes: Array[int] = []
var stream_point := Vector3(0, 0, STREAM_Z - 2.2)
var break_point := BREAK_POS
var rock_point := ROCK_POS + Vector3(0, 0, 1.6)
var audience_center := ROCK_POS + Vector3(0, 0, 5.5)

var rng := RandomNumberGenerator.new()


func build(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	for c in get_children():
		c.queue_free()
	stations.clear()
	desk_points.clear()
	desk_tastes.clear()

	_ground()
	_stream()
	_desks()
	_break_room()
	_rock()
	_scatter()


# --- ground ------------------------------------------------------------------

func _ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"

	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(110, 110)
	mi.mesh = plane
	# No outline on the ground: its inverted hull would be a 110 m black box.
	mi.material_override = Ink.mat(Ink.GRASS, 0.0, 3)
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(110, 1, 110)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	add_child(body)

	# Worn ground between the stations - a desire path, which is the cheapest way
	# to tell the player that these four places are the ones that matter. Linked
	# in a ring rather than radiating from the middle, which reads as a star.
	var ring := [DESK_CLUSTER, stream_point, BREAK_POS, ROCK_POS]
	for i in range(ring.size()):
		_path_patch(ring[i], ring[(i + 1) % ring.size()])

	for i in range(10):
		var patch := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.height = 0.002
		disc.top_radius = rng.randf_range(2.0, 5.0)
		disc.bottom_radius = disc.top_radius
		disc.radial_segments = rng.randi_range(11, 16)
		disc.rings = 0
		patch.mesh = disc
		patch.material_override = Ink.mat(
			Ink.GRASS.lerp(Ink.GRASS_DARK, rng.randf_range(0.25, 0.55)), 0.0, 2
		)
		patch.position = Vector3(rng.randf_range(-28, 28), 0.008 + i * 0.003, rng.randf_range(-28, 28))
		patch.rotation.y = rng.randf_range(0, TAU)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)


func _path_patch(from: Vector3, to: Vector3) -> void:
	var steps := int(from.distance_to(to) / 1.6) + 1
	for i in range(steps):
		var t := float(i) / float(maxi(steps - 1, 1))
		var p := from.lerp(to, t)
		var mi := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.height = 0.002
		disc.top_radius = rng.randf_range(0.9, 1.5)
		disc.bottom_radius = disc.top_radius
		disc.radial_segments = 9
		disc.rings = 0
		mi.mesh = disc
		mi.material_override = Ink.mat(Ink.GRASS.lerp(Ink.DIRT, 0.35), 0.0, 2)
		mi.position = p + Vector3(rng.randf_range(-0.5, 0.5), 0.02, rng.randf_range(-0.5, 0.5))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


# --- the water cooler --------------------------------------------------------

func _stream() -> void:
	var water := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(70, 0.24, 3.4)
	water.mesh = bm
	water.position = Vector3(0, 0.02, STREAM_Z)
	# Flat and slightly luminous rather than reflective: a mirror would fight the
	# flat fills everywhere else.
	var wm := Ink.mat(Color("4f8296"), 0.0, 2)
	wm.set_shader_parameter("rim_strength", 0.9)
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	for bank_z in [STREAM_Z - 1.9, STREAM_Z + 1.9]:
		var bank := MeshInstance3D.new()
		var bbm := BoxMesh.new()
		bbm.size = Vector3(70, 0.18, 0.8)
		bank.mesh = bbm
		bank.position = Vector3(0, 0.07, bank_z)
		bank.material_override = Ink.mat(Ink.DIRT.lerp(Ink.GRASS_DARK, 0.45), 0.0, 2)
		add_child(bank)

	# Stepping stones - the thing you actually stand on to talk to people.
	for i in range(5):
		var stone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.height = 0.22
		cm.top_radius = rng.randf_range(0.45, 0.7)
		cm.bottom_radius = cm.top_radius * 0.9
		cm.radial_segments = rng.randi_range(6, 8)
		cm.rings = 0
		stone.mesh = cm
		stone.position = Vector3(-4.0 + i * 2.0 + rng.randf_range(-0.3, 0.3), 0.12, STREAM_Z + rng.randf_range(-1.0, 1.0))
		stone.rotation.y = rng.randf_range(0, TAU)
		stone.material_override = Ink.mat(Ink.STONE.lerp(Color("5f5b52"), 0.35), 0.8)
		add_child(stone)

	_station(St.STREAM, stream_point, "Stream — water cooler", 3.4)


# --- desks -------------------------------------------------------------------

func _desks() -> void:
	var cols := 3
	var rows := 2
	var i := 0
	for r in range(rows):
		for c in range(cols):
			var p := DESK_CLUSTER + Vector3((c - 1) * 4.6, 0, (r - 0.5) * 4.4)
			p += Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			_desk(p, rng.randf_range(-0.3, 0.3))
			# The first four desks are one per taste; the rest are mixed.
			var taste: int = i if i < 4 else -1
			var label: String = ("%s desk" % Arch.TASTE_NAME[taste]) if taste >= 0 else "Desk — a bit of everything"
			desk_points.append(p + Vector3(0, 0, 1.9))
			desk_tastes.append(taste)
			_station(St.DESK, p + Vector3(0, 0, 1.9), label, 2.4)
			stations[stations.size() - 1]["taste"] = taste
			stations[stations.size() - 1]["desk"] = i
			i += 1


func _desk(at: Vector3, yaw: float) -> void:
	var node := Node3D.new()
	node.name = "Desk"
	node.position = at
	node.rotation.y = yaw
	add_child(node)

	var wood := Ink.mat(Ink.BARK.lerp(Ink.DIRT, rng.randf_range(0.0, 0.3)))
	var slate := Ink.mat(Color("6e7378"))

	# Slab top on two stump legs.
	_box(node, Vector3(2.4, 0.16, 1.2), Vector3(0, 0.78, 0), Ink.mat(Ink.STONE.lerp(Ink.DIRT, 0.25)))
	for sx in [-0.85, 0.85]:
		_cyl(node, 0.26, 0.22, 0.78, Vector3(sx, 0.39, 0), wood, 7)

	# "Monitor": a slate slab leaning on a twig stand.
	var mon := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(1.15, 0.72, 0.07)
	mon.mesh = mm
	mon.position = Vector3(0, 1.26, -0.32)
	mon.rotation.x = 0.16
	mon.material_override = slate
	node.add_child(mon)
	_box(node, Vector3(0.14, 0.24, 0.14), Vector3(0, 0.98, -0.24), wood)

	# Keyboard: a flat strip of bark. Mouse: a pebble.
	_box(node, Vector3(0.9, 0.06, 0.32), Vector3(0, 0.89, 0.22), wood)
	_box(node, Vector3(0.16, 0.09, 0.22), Vector3(0.72, 0.9, 0.22), Ink.mat(Ink.STONE))

	# Stump chair with a slab of bark for a back.
	_cyl(node, 0.42, 0.44, 0.5, Vector3(0, 0.25, 1.25), wood, 8)
	_box(node, Vector3(0.8, 0.5, 0.1), Vector3(0, 0.75, 1.62), wood)


# --- break room --------------------------------------------------------------

func _break_room() -> void:
	var node := Node3D.new()
	node.name = "BreakRoom"
	node.position = BREAK_POS
	add_child(node)

	var wood := Ink.mat(Ink.BARK)

	# A felled log, split flat, as the table.
	var table := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.height = 3.6
	tm.top_radius = 0.62
	tm.bottom_radius = 0.62
	tm.radial_segments = 10
	tm.rings = 0
	table.mesh = tm
	table.position = Vector3(0, 0.62, 0)
	table.rotation.z = PI * 0.5
	table.material_override = wood
	node.add_child(table)

	# Stumps around it.
	for i in range(6):
		var a := TAU * float(i) / 6.0
		_cyl(node, 0.4, 0.42, 0.52, Vector3(cos(a) * 2.9, 0.26, sin(a) * 2.4), wood, 8)

	# Coffee: a hollow log on legs with a drip into a gourd.
	_cyl(node, 0.36, 0.36, 1.0, Vector3(-2.2, 0.5, -1.8), wood, 8)
	_box(node, Vector3(0.5, 0.12, 0.5), Vector3(-2.2, 1.06, -1.8), Ink.mat(Color("4a3226")))
	_cyl(node, 0.22, 0.26, 0.3, Vector3(-2.2, 0.15, -1.3), Ink.mat(Color("9a8f5f")), 7)

	# Canopy overhead so the break room reads as a room.
	_tree(BREAK_POS + Vector3(2.0, 0, -2.6), 1.45)

	_station(St.BREAK, BREAK_POS + Vector3(0, 0, 3.0), "Break room — rally", 3.2)


# --- the presentation rock ---------------------------------------------------

func _rock() -> void:
	var node := Node3D.new()
	node.name = "PresentationRock"
	node.position = ROCK_POS
	add_child(node)

	var stone := Ink.mat(Ink.STONE.lerp(Color("5f5b52"), 0.4))

	# Flat-topped boulder you stand on - and it needs a collider, or the presenter
	# drops straight through it and delivers the talk from inside the rock.
	var rock_body := StaticBody3D.new()
	rock_body.name = "RockBody"
	node.add_child(rock_body)
	var rock_col := CollisionShape3D.new()
	var rock_shape := CylinderShape3D.new()
	rock_shape.height = 0.9
	rock_shape.radius = 2.2
	rock_col.shape = rock_shape
	rock_col.position = Vector3(0, 0.45, 0)
	rock_body.add_child(rock_col)

	var boulder := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.height = 0.9
	cm.top_radius = 2.1
	cm.bottom_radius = 2.6
	cm.radial_segments = 9
	cm.rings = 0
	boulder.mesh = cm
	boulder.position = Vector3(0, 0.45, 0)
	boulder.material_override = stone
	node.add_child(boulder)

	var step := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.height = 0.45
	sm.top_radius = 1.0
	sm.bottom_radius = 1.2
	sm.radial_segments = 8
	sm.rings = 0
	step.mesh = sm
	step.position = Vector3(0, 0.22, 2.7)
	step.material_override = stone
	node.add_child(step)

	# The screen: a pale slate slab wedged upright behind two standing stones.
	var screen := MeshInstance3D.new()
	var scm := BoxMesh.new()
	scm.size = Vector3(5.2, 3.1, 0.22)
	screen.mesh = scm
	screen.position = Vector3(0, 2.55, -2.3)
	screen.rotation.x = -0.06
	screen.material_override = Ink.mat(Color("cfc9b6"))
	screen.name = "Screen"
	node.add_child(screen)

	for sx in [-3.0, 3.0]:
		_cyl(node, 0.42, 0.55, 3.4, Vector3(sx, 1.7, -2.3), stone, 7)

	_station(St.ROCK, rock_point, "Rock — present", 3.0)


# --- scatter -----------------------------------------------------------------

func _scatter() -> void:
	const BLADE_H := 0.30
	var blade := BoxMesh.new()
	blade.size = Vector3(0.035, BLADE_H, 0.028)

	var tufts := 1400
	var per_tuft := 4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	mm.instance_count = tufts * per_tuft

	var i := 0
	for tuft in range(tufts):
		var a := rng.randf_range(0, TAU)
		var d := sqrt(rng.randf()) * 32.0
		var centre := Vector3(cos(a) * d, 0.0, sin(a) * d)
		# Keep grass out of the stream bed.
		if absf(centre.z - STREAM_Z) < 2.2:
			centre.z += 4.0
		var tone := Ink.GRASS_DARK.lerp(Ink.GRASS, rng.randf_range(0.0, 0.65))
		for b in range(per_tuft):
			var t := Transform3D()
			t = t.rotated(Vector3.UP, rng.randf_range(0, TAU))
			t = t.rotated(Vector3.FORWARD, rng.randf_range(-0.42, 0.42))
			var h := rng.randf_range(0.55, 1.35)
			t = t.scaled(Vector3(rng.randf_range(0.8, 1.2), h, 1.0))
			t.origin = centre + Vector3(
				rng.randf_range(-0.16, 0.16), BLADE_H * h * 0.5 - 0.02, rng.randf_range(-0.16, 0.16)
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
	add_child(mmi)

	# A ring of trees to close the room in, with a gap behind the rock so the
	# screen stays readable against sky.
	for i2 in range(16):
		var a := TAU * float(i2) / 16.0 + rng.randf_range(-0.08, 0.08)
		var dir := Vector3(cos(a), 0, sin(a))
		if dir.dot(Vector3(0, 0, -1)) > 0.86:
			continue
		_tree(dir * rng.randf_range(26.0, 33.0), rng.randf_range(0.8, 1.25))


func _tree(at: Vector3, s: float) -> void:
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = at
	tree.scale = Vector3.ONE * s
	tree.rotation.y = rng.randf_range(0, TAU)
	add_child(tree)

	var bark := Ink.mat(Ink.BARK.lerp(Ink.INK, rng.randf_range(0.0, 0.15)))
	var trunk_h := rng.randf_range(3.2, 4.4)
	_cyl(tree, 0.26, 0.48, trunk_h, Vector3(0, trunk_h * 0.5, 0), bark, 8)

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

	var leaves := [Ink.LEAF_A, Ink.LEAF_B, Ink.LEAF_C]
	for i in range(rng.randi_range(4, 6)):
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


# --- helpers -----------------------------------------------------------------

func _station(kind: int, pos: Vector3, label: String, radius: float) -> void:
	stations.append({"kind": kind, "pos": pos, "label": label, "radius": radius})


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, top: float, bottom: float, h: float, at: Vector3,
		mat: Material, segs: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 0
	mi.mesh = cm
	mi.position = at
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Nearest station to a world point, or an empty dictionary if none is in range.
## The desk that gathers [param taste], or a mixed desk for -1.
func desk_point(taste: int) -> Vector3:
	for i in range(desk_points.size()):
		if desk_tastes[i] == taste:
			return desk_points[i]
	return desk_points[0]


func station_at(p: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	for s in stations:
		var d: float = p.distance_to(s["pos"])
		if d <= float(s["radius"]) and d < best_d:
			best_d = d
			best = s
	return best
