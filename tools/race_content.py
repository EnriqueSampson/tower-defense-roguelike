"""The four builder races: every tower's stats, upgrade tree and placeholder
model recipe. Read by tools/generate_races.py (writes the .tres resources)
and tools/blender/race_towers.py (writes the placeholder .glb models).

Units: cost in gold (an upgrade costs the target's cost), cooldown in
seconds, range / detection / splash in towers (1 tower = 2 tiles = 56 sim
pixels, the Wintermaul unit), slow as a fraction.

Tower IDs are wire-level identifiers: never rename one that has shipped.
bolt, cannon, frost and sentry predate races and keep their IDs.
"""

TOWER_PX = 56.0

# model: (archetype, options) consumed by tools/blender/race_towers.py.
# Existing models (bolt, cannon, frost, sentry) are listed with "keep".

RACES = [
    {
        "id": "humans",
        "name": "Humans",
        "color": (0.36, 0.56, 0.84),
        "builder": "builders/human_peasant.glb",
        "description": "Generalists. Reliable single-target damage that escalates from a guy with a sword to a streamer hurling insults. Detection: the Nosy Neighbor.",
        "roots": ["bolt", "sentry"],
    },
    {
        "id": "orcs",
        "name": "Orcs",
        "color": (0.45, 0.68, 0.3),
        "builder": "builders/orc_peon.glb",
        "description": "Splash and brute force. Junk cannons become war rigs; axe throwers end up riding giant lizards. Detection: the Sniffer Boar.",
        "roots": ["orc_axe", "cannon", "orc_boar"],
    },
    {
        "id": "elves",
        "name": "Elves",
        "color": (0.55, 0.85, 0.75),
        "builder": "builders/elf_wisp.glb",
        "description": "Range and control. Archers, hippogryph riders, water spirits that slow, and ancient ents. Detection: the Owl Post.",
        "roots": ["elf_archer", "frost", "elf_sapling"],
    },
    {
        "id": "bugs",
        "name": "Bugs",
        "color": (0.85, 0.62, 0.2),
        "builder": "builders/bug_grub.glb",
        "description": "Dirt-cheap towers built for mazing: a Worker Ant costs 5 gold. Low damage and no splash, until the Hive Queen. Detection: the Firefly.",
        "roots": ["bug_ant", "bug_beetle", "bug_firefly", "bug_mosquito"],
    },
]

# Default fields; each tower overrides what it needs.
DEFAULTS = {
    "splash": 0.0, "slow": 0.0, "slow_duration": 0.0, "pierce": 0, "ground": True, "air": True,
    "magic": False, "detection": 0.0, "options": [], "targeting": 0, "projectile_speed": 620.0,
}

TOWERS = [
    # --- Humans -----------------------------------------------------------
    dict(id="bolt", race="humans", tier=1, name="Guy With a Sword", role="Generalist",
         desc="A guy. A sword. A dream. Reliable single-target damage against anything, flying or not.",
         cost=25, damage=5, cooldown=0.65, range=5.0, options=["human_crossbow", "human_knight"],
         colors=((0.19, 0.37, 0.35), (0.89, 0.73, 0.31)), model=("keep", "towers/human_swordsman.glb")),
    dict(id="human_crossbow", race="humans", tier=2, name="Crossbow Enthusiast", role="Generalist",
         desc="Read one book about crossbows. Will tell you about it. Longer range, hits air.",
         cost=45, damage=16, cooldown=0.7, range=5.5, options=["human_musket"],
         colors=((0.3, 0.42, 0.3), (0.85, 0.7, 0.35)), model=("figure", {"weapon": "crossbow", "clothes": (0.3, 0.45, 0.3)})),
    dict(id="human_musket", race="humans", tier=3, name="Musketeer", role="Sniper",
         desc="One for all, all for this one very loud shot. Pierces armor.",
         cost=90, damage=40, cooldown=0.85, range=6.0, pierce=1, options=["human_streamer"],
         colors=((0.2, 0.25, 0.5), (0.95, 0.85, 0.4)), model=("figure", {"weapon": "musket", "clothes": (0.2, 0.25, 0.55), "hat": "wide"})),
    dict(id="human_streamer", race="humans", tier=4, name="Rage Streamer", role="Ultimate: magic splash",
         desc="Hurls insults at 300 words per minute to an audience of four. Magic damage that splashes; useless against magic immunity.",
         cost=220, damage=90, cooldown=0.9, range=6.0, splash=0.9, magic=True, projectile_speed=900.0,
         colors=((0.45, 0.2, 0.55), (0.95, 0.35, 0.8)), model=("streamer", {})),
    dict(id="human_knight", race="humans", tier=2, name="Knight on a Budget", role="Brawler",
         desc="The armor is cardboard; the enthusiasm is real. Short range, hits hard, pierces armor. Ground only.",
         cost=45, damage=30, cooldown=1.2, range=3.5, pierce=2, air=False, options=["human_minivan"],
         colors=((0.5, 0.5, 0.55), (0.9, 0.9, 0.95)), model=("figure", {"weapon": "lance", "clothes": (0.6, 0.6, 0.65), "hat": "helmet"})),
    dict(id="human_minivan", race="humans", tier=3, name="Minivan of Uncles", role="Rapid fire",
         desc="A car full of uncles with machine guns and opinions. Enormous fire rate at short range.",
         cost=110, damage=11, cooldown=0.18, range=4.5, projectile_speed=1100.0,
         colors=((0.6, 0.62, 0.66), (0.95, 0.8, 0.3)), model=("vehicle", {"body": (0.55, 0.6, 0.7), "guns": 3, "heads": 4})),
    dict(id="sentry", race="humans", tier=1, name="Nosy Neighbor", role="Detection",
         desc="A retiree with binoculars who sees everything. Reveals invisible creeps nearby so every tower can hit them.",
         cost=40, damage=3, cooldown=0.8, range=4.0, detection=6.0, projectile_speed=700.0, options=["human_watch"],
         colors=((0.55, 0.42, 0.3), (0.55, 0.85, 1.0)), model=("keep", "towers/human_nosy_neighbor.glb")),
    dict(id="human_watch", race="humans", tier=2, name="Neighborhood Watch", role="Detection",
         desc="Three neighbors, one flashlight, zero chill. Wider detection and a sharper tongue.",
         cost=60, damage=10, cooldown=0.7, range=4.5, detection=7.0, options=["human_hoa"],
         colors=((0.6, 0.45, 0.3), (0.95, 0.9, 0.4)), model=("figure", {"weapon": "flashlight", "clothes": (0.95, 0.75, 0.2), "hat": "cap"})),
    dict(id="human_hoa", race="humans", tier=3, name="HOA President", role="Detection and slow",
         desc="Issues fines. Creeps slow down to read them. Huge detection radius; magic slow.",
         cost=120, damage=22, cooldown=0.7, range=5.0, detection=8.0, slow=0.25, slow_duration=1.5, magic=True,
         colors=((0.7, 0.3, 0.4), (1.0, 0.9, 0.95)), model=("figure", {"weapon": "clipboard", "clothes": (0.75, 0.3, 0.45), "hat": "bun"})),
    # --- Orcs -------------------------------------------------------------
    dict(id="orc_axe", race="orcs", tier=1, name="Orc With an Axe", role="Brawler",
         desc="He throws the axe. Then he goes and gets the axe. Short range, hits air.",
         cost=20, damage=8, cooldown=1.0, range=3.5, options=["orc_raider"],
         colors=((0.35, 0.5, 0.25), (0.8, 0.8, 0.85)), model=("figure", {"weapon": "axe", "skin": (0.4, 0.6, 0.3), "clothes": (0.45, 0.3, 0.2)})),
    dict(id="orc_raider", race="orcs", tier=2, name="Axe Juggler", role="Brawler",
         desc="Now with three axes. Nobody asked where the other two came from.",
         cost=45, damage=18, cooldown=0.8, range=4.0, options=["orc_lizard"],
         colors=((0.4, 0.55, 0.25), (0.9, 0.5, 0.3)), model=("figure", {"weapon": "axes", "skin": (0.4, 0.6, 0.3), "clothes": (0.6, 0.25, 0.2)})),
    dict(id="orc_lizard", race="orcs", tier=3, name="Lizard Rider", role="Armor breaker",
         desc="An orc riding a giant lizard. The lizard does most of the work, including spitting at birds. Pierces armor.",
         cost=100, damage=40, cooldown=0.7, range=4.5, pierce=2, options=["orc_lizard_king"],
         colors=((0.3, 0.55, 0.35), (0.9, 0.75, 0.3)), model=("rider", {"mount": (0.3, 0.6, 0.35), "skin": (0.4, 0.6, 0.3)})),
    dict(id="orc_lizard_king", race="orcs", tier=4, name="Big Lizard Energy", role="Ultimate: armor breaker",
         desc="The lizard got promoted. The orc is now the lizard's rider, assistant and publicist. Pierces nearly all armor, hits air.",
         cost=200, damage=95, cooldown=0.6, range=5.0, pierce=4,
         colors=((0.2, 0.45, 0.3), (1.0, 0.8, 0.2)), model=("rider", {"mount": (0.2, 0.45, 0.3), "skin": (0.4, 0.6, 0.3), "crown": True, "size": 1.2})),
    dict(id="cannon", race="orcs", tier=1, name="Junk Cannon", role="Area damage",
         desc="Slow, heavy shells that splash packed creeps. Assembled from whatever was lying around. Cannot hit air.",
         cost=45, damage=12, cooldown=1.8, range=3.5, splash=0.75, pierce=1, air=False, targeting=2, projectile_speed=380.0, options=["orc_mortar"],
         colors=((0.36, 0.3, 0.24), (0.94, 0.53, 0.29)), model=("keep", "towers/orc_junk_cannon.glb")),
    dict(id="orc_mortar", race="orcs", tier=2, name="Scrap Mortar", role="Area damage",
         desc="Lobs a bucket of bolts in a high arc. Longer range, bigger splash. Ground only.",
         cost=70, damage=30, cooldown=2.0, range=5.0, splash=1.0, pierce=1, air=False, targeting=2, projectile_speed=360.0, options=["orc_wagon", "orc_flak"],
         colors=((0.4, 0.33, 0.26), (0.95, 0.6, 0.3)), model=("cannon", {"barrel": (0.35, 0.3, 0.28), "short": True})),
    dict(id="orc_wagon", race="orcs", tier=3, name="Battle Wagon", role="Area damage",
         desc="A makeshift car with guns bolted on. Also a cannon. Also a grill. Ground only.",
         cost=130, damage=55, cooldown=1.3, range=4.5, splash=0.9, pierce=2, air=False, targeting=2, projectile_speed=420.0, options=["orc_warrig"],
         colors=((0.45, 0.32, 0.22), (0.95, 0.45, 0.2)), model=("vehicle", {"body": (0.5, 0.35, 0.22), "guns": 2, "heads": 2, "cannon": True})),
    dict(id="orc_warrig", race="orcs", tier=4, name="War Rig", role="Ultimate: area damage",
         desc="Eighteen wheels, four cannons, no brakes. Enormous splash. Ground only.",
         cost=240, damage=120, cooldown=1.1, range=5.0, splash=1.15, pierce=3, air=False, targeting=2, projectile_speed=450.0,
         colors=((0.35, 0.25, 0.2), (1.0, 0.4, 0.15)), model=("vehicle", {"body": (0.4, 0.28, 0.2), "guns": 4, "heads": 3, "cannon": True, "size": 1.2})),
    dict(id="orc_flak", race="orcs", tier=3, name="Flak Goblin", role="Anti-air splash",
         desc="A goblin with a sky-cannon and a grudge against birds. Air only, with splash.",
         cost=110, damage=45, cooldown=0.9, range=6.0, splash=1.05, ground=False, projectile_speed=800.0,
         colors=((0.35, 0.45, 0.3), (0.9, 0.9, 0.5)), model=("cannon", {"barrel": (0.3, 0.35, 0.3), "skyward": True})),
    dict(id="orc_boar", race="orcs", tier=1, name="Sniffer Boar", role="Detection",
         desc="Trained to find truffles. Finds invisible creeps instead. Nobody corrected it.",
         cost=35, damage=4, cooldown=0.9, range=3.5, detection=6.0, options=["orc_warboar"],
         colors=((0.45, 0.3, 0.25), (0.9, 0.7, 0.6)), model=("beast", {"hide": (0.45, 0.32, 0.26), "tusks": True})),
    dict(id="orc_warboar", race="orcs", tier=2, name="Truffle Hog of War", role="Detection",
         desc="Armored, caffeinated, and very good at finding things that do not want to be found.",
         cost=70, damage=14, cooldown=0.8, range=4.0, detection=8.0,
         colors=((0.4, 0.28, 0.24), (0.8, 0.8, 0.85)), model=("beast", {"hide": (0.4, 0.3, 0.26), "tusks": True, "armor": True, "size": 1.15})),
    # --- Elves ------------------------------------------------------------
    dict(id="elf_archer", race="elves", tier=1, name="Elf Archer", role="Long range",
         desc="Never misses. Rarely hits hard. Long range, hits air.",
         cost=25, damage=4, cooldown=0.55, range=6.0, options=["elf_ranger", "elf_owl"],
         colors=((0.25, 0.45, 0.3), (0.75, 0.95, 0.7)), model=("figure", {"weapon": "bow", "skin": (0.95, 0.85, 0.75), "clothes": (0.25, 0.5, 0.3), "hat": "hood"})),
    dict(id="elf_ranger", race="elves", tier=2, name="Ranger", role="Long range",
         desc="Has walked every trail and reviewed each one. Faster, longer shots.",
         cost=50, damage=12, cooldown=0.5, range=6.5, options=["elf_hippogryph"],
         colors=((0.2, 0.4, 0.25), (0.85, 1.0, 0.75)), model=("figure", {"weapon": "bow", "skin": (0.95, 0.85, 0.75), "clothes": (0.2, 0.35, 0.22), "hat": "hood", "cape": True})),
    dict(id="elf_hippogryph", race="elves", tier=3, name="Hippogryph Rider", role="Long range",
         desc="Half horse, half eagle, fully judgmental. The longest bow range there is.",
         cost=110, damage=40, cooldown=0.45, range=7.0,
         colors=((0.75, 0.7, 0.6), (0.9, 1.0, 0.8)), model=("rider", {"mount": (0.8, 0.75, 0.65), "skin": (0.95, 0.85, 0.75), "wings": True})),
    dict(id="elf_owl", race="elves", tier=2, name="Owl Post", role="Detection",
         desc="Sees everything at night, delivers mail during the day. Reveals invisible creeps.",
         cost=50, damage=10, cooldown=0.6, range=6.0, detection=8.0,
         colors=((0.5, 0.4, 0.3), (1.0, 0.85, 0.4)), model=("owl", {})),
    dict(id="frost", race="elves", tier=1, name="Water Spirit", role="Control",
         desc="Low damage, but soaks creeps so they crawl through your maze. Magic: useless against magic-immune creeps.",
         cost=35, damage=2, cooldown=0.9, range=5.0, slow=0.3, slow_duration=2.0, magic=True, projectile_speed=700.0, options=["elf_tide"],
         colors=((0.22, 0.36, 0.5), (0.62, 0.9, 1.0)), model=("keep", "towers/elf_water_spirit.glb")),
    dict(id="elf_tide", race="elves", tier=2, name="Tide Caller", role="Control",
         desc="Summons the tide on command, which is inconvenient for everyone. Stronger magic slow.",
         cost=60, damage=6, cooldown=0.8, range=5.5, slow=0.4, slow_duration=2.5, magic=True, projectile_speed=700.0, options=["elf_water_elemental"],
         colors=((0.2, 0.35, 0.55), (0.5, 0.85, 1.0)), model=("water", {"size": 1.0})),
    dict(id="elf_water_elemental", race="elves", tier=3, name="Water Elemental", role="Ultimate: area slow",
         desc="A lake with ambitions. Its magic splash slows everything it touches.",
         cost=130, damage=20, cooldown=1.0, range=5.5, splash=0.85, slow=0.45, slow_duration=2.5, magic=True, projectile_speed=700.0,
         colors=((0.15, 0.3, 0.6), (0.45, 0.8, 1.0)), model=("water", {"size": 1.3})),
    dict(id="elf_sapling", race="elves", tier=1, name="Sapling", role="Cheap blocker",
         desc="A small, angry tree. Cheap to plant for mazing. Ground only.",
         cost=15, damage=3, cooldown=1.0, range=3.0, air=False, options=["elf_treant"],
         colors=((0.35, 0.5, 0.25), (0.6, 0.85, 0.35)), model=("tree", {"size": 0.7})),
    dict(id="elf_treant", race="elves", tier=2, name="Treant", role="Brawler",
         desc="Slow to anger, slower to walk, very fast to punch. Pierces armor; ground only.",
         cost=60, damage=22, cooldown=1.2, range=3.5, pierce=2, air=False, options=["elf_ent"],
         colors=((0.35, 0.3, 0.2), (0.5, 0.8, 0.3)), model=("tree", {"size": 1.0, "face": True})),
    dict(id="elf_ent", race="elves", tier=3, name="Ancient Ent", role="Armor breaker",
         desc="Remembers when this map was a forest. Holds a grudge about it. Crushes armor and hurls boulders at anything that flies.",
         cost=150, damage=110, cooldown=1.5, range=4.0, pierce=5,
         colors=((0.3, 0.25, 0.18), (0.4, 0.75, 0.3)), model=("tree", {"size": 1.35, "face": True})),
    # --- Bugs -------------------------------------------------------------
    dict(id="bug_ant", race="bugs", tier=1, name="Worker Ant", role="Maze filler",
         desc="Five gold. Carries fifty times its body weight. Hits like it weighs nothing. Perfect for mazing.",
         cost=5, damage=1, cooldown=1.0, range=3.0, options=["bug_soldier_ant"],
         colors=((0.45, 0.25, 0.15), (0.8, 0.45, 0.25)), model=("bug", {"shell": (0.45, 0.2, 0.12), "size": 0.6})),
    dict(id="bug_soldier_ant", race="bugs", tier=2, name="Soldier Ant", role="Maze filler",
         desc="Same ant, bigger mandibles, worse attitude.",
         cost=20, damage=5, cooldown=0.8, range=3.5, options=["bug_army_ant"],
         colors=((0.5, 0.2, 0.12), (0.9, 0.4, 0.2)), model=("bug", {"shell": (0.55, 0.18, 0.1), "size": 0.8, "mandibles": True})),
    dict(id="bug_army_ant", race="bugs", tier=3, name="Army Ant Platoon", role="Generalist",
         desc="Two hundred ants in a trench coat. Steady single-target damage.",
         cost=60, damage=16, cooldown=0.6, range=4.0, options=["bug_queen"],
         colors=((0.4, 0.15, 0.1), (0.95, 0.5, 0.25)), model=("bug", {"shell": (0.4, 0.14, 0.08), "size": 1.0, "mandibles": True, "swarm": True})),
    dict(id="bug_queen", race="bugs", tier=4, name="The Hive Queen", role="Ultimate: splash",
         desc="Every bug answers to her. She answers to no one. The only Bug tower that splashes.",
         cost=250, damage=60, cooldown=1.0, range=5.0, splash=1.05, projectile_speed=700.0,
         colors=((0.55, 0.3, 0.45), (1.0, 0.75, 0.3)), model=("bug", {"shell": (0.55, 0.3, 0.5), "size": 1.35, "crown": True, "wings": True})),
    dict(id="bug_beetle", race="bugs", tier=1, name="Dung Beetle", role="Armor breaker",
         desc="Rolls its ball at the problem. Cheap, pierces a little armor. Ground only.",
         cost=10, damage=3, cooldown=1.2, range=3.0, pierce=1, air=False, options=["bug_stag"],
         colors=((0.2, 0.25, 0.3), (0.6, 0.45, 0.3)), model=("bug", {"shell": (0.15, 0.2, 0.28), "size": 0.7, "ball": True})),
    dict(id="bug_stag", race="bugs", tier=2, name="Stag Beetle", role="Armor breaker",
         desc="Antlers for jaws. Pierces armor. Ground only.",
         cost=30, damage=12, cooldown=1.1, range=3.5, pierce=2, air=False, options=["bug_rhino"],
         colors=((0.3, 0.2, 0.15), (0.75, 0.55, 0.35)), model=("bug", {"shell": (0.3, 0.18, 0.12), "size": 0.9, "antlers": True})),
    dict(id="bug_rhino", race="bugs", tier=3, name="Rhino Beetle", role="Armor breaker",
         desc="Lifts 850 times its own weight; chooses violence. Heavy armor-piercing hits. Ground only.",
         cost=80, damage=40, cooldown=1.1, range=4.0, pierce=4, air=False,
         colors=((0.25, 0.2, 0.18), (0.9, 0.7, 0.4)), model=("bug", {"shell": (0.22, 0.18, 0.16), "size": 1.15, "horn": True})),
    dict(id="bug_firefly", race="bugs", tier=1, name="Firefly", role="Detection",
         desc="Glows. That is the whole plan. Reveals invisible creeps.",
         cost=12, damage=1, cooldown=1.0, range=3.0, detection=5.0, options=["bug_lantern"],
         colors=((0.3, 0.3, 0.2), (1.0, 0.95, 0.4)), model=("bug", {"shell": (0.25, 0.25, 0.18), "size": 0.6, "glow": True, "wings": True})),
    dict(id="bug_lantern", race="bugs", tier=2, name="Lantern Bug", role="Detection",
         desc="A firefly that got into management. Brighter, wider detection.",
         cost=40, damage=5, cooldown=0.8, range=4.0, detection=7.0,
         colors=((0.35, 0.3, 0.2), (1.0, 0.85, 0.3)), model=("bug", {"shell": (0.3, 0.25, 0.15), "size": 0.85, "glow": True, "wings": True})),
    dict(id="bug_mosquito", race="bugs", tier=1, name="Mosquito", role="Control",
         desc="Bites. Itches. Creeps stop to scratch. A weak magic slow for ten gold.",
         cost=10, damage=1, cooldown=0.8, range=4.0, slow=0.2, slow_duration=1.5, magic=True, options=["bug_horsefly"],
         colors=((0.35, 0.35, 0.4), (0.9, 0.3, 0.3)), model=("bug", {"shell": (0.35, 0.35, 0.4), "size": 0.55, "wings": True, "proboscis": True})),
    dict(id="bug_horsefly", race="bugs", tier=2, name="Horsefly", role="Control",
         desc="The mosquito's big cousin who does CrossFit. Stronger magic slow.",
         cost=35, damage=5, cooldown=0.7, range=4.5, slow=0.3, slow_duration=2.0, magic=True,
         colors=((0.3, 0.35, 0.3), (0.8, 0.9, 0.3)), model=("bug", {"shell": (0.3, 0.38, 0.28), "size": 0.8, "wings": True, "proboscis": True})),
]

BUILDERS = [
    ("orc_peon", "peon"),
    ("elf_wisp", "wisp"),
    ("bug_grub", "grub"),
]


def tower(tower_id):
    for spec in TOWERS:
        if spec["id"] == tower_id:
            merged = dict(DEFAULTS)
            merged.update(spec)
            return merged
    raise KeyError(tower_id)


def model_path(spec):
    """assets/models-relative path of a tower's model."""
    kind, options = spec["model"]
    if kind == "keep":
        return options
    return "towers/%s.glb" % spec["id"]
