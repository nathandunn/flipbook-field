## drive6 — the playability harness. Plays whole matches through the real UI
## with real clicks on the real buttons, and prints chess-style metrics at the
## end: wins, margin, lead changes, decisions per match, how often a card was
## blocked, how often a buy was on the table.
##
##   POLICY=greedy|random  MATCHES=n  SPEED=k  SEED=s
##   godot4 --headless --path project --script /abs/path/tools/drive6.gd
##
## greedy reads the same "value" off each card the nemesis does, so a level
## result against it is the balance target; random should lose clearly.
extends SceneTree

var policy := "greedy"
var matches := 3
var speed := 8.0
var rngd := RandomNumberGenerator.new()

var done_matches := 0
var results: Array = []
var decisions := 0
var cards_seen := 0
var cards_enabled := 0
var blocked_seen := 0
var poach_offered := 0
var poach_taken := 0
var kinds := {}
var frames := 0
var last_click_frame := -100
var errors := 0
var t0 := 0.0
var last_phase := -1
var scrolled_for := {}
var clip_tries := {}
var sold_once := false

func _initialize() -> void:
	policy = OS.get_environment("POLICY") if OS.get_environment("POLICY") != "" else "greedy"
	matches = int(OS.get_environment("MATCHES")) if OS.get_environment("MATCHES") != "" else 3
	speed = float(OS.get_environment("SPEED")) if OS.get_environment("SPEED") != "" else 8.0
	rngd.seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_msec() / 1000.0
	print("drive6 policy=%s matches=%d" % [policy, matches])

func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button:
			if not (c as Button).disabled and (c as Button).is_visible_in_tree():
				out.append(c)
		else:
			_buttons(c, out)

func _click(b: Button) -> void:
	var p: Vector2 = b.get_global_rect().get_center()
	var vp: Vector2 = root.get_visible_rect().size
	# A row clipped by its scroll area is on the window but not clickable:
	# the click would land on whatever is drawn there. Scroll to it first.
	var clip := b.get_parent().get_parent() as ScrollContainer
	if clip and not clip.get_global_rect().has_point(p):
		clip.ensure_control_visible(b)
		last_click_frame = frames
		if int(clip_tries.get(b, 0)) < 3:
			clip_tries[b] = int(clip_tries.get(b, 0)) + 1
			return
		print("CLIPPED BUTTON: %s" % b.text)
		errors += 1
	if not (p.x >= 0 and p.y >= 0 and p.x <= vp.x and p.y <= vp.y):
		# Inside a scroll area the row may be clipped; scroll it into view and
		# take the centre again. Still off the window is a real layout bug.
		var sc := b.get_parent().get_parent() as ScrollContainer
		if sc and not scrolled_for.has(b):
			scrolled_for[b] = true
			sc.ensure_control_visible(b)
			# The container re-sorts next frame; come back for the click then.
			last_click_frame = frames
			return
		print("OFFSCREEN BUTTON: %s %s" % [b.text, str(b.get_global_rect())])
		errors += 1
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = p
		e.global_position = p
		e.pressed = down
		root.push_input(e, true)
	last_click_frame = frames

func _game() -> Node:
	for c in root.get_children():
		if c.has_method("_options_for"):
			return c
	return null

func _process(_d: float) -> bool:
	frames += 1
	Engine.time_scale = speed
	var g := _game()
	if g == null or g.get("planner") == null or g.get("player") == null:
		return false
	if frames - last_click_frame < 6:
		return false
	if Time.get_ticks_msec() / 1000.0 - t0 > 900.0:
		print("TIMEOUT")
		_finish()
		return true

	var pl = g.planner
	var tu = g.talk_ui

	# --- the setup screen: a job, four points, a party ----------------------
	var su = g.get("setup")
	if su != null and su.visible:
		var btns: Array = []
		_buttons(su._box, btns)
		if btns.is_empty():
			return false
		match int(su._page):
			0:
				_click(btns[rngd.randi() % btns.size()])
			1:
				# Sell one point first, so selling is exercised, then buy
				# until every point is spent.
				for b in btns:
					if (b as Button).text.begins_with("Done"):
						_click(b)
						return false
				if not sold_once:
					for b in btns:
						if (b as Button).text.begins_with("-"):
							sold_once = true
							_click(b)
							return false
				var buys: Array = []
				for b in btns:
					if (b as Button).text.begins_with("+"):
						buys.append(b)
				if not buys.is_empty():
					_click(buys[rngd.randi() % buys.size()])
			2:
				for b in btns:
					if (b as Button).text.begins_with("Begin"):
						_click(b)
						print("SETUP role=%s stats=%s party=%s" % [Arch.ROLE_NAME[su.role], str(su.stats), str(su.party)])
						sold_once = false
						return false
				var open_rows: Array = []
				for b in btns:
					if (b as Button).text.begins_with("[  ]"):
						open_rows.append(b)
				if not open_rows.is_empty():
					_click(open_rows[rngd.randi() % open_rows.size()])
		return false

	if g.phase == 2 and last_phase != 2:
		var vals: Array = []
		for o in g._options_for(Arch.Side.NEMESIS):
			vals.append("%s=%.1f%s" % [o["label"], float(o.get("value", 0.0)), "" if o.get("enabled", true) else "(x)"])
		print("   THEIR MOVE r=%d m=%d — %s  (you=%d them=%d)  opts: %s" % [g.round_no, g.move_no, g.hud._banner.text, g._count(Arch.Side.PLAYER), g._count(Arch.Side.NEMESIS), " ".join(vals)])
	last_phase = g.phase

	# --- planner offering cards -------------------------------------------
	if pl.visible and pl._mode == "offer":
		var opts: Array = g._options_for(Arch.Side.PLAYER)
		var enabled: Array = []
		for o in opts:
			cards_seen += 1
			if o.get("enabled", true):
				enabled.append(o)
				cards_enabled += 1
			else:
				blocked_seen += 1
			if o["kind"] == "poach":
				poach_offered += 1
		var btns: Array = []
		_buttons(pl._box, btns)
		# The planner's rows were built when the move was offered; people keep
		# walking, so a card can appear or vanish since. Choose only among the
		# rows that are actually on the table.
		var on_table: Array = []
		for o in enabled:
			for b in btns:
				if (b as Button).text.begins_with(o["label"]):
					on_table.append(o)
					break
		enabled = on_table
		if enabled.is_empty():
			return false
		var choice: Dictionary = {}
		if policy == "random":
			choice = enabled[rngd.randi() % enabled.size()]
		else:
			var best_v := -INF
			for o in enabled:
				var v: float = float(o.get("value", 0.0))
				if o["kind"] == "present" and g.move_no < Arch.MOVES_PER_ROUND and g.satchel[Arch.Side.PLAYER].size() < Arch.SLIDES_PER_TALK:
					continue
				if v > best_v:
					best_v = v
					choice = o
		if choice.is_empty():
			choice = enabled[0]
		# Find the button whose text starts with the label.
		for b in btns:
			if (b as Button).text.begins_with(choice["label"]):
				decisions += 1
				kinds[choice["kind"]] = int(kinds.get(choice["kind"], 0)) + 1
				if choice["kind"] == "poach":
					poach_taken += 1
				var vals: Array = []
				for o in opts:
					vals.append("%s=%.1f%s" % [o["label"], float(o.get("value", 0.0)), "" if o.get("enabled", true) else "(x)"])
				var cur := 0
				var curm := 0
				for q in g.people:
					if q.is_curious():
						cur += 1
						if q.curious_for == Arch.Side.PLAYER:
							curm += 1
				print("DECIDE r=%d m=%d %s v=%.1f  | curious=%d mine=%d | %s" % [g.round_no, g.move_no, choice["label"], float(choice.get("value", 0.0)), cur, curm, " ".join(vals)])
				_click(b)
				return false
		print("NO BUTTON for %s" % choice["label"])
		errors += 1
		return false

	# --- talk panel ---------------------------------------------------------
	if tu.visible:
		var btns: Array = []
		_buttons(tu._box, btns)
		if btns.is_empty():
			return false
		var b0: Button = btns[0]
		if b0.text == "Play again":
			_record(g)
			done_matches += 1
			if done_matches >= matches:
				_finish()
				return true
			# reload_current_scene needs a current scene; we added main by hand.
			root.remove_child(g)
			g.queue_free()
			var main: Node = load("res://scenes/main.tscn").instantiate()
			root.add_child(main)
			last_click_frame = frames
			return false
		if b0.text == "Next round" or b0.text == "See the numbers":
			print("TALK: %s | %s | you=%d them=%d" % [b0.text, tu._tally.text.replace("\n", " // "), g._count(Arch.Side.PLAYER), g._count(Arch.Side.NEMESIS)])
			_click(b0)
			return false
		if b0.text.begins_with("Ignore it"):
			decisions += 1
			_click(btns[1] if policy != "random" or rngd.randf() < 0.5 else btns[0])
			return false
		# slides: pick the one most wanted
		decisions += 1
		if policy == "random":
			_click(btns[rngd.randi() % btns.size()])
			return false
		var best: Button = b0
		var bw := -1
		for b in btns:
			var r := RegEx.new()
			r.compile("\\((\\d+) in the crowd")
			var m := r.search((b as Button).text)
			var w: int = int(m.get_string(1)) if m else 0
			if w > bw:
				bw = w
				best = b
		_click(best)
		return false
	return false

func _record(g: Node) -> void:
	var a: int = g._count(Arch.Side.PLAYER)
	var b: int = g._count(Arch.Side.NEMESIS)
	var r := {
		"you": a, "them": b, "margin": a - b, "lead_changes": g.lead_changes,
		"pts_you": g.points[Arch.Side.PLAYER], "pts_them": g.points[Arch.Side.NEMESIS],
		"claps_you": g.claps_total[Arch.Side.PLAYER], "claps_them": g.claps_total[Arch.Side.NEMESIS],
		"boos_you": g.boos_total[Arch.Side.PLAYER], "boos_them": g.boos_total[Arch.Side.NEMESIS],
	}
	results.append(r)
	print("MATCH %d: %s" % [done_matches + 1, str(r)])

func _finish() -> void:
	var wins := 0
	var ties := 0
	var margin := 0.0
	var lc := 0.0
	for r in results:
		if r["margin"] > 0: wins += 1
		elif r["margin"] == 0: ties += 1
		margin += abs(r["margin"])
		lc += r["lead_changes"]
	var n: float = maxf(float(results.size()), 1.0)
	print("SUMMARY policy=%s matches=%d wins=%d ties=%d mean|margin|=%.2f lead_changes/match=%.2f decisions/match=%.1f cards/offer=%.1f blocked=%.0f%% poach_offered=%d poach_taken=%d kinds=%s errors=%d wall=%.0fs" % [
		policy, results.size(), wins, ties, margin / n, lc / n, float(decisions) / n,
		float(cards_seen) / maxf(float(decisions), 1.0), 100.0 * float(blocked_seen) / maxf(float(cards_seen), 1.0),
		poach_offered, poach_taken, str(kinds), errors, Time.get_ticks_msec() / 1000.0 - t0])
	quit()
