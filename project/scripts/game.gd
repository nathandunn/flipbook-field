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
@export var starting_followers: int = 3
@export var starting_haters: int = 1

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const NEMESIS_SPEEDUP := 3.0
## Faces 0 and 1 are spoken for - the two drawings cast as the player and the
## nemesis. The rest are dealt from a shuffled deck so no two people in a match
## wear the same face.
const NEMESIS_FACE := 1

## The player, in manual mode, finished a move at a station.
signal manual_done

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
## True while a move is being walked. Cleared by "Take over".
var _auto: bool = false
## True while waiting for the player to walk to a station and press E.
var _awaiting_manual: bool = false


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
	planner.manual.connect(_on_manual)
	planner.took_over.connect(_on_took_over)

	hud.set_hint(
		"Pick a card each move, or Play it myself · WASD move · Shift run · E act · Esc free mouse"
	)
	_begin_round()


# --- setup -------------------------------------------------------------------

func _pick_name() -> String:
	for attempt in range(40):
		var n: String = Ink.NAMES[rng.randi() % Ink.NAMES.size()]
		if not _used_names.has(n):
			_used_names.append(n)
			return n
	return "Colleague %d" % _used_names.size()


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


func _add_person(kind: int, side: int, at: Vector3) -> Person:
	var p := Person.create(_pick_name(), kind, side, rng.randf_range(0.0, 10.0))
	p.face_index = _deal_face()
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

	# Both sides open with the same pieces. A hater is a piece you cannot clap
	# with but can send to the other side's talk, which is what makes it worth
	# having and worth guarding against.
	for i in range(starting_haters):
		_add_person(Arch.Kind.HATER, Arch.Side.NEMESIS,
			Office.BREAK_POS + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5)))
		_add_person(Arch.Kind.HATER, Arch.Side.PLAYER,
			Office.DESK_CLUSTER + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5) + 4.0))

	# The contested pool. Scattered wide on purpose: reaching them costs walking,
	# which is what makes the move budget bite.
	for i in range(neutral_count):
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(6.0, 20.0)
		_add_person(Arch.Kind.NEUTRAL, Arch.Side.NONE, Vector3(cos(a) * d, 0, sin(a) * d * 0.8))

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
	player.interact_pressed.connect(_on_interact)
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
	if not _presented[Arch.Side.PLAYER]:
		await _present(Arch.Side.PLAYER)
	if not _presented[Arch.Side.NEMESIS]:
		await _present(Arch.Side.NEMESIS)
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

	var free_to_walk := _awaiting_manual and not _busy
	player.input_locked = not free_to_walk
	touch.enabled = free_to_walk

	if not free_to_walk:
		hud.hide_prompt()
		return

	var st := office.station_at(player.global_position)
	if st.is_empty():
		hud.hide_prompt()
		return

	var verb := "TALK" if player.touch_mode else "E"
	if st["kind"] == Office.St.ROCK:
		hud.show_prompt("%s  —  present now" % verb)
	elif _station_id(st) == occupied[Arch.Side.NEMESIS]:
		hud.show_prompt("your nemesis is standing here")
	else:
		hud.show_prompt("%s  —  %s" % [verb, st["label"]])


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
func _options_for(side: int) -> Array:
	var other: int = Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER
	var demand := _demand(side)
	var opts: Array = []

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
			"value": float(demand[taste]) + 1.1 * float(warm[0]) + 0.7 * float(warm[1]),
		})

	var curious := 0
	for p in people:
		if p.is_curious_for(side) and p.global_position.distance_to(office.stream_point) <= Arch.STREAM_RADIUS:
			curious += 1
	opts.append({
		"id": "stream", "kind": "stream", "station": "stream", "pos": office.stream_point,
		"label": "Stream",
		"sub": ("close up to %d of the %d curious about you there" % [Arch.STREAM_CLOSE_MAX, curious]) if curious > 0 else "nobody curious about you there yet - warms them a little",
		"enabled": occupied[other] != "stream", "why": "your nemesis is there",
		"value": minf(float(curious), float(Arch.STREAM_CLOSE_MAX)) * 2.6 + (0.4 if curious == 0 else 0.0),
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
	var haters := 0
	for p in people:
		if p.side == side and p.kind == Arch.Kind.HATER:
			haters += 1
	if _count(side) >= 2 and haters < Arch.BULLY_FROM_HATERS:
		opts.append({
			"id": "heckler", "kind": "heckler", "station": "break", "pos": office.break_point,
			"label": "Send a heckler",
			"sub": "one of your followers turns sour and boos their every talk; with %d they send a bully" % Arch.BULLY_FROM_HATERS,
			"enabled": occupied[other] != "break", "why": "your nemesis is there",
			"value": (1.8 if _count(side) >= _count(other) + 1 else 0.6) + (0.8 if haters == Arch.BULLY_FROM_HATERS - 1 else 0.0),
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
		opts.append({
			"id": "pinch:%d" % taste, "kind": "pinch", "taste": taste, "station": id, "pos": office.desk_points[di],
			"label": "Pinch their %s card" % Arch.TASTE_NAME[taste],
			"sub": "take it out of their hand and into yours  ·  they hold %d" % their_hand.size(),
			"enabled": occupied[other] != id, "why": "your nemesis is standing there",
			"value": 2.6 + 0.4 * float(their_hand.size()) + (0.8 if demand[taste] >= 2 else 0.0),
		})
		pinch_rows += 1

	# A rumour: cool everybody near the stream who was warming to them.
	var theirs_near := 0
	for p in people:
		if p.kind == Arch.Kind.NEUTRAL and p.curious_for == other and p.curiosity > 0.0 \
				and p.global_position.distance_to(office.stream_point) <= Arch.STREAM_RADIUS:
			theirs_near += 1
	if theirs_near > 0:
		opts.append({
			"id": "rumour", "kind": "rumour", "station": "stream", "pos": office.stream_point,
			"label": "Spread a rumour",
			"sub": "%d by the water were warming to them; this cools every one of them" % theirs_near,
			"enabled": occupied[other] != "stream", "why": "your nemesis is there",
			"value": 1.1 * float(theirs_near),
		})

	# Rig the projector: their best slide comes up blank, unless they check it.
	# Never on the last move: a rig they have no move left to check is not a
	# trick, it is a tax on whoever moved first.
	if not rigged[other] and not _presented[other] and their_hand.size() >= 1 \
			and move_no < Arch.MOVES_PER_ROUND:
		opts.append({
			"id": "rig", "kind": "rig", "station": "rock", "pos": office.rock_point,
			"label": "Rig the projector",
			"sub": "their best slide comes up blank at their talk - unless they spend a move to check it",
			"enabled": occupied[other] != "rock", "why": "your nemesis is at the rock",
			"value": (2.4 if their_hand.size() >= 2 else 1.0),
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
	return opts


## What a desk visit at [param from] would do to the neutrals nearby:
## [newly curious about me, taken off the other side's list]. Same arithmetic
## as _warm_nearest, so the number on the card is the number that happens.
func _warm_preview(from: Vector3, side: int) -> Array:
	var pool: Array[Person] = []
	for p in people:
		if p.kind == Arch.Kind.NEUTRAL:
			pool.append(p)
	pool.sort_custom(func(a, b):
		return a.global_position.distance_to(from) < b.global_position.distance_to(from))
	var fresh := 0
	var stolen := 0
	for i in range(mini(Arch.WARM_COUNT, pool.size())):
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
		if best_st.is_empty() or best_d > Arch.POACH_RADIUS:
			continue
		var sid := _station_id(best_st)
		var prop: Dictionary = satchel[side][card]
		out.append({
			"id": "poach:%s" % p.person_name, "kind": "poach", "station": sid, "pos": best_st["pos"],
			"target": p, "card": card,
			"label": "Buy %s" % p.person_name,
			"sub": "they want %s - spend your %s, at the %s" % [Arch.TASTE_NAME[p.taste], prop["name"], best_st["label"].to_lower()],
			"enabled": occupied[other] != sid, "why": "your nemesis is standing there",
			"value": 4.2,
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
	planner.offer(round_no, move_no, Arch.MOVES_PER_ROUND, _options_for(Arch.Side.PLAYER),
		_hand_line(Arch.Side.PLAYER))
	var opt: Dictionary = await _await_choice()
	if opt.is_empty():
		await _manual_move()
		return
	await _execute(Arch.Side.PLAYER, opt, true)


## Waits for a card, or an empty dictionary if the player chose to walk.
func _await_choice() -> Dictionary:
	# Lambdas capture locals by value, so the flag lives in a dictionary the
	# lambda can write through.
	var box := {"done": false, "result": {}}
	var on_pick := func(o: Dictionary):
		box["result"] = o
		box["done"] = true
	var on_manual := func():
		box["done"] = true
	planner.picked.connect(on_pick, CONNECT_ONE_SHOT)
	planner.manual.connect(on_manual, CONNECT_ONE_SHOT)
	while not box["done"]:
		await get_tree().process_frame
	if planner.picked.is_connected(on_pick):
		planner.picked.disconnect(on_pick)
	if planner.manual.is_connected(on_manual):
		planner.manual.disconnect(on_manual)
	return box["result"]


func _manual_move() -> void:
	_busy = false
	_awaiting_manual = true
	hud.toast("Yours. Walk to a station and press E; the rock presents.")
	await manual_done


func _on_manual() -> void:
	pass  # handled by _await_choice


func _on_took_over() -> void:
	_auto = false


## Manual mode: the station you are standing at is your move.
func _on_interact() -> void:
	if not _awaiting_manual or _busy:
		return
	var st := office.station_at(player.global_position)
	if st.is_empty():
		return
	var sid := _station_id(st)
	if sid == occupied[Arch.Side.NEMESIS]:
		hud.toast("Your nemesis is standing there.")
		return
	_awaiting_manual = false
	_busy = true
	var opt := {}
	# By hand, a station is its plain verb; the tricks and bribes are cards.
	for o in _options_for(Arch.Side.PLAYER):
		if o["station"] == sid and o["kind"] in ["desk", "stream", "break", "present"]:
			opt = o
			break
	if opt.is_empty():
		# A mixed desk: no card of its own on the list, but a fine place to stand.
		opt = {"kind": "desk", "taste": -1, "station": sid, "pos": st["pos"], "label": st["label"]}
	await _execute(Arch.Side.PLAYER, opt, false)
	manual_done.emit()


## Walk to the station (if [param walk]) and do the thing.
func _execute(side: int, opt: Dictionary, walk: bool) -> void:
	_busy = true
	if side == Arch.Side.PLAYER:
		if walk:
			_auto = true
			planner.running(1, 1, "%s…" % opt["label"])
			await _walk_player_to(opt["pos"])
			planner.close()
			if not _auto:
				# Took over on the way: the move is theirs to finish by hand.
				await _manual_move()
				return
			_auto = false
	else:
		await _walk_to(nemesis, opt["pos"])

	occupied[side] = opt["station"]
	match String(opt["kind"]):
		"desk":
			_act_desk(side, int(opt["taste"]))
		"stream":
			_act_stream(side)
		"break":
			_act_break(side)
		"heckler":
			_act_heckler(side)
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
	_tick_influencers(side)
	_refresh_hud()
	if side == Arch.Side.PLAYER and String(opt["kind"]) != "present":
		await get_tree().create_timer(0.7).timeout


func _walk_player_to(pos: Vector3, max_time: float = 16.0) -> void:
	player.auto_target = pos
	var t := 0.0
	while t < max_time and player.auto_target != null and _auto:
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
	var warmed := _warm_nearest(_actor_pos(side), Arch.WARM_COUNT, Arch.WARM_AMOUNT, side)
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
		if taken >= Arch.STREAM_CLOSE_MAX:
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

	if side == Arch.Side.NEMESIS:
		hud.toast("They rallied. Nobody of theirs can be bought this round.")
	else:
		hud.toast("Rallied. A wage slave drifted in; your people cannot be bought this round.")


func _act_heckler(side: int) -> void:
	var pool: Array[Person] = []
	for p in people:
		if p.side == side and p.kind == Arch.Kind.FOLLOWER:
			pool.append(p)
	if pool.is_empty():
		return
	var q: Person = pool[rng.randi() % pool.size()]
	q.set_kind_side(Arch.Kind.HATER, side)
	if side == Arch.Side.PLAYER:
		hud.toast("%s has gone sour on your behalf." % q.person_name)
	else:
		hud.toast("They turned %s into a heckler." % q.person_name)
	_note_lead()


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
			p.warm(Arch.RUMOUR_CHILL, side)
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
	target.set_kind_side(Arch.Kind.FOLLOWER, side)
	var home: Vector3 = _actor_pos(side) + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
	target.goto(home)
	target.home_pos = home
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
	await _execute(Arch.Side.NEMESIS, opt, true)
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
		var v: float = float(o.get("value", 0.0)) + rng.randf() * 0.35
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
			haters[rng.randi() % haters.size()].set_kind_side(Arch.Kind.BULLY, side)
			if side == Arch.Side.NEMESIS:
				hud.toast("One of theirs has been sent to sit at the front of your talk.")
			else:
				hud.toast("One of yours is off to heckle their talk.")


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
	talk_ui.begin(side, satchel[side], assembled[0], assembled[1], round_no)
	var result: Dictionary = await talk_ui.finished
	_apply_talk(result)
	phase = was_phase


## Returns [audience, spectators] and walks everybody to the rock.
func _assemble(side: int) -> Array:
	var other: int = Arch.Side.NEMESIS if side == Arch.Side.PLAYER else Arch.Side.PLAYER
	var audience: Array = []
	for p in people:
		if p.side == side and p.kind != Arch.Kind.NEUTRAL:
			audience.append(p)
		elif p.side == other and Arch.boos(p.kind):
			audience.append(p)

	# Crowd size pulls in passers-by; the underdog gets a hand up; in the last
	# round the whole office is watching.
	var slots: int = int(floor(float(audience.size()) / float(Arch.spectator_per_heads(round_no))))
	if _count(side) < _count(other):
		slots += Arch.UNDERDOG_SLOTS
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
	round_stats[side]["lost"] += result["lost"].size()

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
