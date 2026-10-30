extends Node

const FLAVOR := {
	"church_door": "The white church on the Common. The doors are locked; through the wavy glass you can see the pews and, on the altar, a single brass lantern with the wick trimmed.",
	"monument": "A granite obelisk for the men of Harvard who went off to the Civil War. Someone has scratched a tiny lantern into the base, down low where only a kid would see it.",
	"flagpole": "The flag snaps in the wind. The halyard clanks against the pole like a ship's bell.",
	"bench": "A plaque: IN MEMORY OF ELLIS DILLARD, WHO SAT HERE. Grandpa. He did sit here. Every morning, with Nell's coffee, for forty years.",
	"schoolhouse": "The old Center School. Your mom went here. The windows are dark, except one in the attic, which shouldn't have a light at all.",
	"old_stones": "Slate stones with winged skulls. 'Remember me as you pass by / As you are now so once was I.' Charming.",
	"display_case": "A glass case: 'HARVARD BEFORE THE FLOOD — 1831.' Arrowheads, a powder horn, and a gap where something was removed. The little card just says ON LOAN.",
	"stairs": "A velvet rope and a sign: HISTORICAL SOCIETY — BY APPOINTMENT. Something upstairs creaks, slowly, like a rocking chair.",
	"chimney": "The chimney of a house that burned in 1890-something. Kids come here to drink and scare each other. There are fresh candle stubs on the hearthstone.",
	"bv_church": "The old Still River meetinghouse. A sign: PRIVATE — STILL RIVER HISTORICAL TRUST. The steeple bell has no clapper.",
	"bv_stones": "These stones are older than the rest and they all face the same way: southeast, toward Bare Hill Pond.",
	"bathhouse": "The town beach bathhouse, shuttered for the season. Someone has stenciled on the door: THE WATER KEEPS ITS OWN.",
	"barn": "Grandpa's barn. It smells like hay, motor oil, and the 1970s. His workbench is exactly as he left it.",
	"well": "The old well, capped with a millstone. When you put your ear to it you can hear... a hum? No. Probably the pump.",
	"family_graves": "The Dillard family plot. Seven generations of Dillards, and one new stone: ELLIS DILLARD, 1921–1995. Next to it, older than any of them: J. DILLARD, KEEPER.",
	"truck": "Grandpa's '72 Ford. The keys are in it, like always. Nobody in Harvard locks anything. Supposedly.",
	"farm_sign": "DILLARD FARM — EST. 1789 — PICK YOUR OWN. Someone painted over the old logo. Under the white you can just make out a D wrapped around a flame.",
	"fv_door": "The farmhouse door has a hand-lettered sign: 'BE PLAIN. BE KIND. BE QUIET AFTER DARK.'",
	"pump": "A cast-iron hand pump. The water that comes out is ice cold and tastes faintly of pennies.",
	"hives": "The beehives are silent. Not a single bee. A Concordant brother has hung little bells on each one, like he's waiting for something to come home.",
	"fv_sign": "FRUITVALE FARM — THE CONCORDANT FAMILY — EST. 1843 — ALL WELCOME AT SUPPER. Underneath, someone added in pencil: 'not after dark'.",
	"store_shelves": "Canned goods, Moxie, night crawlers, VHS rentals ('Return by 7 or Nell WILL call your mother'), and a whole shelf of D batteries. A lot of D batteries.",
}


func W() -> Node:
	return Game.main.world


func flavor(text: String) -> void:
	await UI.say("", text)


func run(ev: String) -> void:
	Game.cutscene += 1
	if has_method("ev_" + ev):
		await call("ev_" + ev)
	elif FLAVOR.has(ev):
		await flavor(FLAVOR[ev])
	Game.cutscene -= 1
	if W() and W().has_method("refresh_npcs"):
		W().refresh_npcs()
	UI.update_hud()


var quiet := false


func on_enter(loc: String) -> void:
	if quiet:
		return
	if has_method("enter_" + loc):
		Game.cutscene += 1
		await call("enter_" + loc)
		Game.cutscene -= 1
		if W() and W().has_method("refresh_npcs"):
			W().refresh_npcs()
		UI.update_hud()


func fight(enemies: Array, opts := {}) -> bool:
	Audio.sfx("encounter")
	await UI.flash(Color(1, 1, 1), 0.3)
	var r: String = await Game.battle(enemies, opts)
	if r == "lose":
		Game.cutscene -= 1
		await Game.lose()
		Game.cutscene += 1
		return false
	return true


func join(id: String) -> void:
	Game.add_member(id)
	Audio.sfx("pickup")
	UI.toast("%s joined the party!" % Data.NAMES[id])


func give(id: String, n := 1) -> void:
	Game.add_item(id, n)
	Audio.sfx("pickup")
	UI.toast("Got %s%s." % [Data.ITEMS[id].name, " ×%d" % n if n > 1 else ""])


# ================================================================ INTRO

func intro() -> void:
	Game.cutscene += 1
	await UI.card("Harvard, Massachusetts", "October 1995.\n\nThirty-five miles from Boston, and nowhere near Cambridge.")
	await UI.card("", "You left this town at eighteen and swore you weren't coming back.\n\nThen Grandpa died. Then Grandma called and said, \"Sammy, Rowan Fitch is missing,\" and hung up before you could ask why she was telling you.")
	Game.time = "day"
	Game.cutscene -= 1
	await Game.goto("farm", "drive")
	Game.cutscene += 1
	await UI.say("", "Dillard Farm. The orchard's gone half wild. The porch light is on in broad daylight.")
	var w := W()
	await w.walk_to(w.player, Vector2(560, 470))
	w.player.face(Vector2.LEFT)
	await UI.talk([
		["ada", "There's my boy. You look thin. Boston doesn't feed you."],
		["sam", "Hi, Grandma. What's going on with Rowan?"],
		["ada", "Rowan Fitch went out on that bicycle Tuesday night and didn't come home. Three days now."],
		["ada", "Chief Bismark thinks he ran off to New York. Rowan's mother doesn't. Neither do I."],
		["sam", "Why call me, though? I haven't talked to Rowan since high school."],
		["ada", "Because Rowan called HERE, Tuesday. Late. Asked for you. Said, 'Tell Sam I found the Hum.'"],
		["sam", "...The Hum. Like when we were kids? The noise by the pond?"],
		["ada", "I don't know anything about any hum."],
		["ada", "Here. Your grandfather's flashlight. He'd want you to have it. Don't go poking around the pond after dark."],
	])
	give("flashlight")
	await UI.talk([
		["ada", "And take Dusty. He's been sitting at the end of the driveway since Tuesday like he's waiting for somebody."],
	])
	join("dusty")
	await UI.talk([
		["ada", "Go see the Chief at the Common. Get Nell to feed you a donut. And Sammy—"],
		["ada", "...Never mind. Go on."],
	])
	Game.setf("intro_done")
	Game.set_objective("Ask about Rowan on Harvard Common (head out the drive, then northwest).")
	if UI.touch_ui:
		UI.toast("Tip: walk off the farm to reach the town map. A interacts. MENU opens your journal and items.")
	else:
		UI.toast("Tip: walk off the edge of the farm to reach the town map. Z/Enter interacts. Tab opens the menu.")
	Game.cutscene -= 1


# ================================================================ FARM

func ev_ada() -> void:
	if Game.flag("ch1_done"):
		await UI.talk([
			["ada", "Eat something. We'll talk when I'm ready to talk, Samuel."],
			["sam", "You were on the dock with a lantern, Grandma."],
			["ada", "Eat. Something."],
		])
	elif Game.flag("bellview_done"):
		await UI.talk([["ada", "Where have you been? It's the middle of the night. What is that you're carrying?"],
			["sam", "...Nothing. Just a lantern."], ["ada", "...Go to bed, Sammy."]])
	else:
		var lines := [
			"Your grandfather sat on that bench on the Common every morning for forty years. Nell will tell you.",
			"Don't eat the apples from the north rows. They've gone mealy. Something's wrong with the water.",
			"The Concordant folks up at Fruitvale brought a pie when Ellis died. Strange people. Kind, though.",
			"If you see Mary at the library, tell her I still have her casserole dish.",
		]
		await UI.say("ada", lines[randi() % lines.size()])
	await UI.say("", "Grandma makes you a plate. Everyone is fully rested.")
	Game.heal_all()
	Audio.sfx("heal")


func ev_farm_door() -> void:
	if await UI.confirm("", "Grandma's kitchen. Rest a while and write in your journal? (Heals everyone and saves the game.)"):
		Game.heal_all()
		Game.location = "farm"
		Game.spawn = "porch"
		Game.save()
		Audio.sfx("save")
		await UI.say("", "You rest at the kitchen table. The clock ticks. Game saved.")


# ================================================================ COMMON

func ev_payphone() -> void:
	Audio.sfx("phone_ring", 1.4, -8)
	var lines := ["Mom picks up on the first ring. \"Did you eat? Is your grandmother all right? Don't go near the pond.\"",
		"Mom: \"Your father says hi. He also says don't go near the pond.\"",
		"Mom: \"Sammy, I'm in the middle of Melrose Place. Are you being careful?\""]
	await UI.say("", lines[randi() % lines.size()])
	if await UI.confirm("", "Save your progress?"):
		Game.location = "common"
		Game.spawn = "phone"
		Game.save()
		Audio.sfx("save")
		await UI.say("", "Saved. Mom says she loves you. Mom says don't go near the pond.")


func ev_chief() -> void:
	if not Game.flag("met_chief"):
		await UI.talk([
			["chief", "Well, well. Sam Dillard. Sorry about your grandfather, son. Ellis was a good man."],
			["sam", "Thanks, Chief. I'm here about Rowan Fitch."],
			["chief", "Course you are. Look. Rowan's twenty-two, owes money to half the people at Fort Devlin, and has been saying for a year he's moving to New York."],
			["chief", "Kid got on a bus. Happens."],
			["sam", "Rowan called my grandmother's house the night he disappeared. Talking about the Hum."],
			["chief", "The Hum. Christ on a bike."],
			["chief", "Sam, there is no Hum. There's the Commonweal plant out at the old fort, there's high-tension lines, and there's teenagers with too much time."],
			["chief", "Officer Reyes, make sure Mr. Dillard gets home all right. I've got a meeting."],
		])
		var w := W()
		if w.npc("chief"):
			w.walk_to(w.npc("chief"), Vector2(1300, 600))
		await UI.talk([
			["dani", "...Hey, Sam."],
			["sam", "Dani? Dani Reyes? You're a COP?"],
			["dani", "Three years. Don't make it weird."],
			["dani", "Listen. I'm not supposed to tell you this. Somebody called in a bike in the culvert on Lovers Lane yesterday. Chief told me to leave it."],
			["dani", "It's a red Schwinn. Rowan's."],
			["dani", "I'm off shift in twenty minutes. Meet me on Lovers Lane. It's just west of here — off the top of the Common."],
		])
		Game.setf("met_chief")
		Game.set_objective("Meet Dani on Lovers Lane (just west of the Common).")
		if w.npc("dani"):
			await w.walk_to(w.npc("dani"), Vector2(1300, 640))
		w.remove_npc("dani")
		w.remove_npc("chief")
	else:
		var lines := [
			"Go home, Sam. Help your grandmother with the orchard.",
			"I've got a town meeting about the Commonweal decommissioning. Half the town wants the jobs, half the town wants it gone. Nobody wants to hear about a hum.",
			"If I catch you out at Bellview after dark, I'm calling Ada.",
			"You know there's a statute about trespassing on the Shaker land? Of course you don't.",
		]
		await UI.say("chief", lines[randi() % lines.size()])


func ev_dani_common() -> void:
	await UI.say("dani", "Talk to the Chief first. He's in a mood. Trust me.")


func ev_dwayne() -> void:
	var lines := [
		["teen", "Dude, you're Ellis Dillard's grandkid? Your grandpa used to yell at us for skating on the Common. RIP, man."],
		["teen", "You hear the Hum? Like three in the morning? Sounds like the world's biggest fridge. My mom says it's the Commonweal plant. My mom also thinks Nirvana is devil music."],
		["teen", "Rowan? Yeah, Rowan was all into it. Had like a tape recorder taped to his bike. Said he was gonna get it on tape and send it to Unsolved Mysteries."],
		["teen", "Don't go to the cemetery crypt. There's a dead guy in there that MOVES. Patty's little sister saw it."],
	]
	var l: Array = lines[randi() % lines.size()]
	await UI.say(l[0], l[1])


func ev_deacon() -> void:
	if Game.has_item("lantern"):
		await UI.talk([["deacon", "...Where did you get that lantern, young man?"],
			["sam", "Somebody dropped it."],
			["deacon", "Put it out. Please. Before the water notices."]])
		return
	var lines := [
		"Evening. The church is closed, I'm afraid. We open again for Sunday service. And for... other occasions.",
		"Your grandfather was a faithful man. Faithful to this town. More than you know.",
		"Have you ever noticed every old house in this town keeps a lamp in the window? Old habit. Very old.",
	]
	await UI.say("deacon", lines[randi() % lines.size()])


# ================================================================ STORE

func enter_store() -> void:
	if not Game.flag("met_nell"):
		Game.setf("met_nell")
		await UI.talk([["nell", "Sammy Dillard! Get over here. I'm so sorry about Ellis, hon. He paid for his coffee every morning for forty years, and he never once took a lid."]])


func ev_nell() -> void:
	var c := await UI.choose("nell", "What'll it be, hon?", ["Buy something", "Ask about Rowan", "Ask about the Hum", "Nothing"])
	match c:
		0:
			await UI.shop()
		1:
			await UI.talk([["nell", "Rowan came in Tuesday around six. Bought four D batteries and a coffee, black. Said, 'Nell, if I'm not back by Thursday, tell my brother he can have my comics.'"],
				["nell", "I thought he was joking. Kit's been in every day asking. Poor kid's been hanging around the cemetery with Patty's girl."]])
			Game.note("Nell: Rowan bought batteries Tuesday. His brother Kit hangs around the cemetery.")
		2:
			await UI.talk([["nell", "The Hum? Hon, that's been going since I was a girl. Comes and goes. It started up again the week your grandfather died."],
				["nell", "My mother used to say it was the drowned church bells under Bare Hill Pond. Said they flooded a whole road when they built the dam."]])
			Game.note("Nell: the Hum restarted the week Grandpa died. A road was flooded when Bare Hill Pond was dammed.")
		_:
			await UI.say("nell", "Take care of yourself. And your grandmother.")


func ev_coffee_pot() -> void:
	if Game.money < 1:
		await UI.say("", "The coffee pot is still half full. A sign says $1, HONOR SYSTEM. You don't have a dollar.")
		return
	if await UI.confirm("", "Coffee is $1, honor system. Pour a cup to go?"):
		Game.money -= 1
		give("coffee")


func ev_bulletin() -> void:
	await UI.say("", "The bulletin board:\n• MISSING: ROWAN FITCH, 22. RED SCHWINN. CALL LINDA.\n• LOST GOOSE. ANSWERS TO 'GERALD.' DO NOT APPROACH.\n• FRUITVALE HARVEST SUPPER — ALL WELCOME — BE HOME BY DARK.")


# ================================================================ LOVERS LANE

func enter_lovers_lane() -> void:
	if Game.flag("met_chief") and not Game.flag("lane_done"):
		var w := W()
		var d: Actor = w.add_npc("dani", "dani", Vector2(830, 760), "dani_lane", Vector2.UP)
		d.ev = "dani_lane"
		if not Game.flag("lane_hello"):
			Game.setf("lane_hello")
			await UI.say("dani", "Over here, Sam. The culvert by the guardrail.")


func ev_dani_lane() -> void:
	await UI.say("dani", "It's down in the culvert, under the guardrail. Take a look.")


func ev_culvert() -> void:
	if not Game.flag("met_chief"):
		await UI.say("", "Something red is wedged deep in the culvert. You can't get it loose by yourself.")
		return
	if Game.flag("lane_done"):
		await UI.say("", "The culvert drips. Further in, the dark goes back a lot further than a culvert should.")
		return
	var w := W()
	await UI.talk([
		["", "Wedged in the culvert: a red Schwinn ten-speed, front wheel folded like a taco. Taped to the handlebars, a Walkman."],
		["dani", "That's Rowan's. Nobody leaves a bike like that and gets on a bus."],
		["sam", "There's a tape in the Walkman. It says HUM LOG."],
	])
	give("tape")
	Audio.stop_music(1.0)
	Audio.sfx("hum", 0.8, -4)
	await UI.talk([
		["tape", "*click* ...October tenth, two-forty AM. Lovers Lane. It's loud tonight. Like the whole ground is a speaker."],
		["tape", "It's not the Commonweal plant. I checked. It's coming from the pond. From UNDER the pond."],
		["tape", "There are lights out on the water. Twelve of them. They're... walking. Toward the road. Toward—"],
		["tape", "*a long low note, like a bell under water* ...hello? Who's there? Who—"],
		["tape", "*click*"],
	])
	await UI.say("dani", "...Okay. Okay. I'm officially weirded out. I'm coming with you.")
	join("dani")
	await UI.say("", "The leaves at the culvert mouth start to move. Not blowing. Standing up.")
	if not await fight(["hollow"], {"intro": "Something made of wet leaves and pond-cold climbs out of the culvert!", "no_run": true}):
		return
	await UI.talk([
		["dani", "What. Was. That."],
		["sam", "I don't know. But it said Rowan's name."],
		["dani", "Rowan said the lights were walking toward 'the road.' Which road? This town is nothing but roads."],
		["sam", "Mary Williams at the library. She knows every road in this town, back to the cow paths."],
	])
	Game.setf("lane_done")
	Game.set_time("dusk")
	Game.note("Found Rowan's bike and tape in the Lovers Lane culvert. Rowan heard the Hum under Bare Hill Pond and saw twelve lights.")
	Game.set_objective("Ask Mary at the library (on the Common) about 'the road.'")
	w.remove_npc("dani")


func ev_cellar_hole() -> void:
	if Game.has_item("bottle") or Game.flag("gave_bottle"):
		await UI.say("", "The old cellar hole. Granite blocks, a birch growing up through the middle. Somebody's house, once.")
		return
	await UI.say("", "Between the stones of the old cellar hole, something blue catches the light: a hand-blown bottle, the kind people buried under doorsteps for luck.")
	give("bottle")


# ================================================================ LIBRARY

func ev_mary() -> void:
	if Game.flag("lane_done") and not Game.flag("mary_told"):
		await UI.talk([
			["mary", "Sam Dillard. I was at your grandfather's funeral. You didn't see me. I was behind the big Concordant fellow."],
			["sam", "Mary, we found Rowan's bike. And a tape. He said lights on the pond were walking toward 'the road.'"],
			["mary", "...Bare Hill Pond was raised in 1831. The mill company built a dam at the outlet so they'd have water power year-round."],
			["mary", "There was a road along the old shore. Twelve families. Hollow Road."],
			["mary", "The company bought them out. Most of them. The ones who wouldn't sell..."],
			["mary", "Well. The water came up anyway."],
			["dani", "You're saying they drowned twelve families for a mill."],
			["mary", "I'm saying the town records for October 1831 are missing. Every page. Somebody took them."],
			["mary", "But the newspaper's on microfiche. Over by the wall. See what it says."],
		])
		Game.setf("mary_told")
		Game.note("Mary: Bare Hill Pond was raised in 1831, flooding 'Hollow Road' and twelve families. The October 1831 town records are missing.")
		Game.set_objective("Read the October 1831 newspaper on the library microfiche.")
		return
	if Game.flag("fiche") and Game.curio_count() > 0:
		await _curios()
		return
	var lines := [
		"The Historical Society is upstairs. By appointment only. I am the appointment.",
		"Shh. People are reading. Well, nobody's reading. But they might.",
		"Tell your grandmother I'd like my casserole dish back. It's been eleven years.",
	]
	if Game.flag("fiche") and not Game.flag("mary_curios_told"):
		Game.setf("mary_curios_told")
		await UI.talk([["mary", "Oh, and Sam — I'm putting together a little display for the Historical Society. Things from before the flood."],
			["mary", "If you find anything old out there — bottles, iron, papers — bring it to me. I might be able to tell you what it means."]])
		Game.note("Mary wants old curios from before the flood for her display.")
		return
	await UI.say("mary", lines[randi() % lines.size()])


func _curios() -> void:
	var have := []
	for id in ["bottle", "hymnal", "horseshoe"]:
		if Game.has_item(id):
			have.append(id)
	for id in have:
		Game.remove_item(id)
		Game.setf("gave_" + id)
		match id:
			"bottle":
				await UI.talk([["mary", "A witch bottle! People buried these under the doorstep to keep things out. There's a slip of paper inside... 'Let the water keep its own and leave this house be.'"]])
			"hymnal":
				await UI.talk([["mary", "A Concordant hymn, 1843. 'The water keeps its own / twelve lamps to light them home.' They sang it on the shore. Every year. For the drowned."]])
			"horseshoe":
				await UI.talk([["mary", "An ox shoe. Split. The teamsters drove oxen down Hollow Road to haul for the mill. One of them, Amos Pell, refused to leave when the water came. They say he's still down there, with his team."]])
	var n := 0
	for id in ["bottle", "hymnal", "horseshoe"]:
		if Game.flag("gave_" + id):
			n += 1
	if n >= 3 and not Game.flag("curios_done"):
		Game.setf("curios_done")
		await UI.talk([
			["mary", "That's all of it, I think. Sam... these are the names."],
			["mary", "I copied the Hollow Road families out of the church book. Twelve households. If you ever have to face what's under that water — say their names. Out loud."],
			["mary", "The dead want to be remembered more than anything. Even more than they want to be left alone."],
		])
		var sam: Dictionary = Game.member("sam")
		if not sam.knacks.has("old_words"):
			sam.knacks.append("old_words")
		Audio.sfx("save")
		UI.toast("Sam learned Old Words! (Strong against ghosts)")
		Game.note("Mary gave Sam the names of the Hollow Road families. (Old Words)")
	else:
		await UI.say("mary", "Bring me anything else you find. I have a feeling there are more pieces.")


func ev_microfiche() -> void:
	if not Game.flag("mary_told"):
		await UI.say("", "A microfiche reader. It smells like hot dust. You'd need to know what you were looking for.")
		return
	if Game.flag("fiche"):
		await UI.say("", "WORCESTER COUNTY SPY, Oct. 19, 1831: \"...the remaining households of Hollow Road declined removal. Mr. J. Dillard, agent, states the matter is KEPT.\"")
		return
	Audio.sfx("cursor")
	await UI.talk([
		["", "You crank through reels of Worcester County Spy. October 1831. Ads for cures, a lost cow, a sermon..."],
		["", "\"HARVARD. — The dam at Bare Hill being completed, the pond rose eleven feet within the fortnight. The remaining households of Hollow Road declined removal. Mr. J. Dillard, agent for the company, states the matter is KEPT, and no further notice need be taken.\""],
		["dani", "J. Dillard. Sam..."],
		["sam", "There's a J. Dillard in our family plot. The stone just says KEEPER."],
		["mary", "The Hollow Road families aren't in Center Cemetery. They were never buried. There's a marker for them out at Bellview, in Still River. Nobody visits."],
		["mary", "But if you want to know what's been happening at night lately, ask the kids at Center Cemetery. They see everything. They're out there every evening, daring each other to knock on the crypt."],
	])
	Game.setf("fiche")
	Game.note("1831 newspaper: 'Mr. J. Dillard, agent, states the matter is KEPT.' An ancestor. The Hollow Road dead have a marker at Bellview.")
	Game.set_objective("Talk to the kids at Center Cemetery (south side of the Common).")


# ================================================================ CEMETERY

func ev_kit_cemetery() -> void:
	if not Game.flag("fiche"):
		await UI.say("kit", "Go away. We're doing a stakeout. It's very important. ...You're Sam? Rowan's friend Sam? Rowan talked about you. Talk to me later, I'm busy.")
		return
	if not Game.flag("crypt_done"):
		await UI.talk([
			["kit", "You're Sam Dillard. Rowan's my brother. I'm Kit."],
			["kit", "There's a guy who lives in the crypt. Like actually LIVES there. Patty thinks he's a zombie. He's not a zombie. Zombies don't have a radio."],
			["kit", "He's out every night. If anybody saw what happened to Rowan, it's him. But he won't talk to kids."],
			["sam", "Okay. I'll knock."],
		])
		Game.set_objective("Knock on the crypt door.")
	else:
		await UI.say("kit", "Let's GO. Bellview. Before they move him again.")


func ev_patty() -> void:
	if not Game.flag("crypt_done"):
		await UI.say("girl", "The corpse in the crypt MOVES. I saw it. It moved its foot. Then it moved its whole entire self.")
	elif not Game.flag("patty_reward"):
		Game.setf("patty_reward")
		await UI.talk([["girl", "So the corpse is just a guy. A guy named ABNER. That is the most disappointing thing that has ever happened to me."],
			["girl", "Here. I was gonna use these to blow up the zombie. You can have them."]])
		give("rocket", 3)
		Game.note("The Moving Corpse of Center Cemetery: just Abner. Patty Jr. gave you bottle rockets.")
	else:
		await UI.say("girl", "My mom says if I'm not home by the streetlights I'm grounded till Christmas. The streetlights have been on for an hour.")


func ev_crypt() -> void:
	if not Game.flag("fiche"):
		await UI.say("", "A granite crypt set into the hill. DILLARD is not on it, thank God. The iron door is cracked open half an inch, and warm air breathes out.")
		return
	if Game.flag("crypt_done"):
		await UI.say("", "The crypt door is shut. Inside, faintly, a radio is playing the Red Sox postgame.")
		return
	Audio.sfx("door", 0.7)
	await UI.say("", "You knock. Three times. Something shifts inside. The door grinds open...")
	var w := W()
	var ab: Actor = w.add_npc("abner", "abner", Vector2(400, 300), "abner", Vector2.DOWN)
	await w.walk_to(ab, Vector2(470, 340))
	await UI.talk([
		["abner", "What. It's six-thirty. Some of us work nights."],
		["sam", "You're... living in the crypt?"],
		["abner", "Renting. The Whitcombs died out in 1902. Nobody's complained. You're Ellis's grandson. You have the nose."],
		["sam", "My friend Rowan disappeared Tuesday night. Did you see anything?"],
		["abner", "...Tuesday I was out walking. I walk at night. Better company."],
		["abner", "There were men on Still River Road. Twelve of 'em. Long coats, hoods. Each one carrying a lantern."],
		["abner", "And the lanterns HUMMED. Like a bee in a jar. They were carrying something between 'em, on a board. Something with a bicycle helmet."],
		["abner", "They went into Bellview. I went back to bed. I'm sixty-eight years old."],
		["kit", "That's Rowan. That's ROWAN. I'm coming with you. Don't even try to say no."],
		["dani", "He's twelve, Sam."],
		["kit", "I'm twelve and a HALF. And I have a slingshot."],
	])
	join("kit")
	Game.setf("crypt_done")
	Game.set_time("night")
	Game.note("Abner saw twelve hooded men with humming lanterns carry someone with a bike helmet into Bellview Burial Ground. Kit joined.")
	Game.set_objective("Go to Bellview Burial Ground, out west in Still River.")
	w.remove_npc("abner")


func ev_abner() -> void:
	if Game.has_item("cider") and not Game.flag("abner_cider"):
		if await UI.confirm("abner", "Is that hot cider? I'd trade a story for that. A true one."):
			Game.remove_item("cider")
			Game.setf("abner_cider")
			await UI.talk([
				["abner", "Ahh. That's the stuff."],
				["abner", "My father used to say there's a bell under Bare Hill Pond. From the Hollow Road meetinghouse. When it rings, the Keeper has to go down to the water."],
				["abner", "Your grandfather went down every October. Took a lantern. Came back wet to the knees. Never said a word about it."],
				["abner", "Here. Found these on a fellow who didn't need them anymore. Don't ask."],
			])
			give("salts", 2)
			Game.note("Abner: Grandpa went down to the pond every October with a lantern.")
			return
	var lines := [
		"I'd invite you in, but there's only room for me and the Whitcombs.",
		"You want to know a secret? Hot cider. Bring me hot cider and I'll tell you something worth knowing.",
		"The Concordants up at Fruitvale leave a plate out for me on Sundays. Good people. Don't eat the bread, though.",
	]
	await UI.say("abner", lines[randi() % lines.size()])


# ================================================================ BELLVIEW

func enter_bellview() -> void:
	if Game.flag("crypt_done") and not Game.flag("bellview_done") and not Game.flag("bv_hello"):
		Game.setf("bv_hello")
		Audio.sfx("phone_ring", 0.9, -4)
		await UI.talk([
			["", "Somewhere among the stones, a telephone is ringing."],
			["dani", "There are no phone lines out here. There's no POWER out here."],
			["kit", "It's coming from the vault."],
		])
		Game.set_objective("Find the ringing phone in Bellview's vault.")


func ev_vault() -> void:
	if not Game.flag("crypt_done"):
		await UI.say("", "A receiving vault built into the hill, where they kept the dead through winter when the ground was frozen. The hinges have been oiled recently.")
		return
	if Game.flag("bellview_done"):
		await UI.say("", "The vault is empty. The old black telephone sits on a stone shelf with its cord trailing into the dirt. It doesn't ring.")
		return
	Audio.sfx("phone_ring", 0.9, -2)
	await UI.say("", "Inside, on a stone shelf, sits an old black rotary telephone. Its cord runs down into the dirt floor. It's ringing.")
	await UI.say("", "You pick it up.")
	Audio.stop_music(0.5)
	Audio.sfx("hum", 0.7, -6)
	await UI.talk([
		["rowan", "...Sam? Sam, is that you? It's so loud down here—"],
		["sam", "Rowan! Where are you?!"],
		["rowan", "Under. On the road. They're all sitting at their tables, Sam. They're waiting for the lanterns. They've been waiting a hundred and sixty years."],
		["rowan", "Don't let them bring the lanterns down to the water. If the lanterns go down, the road comes UP."],
		["rowan", "Ask Ada. Ada knows. Ask her why your grandfather—"],
		["", "*a long, low bell note* ...and then a dial tone."],
		["kit", "That was Rowan. That was Rowan's voice. Sam, that was ROWAN."],
	])
	await UI.say("", "Tucked behind the phone is a sheet of foxed paper, torn from an old bound book.")
	give("ledger")
	await UI.say("", "\"Hollow Road. Twelve households. KEPT. Let the Keeper's line light them each October and the water shall stay quiet. — J. Dillard, Keeper, 1831.\"")
	Audio.sfx("bell", 0.6)
	var w := W()
	var lm: Actor = w.add_npc("lantern_man", "lantern_man", Vector2(760, 640), "", Vector2.UP)
	await w.walk_to(lm, Vector2(560, 420), 60)
	await UI.talk([
		["lantern_man", "That page does not belong to you."],
		["sam", "It's got my family's name on it. I'd say it does."],
		["lantern_man", "Then you know what you owe. Give it back, and go home to Ada, and keep the water quiet."],
		["dani", "Harvard Police. Take the hood off. Slowly."],
		["lantern_man", "...Officer Reyes. Your mother's people were Kept too, you know. Everyone in this town is Kept by somebody."],
	])
	if not await fight(["lantern_man"], {"intro": "The Lantern Man raises his humming lantern!", "no_run": true}):
		w.remove_npc("lantern_man")
		return
	w.remove_npc("lantern_man")
	await UI.talk([
		["", "Where the Lantern Man stood, there's only a puddle of black pond water and the brass lantern, still warm."],
		["sam", "There's a crest on it. A D wrapped around a flame."],
		["sam", "That's on Grandpa's barn. It's painted over on the farm sign. It's OURS."],
	])
	give("lantern")
	Audio.sfx("bell", 0.5)
	await UI.talk([
		["", "Far off, over the hills to the south, a bell is ringing. Deep. Wet. Under water."],
		["kit", "That's coming from the pond."],
		["dani", "Bare Hill Pond. The town beach. Let's go before I come to my senses."],
	])
	Game.setf("bellview_done")
	Game.note("Rowan called from 'under the road.' The ledger: J. Dillard, Keeper, 1831. Defeated a Lantern Man and took his crested lantern — the Dillard crest.")
	Game.set_objective("Follow the bell to Bare Hill Pond beach. Go out on the dock.")


# ================================================================ BEACH

func enter_beach() -> void:
	if Game.flag("bellview_done") and not Game.flag("ch1_done"):
		if Game.time != "night":
			Game.set_time("night")
		Audio.sfx("bell", 0.5, -2)
		await UI.say("", "The bell is louder here. Out past the end of the dock, twelve small lights float on the black water.")


func ev_dock_end() -> void:
	if not Game.flag("bellview_done"):
		await UI.say("", "The end of the town dock. The water is dark and very still. In summer you can see the bottom here. Today you can't.")
		return
	if Game.flag("ch1_done"):
		await UI.say("", "The water is quiet now. Twelve lights still float out there, but they don't move.")
		return
	await UI.talk([
		["", "The lantern in your hand flares white. The lights on the water turn — all twelve at once — toward you."],
		["", "The pond heaves. Something comes up the side of the dock: an enormous man in a teamster's coat, streaming weed, an ox yoke over his shoulders."],
		["sam", "Amos Pell?"],
		["", "A voice like a drain gurgling: \"HOLLOW... ROAD...\""],
	])
	if not await fight(["teamster"], {"intro": "The Drowned Teamster rises out of Bare Hill Pond!", "no_run": true, "music": "boss"}):
		return
	Audio.stop_music(1.5)
	await UI.flash(Color(0.7, 0.85, 1.0), 0.8)
	await UI.card("", "For a moment you can see straight down through the water.\n\nA road. Stone walls. Twelve houses with lamps in every window. People sitting at their tables in their Sunday clothes, faces turned up toward you, waiting.\n\nAnd on the road, on a red bicycle, someone wearing a helmet looks up and waves.")
	var w := W()
	var ada: Actor = w.add_npc("ada", "ada", Vector2(960, 900), "", Vector2.UP)
	await w.walk_to(ada, Vector2(980, 760), 70)
	Audio.play_music("night")
	await UI.talk([
		["ada", "Sammy."],
		["sam", "...Grandma? What are you doing out here?"],
		["", "She's carrying a lantern. It has the same crest."],
		["ada", "You should have stayed in Boston."],
	])
	await UI.fade_out(1.5)
	Game.setf("ch1_done")
	Game.set_time("day")
	await UI.card("End of Chapter One", "THE KEEPER'S LANTERN\n\nRowan Fitch is alive, somewhere under Bare Hill Pond.\nGrandma Ada is not telling you something.\nAnd somewhere in town, eleven more lanterns are waiting.")
	Game.note("Defeated the Drowned Teamster. Saw Hollow Road under the pond — and Rowan, alive. Grandma Ada was on the dock with a crested lantern.")
	Game.set_objective("(Chapter 2 coming soon.) Explore Harvard. Help Mary, Brother Lark, and Abner.")
	Game.location = "farm"
	Game.spawn = "porch"
	Game.save()
	await Game.goto("farm", "porch")
	UI.toast("Game saved. The town is yours to explore.")


func ev_sand() -> void:
	if Game.has_item("horseshoe") or Game.flag("gave_horseshoe"):
		await UI.say("", "Wet sand and goose prints. Lots of goose prints.")
		return
	if Game.flag("lane_done"):
		await UI.say("", "Half-buried in the wet sand at the waterline: a split iron shoe, too big and too flat for a horse. It's cold. Pond-bottom cold.")
		give("horseshoe")
	else:
		await UI.say("", "Wet sand and goose prints. Something iron is half-buried here, frozen into the cold mud. Maybe later.")


# ================================================================ FRUITVALE

func ev_lark() -> void:
	if Game.flag("lark_done"):
		var lines := ["We hold a vigil on the shore each October. You'd be welcome. Bring a coat.",
			"Brother Abel says the hives will come back when the water quiets. Brother Abel says a lot of things.",
			"Our founder came here in 1843 to live plainly. She found the twelve lights the first week. She stayed anyway."]
		await UI.say("lark", lines[randi() % lines.size()])
		return
	if not Game.flag("lark_asked"):
		Game.setf("lark_asked")
		await UI.talk([
			["lark", "Welcome, friend. We are the Concordant Family. We grow what we eat and keep no animals and drink no stimulants."],
			["lark", "...Which is why I must ask, quietly, whether you might bring a cup of Nell's coffee for Brother Abel. He is struggling. Spiritually. And in the mornings."],
		])
		Game.note("Brother Lark (Fruitvale) wants a coffee from Nell's for Brother Abel.")
		return
	if Game.has_item("coffee"):
		Game.remove_item("coffee")
		Game.setf("lark_done")
		await UI.talk([
			["lark", "Bless you. I shall tell Brother Abel it was left by an angel. A caffeinated angel."],
			["lark", "In return — we don't have much, but we have this. A page from our founder's hymnal. She wrote it on the shore of Bare Hill Pond."],
		])
		give("hymnal")
		await UI.talk([["lark", "We have sung it every October since 1843. For the twelve lights. Somebody ought to remember them."]])
		Game.note("Brother Lark gave you a hymnal page: 'The Water Keeps Its Own.'")
	else:
		await UI.say("lark", "No coffee yet? Brother Abel is staring at the pump again. He thinks it might start producing coffee if he believes hard enough.")


func ev_abel() -> void:
	var lines := [
		"The bees left the night the hum came back. Every one. They know something.",
		"We don't go down to the water after dark. Not in October. It's in the Rule.",
		"Is that... do you smell coffee? No. No, of course not. Forgive me.",
	]
	await UI.say("farmer", lines[randi() % lines.size()])


# ================================================================ OVERLAND LOOKS

func ev_look_fort_devlin() -> void:
	if Game.flag("lane_done") and not Game.flag("fd_fight"):
		Game.setf("fd_fight")
		await UI.say("coveralls", "Ma'am. Sir. Dog. This is a restricted area. I'm going to have to ask you to come with me.")
		await fight(["coveralls", "coveralls"])
