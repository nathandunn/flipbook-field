## Game — the match, played as moves.
##
## You move, they move, you move, they move - four each - then both of you
## present, and a round is scored. Three rounds. Whoever has the most people at
## the end wins; points break ties.
##
## What changed from the first version, and why. Turns used to come in lumps:
## four actions from you, then four from them, so nothing you did could block,
## bait or answer the other side, and the match was two games of solitaire
## compared at the end. Now:
##
##   - Moves alternate, so the station you stand on is one they cannot use next
##     move, and the card they just took tells you what their talk will be.
##   - Desks are typed. You go to the Story desk because the room wants stories.
##     The HUD shows what the room wants; the board is public.
##   - Every card has two uses. Play it as a slide, or spend it to buy somebody
##     on the other side who wants it and is within reach. Their followers are
##     your targets and yours are theirs, and the break room's resolve is now a
##     defence and not just a free wage slave.
##   - The rounds escalate and the underdog gets a hand up.
##   - Both sides start with the same pieces, and only clappers score. A hater
##     or a wage slave is a piece, not a point.
##   - Interest is a tug of war: a neutral is curious about one side at a time,
##     so warming somebody is an investment the other side has to spend a move
##     to take back, not a gift to whoever reaches the stream next.
##   - Somebody booed out of a talk goes back to the grass, warm, rather than
##     joining the other side - which is what stops one bad talk from being
##     the whole match.
##   - Sabotage, both ways. Pinch a card from their hand at the desk of that
##     taste, spread a rumour at the stream to cool the people they warmed,
##     rig the projector at the rock so their best slide comes up blank. Every
##     trick is a move they can see on the HUD and answer.
extends Node3D

enum Phase { PLAYER_TURN, TALK, NEMESIS_TURN, ROUND_END, MATCH_OVER }

@export var world_seed: int = 0
@export var neutral_count: int = 12
@export var starting_haters: int = 1

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const NEMESIS_SPEEDUP := 3.0
## Faces 0 and 1 are spoken for - the two drawings cast as the player and the
## nemesis. The rest are dealt from a shuffled deck so no two people in a match
## wear the same face.
const NEMESIS_FACE := 1


var rng := RandomNumberGenerator.new()
var office: Office
var player: Player
var nemesis: Person
var people: Array[Person] = []

var phase: int = Phase.PLAYER_TURN
var round_no: int = 1
var move_no: int = 1
## For the HUD's pips: moves left this round.
var actions_left: int = Arch.MOVES_PER_ROUND

var satchel := {Arch.Side.PLAYER: [], Arch.Side.NEMESIS: []}
var points := {Arch.Side.PLAYER: 0, Arch.Side.NEMESIS: 0}
var claps_total := {Arch.Side.PLAYER: 0, Arch.Side.NEMESIS: 0}
var boos_total := {Arch.Side.PLAYER: 0, Arch.Side.NEMESIS: 0}
## Reset each round so the end-of-round card compares like with like.
var round_stats := {}

## Where each side stood for its last move. A station the other side is on is
## off the table for you this move - the chess part.
var occupied := {Arch.Side.PLAYER: "", Arch.Side.NEMESIS: ""}
var _presented := {Arch.Side.PLAYER: false, Arch.Side.NEMESIS: false}
## Lead changes across the match, for the scoreboard and for the harness.
var lead_changes: int = 0
var _last_leader: int = Arch.Side.NONE
## Who opened the last round, so level rounds alternate.
var _last_first: int = Arch.Side.NEMESIS
## Sabotage state. rigged[side] is true when the projector has been rigged
## against that side; cleared when they check it, or when it fires.
var rigged := {Arch.Side.PLAYER: false, Arch.Side.NEMESIS: false}
## What was done to whom this round, for the HUD and the round card.
var sabotage_log := {Arch.Side.PLAYER: [], Arch.Side.NEMESIS: []}

@onready var sun: DirectionalLight3D = $Sun
@onready var hud: Hud = $UI/Hud
@onready var talk_ui: Presentation = $UI/Presentation
@onready var dialogue: Dialogue = $UI/Dialogue
@onready var touch: TouchControls = $UI/Touch

var _used_names: Array[String] = []
var _face_deck: Array[int] = []
var _busy: bool = false
var talk_cam: Camera3D

var planner: Planner
var setup: Setup
## The Clue board: rooms and corridors over the office, and where each
## presenter is standing on it. A move is "walk up to N steps, then act".
var board: Board
var floor_plan: FloorPlan
var roster: Roster
## Set once the setup screen is done and the match is on the board.
var _started: bool = false
var pos := {Arch.Side.PLAYER: "lobby", Arch.Side.NEMESIS: "break"}
## A coin at the start of the match decides who opens by the Stream; it
## swaps every round, so over three rounds one side gets it twice.
var _start_flip: bool = false
## Who each side is: a job, four stats (charm, guile, hustle, grit), and the
## colleagues they started with. See Arch.Role.
var roles := {Arch.Side.PLAYER: Arch.Role.STAFF, Arch.Side.NEMESIS: Arch.Role.STAFF}
var stats := {Arch.Side.PLAYER: [1, 1, 1, 1], Arch.Side.NEMESIS: [1, 1, 1, 1]}
var parties := {Arch.Side.PLAYER: [], Arch.Side.NEMESIS: []}
## IT firewalls: [{room, owner, left}]. A walled room cannot be entered or
## walked through by the side it is walled against, for [code]left[/code] of
## that side's moves.
var firewalls: Array = []


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
	talk_cam.global_position = Office.ROCK_POS + Vector3(10.5, 4.2, 2.0)
	talk_cam.look_at(Office.ROCK_POS + Vector3(0.5, 1.3, 4.2))

	talk_ui.round_closed.connect(_on_round_closed)

	planner = Planner.new()
	planner.name = "Planner"
	$UI.add_child(planner)

	setup = Setup.new()
	setup.name = "Setup"
	$UI.add_child(setup)

	board = Board.from_office(office)
	floor_plan = FloorPlan.new()
	floor_plan.name = "FloorPlan"
	floor_plan.board = board
	$UI.add_child(floor_plan)

	roster = Roster.new()
	roster.name = "Roster"
	roster.game = self
	$UI.add_child(roster)
	planner.left_margin = Roster.W + 12.0
	planner.top_margin = FloorPlan.H + 16.0

	hud.set_hint("Pick a card each move · the board is top right · who is on each side is on the left")
	_start()


## Who are you, and who is with you - then the match.
func _start() -> void:
	_busy = true
	player.input_locked = true
	setup.open()
	var cfg: Dictionary = await setup.done
	_apply_setup(cfg)
	_started = true
	_begin_round()


func _apply_setup(cfg: Dictionary) -> void:
	roles[Arch.Side.PLAYER] = int(cfg["role"])
	stats[Arch.Side.PLAYER] = Array(cfg["stats"])
	parties[Arch.Side.PLAYER] = Array(cfg["party"])
	player.dress(roles[Arch.Side.PLAYER])
	player.auto_speed = 4.4 * (1.0 + 0.08 * float(stats[Arch.Side.PLAYER][2]))
	_start_flip = rng.randi() % 2 == 0
	_place_for_round()
	floor_plan.visible = true
	floor_plan.steps = _steps(Arch.Side.PLAYER)
	_refresh_plan()

	# The nemesis is dealt the same way: a job, the same free points, as many
	# colleagues as you took. Different picks, equal means.
	var nr: int = Arch.PLAYABLE[rng.randi() % Arch.PLAYABLE.size()]
	roles[Arch.Side.NEMESIS] = nr
	var ns: Array = Array(Arch.ROLE_STATS[nr]).duplicate()
	for i in range(Arch.FREE_POINTS):
		var k := int(rng.randi() % 4)
		if int(ns[k]) >= Arch.STAT_MAX:
			k = (k + 1) % 4
		ns[k] = int(ns[k]) + 1
	stats[Arch.Side.NEMESIS] = ns
	nemesis.dress(nr)
	# Four others, one of each job, never its own - the same rule as yours.
	var pool: Array = Arch.PLAYABLE.duplicate()
	pool.erase(nr)
	var np: Array = []
	while np.size() < Arch.PARTY_SIZE and not pool.is_empty():
		np.append(pool.pop_at(rng.randi() % pool.size()))
	parties[Arch.Side.NEMESIS] = np

	_spawn_parties()
	var names: Array[String] = []
	for r in np:
		names.append(Arch.ROLE_NAME[r])
	hud.toast("Your nemesis is %s, with %s." % [Arch.ROLE_NAME[nr], ", ".join(names) if names.size() > 0 else "nobody"], 4.0)
	var mine: Array[String] = []
	for r in parties[Arch.Side.PLAYER]:
		mine.append(Arch.ROLE_NAME[r])
	hud.set_hint("You: %s with %s  ·  Nemesis: %s with %s  ·  pick a card each move" % [
		Arch.ROLE_NAME[roles[Arch.Side.PLAYER]], ", ".join(mine), Arch.ROLE_NAME[nr], ", ".join(names)])


## The colleagues each side starts with, standing near their own end.
func _spawn_parties() -> void:
	# They are pieces: each stands in a room, has morale, and has a job ability.
	for side in [Arch.Side.PLAYER, Arch.Side.NEMESIS]:
		for r in parties[side]:
			var p := _add_person(Arch.Kind.FOLLOWER, side, board.room_pos(pos[side]), int(r))
			p.unit = true
			p.morale = Arch.MORALE_MAX
			p.cooldown = 0
			_park(p, pos[side])


## Is this job on this side - the presenter themselves, or anyone of it
## clapping for them? That is the whole test for a class's upside and its
## downside, so buying their IT person switches both off for them and on for
## you.
func _has(side: int, role: int) -> bool:
	if roles[side] == role:
		return true
	for p in people:
		if p.side == side and p.role == role and Arch.claps(p.kind):
			return true
	return false


func _stat(side: int, i: int) -> int:
	return int(stats[side][i])


## Start of a round: one side by the Stream, the other in the Break room,
## and they swap each round so neither end is anyone's for long.
func _place_for_round() -> void:
	var swap := (round_no % 2 == 0) != _start_flip
	pos = {
		Arch.Side.PLAYER: "break" if swap else "stream",
		Arch.Side.NEMESIS: "stream" if swap else "break",
	}
	_snap_to(player, board.room_pos(pos[Arch.Side.PLAYER]))
	_snap_to(nemesis, board.room_pos(pos[Arch.Side.NEMESIS]))
	# Colleagues start the round with their presenter.
	for side in [Arch.Side.PLAYER, Arch.Side.NEMESIS]:
		for p in _units(side):
			_park(p, pos[side])
			p.global_position = p.home_pos + Vector3(0, 0.1, 0)
	_refresh_plan()


## Steps a side may walk in one move. Hustle is legs.
func _steps(side: int) -> int:
	return maxi(1, 2 + _stat(side, 2) / 2 - (1 if _has(side, Arch.Role.LEGAL) else 0))


## Rooms this side can reach this move, and at what cost. The other side's
## room cannot be entered, and passing through it costs a step more.
func _reach(side: int) -> Dictionary:
	return _reach_from(side, pos[side])


func _reach_from(side: int, here: String, steps: int = -1) -> Dictionary:
	var d := board.distances(here, _blocked_for(side), _toll_for(side))
	var lim := _steps(side) if steps < 0 else steps
	var out := {}
	for id in d:
		if int(d[id]) <= lim:
			out[id] = int(d[id])
	return out


## Rooms this side cannot enter or walk through: any room the other side's
## IT has walled off.
func _blocked_for(side: int) -> Array:
	var out: Array = []
	for w in firewalls:
		if int(w["owner"]) != side and not out.has(w["room"]):
			out.append(w["room"])
	return out


## Rooms that cost a step more to walk through: where the other presenter is
## standing. You cannot stop there, but you can squeeze past. (It used to be a
## wall; once colleagues could move instead, a presenter parked in the Lobby
## sealed the Break room off from every desk for a whole match.)
func _toll_for(side: int) -> Array:
	return [pos[_other(side)]]


func _walled_against(side: int, room: String) -> bool:
	for w in firewalls:
		if int(w["owner"]) != side and w["room"] == room:
			return true
	return false


func _refresh_plan() -> void:
	if floor_plan == null:
		return
	floor_plan.you = pos[Arch.Side.PLAYER]
	floor_plan.them = pos[Arch.Side.NEMESIS]
	floor_plan.steps = _steps(Arch.Side.PLAYER)
	var toks: Array = []
	for side in [Arch.Side.PLAYER, Arch.Side.NEMESIS]:
		for u in _units(side):
			toks.append([u.room, side, Arch.ROLE_NAME[u.role].substr(0, 1), u.morale, u.cooldown <= 0])
	floor_plan.units = toks
	var walls := {}
	for w in firewalls:
		walls[w["room"]] = int(w["owner"])
	floor_plan.walls = walls


## Apply the board to an option: out of reach is out of the question, and the
## card says how far it is.
func _gate(side: int, opt: Dictionary, reach: Dictionary, here: String) -> Dictionary:
	var room: String = opt["station"]
	var other := _other(side)
	if room == pos[other]:
		opt["enabled"] = false
		opt["why"] = "your nemesis is standing there"
	elif _walled_against(side, room):
		opt["enabled"] = false
		opt["why"] = "their IT has firewalled the %s" % board.room_name(room)
	elif not reach.has(room):
		var far := board.dist(here, room, _blocked_for(side), _toll_for(side))
		opt["enabled"] = false
		opt["why"] = ("%d steps away, you have %d" % [far, _steps(side)]) if far < 999 else "no way through - walled off"
	else:
		opt["sub"] = str(opt["sub"]) + ("  ·  %d step%s" % [reach[room], "" if reach[room] == 1 else "s"] if reach[room] > 0 else "  ·  here")
	return opt


# --- setup -------------------------------------------------------------------

func _pick_name() -> String:
	for attempt in range(40):
		var n: String = Ink.NAMES[rng.randi() % Ink.NAMES.size()]
		if not _used_names.has(n):
			_used_names.append(n)
			return n
	var fallback := "Colleague %d" % (_used_names.size() + 1)
	_used_names.append(fallback)
	return fallback


## Next unused face. The deck refills if the crowd ever outgrows it, which means
## faces repeat rather than anyone turning up blank.
func _deal_face() -> int:
	if _face_deck.is_empty():
		for i in range(2, Ink.FACE_COUNT):
			_face_deck.append(i)
		for i in range(_face_deck.size() - 1, 0, -1):
			var j := int(rng.randi() % (i + 1))
			var swap := _face_deck[i]
			_face_deck[i] = _face_deck[j]
			_face_deck[j] = swap
	return _face_deck.pop_back()


func _add_person(kind: int, side: int, at: Vector3, role: int = -1) -> Person:
	var p := Person.create(_pick_name(), kind, side, rng.randf_range(0.0, 10.0))
	p.face_index = _deal_face()
	p.role = role if role >= 0 else Arch.random_role(rng)
	var tastes: Array = Arch.ROLE_TASTES[p.role]
	p.taste = int(tastes[rng.randi() % tastes.size()])
	add_child(p)
	p.global_position = at + Vector3(0, 0.1, 0)
	p.home_pos = at
	people.append(p)
	return p


func _spawn_people() -> void:
	# Followers come from the setup screen now: your party, and theirs.
	# Both sides open with the same pieces. A hater is a piece you cannot clap
	# with but can send to the other side's talk, which is what makes it worth
	# having and worth guarding against.
	# Staff by job: a heckler has no rule to lend, only a voice. They are named
	# on the roster under the side that sent them.
	for i in range(starting_haters):
		_add_person(Arch.Kind.HATER, Arch.Side.NEMESIS,
			Office.BREAK_POS + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5)), Arch.Role.STAFF)
		_add_person(Arch.Kind.HATER, Arch.Side.PLAYER,
			Office.DESK_CLUSTER + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5) + 4.0), Arch.Role.STAFF)

	# The contested pool. Scattered wide on purpose: reaching them costs walking,
	# which is what makes the move budget bite.
	var ceo_seen := false
	for i in range(neutral_count):
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(6.0, 20.0)
		var q := _add_person(Arch.Kind.NEUTRAL, Arch.Side.NONE, Vector3(cos(a) * d, 0, sin(a) * d * 0.8))
		if q.role == Arch.Role.CEO:
			if ceo_seen:
				q.role = Arch.Role.STAFF
			ceo_seen = true

	nemesis = Person.create("Your Nemesis", Arch.Kind.FOLLOWER, Arch.Side.NEMESIS, 3.3)
	nemesis.face_index = NEMESIS_FACE
	add_child(nemesis)
	nemesis.global_position = Office.BREAK_POS + Vector3(0, 0.1, 2.0)
	nemesis.home_pos = Office.BREAK_POS
	if nemesis.rig:
		nemesis.rig.scale *= 1.08


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.2, 4.0)
	dialogue.camera = player.camera
	touch.player = player


# --- the round ---------------------------------------------------------------

func _reset_round_stats() -> void:
	round_stats = {
		Arch.Side.PLAYER: {"claps": 0, "boos": 0, "gained": 0, "lost": 0},
		Arch.Side.NEMESIS: {"claps": 0, "boos": 0, "gained": 0, "lost": 0},
	}


func _begin_round() -> void:
	_reset_round_stats()
	for p in people:
		p.resolve = false
	occupied = {Arch.Side.PLAYER: "", Arch.Side.NEMESIS: ""}
	_presented = {Arch.Side.PLAYER: false, Arch.Side.NEMESIS: false}
	sabotage_log = {Arch.Side.PLAYER: [], Arch.Side.NEMESIS: []}
	firewalls.clear()
	# A night's sleep: every colleague gets a point of morale back.
	if round_no > 1:
		for side in [Arch.Side.PLAYER, Arch.Side.NEMESIS]:
			for u in _units(side):
				u.morale = mini(u.morale + 1, Arch.MORALE_MAX)
	# Everybody back to an end of the building for the round.
	if round_no > 1:
		_place_for_round()
	actions_left = Arch.MOVES_PER_ROUND
	_refresh_hud()
	hud.banner("ROUND %d" % round_no, 2.0)

	# Who moves last matters more than who moves first: the second mover gets
	# first pick of whoever the first just made curious, and the last move of a
	# round is the one nothing can answer. So the side that is behind moves
	# second, and on level terms it alternates - the white-and-black of this game.
	var first := _first_mover()
	if round_no > 1:
		hud.toast("Ahead, so you move first." if first == Arch.Side.PLAYER else "Behind, so you get the last word.")
	for m in range(Arch.MOVES_PER_ROUND):
		move_no = m + 1
		actions_left = Arch.MOVES_PER_ROUND - m
		for side in ([Arch.Side.PLAYER, Arch.Side.NEMESIS] if first == Arch.Side.PLAYER else [Arch.Side.NEMESIS, Arch.Side.PLAYER]):
			if _presented[side]:
				continue
			if side == Arch.Side.PLAYER:
				await _player_move()
			else:
				await _nemesis_move()
		_refresh_hud()

	_send_bullies()
	# Talks in move order too: whoever had the last word presents second.
	for side in ([Arch.Side.PLAYER, Arch.Side.NEMESIS] if first == Arch.Side.PLAYER else [Arch.Side.NEMESIS, Arch.Side.PLAYER]):
		if not _presented[side]:
			await _present(side)
	_end_round()


func _first_mover() -> int:
	var a := _count(Arch.Side.PLAYER)
	var b := _count(Arch.Side.NEMESIS)
	var first: int
	if a > b:
		first = Arch.Side.PLAYER
	elif b > a:
		first = Arch.Side.NEMESIS
	else:
		first = Arch.Side.NEMESIS if _last_first == Arch.Side.PLAYER else Arch.Side.PLAYER
	_last_first = first
	return first


func _refresh_hud() -> void:
	hud.set_round(round_no, Arch.ROUNDS_PER_MATCH)
	hud.set_score(
		_count(Arch.Side.PLAYER), _count(Arch.Side.NEMESIS),
		points[Arch.Side.PLAYER], points[Arch.Side.NEMESIS]
	)
	hud.set_props(satchel[Arch.Side.PLAYER])
	hud.set_demand(_demand(Arch.Side.PLAYER), satchel[Arch.Side.NEMESIS].size(), _flags_line())
	hud.set_actions(actions_left, Arch.MOVES_PER_ROUND)


## The sabotage tell. Nothing done to you is ever hidden.
func _flags_line() -> String:
	var parts: Array[String] = []
	if rigged[Arch.Side.PLAYER]:
		parts.append("PROJECTOR RIGGED against you")
	if rigged[Arch.Side.NEMESIS]:
		parts.append("you rigged their projector")
	for line in sabotage_log[Arch.Side.PLAYER]:
		parts.append(str(line))
	return "  ·  ".join(parts)


## The score: people who would clap for this side. Wage slaves and haters are
## pieces, not points - otherwise four trips to the break room beat any talk.
func _count(side: int) -> int:
	var n := 0
	for p in people:
		if p.side == side and Arch.claps(p.kind):
			n += 1
	return n


## Who would be at this side's talk right now, and what they want. This is the
## table, and it is always on the HUD.
func _demand(side: int) -> Dictionary:
	var d := {0: 0, 1: 0, 2: 0, 3: 0}
	for p in people:
		if (p.side == side and Arch.claps(p.kind)) or p.is_curious_for(side):
			d[p.taste] += 1
	return d


func _process(_delta: float) -> void:
	if player == null:
		return
	# Every move is a card; nobody walks by hand.
	player.input_locked = true
	touch.enabled = false
	# The roster is the table; the talk and the round card sit on top of it.
	roster.visible = _started and not talk_ui.visible
	floor_plan.visible = _started and not talk_ui.visible


# --- one move ----------------------------------------------------------------

func _station_id(st: Dictionary) -> String:
	match int(st["kind"]):
		Office.St.DESK:
			return "desk:%d" % int(st.get("desk", 0))
		Office.St.STREAM:
			return "stream"
		Office.St.BREAK:
			return "break"
	return "rock"


## Every legal move for [param side], each one saying what it would do. The
## same list feeds the player's cards and the nemesis's choice, so the AI can
## never do something you could not.
## [param from_room] evaluates the board as if the side stood there (for the
## one-move lookahead); [param lookahead] adds to each card what it opens up
## next move, so walking to the Lobby is worth what the Lobby is next to.
func _options_for(side: int, from_room: String = "", lookahead: bool = true, with_units: bool = true) -> Array:
	var other: int = Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER
	var demand := _demand(side)
	var opts: Array = []
	var here: String = pos[side] if from_room == "" else from_room
	var need := _card_need(side)

	for i in range(office.desk_points.size()):
		var taste: int = office.desk_tastes[i]
		if taste < 0:
			continue
		var id := "desk:%d" % i
		var warm := _warm_preview(office.desk_points[i], side)
		var sub := "take a %s card  ·  %d in the room want it" % [Arch.TASTE_NAME[taste], demand[taste]]
		if warm[0] > 0:
			sub += "  ·  %d nearby get curious" % warm[0]
		if warm[1] > 0:
			sub += "  ·  steals %d from them" % warm[1]
		opts.append({
			"id": id, "kind": "desk", "taste": taste, "station": id, "pos": office.desk_points[i],
			"label": "%s desk" % Arch.TASTE_NAME[taste],
			"sub": sub,
			"enabled": occupied[other] != id, "why": "your nemesis is there",
			"value": float(demand[taste]) + 1.1 * float(warm[0]) + 0.7 * float(warm[1]) + need,
		})

	var curious := 0
	for p in people:
		if p.is_curious_for(side) and p.global_position.distance_to(office.stream_point) <= Arch.STREAM_RADIUS:
			curious += 1
	var close_max := _close_max(side)
	opts.append({
		"id": "stream", "kind": "stream", "station": "stream", "pos": office.stream_point,
		"label": "Stream",
		"sub": ("close up to %d of the %d curious about you there" % [close_max, curious]) if curious > 0 else "nobody curious about you there yet - warms them a little",
		"enabled": occupied[other] != "stream", "why": "your nemesis is there",
		"value": minf(float(curious), float(close_max)) * 2.6 + (0.4 if curious == 0 else 0.0),
	})

	var exposed := 0
	for p in people:
		if p.side == side and Arch.flippable(p.kind) and not p.resolve:
			exposed += 1
	opts.append({
		"id": "break", "kind": "break", "station": "break", "pos": office.break_point,
		"label": "Break room",
		"sub": ("shield your %d followers from being bought this round; a wage slave pads the crowd" % exposed) if exposed > 0 else "a wage slave pads the crowd; nothing of yours is exposed",
		"enabled": occupied[other] != "break", "why": "your nemesis is there",
		"value": 0.5 + (2.4 if exposed >= 1 and _threatened(side) else 0.0),
	})

	# Turning a follower into a heckler: one point down now, for a piece that
	# boos at every one of their talks from here on. Two of them send a bully.
	# The card names who goes, and what that costs you.
	var haters := 0
	for p in people:
		if p.side == side and p.kind == Arch.Kind.HATER:
			haters += 1
	var who := _heckler_pick(side)
	if who != null and haters < Arch.BULLY_FROM_HATERS:
		var hr := _has(side, Arch.Role.HR)
		var loses: String = "you keep every rule" if not _rule_lost_without(side, who) \
			else "you lose: %s" % Arch.PERK_SHORT[who.role]
		opts.append({
			"id": "heckler", "kind": "heckler", "station": "break", "pos": office.break_point,
			"target": who,
			"label": "Send %s (%s) to heckle" % [who.person_name, Arch.ROLE_NAME[who.role]],
			"sub": "stops clapping for you, boos every talk of theirs; %s%s" % [loses,
				"; one more and a bully goes" if haters == Arch.BULLY_FROM_HATERS - 1 else ""],
			"enabled": occupied[other] != "break" and not hr,
			"why": "your HR will not allow it" if hr else "your nemesis is there",
			"value": (1.8 if _count(side) >= _count(other) + 1 else 0.6) + (0.8 if haters == Arch.BULLY_FROM_HATERS - 1 else 0.0)
				- (1.0 if _rule_lost_without(side, who) else 0.0),
		})

	# --- sabotage -----------------------------------------------------------
	# Pinch a card: stand at the desk of a taste they hold and take one.
	var their_hand: Array = satchel[other]
	var pinch_tastes := {}
	for c in their_hand:
		if int(c["taste"]) >= 0:
			pinch_tastes[int(c["taste"])] = true
	var pinch_rows := 0
	for taste in pinch_tastes.keys():
		if pinch_rows >= 2:
			break
		var di := -1
		for i in range(office.desk_tastes.size()):
			if office.desk_tastes[i] == taste:
				di = i
		if di < 0:
			continue
		var id := "desk:%d" % di
		var legal := _has(other, Arch.Role.LEGAL)
		opts.append({
			"id": "pinch:%d" % taste, "kind": "pinch", "taste": taste, "station": id, "pos": office.desk_points[di],
			"label": "Pinch their %s card" % Arch.TASTE_NAME[taste],
			"sub": "take it out of their hand and into yours  ·  they hold %d" % their_hand.size(),
			"enabled": occupied[other] != id and not legal,
			"why": "their Legal has the desk locked" if legal else "your nemesis is standing there",
			"value": 2.6 + 0.4 * float(their_hand.size()) + (0.8 if demand[taste] >= 2 else 0.0) + 0.3 * _stat(side, 1) + need,
		})
		pinch_rows += 1

	# A rumour: cool everybody near the stream who was warming to them.
	var theirs_near := 0
	# What the rumour actually takes off them: nobody cools below nothing, so a
	# big chill on a lukewarm crowd is worth what they had, not what it could
	# have taken. (Uncapped, a Marketing nemesis with guile valued a rumour at
	# 25 and spent whole rounds at the water with an empty hand.)
	var cooled := 0.0
	for p in people:
		if p.kind == Arch.Kind.NEUTRAL and p.curious_for == other and p.curiosity > 0.0 \
				and p.global_position.distance_to(office.stream_point) <= Arch.STREAM_RADIUS:
			theirs_near += 1
			cooled += minf(_chill(side) * (2.0 if _has(other, Arch.Role.MARKETING) else 1.0), p.curiosity)
	if theirs_near > 0:
		opts.append({
			"id": "rumour", "kind": "rumour", "station": "stream", "pos": office.stream_point,
			"label": "Spread a rumour",
			"sub": "%d by the water were warming to them; cools each by %.1f" % [theirs_near, _chill(side)],
			"enabled": occupied[other] != "stream", "why": "your nemesis is there",
			"value": 1.1 * cooled / Arch.RUMOUR_CHILL,
		})

	# Rig the projector: their best slide comes up blank, unless they check it.
	# Never on the last move: a rig they have no move left to check is not a
	# trick, it is a tax on whoever moved first.
	if not rigged[other] and not _presented[other] and their_hand.size() >= 1 \
			and move_no < Arch.MOVES_PER_ROUND:
		var it := _has(other, Arch.Role.IT)
		var own_it := _has(side, Arch.Role.IT)
		opts.append({
			"id": "rig", "kind": "rig", "station": "rock", "pos": office.rock_point,
			"label": "Rig the projector",
			"sub": "their best slide comes up blank at their talk - unless they spend a move to check it",
			"enabled": occupied[other] != "rock" and not it and not own_it,
			"why": "their IT has it locked down" if it else ("your IT will not touch a projector" if own_it else "your nemesis is at the rock"),
			"value": (2.4 if their_hand.size() >= 2 else 1.0) + 0.3 * _stat(side, 1),
		})
	if rigged[side]:
		opts.append({
			"id": "check", "kind": "check", "station": "rock", "pos": office.rock_point,
			"label": "Check the projector",
			"sub": "it has been rigged against you; this puts it right",
			"enabled": occupied[other] != "rock", "why": "your nemesis is at the rock",
			"value": 2.2 if satchel[side].size() >= 2 else 0.9,
		})

	# Buying people. One card, one person, if you can reach them from a station.
	for t in _poach_targets(side):
		opts.append(t)

	opts.append({
		"id": "present", "kind": "present", "station": "rock", "pos": office.rock_point,
		"label": "Present now",
		"sub": ("%d slide%s in hand; the room is what it is" % [satchel[side].size(), "" if satchel[side].size() == 1 else "s"]) + (" - PROJECTOR RIGGED, your best slide will be blank" if rigged[side] else ""),
		"enabled": true,
		"value": (2.5 if satchel[side].size() >= Arch.SLIDES_PER_TALK else -1.0),
	})

	# A pure move: stand in the Lobby, act on nothing, be one step from
	# everything next move. Its worth is entirely what it opens up.
	if here != "lobby":
		opts.append({
			"id": "lobby", "kind": "lobby", "station": "lobby", "pos": board.room_pos("lobby"),
			"label": "Walk to the Lobby",
			"sub": "no action; the hub - every room is close from here",
			"enabled": true, "why": "",
			"value": 0.2,
		})

	# The board has the last word on every card.
	var reach := _reach_from(side, here)
	for o in opts:
		if o.get("enabled", true):
			_gate(side, o, reach, here)

	# One move of lookahead, on both sides' cards alike: a card is worth what it
	# does plus half of the best thing it puts within reach. This is what makes
	# the AI walk to the Lobby to get at the desks instead of rallying in the
	# Break room four times because nothing else was in range.
	if lookahead:
		for o in opts:
			if o.get("enabled", true) and o["kind"] != "present":
				o["value"] = float(o["value"]) + 0.5 * _best_next(side, o["station"])

	# Or move a colleague instead: one card per colleague, their best use of
	# their ability from where they can walk this move.
	# A colleague's move leaves you where you are, so it keeps the same "what
	# next" the other cards are credited with: your best move from here.
	if with_units and from_room == "":
		var stay := 0.5 * _best_next(side, here) if lookahead else 0.0
		for o in _unit_options(side):
			if o.get("enabled", false):
				o["value"] = float(o["value"]) + stay
			opts.append(o)
	return opts


## What one more card in hand is worth on top of what it does: a talk needs
## slides. Nothing once the hand can fill a talk; a little while it cannot;
## a lot when there are no longer enough moves left to fill it.
func _card_need(side: int) -> float:
	var need: int = Arch.SLIDES_PER_TALK - satchel[side].size()
	if need <= 0:
		return 0.0
	var left: int = Arch.MOVES_PER_ROUND - move_no + 1
	return 1.0 + (1.5 if left <= need else 0.0)


## The best immediate value available next move from [param room].
func _best_next(side: int, room: String) -> float:
	var best := 0.0
	for o in _options_for(side, room, false, false):
		if o.get("enabled", true) and o["kind"] != "present" and o["kind"] != "lobby":
			best = maxf(best, float(o["value"]))
	return best


## How many the stream closes for this side: Sales sells.
func _close_max(side: int) -> int:
	return Arch.STREAM_CLOSE_MAX + (1 if _has(side, Arch.Role.SALES) else 0)


## How hard this side's rumours cool: guile, doubled by Marketing.
func _chill(side: int) -> float:
	var c: float = Arch.RUMOUR_CHILL + 0.4 * float(_stat(side, 1))
	return c * 2.0 if _has(side, Arch.Role.MARKETING) else c


## How far this side can reach to buy somebody: hustle, and Sales.
func _buy_reach(side: int) -> float:
	return Arch.POACH_RADIUS + 1.5 * float(_stat(side, 2)) + (3.0 if _has(side, Arch.Role.SALES) else 0.0)


## What a desk visit at [param from] would do to the neutrals nearby:
## [newly curious about me, taken off the other side's list]. Same arithmetic
## as _warm_nearest, so the number on the card is the number that happens.
func _warm_preview(from: Vector3, side: int, count: int = -1) -> Array:
	var pool: Array[Person] = []
	for p in people:
		if p.kind == Arch.Kind.NEUTRAL:
			pool.append(p)
	pool.sort_custom(func(a, b):
		return a.global_position.distance_to(from) < b.global_position.distance_to(from))
	var fresh := 0
	var stolen := 0
	var n := count if count >= 0 else Arch.WARM_COUNT + (1 if _has(side, Arch.Role.INTERN) else 0)
	for i in range(mini(n, pool.size())):
		var q := pool[i]
		if q.global_position.distance_to(from) > 16.0:
			break
		var r := Person.warm_rule(q.curiosity, q.curious_for, Arch.WARM_AMOUNT, side)
		var was_theirs: bool = q.is_curious() and q.curious_for != side
		var now_mine: bool = r[1] == side and r[0] >= Arch.CURIOUS_AT
		if was_theirs and not (r[1] != side and r[0] >= Arch.CURIOUS_AT):
			stolen += 1
		if now_mine and not q.is_curious_for(side):
			fresh += 1
	return [fresh, stolen]


## Does the other side hold a card matching one of my unshielded followers
## who is within reach of some station? That is what the break room defends.
func _threatened(side: int) -> bool:
	var other: int = Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER
	return not _poach_targets(other, 1).is_empty()


## Followers of the other side who want a card [param side] holds, and stand
## within reach of a station [param side] could act at. Sorted by walk.
func _poach_targets(side: int, limit: int = 2) -> Array:
	var other: int = Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER
	var out: Array = []
	var from: Vector3 = _actor_pos(side)
	for p in people:
		if p.side != other or not Arch.flippable(p.kind) or p.resolve:
			continue
		var card := -1
		for i in range(satchel[side].size()):
			if int(satchel[side][i]["taste"]) == p.taste:
				card = i
				break
		# An intern goes with whoever is holding anything at all.
		if card < 0 and p.role == Arch.Role.INTERN and satchel[side].size() > 0:
			card = 0
		if card < 0:
			continue
		# The nearest station to them is where you would stand to make the offer.
		var best_st := {}
		var best_d := INF
		for st in office.stations:
			if st["kind"] == Office.St.ROCK:
				continue
			var d: float = p.global_position.distance_to(st["pos"])
			if d < best_d:
				best_d = d
				best_st = st
		if best_st.is_empty() or best_d > _buy_reach(side):
			continue
		var sid := _station_id(best_st)
		var prop: Dictionary = satchel[side][card]
		# A colleague of theirs has morale: a card shakes them, and only the
		# card that takes their morale to nothing brings them over.
		var shakes: bool = p.unit and p.morale > Arch.BUY_MORALE_HIT
		var what := ("morale %d -> %d, comes over at 0" % [p.morale, p.morale - Arch.BUY_MORALE_HIT]) if shakes \
			else ("comes over" + (" with their %s ability" % Arch.ABILITY[p.role][0] if p.unit else ""))
		out.append({
			"id": "poach:%s" % p.person_name, "kind": "poach", "station": sid, "pos": best_st["pos"],
			"target": p, "card": card,
			"label": "%s %s" % ["Shake" if shakes else "Buy", p.person_name],
			"sub": "%s, wants %s - spend your %s, at the %s; %s" % [Arch.ROLE_NAME[p.role], Arch.TASTE_NAME[p.taste], prop["name"], best_st["label"].to_lower(), what],
			"enabled": occupied[other] != sid, "why": "your nemesis is standing there",
			"value": 1.6 if shakes else (4.8 if p.unit else 4.2),
			"walk": from.distance_to(best_st["pos"]),
		})
	out.sort_custom(func(a, b): return a["walk"] < b["walk"])
	return out.slice(0, limit)


func _hand_line(side: int) -> String:
	if satchel[side].is_empty():
		return "Your hand is empty."
	var names: Array[String] = []
	for p in satchel[side]:
		names.append("%s (%s)" % [p["name"], Arch.TASTE_NAME[p["taste"]]])
	return "Hand: " + ", ".join(names)


func _player_move() -> void:
	phase = Phase.PLAYER_TURN
	_busy = true
	player.auto_target = null
	_refresh_hud()
	floor_plan.reach = _reach(Arch.Side.PLAYER)
	_refresh_plan()
	planner.offer(round_no, move_no, Arch.MOVES_PER_ROUND, _options_for(Arch.Side.PLAYER),
		_hand_line(Arch.Side.PLAYER))
	var opt: Dictionary = await planner.picked
	floor_plan.reach = {}
	await _execute(Arch.Side.PLAYER, opt)


## Walk the route on the board, then do the thing.
func _execute(side: int, opt: Dictionary) -> void:
	_busy = true
	var room: String = opt["station"]
	if opt.has("unit"):
		await _execute_unit(side, opt)
		return
	var route: Array = board.path(pos[side], room, _blocked_for(side), _toll_for(side))
	if side == Arch.Side.PLAYER:
		for i in range(route.size()):
			planner.running(i + 1, route.size(), "%s…" % opt["label"])
			await _walk_player_to(board.room_pos(route[i]))
		planner.close()
		_snap_to(player, opt["pos"])
	else:
		for r in route:
			await _walk_to(nemesis, board.room_pos(r), 6.0)
		_snap_to(nemesis, opt["pos"])

	occupied[side] = room
	pos[side] = room
	_refresh_plan()
	match String(opt["kind"]):
		"desk":
			_act_desk(side, int(opt["taste"]))
		"stream":
			_act_stream(side)
		"break":
			_act_break(side)
		"heckler":
			_act_heckler(side, opt.get("target"))
		"pinch":
			_act_pinch(side, int(opt["taste"]))
		"rumour":
			_act_rumour(side)
		"rig":
			_act_rig(side)
		"check":
			_act_check(side)
		"poach":
			_act_poach(side, opt["target"], int(opt["card"]))
		"present":
			await _present(side)
		"lobby":
			if side == Arch.Side.PLAYER:
				hud.toast("You stand in the Lobby. Everything is close from here.")
			else:
				hud.toast("They are in the Lobby.")
	_tick_influencers(side)
	_after_move(side, null)
	_refresh_hud()
	if side == Arch.Side.PLAYER and String(opt["kind"]) != "present":
		await get_tree().create_timer(0.7).timeout


## The walk is the picture; the move is the rule. If a stump or a desk got in
## the way, the mover still ends up at the station, for either side, so the
## match is never decided by who tripped.
func _snap_to(who: Node3D, target: Vector3) -> void:
	var flat := Vector3(target.x, who.global_position.y, target.z)
	if who.global_position.distance_to(flat) > 1.2:
		who.global_position = flat + Vector3(0, 0.05, 0)


func _walk_player_to(target: Vector3, max_time: float = 16.0) -> void:
	player.auto_target = target
	var t := 0.0
	while t < max_time and player.auto_target != null:
		await get_tree().process_frame
		t += get_process_delta_time()
	player.auto_target = null


# --- the verbs ---------------------------------------------------------------

func _act_desk(side: int, taste: int) -> void:
	if taste < 0:
		taste = rng.randi() % 4
	var names: Array = Arch.PROPS[taste]
	var prop := {"taste": taste, "name": names[rng.randi() % names.size()]}
	satchel[side].append(prop)

	# The pile of stuff is what makes people curious. Warming is a side effect of
	# gathering, which is what keeps the stream from being the only good move.
	var warmed := _warm_nearest(_actor_pos(side), Arch.WARM_COUNT + (1 if _has(side, Arch.Role.INTERN) else 0), Arch.WARM_AMOUNT, side)
	if side == Arch.Side.PLAYER:
		hud.toast("Took %s. %d nearby got curious." % [prop["name"], warmed])
	else:
		hud.toast("They took a %s card." % Arch.TASTE_NAME[taste])


func _act_stream(side: int) -> void:
	var curious: Array[Person] = []
	for p in people:
		if p.is_curious_for(side) and p.global_position.distance_to(office.stream_point) <= Arch.STREAM_RADIUS:
			curious.append(p)

	if curious.is_empty():
		var warmed := 0
		for p in people:
			if p.kind == Arch.Kind.NEUTRAL \
					and p.global_position.distance_to(office.stream_point) <= Arch.STREAM_RADIUS:
				p.warm(0.5, side)
				warmed += 1
		if side == Arch.Side.PLAYER:
			hud.toast("Nobody by the water was interested yet. %d warmed a little." % warmed)
		return

	curious.sort_custom(func(a, b): return a.curiosity > b.curiosity)
	var taken := 0
	for p in curious:
		if taken >= _close_max(side):
			break
		var kind := Arch.Kind.FOLLOWER
		if p.curiosity >= Arch.CURIOSITY_MAX - 0.01 and rng.randf() < 0.3:
			kind = Arch.Kind.INFLUENCER
		p.set_kind_side(kind, side)
		p.goto(p.home_pos)
		taken += 1

	if side == Arch.Side.PLAYER:
		hud.toast("Won over %d at the water." % taken)
	else:
		hud.toast("They won over %d at the water." % taken)


func _act_break(side: int) -> void:
	var at: Vector3 = office.break_point + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	_add_person(Arch.Kind.WAGE_SLAVE, side, at)

	for p in people:
		if p.side == side and Arch.flippable(p.kind):
			p.resolve = true
	for u in _units(side):
		u.morale = mini(u.morale + 1, Arch.MORALE_MAX)

	if side == Arch.Side.NEMESIS:
		hud.toast("They rallied. Nobody of theirs can be bought this round.")
	else:
		hud.toast("Rallied. A wage slave drifted in; your people cannot be bought this round.")


func _act_heckler(side: int, target: Variant) -> void:
	var q: Person = target as Person
	if q == null or q.side != side or q.kind != Arch.Kind.FOLLOWER:
		q = _heckler_pick(side)
	if q == null:
		return
	q.set_kind_side(Arch.Kind.HATER, side)
	q.unit = false
	if side == Arch.Side.PLAYER:
		hud.toast("%s (%s) is off to heckle their talks." % [q.person_name, Arch.ROLE_NAME[q.role]])
	else:
		hud.toast("They sent %s (%s) to heckle your talks." % [q.person_name, Arch.ROLE_NAME[q.role]])
	_note_lead()


## Who this side would send to heckle: the follower whose leaving costs the
## least - somebody whose job is covered by someone else first.
func _heckler_pick(side: int) -> Person:
	var best: Person = null
	var best_cost := INF
	for p in people:
		if p.side != side or p.kind != Arch.Kind.FOLLOWER:
			continue
		var cost := 1.0 if _rule_lost_without(side, p) else 0.0
		if p.role == Arch.Role.STAFF:
			cost -= 0.5
		# A colleague on the board is a piece as well as a clap.
		if p.unit:
			cost += 0.75
		if cost < best_cost:
			best_cost = cost
			best = p
	return best


## Would this side lose a job's rules if [param who] stopped clapping for it?
func _rule_lost_without(side: int, who: Person) -> bool:
	if who.role == Arch.Role.STAFF or roles[side] == who.role:
		return false
	for p in people:
		if p != who and p.side == side and p.role == who.role and Arch.claps(p.kind):
			return false
	return true


# --- colleagues on the board -------------------------------------------------

## The colleagues who are pieces for this side right now.
func _units(side: int) -> Array[Person]:
	var out: Array[Person] = []
	for p in people:
		if p.unit and p.side == side and Arch.claps(p.kind):
			out.append(p)
	return out


## Stand a colleague in a room: where they go home to after a talk, and where
## they walk from next time. Spread round the room so a crowd is not one block.
func _park(p: Person, room: String) -> void:
	p.room = room
	var same := 0
	for q in people:
		if q != p and q.unit and q.room == room:
			same += 1
	var a := float(same) * 1.3 + (0.0 if p.side == Arch.Side.PLAYER else PI)
	p.home_pos = board.room_pos(room) + Vector3(cos(a) * 2.2, 0, sin(a) * 2.2)
	p.goto(p.home_pos)


func _ability_name(role: int) -> String:
	return str(Arch.ABILITY[role][0])


## One card per colleague: the best thing their ability can do from any room
## they can reach this move, or why they cannot act.
func _unit_options(side: int) -> Array:
	var out: Array = []
	var other := _other(side)
	# What the other side would most like to do in each room - what a firewall
	# there would take away from them. Computed once, without their colleagues.
	var their_best := {}
	var needs_it := false
	for u in _units(side):
		if u.role == Arch.Role.IT and u.cooldown <= 0:
			needs_it = true
	if needs_it:
		for o in _options_for(other, "", false, false):
			if o.get("enabled", true) and o["kind"] != "present" and o["kind"] != "lobby":
				var st: String = o["station"]
				their_best[st] = maxf(float(their_best.get(st, 0.0)), float(o["value"]))

	for u in _units(side):
		var name := _ability_name(u.role)
		var label := "%s (%s): %s" % [u.person_name, Arch.ROLE_NAME[u.role], name]
		var card := {
			"id": "unit:%s" % u.person_name, "kind": "ability", "unit": u, "group": "colleagues",
			"station": u.room, "pos": board.room_pos(u.room), "label": label,
			"sub": "", "enabled": false, "why": "", "value": 0.0,
		}
		if u.cooldown > 0:
			card["why"] = "resting - ready in %d move%s" % [u.cooldown, "" if u.cooldown == 1 else "s"]
			out.append(card)
			continue
		var here := u.room if u.room != "" else String(pos[side])
		var reach := _reach_from(side, here, 0 if u.role == Arch.Role.HR else Arch.UNIT_STEPS)
		var best := {}
		for room in reach:
			if _walled_against(side, room) or room == pos[other]:
				continue
			var e := _ability_at(side, u, room, their_best)
			if e.is_empty():
				continue
			if best.is_empty() or float(e["value"]) > float(best["value"]):
				best = e
				best["room"] = room
				best["steps"] = int(reach[room])
		if best.is_empty():
			card["why"] = "nothing for %s to do within %d steps" % [name, Arch.UNIT_STEPS]
			out.append(card)
			continue
		var room: String = best["room"]
		card["station"] = room
		card["pos"] = board.room_pos(room)
		card["target"] = best.get("target")
		card["enabled"] = true
		card["value"] = float(best["value"])
		var walk := "  ·  here" if int(best["steps"]) == 0 else "  ·  walks %d to the %s" % [best["steps"], board.room_name(room)]
		card["sub"] = "%s%s  ·  rests %d" % [best["sub"], walk, int(Arch.ABILITY[u.role][2])]
		out.append(card)
	return out


## What colleague [param u]'s ability would do in [param room]: {value, sub,
## target?}, or empty if nothing. Same numbers the nemesis reads.
func _ability_at(side: int, u: Person, room: String, their_best: Dictionary) -> Dictionary:
	var other := _other(side)
	var at := board.room_pos(room)
	match u.role:
		Arch.Role.CEO, Arch.Role.INTERN:
			var n := Arch.WARM_COUNT + 2 if u.role == Arch.Role.CEO else 2
			var w := _warm_preview(at, side, n)
			var healed := 0
			if u.role == Arch.Role.INTERN:
				for q in _units(side):
					if q != u and q.room == room and q.morale < Arch.MORALE_MAX:
						healed += 1
			var v := 1.1 * float(w[0]) + 0.7 * float(w[1]) + 0.5 * float(healed)
			if v <= 0.0:
				return {}
			var sub := "%d on the grass get curious" % w[0]
			if w[1] > 0:
				sub += ", %d taken off them" % w[1]
			if healed > 0:
				sub += ", +1 morale to %d here" % healed
			return {"value": v, "sub": sub}
		Arch.Role.ENGINEER:
			if not room.begins_with("desk:"):
				return {}
			var taste: int = office.desk_tastes[int(room.split(":")[1])]
			if taste < 0:
				return {}
			var d := _demand(side)
			return {"value": float(d[taste]) + 0.8 + _card_need(side), "sub": "takes a %s card  ·  %d in the room want it" % [Arch.TASTE_NAME[taste], d[taste]]}
		Arch.Role.IT:
			var v: float = 0.6 * float(their_best.get(room, 0.0))
			for w in firewalls:
				if w["room"] == room and int(w["owner"]) == side:
					return {}
			if v < 0.5:
				return {}
			return {"value": v, "sub": "shuts the %s to them for %d of their moves" % [board.room_name(room), Arch.FIREWALL_MOVES]}
		Arch.Role.HR:
			var healed := 0
			for q in _units(side):
				if q.morale < Arch.MORALE_MAX:
					healed += 1
			var exposed := false
			for q in _units(side):
				if not q.resolve:
					exposed = true
			var v := 0.9 * float(healed) + (1.6 if exposed and _threatened(side) else 0.0)
			if v <= 0.0:
				return {}
			return {"value": v, "sub": "+1 morale to %d colleague%s; nobody of yours can be bought this round" % [healed, "" if healed == 1 else "s"]}
		Arch.Role.MARKETING:
			var hit: Array[String] = []
			var v := 0.0
			for t in _smear_targets(other, room):
				hit.append("%s %d->%d" % [t.person_name, t.morale, t.morale - 1])
				v += 1.0 + (1.5 if t.morale <= 1 else 0.0)
			if hit.is_empty():
				return {}
			return {"value": v, "sub": "-1 morale: %s" % ", ".join(hit)}
		Arch.Role.SALES:
			var n := 0
			for q in people:
				if q.is_curious_for(side) and q.global_position.distance_to(at) <= Arch.STREAM_RADIUS:
					n += 1
			n = mini(n, 2)
			if n == 0:
				return {}
			return {"value": 2.4 * float(n), "sub": "wins %d curious about you near the %s" % [n, board.room_name(room)]}
		Arch.Role.LEGAL:
			var best: Person = null
			var bv := 0.0
			for t in _units(other):
				if board.dist(room, t.room) > 1:
					continue
				var v := 1.0 + (0.8 if t.cooldown <= 0 else 0.0) + (1.5 if t.morale <= 1 else 0.0)
				if v > bv:
					bv = v
					best = t
			if best == null:
				return {}
			return {"value": bv, "target": best, "sub": "%s (%s): morale %d->%d, %s rests 2 more" % [
				best.person_name, Arch.ROLE_NAME[best.role], best.morale, best.morale - 1, _ability_name(best.role)]}
	return {}


## Who a smear from [param room] lands on: the two shakiest of [param side]'s
## colleagues within a step. Two, not everyone: a rumour needs a target.
func _smear_targets(side: int, room: String) -> Array[Person]:
	var near: Array[Person] = []
	for t in _units(side):
		if board.dist(room, t.room) <= 1:
			near.append(t)
	near.sort_custom(func(a, b): return a.morale < b.morale)
	return near.slice(0, Arch.SMEAR_TARGETS)


## A colleague's move: walk their route, then use the ability there.
func _execute_unit(side: int, opt: Dictionary) -> void:
	var u: Person = opt["unit"]
	var room: String = opt["station"]
	var route: Array = board.path(u.room, room, _blocked_for(side), _toll_for(side)) if u.room != room else []
	for i in range(route.size()):
		if side == Arch.Side.PLAYER:
			planner.running(i + 1, route.size(), "%s…" % opt["label"])
		await _walk_to(u, board.room_pos(route[i]), 5.0, true)
	if side == Arch.Side.PLAYER:
		planner.close()
	_park(u, room)
	_snap_to(u, u.home_pos)
	_use_ability(side, u, room, opt.get("target"))
	u.cooldown = int(Arch.ABILITY[u.role][2])
	_tick_influencers(side)
	_after_move(side, u)
	_refresh_plan()
	_refresh_hud()
	if side == Arch.Side.PLAYER:
		await get_tree().create_timer(0.7).timeout


func _use_ability(side: int, u: Person, room: String, target: Variant) -> void:
	var other := _other(side)
	var at := board.room_pos(room)
	var who := "%s (%s)" % [u.person_name, Arch.ROLE_NAME[u.role]]
	var yours := side == Arch.Side.PLAYER
	match u.role:
		Arch.Role.CEO, Arch.Role.INTERN:
			var n := Arch.WARM_COUNT + 2 if u.role == Arch.Role.CEO else 2
			var warmed := _warm_nearest(at, n, Arch.WARM_AMOUNT, side)
			var healed := 0
			if u.role == Arch.Role.INTERN:
				for q in _units(side):
					if q != u and q.room == room and q.morale < Arch.MORALE_MAX:
						q.morale += 1
						healed += 1
			hud.toast("%s%s: %d on the grass warmed%s." % ["" if yours else "Their ", who, warmed,
				(", %d colleague%s perked up" % [healed, "" if healed == 1 else "s"]) if healed > 0 else ""])
		Arch.Role.ENGINEER:
			var taste: int = office.desk_tastes[int(room.split(":")[1])]
			var names: Array = Arch.PROPS[taste]
			var prop := {"taste": taste, "name": names[rng.randi() % names.size()]}
			satchel[side].append(prop)
			hud.toast("%s built a demo: %s." % [who, prop["name"]] if yours else "Their %s built a %s demo." % [who, Arch.TASTE_NAME[taste]])
		Arch.Role.IT:
			firewalls.append({"room": room, "owner": side, "left": Arch.FIREWALL_MOVES})
			if yours:
				hud.toast("%s firewalled the %s. They cannot get in for %d moves." % [who, board.room_name(room), Arch.FIREWALL_MOVES])
			else:
				hud.toast("Their %s firewalled the %s against you." % [who, board.room_name(room)])
				sabotage_log[Arch.Side.PLAYER].append("%s walled off" % board.room_name(room))
		Arch.Role.HR:
			for q in _units(side):
				q.morale = mini(q.morale + 1, Arch.MORALE_MAX)
				q.resolve = true
			for q in people:
				if q.side == side and Arch.flippable(q.kind):
					q.resolve = true
			hud.toast(("%s held one-on-ones. Everyone +1 morale and nobody can be bought." % who) if yours else "Their %s held one-on-ones. Their people cannot be bought this round." % who)
		Arch.Role.MARKETING:
			var hit: Array[String] = []
			for t in _smear_targets(other, room):
				hit.append(t.person_name)
				_hurt(t, 1)
			hud.toast("%s%s smeared %s." % ["" if yours else "Their ", who, ", ".join(hit) if hit.size() > 0 else "nobody"])
			if not yours and hit.size() > 0:
				sabotage_log[Arch.Side.PLAYER].append("smear on %s" % ", ".join(hit))
		Arch.Role.SALES:
			var curious: Array[Person] = []
			for q in people:
				if q.is_curious_for(side) and q.global_position.distance_to(at) <= Arch.STREAM_RADIUS:
					curious.append(q)
			curious.sort_custom(func(a, b): return a.curiosity > b.curiosity)
			var won := 0
			for q in curious:
				if won >= 2:
					break
				q.set_kind_side(Arch.Kind.FOLLOWER, side)
				q.home_pos = at + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
				q.goto(q.home_pos)
				won += 1
			round_stats[side]["gained"] += won
			hud.toast("%s%s closed %d at the %s." % ["" if yours else "Their ", who, won, board.room_name(room)])
			_note_lead()
		Arch.Role.LEGAL:
			var t: Person = target as Person
			if t == null or not t.unit or t.side != other:
				return
			t.cooldown += 2
			hud.toast("%s%s served %s (%s) - %s rests 2 more." % ["" if yours else "Their ", who, t.person_name, Arch.ROLE_NAME[t.role], _ability_name(t.role)])
			if not yours:
				sabotage_log[Arch.Side.PLAYER].append("%s served" % t.person_name)
			_hurt(t, 1)


## Knock a colleague's morale. At nothing they walk out.
func _hurt(t: Person, n: int) -> void:
	t.morale -= n
	if t.morale > 0:
		return
	var side := t.side
	t.unit = false
	t.set_kind_side(Arch.Kind.NEUTRAL, Arch.Side.NONE)
	t.warm(Arch.CURIOUS_AT - 0.5)
	t.home_pos = t.global_position + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
	t.goto(t.home_pos)
	round_stats[side]["lost"] += 1
	hud.toast("%s (%s) has had enough and walked out on %s." % [t.person_name, Arch.ROLE_NAME[t.role], "you" if side == Arch.Side.PLAYER else "them"])
	_note_lead()


## After any move by [param side]: its resting colleagues get a move closer to
## ready, and walls against it wear down.
func _after_move(side: int, used: Person) -> void:
	for u in _units(side):
		if u != used and u.cooldown > 0:
			u.cooldown -= 1
	for i in range(firewalls.size() - 1, -1, -1):
		if int(firewalls[i]["owner"]) != side:
			firewalls[i]["left"] = int(firewalls[i]["left"]) - 1
			if int(firewalls[i]["left"]) <= 0:
				firewalls.remove_at(i)


# --- sabotage ----------------------------------------------------------------

func _other(side: int) -> int:
	return Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER


func _act_pinch(side: int, taste: int) -> void:
	var other := _other(side)
	for i in range(satchel[other].size()):
		if int(satchel[other][i]["taste"]) == taste:
			var card: Dictionary = satchel[other][i]
			satchel[other].remove_at(i)
			satchel[side].append(card)
			if side == Arch.Side.PLAYER:
				hud.toast("Pinched their %s. It is yours now." % card["name"])
				sabotage_log[Arch.Side.NEMESIS].append("you pinched their %s" % Arch.TASTE_NAME[taste])
			else:
				hud.toast("They pinched your %s right off the desk." % card["name"])
				sabotage_log[Arch.Side.PLAYER].append("they pinched your %s" % Arch.TASTE_NAME[taste])
			return


func _act_rumour(side: int) -> void:
	var other := _other(side)
	var cooled := 0
	for p in people:
		if p.kind == Arch.Kind.NEUTRAL and p.curious_for == other and p.curiosity > 0.0 \
				and p.global_position.distance_to(office.stream_point) <= Arch.STREAM_RADIUS:
			p.cool(_chill(side) * (2.0 if _has(other, Arch.Role.MARKETING) else 1.0))
			cooled += 1
	if side == Arch.Side.PLAYER:
		hud.toast("A word by the water. %d went cold on them." % cooled)
		sabotage_log[Arch.Side.NEMESIS].append("your rumour cooled %d" % cooled)
	else:
		hud.toast("They have been talking about you by the water. %d of yours went cold." % cooled)
		sabotage_log[Arch.Side.PLAYER].append("their rumour cooled %d of yours" % cooled)


func _act_rig(side: int) -> void:
	var other := _other(side)
	rigged[other] = true
	if side == Arch.Side.PLAYER:
		hud.toast("Projector rigged. Their best slide will be a blank.")
	else:
		hud.toast("They were at the rock. Your projector has been rigged - check it, or present blind.")


func _act_check(side: int) -> void:
	rigged[side] = false
	if side == Arch.Side.PLAYER:
		hud.toast("Projector checked and put right.")
	else:
		hud.toast("They checked the projector. Your rig is undone.")


## A rigged projector fires now: the slide the room most wanted goes blank.
func _spring_rig(side: int) -> void:
	if not rigged[side] or satchel[side].is_empty():
		rigged[side] = false
		return
	rigged[side] = false
	var demand := _demand(side)
	var best := 0
	for i in range(satchel[side].size()):
		if int(demand.get(int(satchel[side][i]["taste"]), 0)) > int(demand.get(int(satchel[side][best]["taste"]), 0)):
			best = i
	var lost: Dictionary = satchel[side][best]
	satchel[side][best] = {"taste": -1, "name": Arch.DUD_NAME}
	if side == Arch.Side.PLAYER:
		hud.toast("The projector was rigged. Your %s is a blank slide." % lost["name"])
	else:
		hud.toast("Their projector was rigged. Their %s came up blank." % lost["name"])


## Spend a card on a person. The card is gone; the person is yours.
func _act_poach(side: int, target: Person, card: int) -> void:
	if card < 0 or card >= satchel[side].size() or target == null:
		return
	var prop: Dictionary = satchel[side][card]
	satchel[side].remove_at(card)
	if target.unit and target.morale > Arch.BUY_MORALE_HIT:
		target.morale -= Arch.BUY_MORALE_HIT
		if side == Arch.Side.PLAYER:
			hud.toast("%s (%s) took the %s and wavered - morale %d." % [target.person_name, Arch.ROLE_NAME[target.role], prop["name"], target.morale])
		else:
			hud.toast("They offered %s a %s. Morale %d - one more and they go." % [target.person_name, Arch.TASTE_NAME[prop["taste"]], target.morale])
		return
	target.set_kind_side(Arch.Kind.FOLLOWER, side)
	var home: Vector3 = _actor_pos(side) + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
	target.goto(home)
	target.home_pos = home
	if target.unit:
		# Came over shaken, and their ability has to settle in first.
		target.morale = 2
		target.cooldown = int(Arch.ABILITY[target.role][2])
		_park(target, pos[side])
	round_stats[side]["gained"] += 1
	var other: int = Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER
	round_stats[other]["lost"] += 1
	if side == Arch.Side.PLAYER:
		hud.toast("%s took the %s and came over." % [target.person_name, prop["name"]])
	else:
		hud.toast("They bought %s off you with a %s." % [target.person_name, Arch.TASTE_NAME[prop["taste"]]])
	_note_lead()


func _warm_nearest(from: Vector3, count: int, amount: float, by: int) -> int:
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
		pool[i].warm(amount, by)
		if pool[i].is_curious():
			pool[i].goto(office.stream_point + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-2, 2)))
		n += 1
	return n


func _tick_influencers(side: int) -> void:
	for p in people:
		if p.side == side and p.kind == Arch.Kind.INFLUENCER:
			_warm_nearest(p.global_position, 1, Arch.WARM_AMOUNT, side)


func _actor_pos(side: int) -> Vector3:
	return player.global_position if side == Arch.Side.PLAYER else nemesis.global_position


func _note_lead() -> void:
	var a := _count(Arch.Side.PLAYER)
	var b := _count(Arch.Side.NEMESIS)
	var leader: int = Arch.Side.PLAYER if a > b else (Arch.Side.NEMESIS if b > a else Arch.Side.NONE)
	if leader != Arch.Side.NONE and _last_leader != Arch.Side.NONE and leader != _last_leader:
		lead_changes += 1
	if leader != Arch.Side.NONE:
		_last_leader = leader


# --- the nemesis -------------------------------------------------------------

func _nemesis_move() -> void:
	phase = Phase.NEMESIS_TURN
	_busy = true
	planner.close()
	var opt := _nemesis_choose()
	hud.banner("THEIR MOVE — %s" % opt["label"], 1.4)
	Engine.time_scale = NEMESIS_SPEEDUP
	await _execute(Arch.Side.NEMESIS, opt)
	Engine.time_scale = 1.0


## Takes the biggest number on the board. Deliberately legible: every card's
## value is the same number the player sees on it, so after one round you can
## predict the nemesis and play around it.
func _nemesis_choose() -> Dictionary:
	var best := {}
	var best_v := -INF
	for o in _options_for(Arch.Side.NEMESIS):
		if not o.get("enabled", true):
			continue
		var v: float = float(o.get("value", 0.0)) + rng.randf() * 0.1
		# Do not present before there is anything to say, unless it is the last move.
		if o["kind"] == "present" and move_no < Arch.MOVES_PER_ROUND and satchel[Arch.Side.NEMESIS].size() < Arch.SLIDES_PER_TALK:
			continue
		if v > best_v:
			best_v = v
			best = o
	return best


## Same rule for both sides: with two or more haters, one goes to sit at the
## front of the other side's talk. It boos harder and always takes somebody.
func _send_bullies() -> void:
	for side in [Arch.Side.PLAYER, Arch.Side.NEMESIS]:
		var haters: Array[Person] = []
		for p in people:
			if p.side == side and p.kind == Arch.Kind.HATER:
				haters.append(p)
		if haters.size() >= Arch.BULLY_FROM_HATERS:
			var b: Person = haters[rng.randi() % haters.size()]
			b.set_kind_side(Arch.Kind.BULLY, side)
			if side == Arch.Side.NEMESIS:
				hud.toast("%s, their bully, will sit at the front of your talk." % b.person_name)
			else:
				hud.toast("%s goes to bully their talk from the front row." % b.person_name)


func _walk_to(p: Person, target: Vector3, max_time: float = 12.0, hurry: bool = false) -> void:
	p.goto(target, hurry)
	var t := 0.0
	while t < max_time:
		await get_tree().process_frame
		t += get_process_delta_time()
		var flat := Vector3(target.x, p.global_position.y, target.z)
		if p.global_position.distance_to(flat) <= Person.ARRIVE_DIST + 0.2:
			break
	p.stop_walking()


# --- presentation ------------------------------------------------------------

func _present(side: int) -> void:
	_busy = true
	_presented[side] = true
	var was_phase := phase
	phase = Phase.TALK
	planner.close()

	if satchel[side].is_empty():
		hud.toast("Nothing in hand. That was a short talk.")

	var assembled := _assemble(side)

	pos[side] = "rock"
	_refresh_plan()
	var stage: Vector3 = Office.ROCK_POS + Vector3(0, 1.05, 0)
	if side == Arch.Side.PLAYER:
		player.velocity = Vector3.ZERO
		player.auto_target = null
		player.global_position = stage
		player.rotation.y = PI
	else:
		nemesis.stop_walking()
		nemesis.global_position = stage
		nemesis.rotation.y = PI

	Engine.time_scale = 1.0
	talk_cam.current = true
	hud.hide_prompt()
	hud.banner("Gathering at the rock…", 2.0)
	await get_tree().create_timer(3.4).timeout

	_spring_rig(side)
	talk_ui.begin(side, satchel[side], assembled[0], assembled[1], round_no, {
		"charm": _stat(side, 0), "grit": _stat(side, 3), "engineer": _has(side, Arch.Role.ENGINEER),
		"story_minus": _has(side, Arch.Role.ENGINEER), "data_minus": _has(side, Arch.Role.SALES),
		"bully_takes": 2 if _has(side, Arch.Role.CEO) else 1,
	})
	var result: Dictionary = await talk_ui.finished
	_apply_talk(result)
	phase = was_phase


## Returns [audience, spectators] and walks everybody to the rock.
func _assemble(side: int) -> Array:
	var other: int = Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER
	var audience: Array = []
	var hr := _has(side, Arch.Role.HR)
	for p in people:
		if p.side == side and p.kind != Arch.Kind.NEUTRAL:
			audience.append(p)
		elif p.side == other and Arch.boos(p.kind):
			if p.kind == Arch.Kind.BULLY and hr:
				continue  # HR at the door
			audience.append(p)

	# Crowd size pulls in passers-by; the underdog gets a hand up; in the last
	# round the whole office is watching.
	var slots: int = int(floor(float(audience.size()) / float(Arch.spectator_per_heads(round_no))))
	if _count(side) < _count(other):
		slots += Arch.UNDERDOG_SLOTS
	if _has(side, Arch.Role.CEO):
		slots += 1
	# The grass seats go to people curious about this side, nearest first.
	var curious: Array[Person] = []
	for p in people:
		if p.is_curious_for(side):
			curious.append(p)
	curious.sort_custom(func(a, b):
		return a.global_position.distance_to(office.audience_center) \
			< b.global_position.distance_to(office.audience_center))
	var spectators: Array = curious.slice(0, maxi(slots, 0))

	var seats := audience + spectators
	for i in range(seats.size()):
		var row := i / 6
		var col := i % 6
		var seat: Vector3 = office.audience_center + Vector3((col - 2.5) * 1.5, 0, row * 1.7)
		var person: Person = seats[i]
		person.goto(seat, true)
		person.look_at_node(nemesis if side == Arch.Side.NEMESIS else player)

	return [audience, spectators]


func _apply_talk(result: Dictionary) -> void:
	var side: int = result["side"]
	var other: int = Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER

	for p in result["won"]:
		(p as Person).set_kind_side(Arch.Kind.FOLLOWER, side)
	# Somebody booed out of your talk does not join the other side; they go back
	# to the grass, curious, and can be won again. That is what stops one bad
	# talk from being the end of the match.
	for p in result["lost"]:
		var q := p as Person
		# A colleague is harder to shift: the bully costs them morale, and they
		# only walk when it runs out.
		if q.unit and q.morale > Arch.BULLY_MORALE_HIT:
			q.morale -= Arch.BULLY_MORALE_HIT
			hud.toast("%s (%s) was shaken by the bully - morale %d." % [q.person_name, Arch.ROLE_NAME[q.role], q.morale])
			continue
		q.unit = false
		q.set_kind_side(Arch.Kind.NEUTRAL, Arch.Side.NONE)
		# Warm, not curious: one desk visit away from being closable again, and
		# not a free spectator for whoever presents next.
		q.warm(Arch.CURIOUS_AT - 0.5)

	claps_total[side] += int(result["claps"])
	boos_total[side] += int(result["boos"])
	points[side] += maxi(int(result["claps"]) - int(result["boos"]), 0)

	round_stats[side]["claps"] += int(result["claps"])
	round_stats[side]["boos"] += int(result["boos"])
	round_stats[side]["gained"] += result["won"].size()
	for p in result["lost"]:
		if (p as Person).side != side:
			round_stats[side]["lost"] += 1

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

	_note_lead()
	_refresh_hud()


# --- round / match -----------------------------------------------------------

func _end_round() -> void:
	phase = Phase.ROUND_END
	_busy = true

	for p in people:
		if p.kind == Arch.Kind.BULLY:
			p.set_kind_side(Arch.Kind.HATER, p.side)

	var you: Dictionary = round_stats[Arch.Side.PLAYER].duplicate()
	var them: Dictionary = round_stats[Arch.Side.NEMESIS].duplicate()
	you["people"] = _count(Arch.Side.PLAYER)
	them["people"] = _count(Arch.Side.NEMESIS)

	await get_tree().create_timer(0.8).timeout
	if round_no >= Arch.ROUNDS_PER_MATCH:
		phase = Phase.MATCH_OVER
	talk_ui.show_round(round_no, Arch.ROUNDS_PER_MATCH, you, them, round_no >= Arch.ROUNDS_PER_MATCH)


func _on_round_closed(again: bool) -> void:
	if again:
		get_tree().reload_current_scene()
		return
	round_no += 1
	_busy = false
	_begin_round()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reshuffle") and (phase == Phase.MATCH_OVER or phase == Phase.PLAYER_TURN):
		get_tree().reload_current_scene()
