class_name Data
extends RefCounted

# Display names for speakers/portraits.
const NAMES := {
	"sam": "Sam", "dani": "Dani", "dusty": "Dusty", "kit": "Kit",
	"ada": "Grandma Ada", "nell": "Nell", "chief": "Chief Bismark", "mary": "Mary Williams",
	"abner": "Abner Quill", "lark": "Brother Lark", "deacon": "Deacon Pruitt", "rowan": "Rowan",
	"farmer": "Brother Abel", "girl": "Patty Jr.", "teen": "Dwayne", "lantern_man": "???",
	"coveralls": "Man in Coveralls", "phone": "The Phone", "mom": "Mom", "tape": "Rowan (tape)",
}

const MEMBERS := {
	"sam": {"name": "Sam", "hp": 42, "nerve": 12, "atk": 9, "def": 6, "spd": 7,
		"knacks": ["glare", "grandpa"], "bash": "bashes", "sprite": "sam"},
	"dani": {"name": "Dani", "hp": 50, "nerve": 9, "atk": 11, "def": 8, "spd": 8,
		"knacks": ["freeze", "sidearm"], "bash": "lands a jab on", "sprite": "dani"},
	"dusty": {"name": "Dusty", "hp": 36, "nerve": 6, "atk": 8, "def": 5, "spd": 13,
		"knacks": ["fetch", "growl"], "bash": "bites", "sprite": "dusty"},
	"kit": {"name": "Kit", "hp": 30, "nerve": 14, "atk": 6, "def": 4, "spd": 11,
		"knacks": ["slingshot", "pep"], "bash": "kicks", "sprite": "kit"},
}

# type: dmg | dmg_all | stun | stun_all | heal | heal_all | fetch | weaken
const KNACKS := {
	"glare": {"name": "Flashlight Glare", "cost": 3, "type": "dmg", "power": 10, "ghost": 2.2, "stun": 0.45,
		"text": "%s snaps Grandpa's flashlight into %s's eyes!"},
	"grandpa": {"name": "Grandpa's Advice", "cost": 4, "type": "heal", "power": 28, "self": true,
		"text": "%s remembers Grandpa: \"Breathe. Count the fence posts.\""},
	"old_words": {"name": "Old Words", "cost": 6, "type": "dmg_all", "power": 16, "ghost": 2.0,
		"text": "%s reads the drowned names aloud from Mary's notes..."},
	"freeze": {"name": "Freeze! Police!", "cost": 3, "type": "stun_all", "power": 0, "stun": 0.6, "living_only": true,
		"text": "%s yells \"FREEZE! POLICE!\""},
	"sidearm": {"name": "Service Revolver", "cost": 5, "type": "dmg", "power": 24, "ghost": 0.3,
		"text": "%s draws her service revolver. BLAM!"},
	"fetch": {"name": "Fetch", "cost": 2, "type": "fetch", "power": 0,
		"text": "%s bounds off into the dark..."},
	"growl": {"name": "Growl", "cost": 2, "type": "weaken", "power": 0,
		"text": "%s growls low at %s."},
	"slingshot": {"name": "Slingshot", "cost": 2, "type": "dmg", "power": 12, "sure": true,
		"text": "%s lets fly with a wrist-rocket!"},
	"pep": {"name": "Pep Talk", "cost": 4, "type": "heal", "power": 30,
		"text": "%s gives %s a pep talk. \"You're totally not gonna die!\""},
	"rocket": {"name": "Bottle Rocket", "cost": 5, "type": "dmg_all", "power": 10,
		"text": "%s lights a bottle rocket! FWEEEE-POP!"},
}

# use: field+battle "heal"/"nerve"/"revive", battle only "ghost"/"all", key items have no use.
const ITEMS := {
	"coffee": {"name": "Nell's Coffee", "price": 1, "use": "heal", "power": 25,
		"desc": "Black, bitter, bottomless. Restores 25 HP."},
	"donut": {"name": "Cider Donut", "price": 2, "use": "heal", "power": 45,
		"desc": "Warm, cinnamon-sugared. Restores 45 HP."},
	"cider": {"name": "Hot Cider", "price": 3, "use": "nerve", "power": 10,
		"desc": "Mulled, from the orchard up the road. Restores 10 Nerve."},
	"batteries": {"name": "D Batteries", "price": 5, "use": "nerve", "power": 20,
		"desc": "Fresh Duraflames for the flashlight. Restores 20 Nerve."},
	"rock_salt": {"name": "Rock Salt", "price": 4, "use": "ghost", "power": 26,
		"desc": "A coffee can of road salt. Ghosts hate it. (Battle)"},
	"rocket": {"name": "Bottle Rocket", "price": 6, "use": "all", "power": 14,
		"desc": "Left over from the 4th. Hits all enemies. (Battle)"},
	"salts": {"name": "Smelling Salts", "price": 10, "use": "revive", "power": 30,
		"desc": "Wakes up a knocked-out friend."},
	"flashlight": {"name": "Grandpa's Flashlight", "key": true,
		"desc": "A heavy steel Maglite. It has a little lantern scratched into the butt cap."},
	"tape": {"name": "Rowan's Tape", "key": true,
		"desc": "A TDK-90 labeled 'HUM LOG' in Rowan's handwriting."},
	"ledger": {"name": "Ledger Page, 1831", "key": true,
		"desc": "\"Hollow Road — twelve households — KEPT. — J. Dillard, Keeper.\""},
	"lantern": {"name": "Crested Lantern", "key": true,
		"desc": "A brass lantern. The crest is a D wrapped around a lantern flame. Your family's."},
	"bottle": {"name": "Blue Glass Bottle", "key": true, "curio": true,
		"desc": "Hand-blown, from a cellar hole on Lovers Lane. Something rattles inside."},
	"hymnal": {"name": "Hymnal Page", "key": true, "curio": true,
		"desc": "A Concordant hymn: 'The Water Keeps Its Own.'"},
	"horseshoe": {"name": "Ox Shoe", "key": true, "curio": true,
		"desc": "A split iron ox shoe, found in the sand at Bare Hill. Cold to the touch."},
}

const SHOP := ["coffee", "donut", "cider", "batteries", "rock_salt", "rocket", "salts"]

# moves: [text, type, power]   type: hit | hit_all | nerve | stun | none
const ENEMIES := {
	"raccoon": {"name": "Rabid Raccoon", "hp": 22, "atk": 8, "def": 2, "spd": 9, "exp": 7, "money": 3,
		"moves": [["%s lunges and bites!", "hit", 1.0], ["%s foams at the mouth menacingly.", "none", 0],
			["%s rummages through %s's pockets!", "hit", 0.6]],
		"defeat": "The %s scampered off into a culvert!", "scale": 0.8},
	"goose": {"name": "Angry Goose", "hp": 30, "atk": 10, "def": 3, "spd": 10, "exp": 10, "money": 2,
		"moves": [["%s HONKS with its entire soul!", "nerve", 3], ["%s flogs %s with its wings!", "hit", 1.1],
			["%s hisses.", "none", 0]],
		"defeat": "The %s honked one last time and waddled away.", "scale": 0.95},
	"cyclist": {"name": "Lost Cyclist", "hp": 34, "atk": 10, "def": 4, "spd": 8, "exp": 14, "money": 0, "ghost": true,
		"moves": [["%s rings a bell that isn't there...", "nerve", 4], ["%s swings its broken handlebars!", "hit", 1.1],
			["%s asks which way is home.", "none", 0]],
		"defeat": "The %s found its way home. Maybe.", "scale": 1.0},
	"hollow": {"name": "Hollow", "hp": 40, "atk": 12, "def": 5, "spd": 7, "exp": 18, "money": 0, "ghost": true,
		"moves": [["%s whispers %s's name...", "nerve", 5], ["%s seeps cold into %s!", "hit", 1.2],
			["%s sheds dead leaves.", "none", 0]],
		"defeat": "The %s came apart like wet leaves.", "scale": 1.05},
	"coveralls": {"name": "Man in Coveralls", "hp": 45, "atk": 12, "def": 6, "spd": 6, "exp": 22, "money": 15,
		"moves": [["%s strikes the tuning fork. MMMMMMMMM.", "hit_all", 0.7], ["%s swings a clipboard!", "hit", 1.0],
			["%s says, \"Ma'am, this is a restricted area.\"", "none", 0]],
		"defeat": "The %s radioed for a ride and left.", "scale": 1.0},
	"wisp": {"name": "Pond Light", "hp": 24, "atk": 9, "def": 2, "spd": 14, "exp": 12, "money": 0, "ghost": true,
		"moves": [["%s beckons %s toward the water...", "stun", 0], ["%s flares!", "hit", 1.0]],
		"defeat": "The %s guttered out.", "scale": 0.9},
	"scarecrow": {"name": "Orchard Scarecrow", "hp": 38, "atk": 11, "def": 6, "spd": 5, "exp": 15, "money": 4,
		"moves": [["%s jabs with a pitchfork!", "hit", 1.15], ["%s creaks in the wind.", "none", 0]],
		"defeat": "The %s fell over. It was just a scarecrow. Probably.", "scale": 1.0},
	"lantern_man": {"name": "Lantern Man", "hp": 150, "atk": 14, "def": 7, "spd": 9, "exp": 90, "money": 60, "boss": true,
		"moves": [["%s swings the lantern like a flail!", "hit", 1.2], ["%s raises the lantern. The flame goes white!", "hit_all", 0.8],
			["%s recites: \"Keep the water quiet. Keep the names below.\"", "nerve", 5], ["%s stares at %s from inside the hood.", "stun", 0]],
		"defeat": "The %s staggered back and fled into the fog, dropping the lantern!", "scale": 1.25},
	"teamster": {"name": "The Drowned Teamster", "hp": 240, "atk": 16, "def": 8, "spd": 6, "exp": 160, "money": 0, "boss": true, "ghost": true,
		"moves": [["%s cracks a bullwhip of pond weed!", "hit", 1.3], ["%s hauls the pond up over everyone!", "hit_all", 0.9],
			["%s grips %s with a waterlogged hand!", "stun", 0], ["%s groans: \"Hollow Road... we were HOME...\"", "nerve", 6]],
		"defeat": "The %s sank back under the black water.", "scale": 1.35},
}

# Overland landmarks. loc = location id to enter; locked = flavor text when not enterable.
const LANDMARKS := {
	"dillard_farm": {"name": "Dillard Farm", "loc": "farm", "spawn": "drive"},
	"common": {"name": "Harvard Common", "loc": "common", "spawn": "west"},
	"lovers_lane": {"name": "Lovers Lane", "loc": "lovers_lane", "spawn": "south"},
	"bellview": {"name": "Bellview Burial Ground", "loc": "bellview", "spawn": "gate"},
	"barehill_beach": {"name": "Bare Hill Pond Beach", "loc": "beach", "spawn": "path"},
	"fruitvale": {"name": "Fruitvale Farm", "loc": "fruitvale", "spawn": "path"},
	"fort_devlin": {"name": "Fort Devlin", "locked": "A chain-link gate, new padlock. A sign: COMMONWEAL RESEARCH — DECOMMISSIONING IN PROGRESS — NO TRESPASSING. Past the fence, the ground hums like a refrigerator the size of a town."},
	"mirror_lake": {"name": "Mirror Lake", "locked": "The old-timers call it Hell Pond. A hundred and fifty feet deep, they say, and nobody's found the bottom of it. A fresh orange cable runs from the woods straight down into the water."},
	"observatory": {"name": "Pinnacle Ridge Observatory", "locked": "The domes have been shuttered since the university pulled out. Last night one of them was turning. Nobody's had a key since 1986."},
	"shaker_village": {"name": "Shaker Village", "locked": "Quiet clapboard houses and a cemetery of cast-iron markers shaped like lollipops. Someone has left a lit lantern on every one of them. The Shakers have been gone for decades."},
	"abbey": {"name": "Saint Bramble's Abbey", "locked": "The brothers make fruitcake and keep to themselves. Lately the bells ring at 3 a.m., and they won't say who's ringing them."},
	"oxbow": {"name": "The Oxbow", "locked": "The Nashua loops back on itself here. Fishermen say something big moves in the oxbow at night, pushing a wake with no head in front of it."},
	"poor_farm": {"name": "Poor Farm Road", "locked": "There's a headstone out here for a man who died in the 1800s epidemic. Nobody would touch the body, so they buried him in his bed. Kids say on cold nights you can hear the bedsprings."},
	"carrow_orchard": {"name": "Carrow Orchards", "locked": "Old Chester Carrow says the scarecrows have been moving between rows. His granddaughter Brandi says he's been moving them himself. Both of them lock the barn at night."},
	"cleaves_hill": {"name": "Cleaves Hill", "locked": "The best view in town. On a clear night you can see Boston's glow, Wachusett, and twelve small lights floating on Bare Hill Pond that nobody seems to own."},
}

const TIMES := {"day": Color(1, 1, 1), "dusk": Color(1.0, 0.8, 0.72), "night": Color(0.36, 0.4, 0.62)}
