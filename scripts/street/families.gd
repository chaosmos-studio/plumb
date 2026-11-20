class_name StreetFamilies
extends RefCounted

## The marble folk who move into the street at each milestone (REVAMP_PLAN.md section 15, decision 12): round marbles
## like the cast in their own colours, each family told apart by its house and a few small props (Codex's H1, as
## build/review/art/h1-lineups.png shows them). They arrive in the order of StreetRewards.FAMILIES.

## Each family's members, largest first: the body's colour (folk_<body>), its size beside a cast member, the props it
## wears (prop_<name>, each placed by its own record) and whether it grins or smiles.
const MEMBERS: Array[Array] = [
	[{"body": "peach", "size": 1.0, "props": ["baker_hat"], "grin": true},
		{"body": "warm_brown", "size": 1.0, "props": ["baker_apron"], "grin": false},
		{"body": "cream", "size": 0.64, "props": ["flour_hat"], "grin": true}],
	[{"body": "sky_blue", "size": 1.0, "props": ["straw_cap", "wheat_sprig"], "grin": true},
		{"body": "mint", "size": 0.72, "props": ["blue_neckerchief"], "grin": false}],
	[{"body": "slate_blue", "size": 1.0, "props": ["spectacles", "pocket_watch"], "grin": false},
		{"body": "lilac", "size": 0.72, "props": ["top_hat"], "grin": true}],
	[{"body": "lime", "size": 0.99, "props": ["leaf_crown"], "grin": true},
		{"body": "leaf_green", "size": 0.86, "props": ["acorn_cap"], "grin": false},
		{"body": "sunflower_yellow", "size": 0.65, "props": ["leaf_twig"], "grin": true}],
]

## Family `f`'s members.
static func members(f: int) -> Array:
	return MEMBERS[posmod(f, MEMBERS.size())]

## Family `f`'s house (a piece on the town page).
static func house(f: int) -> String:
	return StreetRewards.FAMILY_HOUSES[posmod(f, StreetRewards.FAMILY_HOUSES.size())]
