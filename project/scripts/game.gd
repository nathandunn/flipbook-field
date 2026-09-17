## Game — the turn loop, the nemesis, and the scoring.
##
## One round is: your turn (4 actions) → your talk → their turn (played out at
## 3x so you can read it) → their talk → scoreboard. Three rounds to a match.
## Whoever has the most people at the end wins; points break ties.
extends Node3D

enum Phase { PLAYER_TURN, TALK, NEMESIS_TURN, ROUND_END, MATCH_OVER }

@export var world_seed: int = 0
@export var neutral_count: int = 12
@export var starting_followers: int = 3
@export var starting_haters: int = 2

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const NEMESIS_SPEEDUP := 3.0

var rng := RandomNumberGenerator.new()
var office: Office
var player: Player
var nemesis: Person
var people: Array[Person] = []

var phase: int = Phase.PLAYER_TURN
var round_no: int = 1
var actions_left: int = Arch.ACTIONS_PER_TURN

var satchel := {Arch.Side.PLAYER: [], Arch.Side.NEMESIS: []}
var points := {Arch.Side.PLAYER: 0, Arch.Side.NEMESIS: 0}
var claps_total := {Arch.Side.PLAYER: 0, Arch.Side.NEMESIS: 0}
var boos_total := {Arch.Side.PLAYER: 0, Arch.Side.NEMESIS: 0}
## Reset each round so the end-of-round card compares like with like.
var round_stats := {}

@onready var sun: DirectionalLight3D = $Sun
@onready var hud: Hud = $UI/Hud
@onready var talk_ui: Presentation = $UI/Presentation
@onready var dialogue: Dialogue = $UI/Dialogue
@onready var touch: TouchControls = $UI/Touch

var _used_names: Array[String] = []
var _busy: bool = false
var talk_cam: Camera3D


func _ready() -> void:
	rng.seed = world_seed if world_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0)

	office = Office.new()
	office.name = "Office"
	add_child(office)
	office.build(rng)

	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(38.0), 0.0)

	_spawn_people()
	_spawn_player()

	# A fixed stage camera for talks. Presenting from inside your own crowd, which
	# is what the follow camera gives you, is a wall of blocks.
	talk_cam = Camera3D.new()
	talk_cam.name = "TalkCamera"
	talk_cam.fov = 50.0
	add_child(talk_cam)
	# Side-on: presenter on the left, crowd filling the right. Behind the presenter
	# would be the obvious shot, but the slate screen sits back there and blocks it.
	talk_cam.global_position = Office.ROCK_POS + Vector3(10.5, 4.2, 2.0)
	talk_cam.look_at(Office.ROCK_POS + Vector3(0.5, 1.3, 4.2))

	talk_ui.finished.connect(_on_talk_finished)
	talk_ui.round_closed.connect(_on_round_closed)

	hud.set_hint(
		"WASD move · Shift run · E act at a station · walk to the rock to present · Esc free mouse"
	)
	_begin_player_turn()


# --- setup -------------------------------------------------------------------

func _pick_name() -> String:
	for attempt in range(40):
		var n: String = Ink.NAMES[rng.randi() % Ink.NAMES.size()]
		if not _used_names.has(n):
			_used_names.append(n)
			return n
	return "Colleague %d" % _used_names.size()


func _add_person(kind: int, side: int, at: Vector3) -> Person:
	var p := Person.create(_pick_name(), kind, side, rng.randf_range(0.0, 10.0))
	p.taste = rng.randi() % 4
	add_child(p)
	p.global_position = at + Vector3(0, 0.1, 0)
	p.home_pos = at
	people.append(p)
	return p


func _spawn_people() -> void:
	for i in range(starting_followers):
		var a := TAU * float(i) / float(starting_followers)
		_add_person(Arch.Kind.FOLLOWER, Arch.Side.PLAYER,
			Office.DESK_CLUSTER + Vector3(cos(a) * 3.5, 0, sin(a) * 3.0 + 4.0))

	for i in range(starting_followers):
		var a := TAU * float(i) / float(starting_followers)
		_add_person(Arch.Kind.FOLLOWER, Arch.Side.NEMESIS,
			Office.BREAK_POS + Vector3(cos(a) * 3.5, 0, sin(a) * 3.0))

	for i in range(starting_haters):
		_add_person(Arch.Kind.HATER, Arch.Side.NEMESIS,
			Office.BREAK_POS + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5)))

	# The contested pool. Scattered wide on purpose: reaching them costs walking,
	# which is what makes the action budget bite.
	for i in range(neutral_count):
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(6.0, 20.0)
		_add_person(Arch.Kind.NEUTRAL, Arch.Side.NONE, Vector3(cos(a) * d, 0, sin(a) * d * 0.8))

	nemesis = Person.create("Your Nemesis", Arch.Kind.FOLLOWER, Arch.Side.NEMESIS, 3.3)
	add_child(nemesis)
	nemesis.global_position = Office.BREAK_POS + Vector3(0, 0.1, 2.0)
	nemesis.home_pos = Office.BREAK_POS
	if nemesis.rig:
		nemesis.rig.scale *= 1.08


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.2, 4.0)
	player.interact_pressed.connect(_on_interact)
	dialogue.camera = player.camera
	touch.player = player


# --- turn loop ---------------------------------------------------------------

func _reset_round_stats() -> void:
	round_stats = {
		Arch.Side.PLAYER: {"claps": 0, "boos": 0, "gained": 0, "lost": 0},
		Arch.Side.NEMESIS: {"claps": 0, "boos": 0, "gained": 0, "lost": 0},
	}


func _begin_player_turn() -> void:
	phase = Phase.PLAYER_TURN
	actions_left = Arch.ACTIONS_PER_TURN
	_reset_round_stats()
	for p in people:
		p.resolve = false
	_refresh_hud()
	hud.banner("ROUND %d — YOUR TURN" % round_no, 2.0)


func _refresh_hud() -> void:
	hud.set_round(round_no, Arch.ROUNDS_PER_MATCH)
	hud.set_score(
		_count(Arch.Side.PLAYER), _count(Arch.Side.NEMESIS),
		points[Arch.Side.PLAYER], points[Arch.Side.NEMESIS]
	)
	hud.set_props(satchel[Arch.Side.PLAYER])
	hud.set_actions(actions_left, Arch.ACTIONS_PER_TURN)


func _count(side: int) -> int:
	var n := 0
	for p in people:
		if p.side == side and p.kind != Arch.Kind.NEUTRAL:
			n += 1
	return n


func _process(_delta: float) -> void:
	if player == null:
		return

	var free_to_walk := phase == Phase.PLAYER_TURN and not _busy
	player.input_locked = not free_to_walk
	touch.enabled = free_to_walk

	if not free_to_walk:
		hud.hide_prompt()
		return

	var st := office.station_at(player.global_position)
	if st.is_empty():
		hud.hide_prompt()
		return

	var verb := "E"
	if player.touch_mode:
		verb = "TALK"
	if st["kind"] == Office.St.ROCK:
		hud.show_prompt("%s  —  present (ends your turn)" % verb)
	elif actions_left > 0:
		hud.show_prompt("%s  —  %s" % [verb, st["label"]])
	else:
		hud.show_prompt("out of actions — go to the rock")


func _on_interact() -> void:
	if phase != Phase.PLAYER_TURN or _busy:
		return
	var st := office.station_at(player.global_position)
	if st.is_empty():
		return

	if st["kind"] == Office.St.ROCK:
		_start_talk(Arch.Side.PLAYER)
		return

	if actions_left <= 0:
		hud.toast("No actions left. Head for the rock.")
		return

	actions_left -= 1
	match int(st["kind"]):
		Office.St.DESK:
			_act_desk(Arch.Side.PLAYER)
		Office.St.STREAM:
			_act_stream(Arch.Side.PLAYER)
		Office.St.BREAK:
			_act_break(Arch.Side.PLAYER)
	_tick_influencers(Arch.Side.PLAYER)
	_refresh_hud()


# --- the three verbs ---------------------------------------------------------

func _act_desk(side: int) -> void:
	var taste: int = rng.randi() % 4
	var names: Array = Arch.PROPS[taste]
	var prop := {"taste": taste, "name": names[rng.randi() % names.size()]}
	satchel[side].append(prop)

	# The pile of stuff is what makes people curious. Warming is a side effect of
	# gathering, which is what keeps the stream from being the only good action.
	var warmed := _warm_nearest(_actor_pos(side), Arch.WARM_COUNT, Arch.WARM_AMOUNT)
	if side == Arch.Side.PLAYER:
		hud.toast("Picked up %s. %d nearby got curious." % [prop["name"], warmed])


func _act_stream(side: int) -> void:
	var curious: Array[Person] = []
	for p in people:
		if p.is_curious() and p.global_position.distance_to(office.stream_point) <= Arch.STREAM_RADIUS:
			curious.append(p)

	if curious.is_empty():
		# Small talk with cold people is not nothing, but it is not a close.
		var warmed := 0
		for p in people:
			if p.kind == Arch.Kind.NEUTRAL \
					and p.global_position.distance_to(office.stream_point) <= Arch.STREAM_RADIUS:
				p.warm(0.5)
				warmed += 1
		if side == Arch.Side.PLAYER:
			hud.toast("Nobody by the water was interested yet. %d warmed a little." % warmed)
		return

	curious.sort_custom(func(a, b): return a.curiosity > b.curiosity)
	var taken := 0
	for p in curious:
		if taken >= Arch.STREAM_CLOSE_MAX:
			break
		# A nemesis that already has a crowd starts making enemies instead of
		# friends - which is where haters come from.
		var kind := Arch.Kind.FOLLOWER
		# Somebody you had to work at is worth more than somebody who was already
		# half-convinced: a full-curiosity close sometimes turns out to be a
		# well-connected one.
		if p.curiosity >= Arch.CURIOSITY_MAX - 0.01 and rng.randf() < 0.3:
			kind = Arch.Kind.INFLUENCER
		if side == Arch.Side.NEMESIS and _count(Arch.Side.NEMESIS) >= 5 and rng.randf() < 0.45:
			kind = Arch.Kind.HATER
		p.set_kind_side(kind, side)
		p.goto(p.home_pos)
		taken += 1

	if side == Arch.Side.PLAYER:
		hud.toast("Won over %d at the water." % taken)
	else:
		hud.toast("They won over %d at the water." % taken)


func _act_break(side: int) -> void:
	# Somebody who was never going to argue wanders in and stands at the back.
	var at: Vector3 = office.break_point + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	_add_person(Arch.Kind.WAGE_SLAVE, side, at)

	for p in people:
		if p.side == side and Arch.flippable(p.kind):
			p.resolve = true

	if side == Arch.Side.NEMESIS:
		# Rallying the troops radicalises one of them.
		for p in people:
			if p.side == side and p.kind == Arch.Kind.FOLLOWER and rng.randf() < 0.4:
				p.set_kind_side(Arch.Kind.HATER, side)
				break
		hud.toast("They rallied. Somebody came back angrier.")
	else:
		hud.toast("Rallied. A wage slave drifted in; your people will hold this round.")


func _warm_nearest(from: Vector3, count: int, amount: float) -> int:
	var pool: Array[Person] = []
	for p in people:
		if p.kind == Arch.Kind.NEUTRAL:
			pool.append(p)
	pool.sort_custom(func(a, b):
		return a.global_position.distance_to(from) < b.global_position.distance_to(from))
	var n := 0
	for i in range(mini(count, pool.size())):
		if pool[i].global_position.distance_to(from) > 16.0:
			break
		pool[i].warm(amount)
		# Curious people drift toward the water, which is where you close them.
		if pool[i].is_curious():
			pool[i].goto(office.stream_point + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-2, 2)))
		n += 1
	return n


func _tick_influencers(side: int) -> void:
	for p in people:
		if p.side == side and p.kind == Arch.Kind.INFLUENCER:
			_warm_nearest(p.global_position, 1, Arch.WARM_AMOUNT)


func _actor_pos(side: int) -> Vector3:
	return player.global_position if side == Arch.Side.PLAYER else nemesis.global_position


# --- presentation ------------------------------------------------------------

func _start_talk(side: int) -> void:
	_busy = true
	phase = Phase.TALK

	if satchel[side].is_empty():
		hud.toast("Nothing in the satchel. That was a short talk.")

	var assembled := _assemble(side)

	# Presenter takes the rock and faces +Z, which is where the crowd forms.
	var stage: Vector3 = Office.ROCK_POS + Vector3(0, 1.05, 0)
	if side == Arch.Side.PLAYER:
		player.velocity = Vector3.ZERO
		player.global_position = stage
		player.rotation.y = PI
	else:
		nemesis.stop_walking()
		nemesis.global_position = stage
		nemesis.rotation.y = PI

	talk_cam.current = true
	hud.hide_prompt()
	hud.banner("Gathering at the rock…", 2.0)
	# Long enough to watch who actually turned up, which is the information the
	# slide choices are about to depend on.
	await get_tree().create_timer(3.4).timeout

	talk_ui.begin(side, satchel[side], assembled[0], assembled[1])


## Returns [audience, spectators] and walks everybody to the rock.
func _assemble(side: int) -> Array:
	var other: int = Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER
	var audience: Array = []
	for p in people:
		if p.side == side and p.kind != Arch.Kind.NEUTRAL:
			audience.append(p)
		elif p.side == other and Arch.boos(p.kind):
			audience.append(p)

	# Crowd size is what pulls passers-by in, which is the entire point of wage
	# slaves: volume without signal.
	var slots: int = int(floor(float(audience.size()) / float(Arch.SPECTATOR_PER_HEADS)))
	var curious: Array[Person] = []
	for p in people:
		if p.is_curious():
			curious.append(p)
	curious.sort_custom(func(a, b):
		return a.global_position.distance_to(office.audience_center) \
			< b.global_position.distance_to(office.audience_center))
	var spectators: Array = curious.slice(0, maxi(slots, 0))

	var seats := audience + spectators
	for i in range(seats.size()):
		var row := i / 6
		var col := i % 6
		var seat: Vector3 = office.audience_center + Vector3(
			(col - 2.5) * 1.5, 0, row * 1.7
		)
		var person: Person = seats[i]
		person.goto(seat, true)
		person.look_at_node(nemesis if side == Arch.Side.NEMESIS else player)

	return [audience, spectators]


func _on_talk_finished(result: Dictionary) -> void:
	var side: int = result["side"]
	var other: int = Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER

	for p in result["won"]:
		(p as Person).set_kind_side(Arch.Kind.FOLLOWER, side)
	for p in result["lost"]:
		(p as Person).set_kind_side(Arch.Kind.HATER, other)

	claps_total[side] += int(result["claps"])
	boos_total[side] += int(result["boos"])
	points[side] += maxi(int(result["claps"]) - int(result["boos"]), 0)

	round_stats[side]["claps"] += int(result["claps"])
	round_stats[side]["boos"] += int(result["boos"])
	round_stats[side]["gained"] += result["won"].size()
	# A flip is a loss for whoever was presenting and a gain for the other side.
	round_stats[side]["lost"] += result["lost"].size()
	round_stats[other]["gained"] += result["lost"].size()

	# A talk that went genuinely well converts one of the faithful into a lover,
	# which is what makes momentum compound instead of just accumulating.
	var ratio: float = float(result["claps"]) / maxf(float(result["claps"] + result["boos"]), 1.0)
	if ratio > 0.78 and int(result["claps"]) >= 20:
		for p in people:
			if p.side == side and p.kind == Arch.Kind.FOLLOWER:
				p.set_kind_side(Arch.Kind.LOVER, side)
				if side == Arch.Side.PLAYER:
					hud.toast("%s is now a true believer." % p.person_name)
				break

	satchel[side].clear()

	talk_cam.current = false
	if player and player.camera:
		player.camera.current = true
	if side == Arch.Side.PLAYER:
		player.global_position = office.rock_point + Vector3(0, 0.3, 2.4)

	for p in people:
		p.goto(p.home_pos + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)))
		p.look_at_node(null)

	_refresh_hud()
	_busy = false

	if side == Arch.Side.PLAYER:
		_nemesis_turn()
	else:
		_end_round()


# --- nemesis -----------------------------------------------------------------

func _nemesis_turn() -> void:
	phase = Phase.NEMESIS_TURN
	_busy = true
	hud.banner("THEIR TURN", 1.6)
	await get_tree().create_timer(1.2).timeout

	Engine.time_scale = NEMESIS_SPEEDUP
	for i in range(Arch.ACTIONS_PER_TURN):
		var choice := _nemesis_choose()
		await _walk_to(nemesis, choice["pos"])
		match int(choice["kind"]):
			Office.St.DESK:
				_act_desk(Arch.Side.NEMESIS)
			Office.St.STREAM:
				_act_stream(Arch.Side.NEMESIS)
			Office.St.BREAK:
				_act_break(Arch.Side.NEMESIS)
		_tick_influencers(Arch.Side.NEMESIS)
		_refresh_hud()
		await get_tree().create_timer(0.45).timeout
	Engine.time_scale = 1.0

	# Somebody angry enough gets sent to heckle you next time.
	_maybe_send_bully()

	await _walk_to(nemesis, office.rock_point, 6.0)
	_start_talk(Arch.Side.NEMESIS)


func _nemesis_choose() -> Dictionary:
	var have: int = satchel[Arch.Side.NEMESIS].size()
	var curious_near := 0
	for p in people:
		if p.is_curious() and p.global_position.distance_to(office.stream_point) <= Arch.STREAM_RADIUS:
			curious_near += 1

	# Deliberately legible: gather until it has slides, close when there is
	# anybody to close, rally when it is already ahead. You should be able to
	# predict it after one round, and plan against it.
	var kind: int
	if have < Arch.SLIDES_PER_TALK and (curious_near == 0 or have < 2):
		kind = Office.St.DESK
	elif curious_near > 0:
		kind = Office.St.STREAM
	elif _count(Arch.Side.NEMESIS) >= _count(Arch.Side.PLAYER):
		kind = Office.St.BREAK
	else:
		kind = Office.St.DESK

	if kind == Office.St.DESK:
		var d: Vector3 = office.desk_points[rng.randi() % office.desk_points.size()]
		return {"kind": kind, "pos": d}
	if kind == Office.St.STREAM:
		return {"kind": kind, "pos": office.stream_point}
	return {"kind": kind, "pos": office.break_point}


func _maybe_send_bully() -> void:
	var haters: Array[Person] = []
	for p in people:
		if p.side == Arch.Side.NEMESIS and p.kind == Arch.Kind.HATER:
			haters.append(p)
	if haters.size() >= 2:
		haters[rng.randi() % haters.size()].set_kind_side(Arch.Kind.BULLY, Arch.Side.NEMESIS)
		hud.toast("One of them has been sent to sit at the front of your next talk.")


func _walk_to(p: Person, pos: Vector3, max_time: float = 12.0) -> void:
	p.goto(pos)
	var t := 0.0
	while t < max_time:
		await get_tree().process_frame
		t += get_process_delta_time()
		var flat := Vector3(pos.x, p.global_position.y, pos.z)
		if p.global_position.distance_to(flat) <= Person.ARRIVE_DIST + 0.2:
			break
	p.stop_walking()


# --- round / match -----------------------------------------------------------

func _end_round() -> void:
	phase = Phase.ROUND_END
	_busy = true

	# Bullies go back to being ordinary haters between rounds.
	for p in people:
		if p.kind == Arch.Kind.BULLY:
			p.set_kind_side(Arch.Kind.HATER, p.side)

	var you: Dictionary = round_stats[Arch.Side.PLAYER].duplicate()
	var them: Dictionary = round_stats[Arch.Side.NEMESIS].duplicate()
	you["people"] = _count(Arch.Side.PLAYER)
	them["people"] = _count(Arch.Side.NEMESIS)

	await get_tree().create_timer(0.8).timeout
	talk_ui.show_round(round_no, Arch.ROUNDS_PER_MATCH, you, them,
		round_no >= Arch.ROUNDS_PER_MATCH)


func _on_round_closed(again: bool) -> void:
	if again:
		get_tree().reload_current_scene()
		return
	round_no += 1
	_busy = false
	_begin_player_turn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reshuffle") and (phase == Phase.MATCH_OVER or phase == Phase.PLAYER_TURN):
		get_tree().reload_current_scene()
