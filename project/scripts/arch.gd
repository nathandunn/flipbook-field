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


# --- Classes -----------------------------------------------------------------
# Everybody in the office has a job, and the job is a costume, a taste, and a
# rule. The rule belongs to whichever side has one of them clapping: buy their
# IT person and their projector is open; lose your Legal and your hand is fair
# game. That is what makes who you recruit a strategy and not a headcount.

enum Role { CEO, ENGINEER, IT, HR, MARKETING, SALES, LEGAL, INTERN, STAFF }

const ROLE_KEY := {
	Role.CEO: "ceo", Role.ENGINEER: "engineer", Role.IT: "it", Role.HR: "hr",
	Role.MARKETING: "marketing", Role.SALES: "sales", Role.LEGAL: "legal",
	Role.INTERN: "intern", Role.STAFF: "staff",
}
const ROLE_NAME := {
	Role.CEO: "CEO", Role.ENGINEER: "Engineer", Role.IT: "IT", Role.HR: "HR",
	Role.MARKETING: "Marketing", Role.SALES: "Sales", Role.LEGAL: "Legal",
	Role.INTERN: "Intern", Role.STAFF: "Staff",
}
## What each job wants to see on a slide. Two entries means either.
const ROLE_TASTES := {
	Role.CEO: [Taste.DATA, Taste.STORY], Role.ENGINEER: [Taste.DATA, Taste.GADGET],
	Role.IT: [Taste.GADGET], Role.HR: [Taste.STORY], Role.MARKETING: [Taste.STORY, Taste.GADGET],
	Role.SALES: [Taste.SNACK, Taste.GADGET], Role.LEGAL: [Taste.DATA],
	Role.INTERN: [Taste.SNACK], Role.STAFF: [Taste.DATA, Taste.STORY, Taste.GADGET, Taste.SNACK],
}
## The rule a side gets while it has one of these on it - you, or anyone
## clapping for you. Every job is an upside and a downside, both on at once.
const ROLE_PERK := {
	Role.CEO: "one more seat on the grass at your talks",
	Role.ENGINEER: "Data and Gadget slides land one extra clap per fan",
	Role.IT: "your projector cannot be rigged",
	Role.HR: "their bullies are turned away at the door",
	Role.MARKETING: "your rumours cool twice as hard",
	Role.SALES: "buy from further away, and the stream closes three",
	Role.LEGAL: "your cards cannot be pinched",
	Role.INTERN: "desks warm one more neutral",
	Role.STAFF: "no rule; just here for the snacks",
}
const ROLE_DOWNSIDE := {
	Role.CEO: "a bully in your crowd takes two of yours, not one",
	Role.ENGINEER: "Story slides land one clap less per fan",
	Role.IT: "you cannot rig their projector either",
	Role.HR: "you cannot send hecklers",
	Role.MARKETING: "their rumours hit you twice as hard too",
	Role.SALES: "Data slides land one clap less per fan",
	Role.LEGAL: "one step less a move - everything needs sign-off",
	Role.INTERN: "an intern can be bought with any card",
	Role.STAFF: "none",
}
## The same, short enough for a roster line.
const PERK_SHORT := {
	Role.CEO: "+1 seat at talks", Role.ENGINEER: "+1 clap Data/Gadget",
	Role.IT: "can't be rigged", Role.HR: "blocks their bullies",
	Role.MARKETING: "rumours x2", Role.SALES: "reach +3, closes 3",
	Role.LEGAL: "hand can't be pinched", Role.INTERN: "desks warm +1",
	Role.STAFF: "",
}
const DOWN_SHORT := {
	Role.CEO: "bullies take 2", Role.ENGINEER: "-1 clap Story",
	Role.IT: "can't rig", Role.HR: "can't send hecklers",
	Role.MARKETING: "their rumours x2", Role.SALES: "-1 clap Data",
	Role.LEGAL: "-1 step", Role.INTERN: "buyable with any card",
	Role.STAFF: "",
}
## Where a job starts on the four stats, before free points: charm, guile,
## hustle, grit.
const ROLE_STATS := {
	Role.CEO: [2, 1, 0, 1], Role.ENGINEER: [0, 1, 1, 2], Role.IT: [0, 2, 1, 1],
	Role.HR: [1, 0, 1, 2], Role.MARKETING: [2, 2, 0, 0], Role.SALES: [2, 0, 2, 0],
	Role.LEGAL: [0, 2, 0, 2], Role.INTERN: [1, 0, 3, 0], Role.STAFF: [1, 1, 1, 1],
}
## Jobs you can play and recruit; Staff is the anonymous crowd.
const PLAYABLE := [Role.CEO, Role.ENGINEER, Role.IT, Role.HR, Role.MARKETING, Role.SALES, Role.LEGAL, Role.INTERN]
## How common each job is among the neutrals on the grass.
const ROLE_WEIGHT := {
	Role.INTERN: 24, Role.ENGINEER: 18, Role.SALES: 14, Role.MARKETING: 12,
	Role.HR: 10, Role.IT: 10, Role.LEGAL: 7, Role.CEO: 2, Role.STAFF: 3,
}

## The stats. Every one changes a number you can see on a card.
const STAT_NAME := ["Charm", "Guile", "Hustle", "Grit"]
const STAT_DESC := [
	"claps from your slides, +12% a point",
	"rumours cool harder and your tricks are worth more",
	"buy from further away; walk faster",
	"boos hurt less at your talk; a heckle ignored costs less",
]
const FREE_POINTS := 4
const STAT_MAX := 5
## Colleagues who start on your side: exactly this many, one of each job, and
## not your own. The nemesis is dealt the same.
const PARTY_SIZE := 4
const PARTY_MAX := PARTY_SIZE


static func role_tint(role: int) -> Color:
	match role:
		Role.CEO: return Color("5a4e63")
		Role.ENGINEER: return Color("9c5a4a")
		Role.IT: return Color("4f6b72")
		Role.HR: return Color("b57f9a")
		Role.MARKETING: return Color("c4614f")
		Role.SALES: return Color("5b7fa6")
		Role.LEGAL: return Color("3f4a52")
		Role.INTERN: return Color("d8a94b")
	return Color("a8a08e")


## A job for a neutral, by the weights above.
static func random_role(rng: RandomNumberGenerator) -> int:
	var total := 0
	for r in ROLE_WEIGHT:
		total += int(ROLE_WEIGHT[r])
	var pick := int(rng.randi() % total)
	for r in ROLE_WEIGHT:
		pick -= int(ROLE_WEIGHT[r])
		if pick < 0:
			return r
	return Role.STAFF


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
