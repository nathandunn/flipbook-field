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

const ACTIONS_PER_TURN := 4
const ROUNDS_PER_MATCH := 3
const SLIDES_PER_TALK := 3


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
