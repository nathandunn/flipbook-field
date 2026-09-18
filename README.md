# The Outdoor Office

A Godot 4.4 game with a graphic-novel look. An office made of natural elements —
slab-stone desks, stump chairs, a break room under a canopy, a stream for a water
cooler — and a flat rock you give PowerPoint presentations from. You and your work
nemesis take turns gathering material and winning people over, then present to
whoever turns up. Three rounds. Whoever ends with the most people wins.

## Run it

Open the folder in Godot 4.4 (Forward+) and press F5.

| Key | |
|---|---|
| `WASD` | move (camera-relative) |
| `Shift` | run |
| mouse | orbit camera (click once to capture the pointer) |
| `E` / `Space` | act at a station · present at the rock |
| `R` | restart the match |
| `T` | toggle the screen-space ink pass |
| `Esc` | release the mouse |

On a phone: left thumb drags a floating stick to walk, the right side drags to
look, and the **TALK** button acts.

## Two ways to take a turn

Every turn opens on the **planner**: four slots, each tapped to cycle through
*desk · stream · break room · skip*. Press **GO** and the character walks the
route itself while you watch — a bar at the bottom says which leg it is on, and
**Take over** stops it where it stands and gives you back whatever actions are
unspent. **Play it myself** closes the planner and you walk it by hand, exactly
as before.

The default plan is gather, gather, close, rally — the same legible line the
nemesis plays — so pressing GO without touching anything is a real turn rather
than a trap. The talks are always yours; the planner queues the walking and the
verbs, not the slides.

## The loop

One round is: your turn → your talk → their turn (played out at 3x so you can
read it) → their talk → scoreboard.

**Four actions a turn.** Walk to a station and spend one:

- **Desk** — take a prop for your slides. Also makes the three nearest neutrals
  curious, because a pile of interesting stuff is what draws people over.
- **Stream** — the water cooler. Converts *curious* neutrals standing nearby into
  followers. Cold ones just shrug, so this is the close, not the opener.
- **Break room** — rally. A wage slave wanders in, and your followers get resolve
  against being flipped for the round.

Then walk to the rock and present, which ends your turn. Present early with fewer
slides or spend everything first — that is the turn's real decision.

**The talk.** Your crowd assembles: your people, plus curious neutrals drawn in by
how big the crowd looks, plus anyone who came to boo. You play three props. Every
person wants one of *data, story, gadget, snacks*, and a slide lands in proportion
to how much of the room was hoping for that. Between slides a heckler interrupts:
ignore it for a small guaranteed boo, or clap back — lands and the room roars,
misses and you lose someone.

Then it resolves. Curious neutrals convert on the claps-to-boos ratio, and boo
pressure net of applause peels followers off you and turns them into haters.

## The archetypes

Neutrals are the currency. Everything else is a pump or a drain on them.

| | |
|---|---|
| **Neutral** | Contested. Has a curiosity level and a taste. |
| **Follower** | Claps. Can be flipped by boo pressure. |
| **Wage slave** | Attends, never claps, never flips — too tired. Pure crowd size, which is what draws the spectators who are actually worth winning. |
| **Influencer** | Warms a neutral every turn, for free, anywhere on the map. Comes from closing somebody who was *fully* curious — work for it. |
| **Lover** | Claps, immune to flipping, shields one other person, and makes your comebacks land. A follower becomes one after a talk that really landed. |
| **Hater** | Boos, and turns boo pressure into flips. |
| **Bully** | Sent by your nemesis to sit at the front. Takes one of yours whatever you do. |

Everyone wears a floating pip: colour is allegiance, shape and height are
archetype. Cold neutrals have a small pale pip that grows as they warm up, which
is the only tell you get before you try to close them.

## Where the knobs are

`scripts/arch.gd` holds every number that decides whether this is fun — clap
values, boo values, the curiosity threshold, how many a stream visit can close,
how much crowd size pulls in spectators. Nothing about balance lives in
behaviour code.

- `scripts/office.gd` — the world. Layout is rules, not placements, so moving a
  station is one constant.
- `scripts/planner.gd` — the queue-the-turn panel. Pure UI; it knows the names of
  the three verbs and nothing else.
- `scripts/game.gd` — turn loop, the three verbs, the nemesis, scoring. `_run_plan`
  walks a queued route; `Player.auto_target` is what makes the character drive
  itself.
- `scripts/presentation.gd` — the talk, the hecklers, the scoreboards.
- `scripts/person.gd` — one figure: archetype, curiosity, walking.
- `materials/toon_base.tres` — restyles the whole scene at once.

The nemesis AI in `_nemesis_choose` is deliberately legible: gather until it has
slides, close whenever there is anybody to close, rally when it is ahead. You
should be able to predict it after one round and plan against it. If it starts
feeling unbeatable, that function is where to look first.

## The look

1. `shaders/toon.gdshader` — banded half-lambert with a *tinted* (cool purple)
   shadow rather than a darker one.
2. `shaders/outline.gdshader` — inverted-hull ink, expanded along
   `normalize(VERTEX)` because box meshes have split normals and expanding along
   those leaves a gap at every corner. Thickness is angular, so line weight holds
   constant with distance.
3. `shaders/ink_post.gdshader` — Forward+ only; depth + normal edge detect for
   interior creases. Detects the live renderer at startup and switches itself off
   on web and mobile rather than rendering as an opaque sheet.

Animation is quantised to 12 fps in `block_figure.gd`. One `floor()` call, and it
is most of what makes the figures read as drawn rather than simulated.

## Known gaps

- Round 3 plays exactly like round 1. It probably wants escalation.
- Losing a talk costs you the people it costs you and nothing else.
- Influencers only appear from a full-curiosity close and lovers only from a talk
  that went genuinely well, so a bad first round can leave you without either.
- The nemesis never targets a specific person; it plays the board, not you.
