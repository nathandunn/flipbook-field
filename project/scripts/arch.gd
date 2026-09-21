## Arch — archetypes, props, tastes. Pure data, no nodes.
##
## The design in one line: neutrals are the currency and everything else is a
## pump or a drain on them. Every number that decides whether the game is fun
## lives in this file, so tuning never means hunting through behaviour code.
class_name Arch
extends RefCounted

enum Kind {
	NEUTRAL,     ## the contested resource
	FOLLOWER,    ## claps; can be flipped by boo pressure
	WAGE_SLAVE,  ## attends, never claps, never flips - crowd size without signal
	INFLUENCER,  ## warms a neutral every turn, for free, anywhere
	LOVER,       ## claps, immune to flipping, shields a neighbour
	HATER,       ## boos, and turns boo pressure into flips
	BULLY,       ## sent by the other side; flips a follower mid-presentation
}

enum Side { NONE, PLAYER, NEMESIS }

## What a slide can be made of. Everyone in the crowd wants exactly one of these,
## so a prop lands in proportion to how much of the room was hoping for it.
enum Taste { DATA, STORY, GADGET, SNACK }

const TASTE_NAME := {
	Taste.DATA: "Data",
	Taste.STORY: "Story",
	Taste.GADGET: "Gadget",
	Taste.SNACK: "Snacks",
}

## Props are named after what you'd actually find lying around an office made of
## trees. The name is cosmetic; the taste is what the crowd reacts to.
const PROPS := {
	Taste.DATA: [
		"Bark Chart", "Pebble Tally", "Sap Forecast", "Ring-Count Study",
		"Anthill Survey", "Tide Table",
	],
	Taste.STORY: [
		"Founder Myth", "Campfire Retro", "The Big Storm", "Migration Parable",
		"A Word From Moss", "The Year The River Moved",
	],
	Taste.GADGET: [
		"Slate Tablet", "Pinecone Clicker", "Reed Pointer", "Gourd Speakerphone",
		"Vine Cable Management", "Beetle Mouse",
	],
	Taste.SNACK: [
		"Blackberries", "Hazelnuts", "Honeycomb Tray", "Wild Plums",
		"Smoked Trout", "Acorn Flour Scones",
	],
}

## Claps a single attendee contributes when a slide matches what they wanted.
const CLAP_MATCH := 3.0
## Claps for an attendee who wanted something else but is on your side anyway.
const CLAP_LOYAL := 1.0
## Boos a hater contributes per slide, before matching.
const BOO_BASE := 2.0
## A bully boos like a hater and, at resolve, tries to flip somebody.
const BOO_BULLY := 3.0

## Curiosity 0..3. At or above this, a neutral is "curious" and can be closed at
## the stream. Below it they shrug at you, which is what stops the water cooler
## from being the only action worth taking.
const CURIOUS_AT := 2.0
const CURIOSITY_MAX := 3.0

## Gathering at a desk warms this many of the nearest neutrals, by this much.
const WARM_COUNT := 3
const WARM_AMOUNT := 1.0
## Radius around the stream inside which a curious neutral can be closed.
const STREAM_RADIUS := 6.5
## Most people one stream visit can convert.
const STREAM_CLOSE_MAX := 2

## Crowd size needed to pull in one extra curious neutral as a spectator.
const SPECTATOR_PER_HEADS := 3

const ROUNDS_PER_MATCH := 3
const SLIDES_PER_TALK := 3

# --- The match as a board game -----------------------------------------------
# What made the first version dull was that nothing you did could ever block,
# bait or answer the other side: they moved after you, in a lump. Now moves
# alternate - you, them, you, them - and the board is public. Every card you
# hold can be played as a slide or spent to buy somebody; every station you
# stand on is one they cannot use next move.

## Moves each side gets per round before the talks.
const MOVES_PER_ROUND := 4
## Kept for the HUD's action pips.
const ACTIONS_PER_TURN := MOVES_PER_ROUND

## Spend a card to buy a follower of the other side who wants it, if they are
## within this reach of the station you act at. Lovers are immune; anyone who
## rallied in the break room this round (resolve) is immune too - which is what
## makes the break room a defensive move and not just a free wage slave.
const POACH_RADIUS := 9.0
## Haters needed before one of them goes to bully the other side's talk.
const BULLY_FROM_HATERS := 2

## Sabotage. Every dirty trick has a station, a tell on the HUD, and a counter.
## Pinching a card needs the desk of that taste; a rumour needs the stream and
## only cools people curious about *them*; rigging the projector needs the rock
## and swaps their best slide for a blank one, unless they go and check it.
## Rumours cool this much curiosity.
const RUMOUR_CHILL := 1.0
## What a rigged projector puts up instead of their best slide.
const DUD_NAME := "A Blank Slate"

## Whoever has fewer people gets this many extra spectator slots at their talk.
## A chess game with no way back is a game you stop playing at move ten.
const UNDERDOG_SLOTS := 1


## Round arc. Hecklers interrupt more as the match goes on.
static func heckles_per_talk(round_no: int) -> int:
	return clampi(round_no, 1, SLIDES_PER_TALK - 1)


## In the last round the whole office turns up: a smaller crowd pulls in the
## same number of spectators, so the final talks are the big ones.
static func spectator_per_heads(round_no: int) -> int:
	return SPECTATOR_PER_HEADS if round_no < ROUNDS_PER_MATCH else 2


## Taste name, tolerant of the dud slide's -1.
static func taste_label(taste: int) -> String:
	return TASTE_NAME[taste] if TASTE_NAME.has(taste) else "nothing"


static func side_color(side: int) -> Color:
	match side:
		Side.PLAYER:
			return Color("c4614f")
		Side.NEMESIS:
			return Color("5b7fa6")
		_:
			return Color("b9b3a6")


static func kind_name(kind: int) -> String:
	match kind:
		Kind.NEUTRAL: return "Neutral"
		Kind.FOLLOWER: return "Follower"
		Kind.WAGE_SLAVE: return "Wage Slave"
		Kind.INFLUENCER: return "Influencer"
		Kind.LOVER: return "Lover"
		Kind.HATER: return "Hater"
		Kind.BULLY: return "Bully"
	return "?"


## Pip geometry above the head: size and height encode the archetype so the crowd
## is readable at a glance without labels. Returns [size, height, bright].
static func pip_shape(kind: int) -> Array:
	match kind:
		Kind.INFLUENCER: return [Vector3(0.26, 0.58, 0.26), 0.42, 1.30]
		Kind.LOVER: return [Vector3(0.52, 0.22, 0.22), 0.36, 1.25]
		Kind.HATER: return [Vector3(0.34, 0.34, 0.34), 0.38, 0.50]
		Kind.BULLY: return [Vector3(0.46, 0.46, 0.46), 0.44, 0.34]
		Kind.WAGE_SLAVE: return [Vector3(0.34, 0.13, 0.34), 0.30, 0.78]
		Kind.FOLLOWER: return [Vector3(0.34, 0.24, 0.34), 0.34, 1.0]
	return [Vector3(0.26, 0.16, 0.26), 0.30, 0.9]


## Does this archetype clap for you?
static func claps(kind: int) -> bool:
	return kind == Kind.FOLLOWER or kind == Kind.LOVER or kind == Kind.INFLUENCER


## Does this archetype boo?
static func boos(kind: int) -> bool:
	return kind == Kind.HATER or kind == Kind.BULLY


## Can boo pressure flip this person to the other side?
static func flippable(kind: int) -> bool:
	return kind == Kind.FOLLOWER
