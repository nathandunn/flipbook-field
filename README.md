# The Outdoor Office

A Godot 4.4 game with a graphic-novel look. An office made of natural elements —
slab-stone desks, stump chairs, a break room under a canopy, a stream for a water
cooler — and a flat rock you give PowerPoint presentations from. You and your work
nemesis alternate moves, gathering material and winning people over, then both
present to whoever turns up. Three rounds. Whoever ends with the most people who
would clap for them wins.

## Run it

Open `project/` in Godot 4.4 (Forward+) and press F5.

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

## The match, as a board game

The first version played like two games of solitaire compared at the end: four
actions from you, then four from them, and nothing you did could block, bait or
answer the other side. It was dull for the same reason a card game with no
interaction is dull. The rules now:

- **Moves alternate.** You, them, you, them — four each — then both of you
  present and the round is scored. Whoever is behind moves first; on level terms
  it alternates. The second mover gets first pick of whoever the first just made
  curious, so moving first is not free.
- **The board is public, the hands are hidden.** The HUD always shows what the
  room wants (*Data · Story · Gadget · Snacks*) and how many cards the other side
  holds. What those cards are, you find out at their talk.
- **Every card has two uses.** A card is a slide at the rock, or it is spent to
  *buy* somebody on the other side who wants exactly that thing and is within
  reach of a station. Their followers are your targets and yours are theirs.
- **Blocking.** The station the other side stood on for its last move is closed
  to you this move. Standing on the Story desk is also standing between them
  and the Story desk.
- **Pieces.** A follower can be turned into a heckler: one point down now, for a
  piece that boos at every one of their talks. Two hecklers send a bully, who sits
  at the front and takes somebody whatever they do.
- **Escalation and a way back.** Hecklers interrupt more each round; in the last
  round the whole office turns up. Whoever has fewer people gets an extra seat on
  the grass at their talk, and anyone booed out of a talk goes back to the pool —
  warm, not lost — so one bad round is not the match.

Each move is a card from the **planner**: one row per legal move, and every row
says what it will do *right now* — which desk and how many want it, how many
nearby would get curious, who you could buy and with what. Rows the other side
has blocked are greyed with the reason. The character walks the move itself
while you watch; **Take over** stops it and gives you the controls, and **Play it
myself** skips the cards altogether and the station you press `E` at is your move.

## The moves

- **Desk** (one per taste) — take a card of that taste. Also warms the three
  nearest neutrals toward you. Interest is a tug of war: warming somebody the
  other side has been courting wears their interest down first, then starts them
  on you. The card says how many it wins over and how many it steals.
- **Stream** — the water cooler. Closes up to two neutrals nearby who are curious
  *about you*. Cold ones shrug; this is the close, not the opener.
- **Break room** — rally. Your followers cannot be bought this round, and a wage
  slave wanders in to pad the crowd.
- **Send a heckler** — one follower turns sour. See pieces, above.
- **Buy somebody** — spend a matching card on one of theirs.
- **Present now** — go to the rock early, with whatever is in hand.

**The talk.** Your crowd assembles: your people, plus neutrals curious about you
drawn in by how big the crowd looks, plus anyone who came to boo. You play up to
three slides; every person wants one of the four tastes, and a slide lands in
proportion to how much of the room was hoping for it. Between slides a heckler
interrupts: ignore it for a small guaranteed boo, or clap back — better than even
odds, lands and the room roars, misses and it costs boos (and a person, if their
bully is in the room). The nemesis is heckled on the same schedule and always
lets it go.

Then it resolves. Curious spectators convert on the claps-to-boos ratio, and boo
pressure net of applause sends followers back to the grass.

## The archetypes

Neutrals are the currency. Everything else is a pump or a drain on them.

| | |
|---|---|
| **Neutral** | Contested. Has a curiosity level, a taste, and a side it is curious about. |
| **Follower** | Claps. Can be bought with a matching card, or booed back to neutral. |
| **Wage slave** | Attends, never claps, never flips — too tired. Crowd size, which draws spectators, and not a point. |
| **Influencer** | Warms a neutral every move, for free. Comes from closing somebody who was *fully* curious. |
| **Lover** | Claps, immune to everything, shields one other person, makes clap-backs land. A follower becomes one after a talk that really landed. |
| **Hater** | Boos at the other side's talks. A piece, not a point. Made by *Send a heckler*. |
| **Bully** | With two haters, one goes to sit at the front of the other side's talk and takes somebody whatever they do. |

Everyone wears a floating pip: colour is allegiance, shape and height are
archetype. Cold neutrals have a small pale pip that grows as they warm up.

## Faces

Heads are paper cards carrying Nathan's pen drawings — four originals and sixteen
synthesised variants, generated at build time from an 8 KB blob by
`art/facegen.py`. Face 0 is the player, face 1 the nemesis, the rest are dealt
from a shuffled deck so no two people in a match share a face.

## Playability, measured

`drive6.gd` (kept out of the export) plays whole matches through the real UI —
real clicks on the real buttons — with a greedy policy that reads the same
numbers off the cards the nemesis does, and a random one. Eight matches each,
after the redesign:

| | greedy vs nemesis | random vs nemesis |
|---|---|---|
| wins / ties / losses | 3 / 1 / 4 | 0 / 1 / 7 |
| mean margin | 1.5 people | 4.5 people |
| lead changes per match | 1.0 | 0.1 |
| decisions per match | ~30 | ~18 |

Which is what a fair two-player game looks like from the outside: level against
an equal, punished for playing at random, and the lead moving during the match.
The first version, under the same harness, lost every match by ten and never
changed leader.

## Where the knobs are

`scripts/arch.gd` holds every number that decides whether this is fun — clap and
boo values, the curiosity threshold, poach reach, how many haters make a bully,
the underdog seat. Nothing about balance lives in behaviour code.

- `scripts/office.gd` — the world. Layout is rules, not placements; the first four
  desks carry the four tastes.
- `scripts/planner.gd` — the cards. Pure UI; it draws what it is handed and
  reports which row was pressed.
- `scripts/game.gd` — the move loop, `_options_for` (the one list that feeds both
  the player's cards and the nemesis's choice, so the AI can never do something
  you could not), the verbs, the talks, scoring.
- `scripts/presentation.gd` — the talk, the hecklers, the scoreboards.
- `scripts/person.gd` — one figure: archetype, curiosity and who it is for,
  walking. `warm_rule` is the tug of war, as a pure function.
- `materials/toon_base.tres` — restyles the whole scene at once.

The nemesis in `_nemesis_choose` takes the biggest number on the board, plus a
little noise. Deliberately legible: every value it uses is a value printed on a
card you can see, so after one round you can predict it and play around it.

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

- The nemesis plays the board, not you: it never sets up a buy two moves ahead.
- The pool is twelve neutrals. Most matches end with half of them still on the
  grass; a bigger office or fewer moves would make the close tighter.
- Talks are still the loudest part of the match and the least decided by it.
