class_name Data
extends RefCounted
## Game data: the heroes (towers), the Phyrexian hordes (enemies) and the seven invaded planes
## (levels) with their roads, looks and waves.
##
## Story (the March of the Machine invasion, retold with original characters): the Mother of
## Machines has grown the Realmbreaker, a vast tree of porcelain and steel whose roots punch
## through into every plane. Phyrexians pour out of the root rifts. The heroes of each world stand
## at the roads to its last sanctum, and when the worlds hold, the strike team carries the fight
## to the Realmbreaker's root on Phyrexia itself.

## dmg types: "phys" (armour stops it), "magic" (resistance stops it), "true" (nothing does).
## Per-level arrays are [level 1, 2, 3]. cost[0] builds, cost[1] and cost[2] upgrade.
const TOWERS := {
	"champion": {
		"name": "Sunsworn Champion", "title": "Knight of the Last Dawn", "plane": 0,
		"cost": [90, 110, 160], "dmg": [24, 40, 66], "rate": [0.95, 1.0, 1.1], "range": [4.3, 4.6, 5.0],
		"type": "phys", "air": true, "boss_bonus": [0.25, 0.4, 0.6],
		"color": Color(1.0, 0.86, 0.45),
		"desc": "A knight who has already died once and came back to finish the job. Hurls spears of sunlight; extra damage to the Phyrexian champions.",
		"lore": "Bearer of the god-forged spear. She swore to see the Mother of Machines fall.",
	},
	"ember": {
		"name": "Ember Prodigy", "title": "Pyromancer of the Inventors' City", "plane": 0,
		"cost": [110, 130, 180], "dmg": [16, 27, 42], "rate": [0.8, 0.85, 0.9], "range": [4.0, 4.2, 4.5],
		"type": "magic", "air": true, "splash": [1.4, 1.6, 1.9], "burn": [4.0, 7.0, 11.0],
		"color": Color(1.0, 0.45, 0.12),
		"desc": "Throws fireballs that burst on the horde and leave it burning. Best against crowds.",
		"lore": "Her hair is literally on fire. She is fine with that.",
	},
	"sage": {
		"name": "Timeweaver Sage", "title": "Keeper of Lost Hours", "plane": 0,
		"cost": [80, 100, 140], "dmg": [6, 10, 16], "rate": [0.8, 0.85, 0.9], "range": [3.6, 3.9, 4.3],
		"type": "magic", "air": true, "slow": [0.35, 0.45, 0.55], "slow_time": [1.6, 1.8, 2.1],
		"color": Color(0.45, 0.8, 1.0),
		"desc": "Pulses of bent time slow every Phyrexian around him. Pair him with heavy hitters.",
		"lore": "He once hid a whole country in a pocket of time. Twenty minutes is easy.",
	},
	"ninja": {
		"name": "Moonblade Ninja", "title": "Shadow of the Neon City", "plane": 1,
		"cost": [100, 120, 170], "dmg": [7, 11, 16], "rate": [2.8, 3.1, 3.4], "range": [3.9, 4.1, 4.4],
		"type": "phys", "air": true, "multi": [1, 1, 2],
		"color": Color(0.6, 0.75, 1.0),
		"desc": "A blur of shuriken, very fast, good against swarms and flyers. At level 3 he throws at two targets.",
		"lore": "Thief, bodyguard, brother. His little drone keeps the score.",
	},
	"litho": {
		"name": "Hedron Lithomancer", "title": "Stoneshaper of the Wild World", "plane": 2,
		"cost": [130, 150, 210], "dmg": [42, 72, 118], "rate": [0.42, 0.45, 0.5], "range": [5.0, 5.4, 5.9],
		"type": "phys", "air": false, "splash": [1.7, 1.9, 2.2],
		"color": Color(0.5, 0.95, 0.85),
		"desc": "Drops carved hedron stones from the sky. Slow, long range, huge splash. Cannot hit flyers.",
		"lore": "Old as the mountains and just as patient. She shaped these stones herself.",
	},
	"dragon": {
		"name": "Stormmind Dragon", "title": "Firemind of the City of Guilds", "plane": 3,
		"cost": [170, 190, 260], "dmg": [30, 48, 76], "rate": [0.7, 0.75, 0.8], "range": [4.6, 4.9, 5.3],
		"type": "magic", "air": true, "chain": [3, 4, 6],
		"color": Color(0.4, 0.75, 1.0),
		"desc": "Chain lightning that jumps from one Phyrexian to the next.",
		"lore": "A genius dragon who thinks the invasion is mostly an interesting experiment.",
	},
	"ghost": {
		"name": "Ghostblade Envoy", "title": "Assassin Between Worlds", "plane": 4,
		"cost": [140, 160, 220], "dmg": [36, 60, 98], "rate": [0.75, 0.8, 0.85], "range": [4.1, 4.3, 4.6],
		"type": "true", "air": true, "execute": [0.0, 0.08, 0.14],
		"color": Color(0.8, 0.5, 1.0),
		"desc": "Spectral daggers pass through armour and wards alike. Finishes off badly hurt foes at higher levels.",
		"lore": "She steps between the living and the dead, and stabs both when needed.",
	},
	"grove": {
		"name": "Grovewarden", "title": "Treefolk and Dryad of the Frozen Realms", "plane": 5,
		"cost": [150, 170, 230], "dmg": [22, 36, 58], "rate": [0.5, 0.55, 0.6], "range": [3.5, 3.8, 4.1],
		"type": "magic", "air": false, "root": [0.8, 1.0, 1.25],
		"color": Color(0.55, 1.0, 0.45),
		"desc": "Roots burst from the ground and hold every walker in range for a moment. Cannot reach flyers.",
		"lore": "A dryad who talks to trees, riding the one tree that talks back.",
	},
}
const TOWER_ORDER := ["champion", "ember", "sage", "ninja", "litho", "dragon", "ghost", "grove"]

## Phyrexians. hp is for the first plane; later planes multiply it (PLANES[i].hp).
## leak is how many sanctum lives one costs if it gets through.
const ENEMIES := {
	"mite": {"name": "Scuttling Mite", "hp": 34, "speed": 2.5, "armor": 0.0, "resist": 0.0, "bounty": 5, "leak": 1, "size": 0.45,
		"desc": "Tiny porcelain spiders. Alone they are nothing."},
	"husk": {"name": "Compleated Husk", "hp": 85, "speed": 1.55, "armor": 0.1, "resist": 0.0, "bounty": 9, "leak": 1, "size": 0.8,
		"desc": "Once a soldier of this plane. Now a blade-armed shell that remembers nothing."},
	"hound": {"name": "Flayer Hound", "hp": 70, "speed": 2.7, "armor": 0.05, "resist": 0.0, "bounty": 10, "leak": 1, "size": 0.75,
		"desc": "Fast, low and hungry. Comes in packs."},
	"brute": {"name": "Oilback Brute", "hp": 330, "speed": 1.05, "armor": 0.55, "resist": 0.0, "bounty": 26, "leak": 2, "size": 1.25,
		"desc": "Heavy black plating. Spears and stones glance off; fire and spirit do not."},
	"drake": {"name": "Carrion Drake", "hp": 120, "speed": 1.9, "armor": 0.0, "resist": 0.1, "bounty": 18, "leak": 1, "size": 1.0, "fly": true,
		"desc": "Flies over everything. Stones and roots cannot reach it."},
	"spitter": {"name": "Oil Spitter", "hp": 170, "speed": 1.35, "armor": 0.15, "resist": 0.15, "bounty": 20, "leak": 1, "size": 0.95, "spit": true,
		"desc": "Spits glistening oil at heroes, freezing them in place for a few seconds."},
	"knight": {"name": "Glistening Knight", "hp": 270, "speed": 1.35, "armor": 0.3, "resist": 0.6, "bounty": 26, "leak": 2, "size": 1.05,
		"desc": "The Mother's own knights. Warded against magic."},
	"brood": {"name": "Vat Broodmother", "hp": 620, "speed": 0.85, "armor": 0.2, "resist": 0.2, "bounty": 36, "leak": 3, "size": 1.35, "brood": 6,
		"desc": "A walking vat. When it breaks, mites pour out."},
	"colossus": {"name": "Realmbreaker Colossus", "hp": 4200, "speed": 0.62, "armor": 0.45, "resist": 0.3, "bounty": 220, "leak": 10, "size": 2.1, "boss": true,
		"desc": "A siege engine grown from the Realmbreaker's own bark of steel."},
	"walker": {"name": "Compleated Walker", "hp": 5200, "speed": 0.72, "armor": 0.2, "resist": 0.5, "bounty": 260, "leak": 10, "size": 1.8, "boss": true, "spit": true,
		"desc": "A planeswalker who lost the fight inside. Oils the heroes as it passes."},
	"mother": {"name": "The Porcelain Mother", "hp": 7500, "speed": 0.45, "armor": 0.3, "resist": 0.3, "bounty": 0, "leak": 20, "size": 2.6, "boss": true, "spit": true, "summon": true,
		"desc": "The Mother of Machines herself. Her word is the only word."},
}

## Each plane: look (colours, sky, props), roads (one polyline per spawn rift, all ending at the
## sanctum), waves and what is new. Roads are in world units: x from -22 to 22, z from -13 to 13.
const PLANES := [
	{
		"id": "dominaria", "name": "Dominaria", "place": "The Benalish Fields",
		"intro": "The first root breaks the sky over the old knightly fields. The Timeweaver, the Ember Prodigy and the Sunsworn Champion stand at the road to the chapel.",
		"new": "Heroes: Sunsworn Champion, Ember Prodigy, Timeweaver Sage.",
		"hp": 1.0, "mana": 260, "waves": 10, "roster": ["husk", "mite", "hound", "brute"], "boss": "colossus",
		"roads": [[Vector2(-23, -6), Vector2(-14, -6), Vector2(-14, 6), Vector2(-3, 6), Vector2(-3, -7), Vector2(9, -7), Vector2(9, 5), Vector2(23, 5)]],
		"theme": "dominaria", "time": "day",
		"sky_top": Color(0.28, 0.48, 0.82), "sky_horizon": Color(0.78, 0.84, 0.9), "ground": Color(0.3, 0.42, 0.18),
		"grass": Color(0.33, 0.47, 0.19), "grass2": Color(0.45, 0.5, 0.22), "road": Color(0.55, 0.47, 0.36),
		"sun": Color(1.0, 0.94, 0.82), "sun_energy": 1.25, "sun_dir": Vector3(-0.55, -0.75, -0.4), "ambient": Color(0.55, 0.6, 0.7),
		"fog": Color(0.72, 0.78, 0.86), "fog_density": 0.004,
	},
	{
		"id": "kamigawa", "name": "Kamigawa", "place": "Neon Streets of the Capital",
		"intro": "Two rifts open above the neon capital at midnight. A masked ninja drops from the rooftops to help.",
		"new": "New hero: Moonblade Ninja. New foes: Carrion Drakes fly over the rooftops.",
		"hp": 1.06, "mana": 300, "waves": 12, "roster": ["husk", "mite", "hound", "drake", "brute"], "boss": "walker",
		"roads": [[Vector2(-23, -9), Vector2(-9, -9), Vector2(-9, 0), Vector2(5, 0), Vector2(5, -8), Vector2(15, -8), Vector2(15, 6), Vector2(23, 6)],
			[Vector2(-23, 9), Vector2(-9, 9), Vector2(-9, 0), Vector2(5, 0), Vector2(5, -8), Vector2(15, -8), Vector2(15, 6), Vector2(23, 6)]],
		"theme": "kamigawa", "time": "night",
		"sky_top": Color(0.04, 0.03, 0.12), "sky_horizon": Color(0.22, 0.12, 0.3), "ground": Color(0.08, 0.06, 0.12),
		"grass": Color(0.15, 0.17, 0.17), "grass2": Color(0.2, 0.2, 0.2), "road": Color(0.3, 0.3, 0.33),
		"sun": Color(0.65, 0.7, 1.0), "sun_energy": 0.55, "sun_dir": Vector3(0.4, -0.7, -0.5), "ambient": Color(0.42, 0.4, 0.55),
		"fog": Color(0.12, 0.08, 0.16), "fog_density": 0.006,
	},
	{
		"id": "zendikar", "name": "Zendikar", "place": "The Hedron Canyon",
		"intro": "On the wild world the hedrons still float. The Lithomancer offers her stones to the cause.",
		"new": "New hero: Hedron Lithomancer. New foes: Oil Spitters freeze heroes with oil.",
		"hp": 1.12, "mana": 340, "waves": 12, "roster": ["husk", "hound", "drake", "brute", "spitter"], "boss": "colossus",
		"roads": [[Vector2(-23, 10), Vector2(-16, 10), Vector2(-16, -8), Vector2(-8, -8), Vector2(-8, 8), Vector2(0, 8), Vector2(0, -8), Vector2(8, -8), Vector2(8, 8), Vector2(16, 8), Vector2(16, -4), Vector2(23, -4)]],
		"theme": "zendikar", "time": "dusk",
		"sky_top": Color(0.22, 0.25, 0.5), "sky_horizon": Color(0.95, 0.62, 0.42), "ground": Color(0.35, 0.25, 0.2),
		"grass": Color(0.52, 0.38, 0.27), "grass2": Color(0.4, 0.42, 0.25), "road": Color(0.68, 0.56, 0.42),
		"sun": Color(1.0, 0.72, 0.5), "sun_energy": 1.1, "sun_dir": Vector3(0.7, -0.45, -0.3), "ambient": Color(0.55, 0.45, 0.55),
		"fog": Color(0.85, 0.6, 0.5), "fog_density": 0.004,
	},
	{
		"id": "ravnica", "name": "Ravnica", "place": "The Tenth District",
		"intro": "The city of guilds is one endless street, and the horde is in all of them. Above the spires, a dragon who calls himself a genius takes an interest.",
		"new": "New hero: Stormmind Dragon. New foes: Glistening Knights, warded against magic.",
		"hp": 1.18, "mana": 380, "waves": 13, "roster": ["husk", "hound", "drake", "brute", "spitter", "knight"], "boss": "walker",
		"roads": [[Vector2(-23, -3), Vector2(-12, -3), Vector2(-12, -10), Vector2(4, -10), Vector2(4, 0), Vector2(14, 0), Vector2(14, 7), Vector2(23, 7)],
			[Vector2(-23, 4), Vector2(-12, 4), Vector2(-12, 10), Vector2(4, 10), Vector2(4, 0), Vector2(14, 0), Vector2(14, 7), Vector2(23, 7)]],
		"theme": "ravnica", "time": "overcast",
		"sky_top": Color(0.32, 0.36, 0.45), "sky_horizon": Color(0.68, 0.68, 0.7), "ground": Color(0.25, 0.24, 0.24),
		"grass": Color(0.36, 0.34, 0.32), "grass2": Color(0.3, 0.33, 0.27), "road": Color(0.48, 0.45, 0.42),
		"sun": Color(0.95, 0.92, 0.88), "sun_energy": 0.95, "sun_dir": Vector3(-0.4, -0.8, -0.45), "ambient": Color(0.55, 0.57, 0.62),
		"fog": Color(0.6, 0.6, 0.64), "fog_density": 0.006,
	},
	{
		"id": "innistrad", "name": "Innistrad", "place": "The Moonlit Moor",
		"intro": "Under a blood moon the dead rise to fight beside the living, and the Ghostblade Envoy walks between them.",
		"new": "New hero: Ghostblade Envoy. New foes: Vat Broodmothers burst into mites.",
		"hp": 1.24, "mana": 420, "waves": 14, "roster": ["husk", "mite", "hound", "drake", "brute", "spitter", "knight", "brood"], "boss": "colossus",
		"roads": [[Vector2(-23, -10), Vector2(17, -10), Vector2(17, 9), Vector2(-16, 9), Vector2(-16, -3), Vector2(7, -3), Vector2(7, 3), Vector2(-5, 3)]],
		"theme": "innistrad", "time": "moon",
		"sky_top": Color(0.03, 0.04, 0.08), "sky_horizon": Color(0.2, 0.17, 0.25), "ground": Color(0.06, 0.07, 0.07),
		"grass": Color(0.17, 0.21, 0.16), "grass2": Color(0.22, 0.2, 0.16), "road": Color(0.3, 0.27, 0.24),
		"sun": Color(0.75, 0.8, 1.0), "sun_energy": 0.6, "sun_dir": Vector3(0.5, -0.65, -0.55), "ambient": Color(0.3, 0.32, 0.45),
		"fog": Color(0.18, 0.18, 0.25), "fog_density": 0.009,
	},
	{
		"id": "kaldheim", "name": "Kaldheim", "place": "The Frozen Fjord",
		"intro": "Snow, ice and an aurora over the fjord. A dryad and her treefolk friend hold the bridge to the mead hall.",
		"new": "New hero: Grovewarden. Two rifts again, and the foes are tougher.",
		"hp": 1.3, "mana": 460, "waves": 14, "roster": ["husk", "mite", "hound", "drake", "brute", "spitter", "knight", "brood"], "boss": "walker",
		"roads": [[Vector2(-12, -14), Vector2(-12, -4), Vector2(4, -4), Vector2(4, 6), Vector2(14, 6), Vector2(14, -5), Vector2(23, -5)],
			[Vector2(-23, 7), Vector2(-4, 7), Vector2(-4, -4), Vector2(4, -4), Vector2(4, 6), Vector2(14, 6), Vector2(14, -5), Vector2(23, -5)]],
		"theme": "kaldheim", "time": "aurora",
		"sky_top": Color(0.05, 0.1, 0.22), "sky_horizon": Color(0.45, 0.6, 0.72), "ground": Color(0.75, 0.8, 0.86),
		"grass": Color(0.82, 0.86, 0.92), "grass2": Color(0.7, 0.76, 0.84), "road": Color(0.48, 0.45, 0.44),
		"sun": Color(0.85, 0.92, 1.0), "sun_energy": 0.85, "sun_dir": Vector3(-0.6, -0.55, -0.5), "ambient": Color(0.5, 0.58, 0.72),
		"fog": Color(0.55, 0.65, 0.78), "fog_density": 0.006,
	},
	{
		"id": "phyrexia", "name": "New Phyrexia", "place": "The Realmbreaker's Root",
		"intro": "The worlds held. Now the strike team carries the war to the source. At the Realmbreaker's root the Porcelain Mother comes to meet them in person.",
		"new": "Every hero answers the final call. The Porcelain Mother leads the last wave.",
		"hp": 1.36, "mana": 520, "waves": 15, "roster": ["husk", "mite", "hound", "drake", "brute", "spitter", "knight", "brood"], "boss": "mother",
		"roads": [[Vector2(-23, -9), Vector2(-8, -9), Vector2(-8, -1), Vector2(6, -1), Vector2(6, -9), Vector2(15, -9), Vector2(15, 1), Vector2(23, 1)],
			[Vector2(-23, 9), Vector2(-8, 9), Vector2(-8, -1), Vector2(6, -1), Vector2(6, -9), Vector2(15, -9), Vector2(15, 1), Vector2(23, 1)]],
		"theme": "phyrexia", "time": "phyrexia",
		"sky_top": Color(0.12, 0.02, 0.03), "sky_horizon": Color(0.55, 0.2, 0.15), "ground": Color(0.12, 0.08, 0.08),
		"grass": Color(0.24, 0.2, 0.2), "grass2": Color(0.36, 0.14, 0.12), "road": Color(0.62, 0.6, 0.56),
		"sun": Color(1.0, 0.72, 0.6), "sun_energy": 0.9, "sun_dir": Vector3(0.3, -0.7, -0.6), "ambient": Color(0.5, 0.35, 0.35),
		"fog": Color(0.35, 0.12, 0.1), "fog_density": 0.007,
	},
]

## Which wave each foe first shows up in (0-based); the plane's roster limits the choice.
const FIRST_WAVE := {"husk": 0, "mite": 1, "hound": 2, "drake": 2, "brute": 4, "spitter": 3, "knight": 4, "brood": 6}
## Rough threat of each foe, used to fill a wave's budget.
const THREAT := {"mite": 0.4, "husk": 1.0, "hound": 0.9, "brute": 3.6, "drake": 1.6, "spitter": 2.2, "knight": 3.4, "brood": 6.0}
## The most of a special foe one wave can bring.
const MAX_COUNT := {"brute": 10, "drake": 14, "spitter": 6, "knight": 10, "brood": 4}


## Builds the waves of plane `p`: a list of waves, each a list of groups
## {kind, count, gap (seconds between spawns), delay (seconds after wave start), road}.
## Every wave is mostly fodder (husks, mites, hounds) with a smaller group or two of the
## plane's special foes once they have been introduced; the last wave brings the boss.
static func waves_for(p: int) -> Array:
	var d: Dictionary = PLANES[p]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (p + 1)
	var roads: int = d.roads.size()
	var basics := []
	var specials := []
	for k in d.roster:
		if k in ["husk", "mite", "hound"]:
			basics.append(k)
		else:
			specials.append(k)
	var out := []
	for w in d.waves:
		var last: bool = w == d.waves - 1
		var budget: float = (8.0 + 3.4 * w + 0.42 * w * w) * (1.0 + 0.05 * p)
		var groups := []
		if last:
			groups.append({"kind": d.boss, "count": 1, "gap": 1.0, "delay": 8.0, "road": 0})
			budget *= 0.65
		var open_basics := []
		for k in basics:
			if w >= FIRST_WAVE[k] - mini(p, 1):
				open_basics.append(k)
		var open_specials := []
		for k in specials:
			if w >= FIRST_WAVE[k] - mini(p, 1):
				open_specials.append(k)
		var n_special := 0 if open_specials.is_empty() else mini(1 + int(w / 5.0), open_specials.size())
		var special_share := 0.0 if n_special == 0 else 0.4
		var plan := []
		var basic: String = open_basics[w % open_basics.size()] if w >= 2 else "husk"
		var fodder := budget * (1.0 - special_share)
		# fodder is split over every road
		for r in roads:
			plan.append([basic, fodder / roads, r])
		if w >= 5 and open_basics.size() > 1 and rng.randf() < 0.5:
			var other: String = open_basics[(w + 1) % open_basics.size()]
			plan.append([other, fodder * 0.3, rng.randi_range(0, roads - 1)])
		open_specials.shuffle()
		var pick := open_specials.duplicate()
		# make sure the newest foe of the plane is seen soon after it is introduced
		for k in pick:
			if FIRST_WAVE[k] - mini(p, 1) == w or FIRST_WAVE[k] - mini(p, 1) == w - 1:
				pick.erase(k)
				pick.push_front(k)
				break
		for i in n_special:
			plan.append([pick[i], budget * special_share / n_special, rng.randi_range(0, roads - 1)])
		var delay := 0.0
		for g in plan:
			var k: String = g[0]
			var count := clampi(int(round(g[1] / THREAT[k])), 1, MAX_COUNT.get(k, 30))
			var gap: float = clampf(0.5 + THREAT[k] * 0.3, 0.4, 2.2) * (0.55 if k == "mite" else 1.0)
			groups.append({"kind": k, "count": count, "gap": gap, "delay": delay, "road": g[2]})
			delay += count * gap * (0.3 if roads > 1 else 0.55) + 1.0
		out.append(groups)
	return out
