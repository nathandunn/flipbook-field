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

## Who you are

The match opens on a setup screen: pick a **job**, spend four points on four
**stats**, and take up to four **colleagues** with you. The nemesis is dealt a
job, the same points, and as many colleagues as you took.

A job is a costume, a taste, and a rule. The rule belongs to whichever side has
one of that job clapping for it — so buying their IT person unlocks their
projector, and losing your Legal puts your hand back on the table.

| Job | wants | rule while one is on your side |
|---|---|---|
| **CEO** | Data / Story | one more seat on the grass at your talks |
| **Engineer** | Data / Gadget | Data and Gadget slides land one extra clap per fan |
| **IT** | Gadget | your projector cannot be rigged |
| **HR** | Story | their bullies are turned away at the door |
| **Marketing** | Story / Gadget | your rumours cool twice as hard |
| **Sales** | Snacks / Gadget | buy from further away; the stream closes three |
| **Legal** | Data | your cards cannot be pinched |
| **Intern** | Snacks | desks warm one more neutral; interns can be bought with any card |

Everybody on the grass has a job too, drawn from the usual office mix (lots of
interns, one CEO at most), so who you court is a decision: the engineer by the
stream is worth more to you than the intern if you present Data.

**Stats** — Charm: claps from your slides, +12% a point. Guile: rumours cool
harder and your tricks are worth more. Hustle: buy from further away, walk
faster. Grit: boo pressure at your talk −4 a point, and an ignored heckle costs
less. Each job starts somewhere on these; the four free points are yours.

## The match, as a board game

The first version played like two games of solitaire compared at the end: four
actions from you, then four from them, and nothing you did could block, bait or
answer the other side. It was dull for the same reason a card game with no
interaction is dull. The rules now:

- **Moves alternate.** You, them, you, them — four each — then both of you
  present and the round is scored. Whoever is behind moves *second* — the last
  move of a round is the one nothing can answer, so the underdog gets it. On
  level terms it alternates.
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

## Sabotage

Both ways, every round, and never hidden: everything done to you is printed on
the HUD the moment it happens, and every trick has a counter.

- **Pinch their card** — stand at the desk of a taste they hold and take one
  out of their hand into yours. Counter: stand on that desk yourself (it blocks
  them), or present before they get there.
- **Spread a rumour** — at the stream, cool everybody who was warming to them.
  Counter: close your curious people before they get to the water.
- **Rig the projector** — at the rock, without presenting. Their best slide
  comes up blank at their talk. Counter: **Check the projector**, a move at the
  rock that puts it right — one move for one move. A rig is never allowed on the
  last move of a round, so there is always time to answer it.

The nemesis does all of this to you, with the same cards and the same numbers.

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

## Faces, and the rest of the body

Every figure is a paper doll: each part is a slim slab with a drawing on its
front and another on its back, so a costume reads from any side and the walk
still swings at the joints.

Heads carry Nathan's pen drawings — four originals and sixteen synthesised
variants from `art/facegen.py`. Face 0 is the player, face 1 the nemesis, the
rest are dealt from a shuffled deck so no two people in a match share a face.
The **back of each head is inferred** from its front by `art/bodygen.py`: the
silhouette mirrored, the hair kept (the ink outside the middle of the head,
where the features are), the face dropped, the crown hatched.

Bodies are drawn by `art/bodygen.py` in the same idiom — one pen, paper white,
a wobble in every line — one costume per job, front and back: the CEO's hatched
suit and tie, the engineer's plaid, IT's hoodie, lanyard and pouch (hood hanging
on the back), HR's blazer and badge, marketing's turtleneck and scarf, sales'
rolled sleeves, loosened tie and phone, legal's waistcoat, bow tie and
pinstripes, the intern's sticker and backpack. `build.sh` regenerates all of it
before the import step; nothing is hand-placed.

## Playability, measured

`drive6.gd` (kept out of the export) plays whole matches through the real UI —
real clicks on the real buttons — with a greedy policy that reads the same
numbers off the cards the nemesis does, and a random one. Eight matches each,
after the redesign:

| | greedy vs nemesis | random vs nemesis |
|---|---|---|
| wins / ties / losses | 14 / 9 / 9 (32 matches, random jobs and parties) | 1 / 0 / 11 |
| mean margin | 1.5 people | 4.9 people |
| lead changes per match | 0.6 | 0.25 |
| decisions per match | ~26 | ~22 |
| cards blocked by the other side | 19% | 21% |

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
- `scripts/person.gd` — one figure: archetype, job, curiosity and who it is
  for, walking. `warm_rule` is the tug of war, as a pure function.
- `scripts/setup.gd` — the job / stats / party screen. Pure UI.
- `scripts/block_figure.gd` — the paper doll. `art/bodygen.py` draws what it wears.
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
