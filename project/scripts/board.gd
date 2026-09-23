## Board — the office as a Clue board: rooms joined by corridors.
##
## A room is a station with a name and a place in the world; a corridor is an
## edge with a cost in steps. A move is "walk up to N steps, then act where you
## stand", so where you are is finally a decision: the Rock is two steps from
## the Lobby and four from the Data desk, and a room the other side is standing
## in cannot be entered or walked through. Pure data plus Dijkstra; the 3D
## office is the picture of this graph, not the other way round.
class_name Board
extends RefCounted

## id -> { name, short, pos: Vector3, station: String, plan: Vector2 }
## plan is where the room sits on the drawn board (0..1), which is laid out
## like a floor plan rather than projected from the grass: the desks are a
## block, the Rock is at the top, the Lobby is the hub.
var rooms: Dictionary = {}
## [a, b, cost]
var edges: Array = []
var _adj: Dictionary = {}


## Built from the office so the rooms sit where the stations are.
static func from_office(office: Office) -> Board:
	var b := Board.new()
	var desk_names := ["Data desk", "Story desk", "Gadget desk", "Snacks desk"]
	var shorts := ["DATA", "STORY", "GADGET", "SNACKS"]
	var plans := [Vector2(0.13, 0.36), Vector2(0.34, 0.36), Vector2(0.34, 0.62), Vector2(0.13, 0.62)]
	for i in range(4):
		b._room("desk:%d" % i, desk_names[i], shorts[i], office.desk_points[i], plans[i])
	b._room("stream", "Stream", "STREAM", office.stream_point, Vector2(0.72, 0.84))
	b._room("break", "Break room", "BREAK", office.break_point, Vector2(0.87, 0.46))
	b._room("rock", "The Rock", "ROCK", office.rock_point, Vector2(0.55, 0.12))
	b._room("lobby", "Lobby", "LOBBY", Vector3(0, 0, 1.5), Vector2(0.58, 0.52))

	# Corridors. The desks are a block of four; the Lobby is the hub; the Rock
	# and the Break room are the far ends. Costs are steps, and a step is a
	# move's currency.
	b._edge("desk:0", "desk:1", 1)
	b._edge("desk:1", "desk:2", 1)
	b._edge("desk:0", "desk:3", 1)
	b._edge("desk:3", "desk:1", 1)
	b._edge("desk:2", "lobby", 1)
	b._edge("desk:3", "stream", 2)
	b._edge("lobby", "stream", 1)
	b._edge("lobby", "break", 1)
	b._edge("lobby", "rock", 2)
	b._edge("stream", "break", 2)
	b._edge("stream", "rock", 2)
	b._edge("break", "rock", 2)
	b._edge("rock", "desk:2", 2)
	return b


func _room(id: String, n: String, short: String, pos: Vector3, plan: Vector2) -> void:
	rooms[id] = {"name": n, "short": short, "pos": pos, "station": id, "plan": plan}
	_adj[id] = []


func _edge(a: String, b: String, cost: int) -> void:
	edges.append([a, b, cost])
	_adj[a].append([b, cost])
	_adj[b].append([a, cost])


## Shortest path costs from [param from] to every room, never entering a room
## in [param blocked]. Returns id -> steps.
func distances(from: String, blocked: Array = []) -> Dictionary:
	var dist := {from: 0}
	var open: Array = [from]
	while not open.is_empty():
		# Small graph: a linear scan for the nearest open node is plenty.
		var best_i := 0
		for i in range(open.size()):
			if dist[open[i]] < dist[open[best_i]]:
				best_i = i
		var u: String = open[best_i]
		open.remove_at(best_i)
		for e in _adj[u]:
			var v: String = e[0]
			if blocked.has(v):
				continue
			var nd: int = dist[u] + int(e[1])
			if not dist.has(v) or nd < dist[v]:
				dist[v] = nd
				if not open.has(v):
					open.append(v)
	return dist


func dist(from: String, to: String, blocked: Array = []) -> int:
	var d := distances(from, blocked)
	return int(d[to]) if d.has(to) else 999


## The rooms on the shortest walk from [param from] to [param to], excluding
## [param from], including [param to]. Empty if unreachable.
func path(from: String, to: String, blocked: Array = []) -> Array:
	var d := distances(from, blocked)
	if not d.has(to):
		return []
	# Walk back from the target along strictly decreasing distances.
	var out: Array = [to]
	var cur := to
	while cur != from:
		var found := false
		for e in _adj[cur]:
			var v: String = e[0]
			if d.has(v) and d[v] + int(e[1]) == d[cur] and not blocked.has(v):
				out.push_front(v)
				cur = v
				found = true
				break
		if not found:
			break
	if out.size() > 0 and out[0] == from:
		out.pop_front()
	return out


func room_pos(id: String) -> Vector3:
	return rooms[id]["pos"] if rooms.has(id) else Vector3.ZERO


func room_name(id: String) -> String:
	return rooms[id]["name"] if rooms.has(id) else id
