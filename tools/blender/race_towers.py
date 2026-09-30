"""Placeholders: every race tower that has no model yet, plus the orc, elf
and bug builders. Recipes come from tools/race_content.py (the "model" entry
of each tower), so adding a tower there and rerunning this script is enough.

    python tools/blender/race_towers.py            (bpy 4.5 module)
    Blender -b --python tools/blender/race_towers.py

Conventions (docs/ROADMAP.md, asset spec): 1 unit = 1 tile, towers fit a
2x2 square with the pivot at the base centre, front faces -Y, everything
that aims sits under "Turret", and the actions are idle / attack (towers) or
idle / walk / build / trip (builders). Larger tiers are drawn bigger.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import placeholder_common as pc  # noqa: E402
import race_content  # noqa: E402

SKIN = (0.88, 0.68, 0.55)


def base(root, tier, color=(0.33, 0.34, 0.33)):
    """Stone base; higher tiers get a taller plinth."""
    mat = pc.material("Base", color)
    pc.part("cube", "Base", mat, root, (0, 0, 0.08 + 0.02 * tier), scale=(0.9, 0.9, 0.08 + 0.02 * tier))


def swing(pivot, rest, strike, idle_drift=(-5, 0, 0)):
    """idle sways around `rest`; attack snaps to `strike` and back."""
    pc.keyframe_action(pivot, "idle", "rotation_euler", [
        (0.0, pc.radians(*rest)),
        (0.8, pc.radians(rest[0] + idle_drift[0], rest[1] + idle_drift[1], rest[2] + idle_drift[2])),
        (1.6, pc.radians(*rest)),
    ])
    pc.keyframe_action(pivot, "attack", "rotation_euler", [
        (0.0, pc.radians(*rest)),
        (0.08, pc.radians(*strike)),
        (0.35, pc.radians(*rest)),
    ])
    pivot.rotation_euler = pc.radians(*rest)


def recoil(pivot, rest=(0.0, 0.0, 0.0), back=0.12):
    """idle bobs; attack kicks the part back along +Y (away from the front)."""
    x, y, z = rest
    pc.keyframe_action(pivot, "idle", "location", [(0.0, rest), (1.0, (x, y, z + 0.02)), (2.0, rest)])
    pc.keyframe_action(pivot, "attack", "location", [(0.0, rest), (0.06, (x, y + back, z)), (0.3, rest)])
    pivot.location = rest


def figure(spec, opts, s):
    tier = spec["tier"]
    root = pc.empty(spec["id"])
    base(root, tier)
    skin = pc.material("Skin", opts.get("skin", SKIN))
    clothes = pc.material("Clothes", opts.get("clothes", (0.3, 0.4, 0.6)))
    accent = pc.material("Accent", spec["colors"][1])
    dark = pc.material("Dark", (0.2, 0.18, 0.16))
    turret = pc.empty("Turret", root, (0, 0, 0.2 + 0.02 * tier))
    pc.part("cylinder", "Legs", dark, turret, (0, 0, 0.22 * s), scale=(0.2 * s, 0.2 * s, 0.22 * s), vertices=8)
    pc.part("cylinder", "Torso", clothes, turret, (0, 0, 0.62 * s), scale=(0.28 * s, 0.24 * s, 0.22 * s), vertices=8)
    pc.part("sphere", "Head", skin, turret, (0, 0, 1.02 * s), scale=(0.18 * s, 0.18 * s, 0.18 * s), segments=10, ring_count=6)
    hat = opts.get("hat")
    if hat == "wide":
        pc.part("cylinder", "Hat", dark, turret, (0, 0, 1.18 * s), scale=(0.3 * s, 0.3 * s, 0.03 * s), vertices=12)
        pc.part("cylinder", "HatTop", dark, turret, (0, 0, 1.26 * s), scale=(0.14 * s, 0.14 * s, 0.08 * s), vertices=10)
    elif hat == "helmet":
        pc.part("sphere", "Helmet", accent, turret, (0, 0, 1.08 * s), scale=(0.2 * s, 0.2 * s, 0.15 * s), segments=10, ring_count=6)
    elif hat == "cap":
        pc.part("cylinder", "Cap", accent, turret, (0, -0.04 * s, 1.14 * s), scale=(0.19 * s, 0.19 * s, 0.05 * s), vertices=10)
    elif hat == "hood":
        pc.part("sphere", "Hood", clothes, turret, (0, 0.03 * s, 1.07 * s), scale=(0.21 * s, 0.21 * s, 0.19 * s), segments=10, ring_count=6)
    elif hat == "mask":
        pc.part("cube", "Mask", pc.material("Mask", (0.9, 0.85, 0.7)), turret, (0, -0.16 * s, 1.03 * s), scale=(0.15 * s, 0.03 * s, 0.18 * s))
        pc.part("cube", "Feather", accent, turret, (0, 0, 1.28 * s), scale=(0.02 * s, 0.02 * s, 0.1 * s))
    elif hat == "bun":
        pc.part("sphere", "Bun", pc.material("Hair", (0.9, 0.9, 0.92)), turret, (0, 0.06 * s, 1.2 * s), scale=(0.1 * s, 0.1 * s, 0.1 * s), segments=8, ring_count=5)
    if opts.get("cape"):
        pc.part("cube", "Cape", accent, turret, (0, 0.22 * s, 0.6 * s), scale=(0.26 * s, 0.02 * s, 0.3 * s))
    arm = pc.empty("Arm", turret, (0.3 * s, 0, 0.8 * s))
    pc.part("cylinder", "ArmR", skin, arm, (0, 0, -0.15 * s), scale=(0.06 * s, 0.06 * s, 0.17 * s), vertices=6)
    weapon = opts.get("weapon")
    steel = pc.material("Steel", (0.75, 0.77, 0.8), roughness=0.35)
    wood = pc.material("Wood", (0.4, 0.26, 0.14))
    if weapon == "crossbow":
        pc.part("cube", "Stock", wood, arm, (0, -0.2 * s, -0.25 * s), scale=(0.04 * s, 0.22 * s, 0.04 * s))
        pc.part("cube", "Bow", steel, arm, (0, -0.38 * s, -0.25 * s), scale=(0.22 * s, 0.02 * s, 0.02 * s))
        swing(arm, (0, 0, 0), (-12, 0, 0))
    elif weapon == "musket":
        pc.part("cylinder", "Barrel", steel, arm, (0, -0.35 * s, -0.25 * s), scale=(0.03 * s, 0.03 * s, 0.35 * s), rotation=pc.radians(90, 0, 0), vertices=6)
        swing(arm, (0, 0, 0), (-20, 0, 0))
    elif weapon == "lance":
        pc.part("cylinder", "Lance", steel, arm, (0, -0.4 * s, -0.2 * s), scale=(0.035 * s, 0.035 * s, 0.45 * s), rotation=pc.radians(80, 0, 0), vertices=6)
        swing(arm, (-10, 0, 0), (40, 0, 0))
    elif weapon == "flashlight":
        pc.part("cylinder", "Torch", dark, arm, (0, -0.15 * s, -0.3 * s), scale=(0.04 * s, 0.04 * s, 0.1 * s), rotation=pc.radians(90, 0, 0), vertices=6)
        pc.part("cylinder", "Beam", pc.material("Light", (1.0, 0.95, 0.6), emission=0.8), arm, (0, -0.26 * s, -0.3 * s), scale=(0.05 * s, 0.05 * s, 0.01 * s), rotation=pc.radians(90, 0, 0), vertices=8)
        swing(arm, (0, 0, 0), (-25, 0, 0))
    elif weapon == "clipboard":
        pc.part("cube", "Clipboard", pc.material("Paper", (0.95, 0.94, 0.88)), arm, (0, -0.1 * s, -0.3 * s), scale=(0.12 * s, 0.01 * s, 0.16 * s))
        swing(arm, (0, 0, 0), (-60, 0, 0))
    elif weapon == "staff":
        pc.part("cylinder", "Staff", wood, arm, (0, -0.05 * s, -0.1 * s), scale=(0.025 * s, 0.025 * s, 0.4 * s), vertices=6)
        pc.part("sphere", "Orb", pc.material("Orb", spec["colors"][1], emission=0.8), arm, (0, -0.05 * s, 0.32 * s), scale=(0.07 * s, 0.07 * s, 0.07 * s), segments=8, ring_count=5)
        swing(arm, (0, 0, 0), (-45, 0, 0))
    elif weapon in ("axe", "axes"):
        count = 3 if weapon == "axes" else 1
        for index in range(count):
            offset = (index - (count - 1) / 2.0) * 0.12 * s
            pc.part("cylinder", "Haft%d" % index, wood, arm, (offset, -0.05 * s, -0.25 * s), scale=(0.025 * s, 0.025 * s, 0.22 * s), vertices=6)
            pc.part("cube", "Blade%d" % index, steel, arm, (offset, -0.12 * s, -0.08 * s), scale=(0.02 * s, 0.1 * s, 0.08 * s))
        swing(arm, (-20, 0, 0), (-110, 0, 0))
    elif weapon == "bow":
        pc.part("cube", "Bow", wood, arm, (0, -0.15 * s, -0.25 * s), scale=(0.02 * s, 0.02 * s, 0.34 * s))
        pc.part("cube", "String", pc.material("String", (0.95, 0.95, 0.9)), arm, (0, -0.1 * s, -0.25 * s), scale=(0.005 * s, 0.005 * s, 0.32 * s))
        swing(arm, (0, 0, 0), (-12, 0, 0))
    else:
        swing(arm, (0, 0, 0), (-30, 0, 0))
    return root


def streamer(spec, opts, s):
    root = pc.empty(spec["id"])
    base(root, spec["tier"], (0.25, 0.22, 0.3))
    skin = pc.material("Skin", SKIN)
    hoodie = pc.material("Hoodie", (0.45, 0.2, 0.55))
    desk = pc.material("Desk", (0.15, 0.15, 0.18))
    rgb = pc.material("RGB", (0.95, 0.35, 0.85), emission=0.9)
    screen = pc.material("Screen", (0.4, 0.8, 1.0), emission=0.8)
    turret = pc.empty("Turret", root, (0, 0, 0.3))
    pc.part("cube", "Desk", desk, turret, (0, -0.3, 0.4), scale=(0.6, 0.25, 0.04))
    pc.part("cube", "Monitor", desk, turret, (0, -0.45, 0.7), scale=(0.35, 0.03, 0.22))
    pc.part("cube", "Screen", screen, turret, (0, -0.42, 0.7), scale=(0.31, 0.01, 0.18))
    pc.part("cube", "LightStrip", rgb, turret, (0, -0.3, 0.36), scale=(0.6, 0.26, 0.01))
    pc.part("cylinder", "Chair", rgb, turret, (0, 0.25, 0.55), scale=(0.3, 0.06, 0.35), rotation=pc.radians(90, 0, 0), vertices=10)
    head = pc.empty("Head", turret, (0, 0.05, 0.95))
    pc.part("cylinder", "Body", hoodie, turret, (0, 0.05, 0.62), scale=(0.24, 0.2, 0.22), vertices=8)
    pc.part("sphere", "Face", skin, head, (0, 0, 0), scale=(0.17, 0.17, 0.17), segments=10, ring_count=6)
    pc.part("cylinder", "Headset", desk, head, (0, 0, 0.05), scale=(0.2, 0.03, 0.03), rotation=pc.radians(0, 90, 0), vertices=8)
    pc.part("sphere", "Mic", rgb, head, (0.1, -0.15, -0.08), scale=(0.04, 0.04, 0.04), segments=6, ring_count=4)
    # Attack: leans into the mic and yells.
    swing(head, (0, 0, 0), (-30, 0, 0), idle_drift=(0, 0, 8))
    return root


def vehicle(spec, opts, s):
    s *= opts.get("size", 1.0)
    root = pc.empty(spec["id"])
    base(root, spec["tier"], (0.3, 0.3, 0.3))
    body = pc.material("Paint", opts.get("body", (0.5, 0.5, 0.55)))
    tire = pc.material("Tire", (0.1, 0.1, 0.1))
    glass = pc.material("Glass", (0.5, 0.7, 0.85), roughness=0.2)
    steel = pc.material("Gun", (0.25, 0.25, 0.28), roughness=0.4)
    skin = pc.material("Skin", SKIN)
    turret = pc.empty("Turret", root, (0, 0, 0.25))
    pc.part("cube", "Chassis", body, turret, (0, 0, 0.25 * s), scale=(0.42 * s, 0.7 * s, 0.18 * s))
    pc.part("cube", "Cabin", glass, turret, (0, 0.05 * s, 0.5 * s), scale=(0.36 * s, 0.4 * s, 0.1 * s))
    for x in (-0.44, 0.44):
        for y in (-0.45, 0.45):
            pc.part("cylinder", "Wheel", tire, turret, (x * s, y * s, 0.12 * s), scale=(0.12 * s, 0.12 * s, 0.05 * s), rotation=pc.radians(0, 90, 0), vertices=10)
    heads = opts.get("heads", 2)
    for index in range(heads):
        pc.part("sphere", "Head%d" % index, skin, turret, ((index - (heads - 1) / 2.0) * 0.18 * s, 0.05 * s, 0.68 * s), scale=(0.08 * s, 0.08 * s, 0.08 * s), segments=8, ring_count=5)
    guns = pc.empty("Guns", turret, (0, -0.2 * s, 0.62 * s))
    count = opts.get("guns", 2)
    for index in range(count):
        pc.part("cylinder", "Barrel%d" % index, steel, guns, ((index - (count - 1) / 2.0) * 0.16 * s, -0.25 * s, 0), scale=(0.03 * s, 0.03 * s, 0.25 * s), rotation=pc.radians(90, 0, 0), vertices=6)
    if opts.get("cannon"):
        pc.part("cylinder", "Cannon", steel, guns, (0, -0.1 * s, 0.12 * s), scale=(0.08 * s, 0.08 * s, 0.3 * s), rotation=pc.radians(80, 0, 0), vertices=8)
    recoil(guns, (0, -0.2 * s, 0.62 * s), 0.08 * s)
    return root


def rider(spec, opts, s):
    s *= opts.get("size", 1.0)
    root = pc.empty(spec["id"])
    base(root, spec["tier"])
    mount = pc.material("Mount", opts.get("mount", (0.3, 0.6, 0.35)))
    skin = pc.material("Skin", opts.get("skin", SKIN))
    gold = pc.material("Gold", (1.0, 0.8, 0.25), roughness=0.3)
    steel = pc.material("Steel", (0.75, 0.77, 0.8), roughness=0.35)
    turret = pc.empty("Turret", root, (0, 0, 0.25))
    pc.part("sphere", "MountBody", mount, turret, (0, 0.05 * s, 0.35 * s), scale=(0.28 * s, 0.55 * s, 0.22 * s), segments=12, ring_count=8)
    pc.part("sphere", "MountHead", mount, turret, (0, -0.55 * s, 0.45 * s), scale=(0.16 * s, 0.22 * s, 0.14 * s), segments=10, ring_count=6)
    pc.part("cylinder", "Tail", mount, turret, (0, 0.6 * s, 0.3 * s), scale=(0.06 * s, 0.06 * s, 0.25 * s), rotation=pc.radians(70, 0, 0), vertices=6)
    for x in (-0.22, 0.22):
        for y in (-0.3, 0.35):
            pc.part("cylinder", "Leg", mount, turret, (x * s, y * s, 0.12 * s), scale=(0.06 * s, 0.06 * s, 0.12 * s), vertices=6)
    if opts.get("wings"):
        pc.part("cube", "WingL", pc.material("Feathers", (0.95, 0.95, 0.9)), turret, (-0.45 * s, 0.05 * s, 0.6 * s), scale=(0.3 * s, 0.25 * s, 0.02 * s), rotation=pc.radians(0, 25, 0))
        pc.part("cube", "WingR", pc.material("Feathers", (0.95, 0.95, 0.9)), turret, (0.45 * s, 0.05 * s, 0.6 * s), scale=(0.3 * s, 0.25 * s, 0.02 * s), rotation=pc.radians(0, -25, 0))
    pc.part("cylinder", "Rider", pc.material("Armor", spec["colors"][0]), turret, (0, 0.05 * s, 0.7 * s), scale=(0.14 * s, 0.12 * s, 0.16 * s), vertices=8)
    pc.part("sphere", "RiderHead", skin, turret, (0, 0.05 * s, 0.95 * s), scale=(0.11 * s, 0.11 * s, 0.11 * s), segments=8, ring_count=5)
    if opts.get("crown"):
        pc.part("cylinder", "Crown", gold, turret, (0, -0.55 * s, 0.62 * s), scale=(0.1 * s, 0.1 * s, 0.05 * s), vertices=6)
    arm = pc.empty("Arm", turret, (0.16 * s, 0.05 * s, 0.8 * s))
    pc.part("cylinder", "Spear", steel, arm, (0, -0.3 * s, 0), scale=(0.025 * s, 0.025 * s, 0.35 * s), rotation=pc.radians(80, 0, 0), vertices=6)
    swing(arm, (0, 0, 0), (35, 0, 0))
    return root


def cannon(spec, opts, s):
    root = pc.empty(spec["id"])
    base(root, spec["tier"], (0.36, 0.3, 0.24))
    barrel_mat = pc.material("Barrel", opts.get("barrel", (0.3, 0.3, 0.3)), roughness=0.45)
    wood = pc.material("Wood", (0.4, 0.26, 0.14))
    accent = pc.material("Accent", spec["colors"][1])
    turret = pc.empty("Turret", root, (0, 0, 0.3))
    pc.part("cube", "Mount", wood, turret, (0, 0, 0.18), scale=(0.35, 0.35, 0.14))
    barrel = pc.empty("BarrelPivot", turret, (0, 0, 0.42))
    tilt = 60 if opts.get("skyward") else (35 if opts.get("short") else 10)
    length = 0.3 if opts.get("short") else 0.45
    pc.part("cylinder", "Barrel", barrel_mat, barrel, (0, -length * 0.8, 0), scale=(0.14 * s, 0.14 * s, length * s), rotation=pc.radians(90 - tilt, 0, 0), vertices=10)
    pc.part("cylinder", "Band", accent, barrel, (0, -length * 1.2, 0.1), scale=(0.16 * s, 0.16 * s, 0.03 * s), rotation=pc.radians(90 - tilt, 0, 0), vertices=10)
    if opts.get("skyward"):
        pc.part("sphere", "Goblin", pc.material("Goblin", (0.4, 0.6, 0.3)), turret, (0.3, 0.2, 0.5), scale=(0.12, 0.12, 0.12), segments=8, ring_count=5)
    recoil(barrel, (0, 0, 0.42), 0.12)
    return root


def beast(spec, opts, s):
    s *= opts.get("size", 1.0)
    root = pc.empty(spec["id"])
    base(root, spec["tier"], (0.35, 0.3, 0.22))
    hide = pc.material("Hide", opts.get("hide", (0.45, 0.32, 0.26)))
    bone = pc.material("Tusk", (0.95, 0.92, 0.85))
    plate = pc.material("Plate", (0.5, 0.5, 0.55), roughness=0.4)
    turret = pc.empty("Turret", root, (0, 0, 0.25))
    pc.part("sphere", "Body", hide, turret, (0, 0.1 * s, 0.35 * s), scale=(0.3 * s, 0.45 * s, 0.26 * s), segments=12, ring_count=8)
    for x in (-0.18, 0.18):
        for y in (-0.2, 0.35):
            pc.part("cylinder", "Leg", hide, turret, (x * s, y * s, 0.1 * s), scale=(0.06 * s, 0.06 * s, 0.1 * s), vertices=6)
    head = pc.empty("Head", turret, (0, -0.35 * s, 0.4 * s))
    pc.part("sphere", "Snout", hide, head, (0, -0.1 * s, 0), scale=(0.18 * s, 0.22 * s, 0.16 * s), segments=10, ring_count=6)
    pc.part("cylinder", "Nose", pc.material("Nose", (0.85, 0.55, 0.55)), head, (0, -0.3 * s, 0), scale=(0.08 * s, 0.08 * s, 0.03 * s), rotation=pc.radians(90, 0, 0), vertices=8)
    if opts.get("tusks"):
        pc.part("cylinder", "TuskL", bone, head, (-0.1 * s, -0.25 * s, -0.06 * s), scale=(0.02 * s, 0.02 * s, 0.08 * s), rotation=pc.radians(-40, 0, 0), vertices=5)
        pc.part("cylinder", "TuskR", bone, head, (0.1 * s, -0.25 * s, -0.06 * s), scale=(0.02 * s, 0.02 * s, 0.08 * s), rotation=pc.radians(-40, 0, 0), vertices=5)
    if opts.get("armor"):
        pc.part("cube", "Saddle", plate, turret, (0, 0.1 * s, 0.6 * s), scale=(0.26 * s, 0.3 * s, 0.05 * s))
    # Sniffing: the head dips on idle and lunges on attack.
    swing(head, (0, 0, 0), (-25, 0, 0), idle_drift=(12, 0, 0))
    return root


def owl(spec, opts, s):
    root = pc.empty(spec["id"])
    base(root, spec["tier"], (0.35, 0.3, 0.22))
    wood = pc.material("Post", (0.4, 0.28, 0.16))
    feathers = pc.material("Feathers", (0.55, 0.42, 0.3))
    face = pc.material("Face", (0.9, 0.85, 0.75))
    eyes = pc.material("Eyes", (1.0, 0.85, 0.3), emission=0.7)
    paper = pc.material("Letter", (0.95, 0.94, 0.88))
    pc.part("cylinder", "Post", wood, root, (0, 0, 0.45), scale=(0.08, 0.08, 0.4), vertices=8)
    pc.part("cube", "Mailbox", wood, root, (0, 0.2, 0.55), scale=(0.15, 0.1, 0.1))
    turret = pc.empty("Turret", root, (0, 0, 0.85))
    pc.part("sphere", "Body", feathers, turret, (0, 0, 0.2), scale=(0.22, 0.2, 0.26), segments=10, ring_count=6)
    head = pc.empty("Head", turret, (0, 0, 0.5))
    pc.part("sphere", "HeadBall", feathers, head, (0, 0, 0), scale=(0.2, 0.18, 0.16), segments=10, ring_count=6)
    pc.part("cylinder", "Disc", face, head, (0, -0.14, 0), scale=(0.16, 0.16, 0.02), rotation=pc.radians(90, 0, 0), vertices=10)
    pc.part("sphere", "EyeL", eyes, head, (-0.07, -0.16, 0.02), scale=(0.05, 0.03, 0.05), segments=8, ring_count=5)
    pc.part("sphere", "EyeR", eyes, head, (0.07, -0.16, 0.02), scale=(0.05, 0.03, 0.05), segments=8, ring_count=5)
    pc.part("cube", "Letter", paper, turret, (0, -0.2, 0.05), scale=(0.08, 0.01, 0.05))
    swing(head, (0, 0, 0), (-15, 0, 0), idle_drift=(0, 0, 25))
    return root


def water(spec, opts, s):
    s *= opts.get("size", 1.0)
    root = pc.empty(spec["id"])
    base(root, spec["tier"], (0.25, 0.3, 0.35))
    pool = pc.material("Pool", (0.2, 0.4, 0.65), roughness=0.15)
    spirit = pc.material("Spirit", (0.45, 0.8, 1.0), roughness=0.1, emission=0.4)
    pc.part("cylinder", "Pool", pool, root, (0, 0, 0.2), scale=(0.6, 0.6, 0.05), vertices=16)
    turret = pc.empty("Turret", root, (0, 0, 0.25))
    body = pc.empty("Body", turret, (0, 0, 0))
    pc.part("cylinder", "Column", spirit, body, (0, 0, 0.35 * s), scale=(0.2 * s, 0.2 * s, 0.35 * s), vertices=12)
    pc.part("sphere", "Head", spirit, body, (0, 0, 0.82 * s), scale=(0.22 * s, 0.22 * s, 0.2 * s), segments=12, ring_count=8)
    pc.part("sphere", "ArmL", spirit, body, (-0.3 * s, -0.05 * s, 0.55 * s), scale=(0.1 * s, 0.1 * s, 0.14 * s), segments=8, ring_count=5)
    pc.part("sphere", "ArmR", spirit, body, (0.3 * s, -0.05 * s, 0.55 * s), scale=(0.1 * s, 0.1 * s, 0.14 * s), segments=8, ring_count=5)
    if opts.get("tentacles"):
        for index in range(4):
            angle = index * 90 + 45
            tentacle = pc.material("Tentacle", spec["colors"][1])
            pc.part("cylinder", "Tentacle%d" % index, tentacle, body, (0.3 * s * (1 if angle < 180 else -1) * (1 if index % 2 == 0 else 0.6), 0.3 * s * (1 if index in (1, 2) else -1), 0.3 * s), scale=(0.05 * s, 0.05 * s, 0.3 * s), rotation=pc.radians(30 * (1 if index % 2 else -1), 25, 0), vertices=6)
    swing(body, (0, 0, 0), (-18, 0, 0), idle_drift=(0, 0, 10))
    return root


def drone(spec, opts, s):
    root = pc.empty(spec["id"])
    base(root, spec["tier"], (0.3, 0.3, 0.32))
    shell = pc.material("Shell", spec["colors"][0], roughness=0.4)
    lens = pc.material("Lens", spec["colors"][1], emission=0.8)
    dark = pc.material("Rotor", (0.1, 0.1, 0.12))
    pc.part("cylinder", "Mast", dark, root, (0, 0, 0.45), scale=(0.04, 0.04, 0.3), vertices=6)
    turret = pc.empty("Turret", root, (0, 0, 0.9))
    body = pc.empty("Body", turret, (0, 0, 0))
    pc.part("cube", "Hull", shell, body, (0, 0, 0), scale=(0.22, 0.22, 0.07))
    pc.part("sphere", "Camera", lens, body, (0, -0.22, -0.02), scale=(0.07, 0.05, 0.07), segments=8, ring_count=5)
    for x in (-0.3, 0.3):
        for y in (-0.3, 0.3):
            pc.part("cylinder", "Rotor", dark, body, (x, y, 0.06), scale=(0.14, 0.14, 0.01), vertices=10)
    pc.keyframe_action(body, "idle", "location", [(0.0, (0, 0, 0)), (0.6, (0, 0, 0.08)), (1.2, (0, 0, 0))])
    pc.keyframe_action(body, "attack", "location", [(0.0, (0, 0, 0)), (0.06, (0, 0.08, 0)), (0.3, (0, 0, 0))])
    return root


def dish(spec, opts, s):
    root = pc.empty(spec["id"])
    base(root, spec["tier"], (0.3, 0.32, 0.38))
    metal = pc.material("Metal", (0.75, 0.78, 0.82), roughness=0.3)
    panel = pc.material("Panel", (0.2, 0.3, 0.6), roughness=0.2)
    beam = pc.material("Beam", spec["colors"][1], emission=0.9)
    pc.part("cylinder", "Pillar", metal, root, (0, 0, 0.45), scale=(0.12, 0.12, 0.35), vertices=10)
    pc.part("cube", "PanelL", panel, root, (-0.55, 0.3, 0.45), scale=(0.25, 0.12, 0.01), rotation=pc.radians(30, 0, 0))
    pc.part("cube", "PanelR", panel, root, (0.55, 0.3, 0.45), scale=(0.25, 0.12, 0.01), rotation=pc.radians(30, 0, 0))
    turret = pc.empty("Turret", root, (0, 0, 0.85))
    dish_pivot = pc.empty("Dish", turret, (0, 0, 0.1))
    pc.part("sphere", "Bowl", metal, dish_pivot, (0, -0.1, 0.2), scale=(0.5, 0.18, 0.5), segments=14, ring_count=8)
    pc.part("cylinder", "Emitter", metal, dish_pivot, (0, -0.4, 0.2), scale=(0.03, 0.03, 0.25), rotation=pc.radians(90, 0, 0), vertices=6)
    pc.part("sphere", "Focus", beam, dish_pivot, (0, -0.65, 0.2), scale=(0.08, 0.08, 0.08), segments=8, ring_count=5)
    pc.part("cube", "Phone", panel, dish_pivot, (0, -0.2, 0.62), scale=(0.08, 0.01, 0.14))
    swing(dish_pivot, (-25, 0, 0), (-5, 0, 0), idle_drift=(0, 0, 12))
    return root


def tree(spec, opts, s):
    s *= opts.get("size", 1.0)
    root = pc.empty(spec["id"])
    base(root, spec["tier"], (0.3, 0.25, 0.18))
    bark = pc.material("Bark", (0.38, 0.27, 0.16))
    leaves = pc.material("Leaves", spec["colors"][1])
    glow = pc.material("Eyes", (0.9, 1.0, 0.5), emission=0.8)
    turret = pc.empty("Turret", root, (0, 0, 0.2))
    pc.part("cylinder", "Trunk", bark, turret, (0, 0, 0.35 * s), scale=(0.16 * s, 0.16 * s, 0.35 * s), vertices=8)
    pc.part("sphere", "Canopy", leaves, turret, (0, 0, 0.85 * s), scale=(0.4 * s, 0.4 * s, 0.32 * s), segments=10, ring_count=6)
    if opts.get("face"):
        pc.part("cube", "EyeL", glow, turret, (-0.06 * s, -0.16 * s, 0.5 * s), scale=(0.03 * s, 0.01 * s, 0.02 * s))
        pc.part("cube", "EyeR", glow, turret, (0.06 * s, -0.16 * s, 0.5 * s), scale=(0.03 * s, 0.01 * s, 0.02 * s))
    branch = pc.empty("Branch", turret, (0.18 * s, 0, 0.55 * s))
    pc.part("cylinder", "Limb", bark, branch, (0, -0.2 * s, 0), scale=(0.05 * s, 0.05 * s, 0.22 * s), rotation=pc.radians(70, 0, 0), vertices=6)
    pc.part("sphere", "Fist", leaves, branch, (0, -0.42 * s, 0.06 * s), scale=(0.1 * s, 0.1 * s, 0.1 * s), segments=8, ring_count=5)
    swing(branch, (20, 0, 0), (-60, 0, 0))
    return root


def bug(spec, opts, s):
    s *= opts.get("size", 1.0)
    root = pc.empty(spec["id"])
    base(root, spec["tier"], (0.4, 0.33, 0.24))
    shell = pc.material("Shell", opts.get("shell", (0.4, 0.2, 0.1)), roughness=0.35)
    dark = pc.material("Legs", (0.1, 0.08, 0.06))
    accent = pc.material("Accent", spec["colors"][1])
    turret = pc.empty("Turret", root, (0, 0, 0.22))
    pc.part("sphere", "Abdomen", shell, turret, (0, 0.3 * s, 0.25 * s), scale=(0.22 * s, 0.3 * s, 0.2 * s), segments=10, ring_count=6)
    pc.part("sphere", "Thorax", shell, turret, (0, 0, 0.25 * s), scale=(0.15 * s, 0.15 * s, 0.14 * s), segments=10, ring_count=6)
    for side in (-1, 1):
        for y in (-0.08, 0.05, 0.18):
            pc.part("cylinder", "Leg", dark, turret, (side * 0.2 * s, y * s, 0.12 * s), scale=(0.02 * s, 0.02 * s, 0.14 * s), rotation=pc.radians(0, side * 50, 0), vertices=5)
    head = pc.empty("Head", turret, (0, -0.2 * s, 0.28 * s))
    pc.part("sphere", "HeadBall", shell, head, (0, -0.05 * s, 0), scale=(0.12 * s, 0.12 * s, 0.11 * s), segments=8, ring_count=5)
    for side in (-1, 1):
        pc.part("cylinder", "Antenna", dark, head, (side * 0.06 * s, -0.08 * s, 0.14 * s), scale=(0.01 * s, 0.01 * s, 0.1 * s), rotation=pc.radians(-30, side * 20, 0), vertices=4)
    if opts.get("mandibles"):
        pc.part("cube", "MandibleL", dark, head, (-0.05 * s, -0.18 * s, -0.03 * s), scale=(0.02 * s, 0.06 * s, 0.02 * s), rotation=pc.radians(0, 0, 25))
        pc.part("cube", "MandibleR", dark, head, (0.05 * s, -0.18 * s, -0.03 * s), scale=(0.02 * s, 0.06 * s, 0.02 * s), rotation=pc.radians(0, 0, -25))
    if opts.get("antlers"):
        pc.part("cube", "AntlerL", accent, head, (-0.07 * s, -0.22 * s, 0.02 * s), scale=(0.02 * s, 0.12 * s, 0.02 * s), rotation=pc.radians(0, 0, 20))
        pc.part("cube", "AntlerR", accent, head, (0.07 * s, -0.22 * s, 0.02 * s), scale=(0.02 * s, 0.12 * s, 0.02 * s), rotation=pc.radians(0, 0, -20))
    if opts.get("horn"):
        pc.part("cylinder", "Horn", accent, head, (0, -0.16 * s, 0.1 * s), scale=(0.03 * s, 0.03 * s, 0.14 * s), rotation=pc.radians(-40, 0, 0), vertices=6)
    if opts.get("proboscis"):
        pc.part("cylinder", "Proboscis", dark, head, (0, -0.2 * s, -0.02 * s), scale=(0.01 * s, 0.01 * s, 0.1 * s), rotation=pc.radians(80, 0, 0), vertices=4)
    if opts.get("wings"):
        wing = pc.material("Wing", (0.85, 0.9, 0.95), roughness=0.2)
        pc.part("cube", "WingL", wing, turret, (-0.18 * s, 0.2 * s, 0.4 * s), scale=(0.16 * s, 0.24 * s, 0.01 * s), rotation=pc.radians(0, 20, 10))
        pc.part("cube", "WingR", wing, turret, (0.18 * s, 0.2 * s, 0.4 * s), scale=(0.16 * s, 0.24 * s, 0.01 * s), rotation=pc.radians(0, -20, -10))
    if opts.get("glow"):
        pc.part("sphere", "Lamp", pc.material("Glow", (1.0, 0.95, 0.4), emission=0.9), turret, (0, 0.45 * s, 0.25 * s), scale=(0.12 * s, 0.12 * s, 0.1 * s), segments=8, ring_count=5)
    if opts.get("ball"):
        pc.part("sphere", "DungBall", pc.material("Dung", (0.35, 0.25, 0.15)), turret, (0, -0.5 * s, 0.14 * s), scale=(0.14 * s, 0.14 * s, 0.14 * s), segments=10, ring_count=6)
    if opts.get("crown"):
        pc.part("cylinder", "Crown", pc.material("Gold", (1.0, 0.8, 0.25), roughness=0.3, emission=0.3), head, (0, -0.05 * s, 0.13 * s), scale=(0.08 * s, 0.08 * s, 0.04 * s), vertices=6)
    if opts.get("swarm"):
        for index, (x, y) in enumerate(((-0.45, 0.4), (0.45, 0.35), (-0.4, -0.35), (0.42, -0.4))):
            pc.part("sphere", "Buddy%d" % index, shell, root, (x, y, 0.3), scale=(0.08, 0.12, 0.07), segments=6, ring_count=4)
    swing(head, (0, 0, 0), (-30, 0, 0), idle_drift=(0, 0, 10))
    return root


ARCHETYPES = {
    "figure": figure, "streamer": streamer, "vehicle": vehicle, "rider": rider, "cannon": cannon,
    "beast": beast, "owl": owl, "water": water, "tree": tree, "bug": bug, "drone": drone, "dish": dish,
}


def build_tower(spec):
    kind, opts = spec["model"]
    pc.reset_scene()
    scale = 0.8 + 0.1 * spec["tier"]
    ARCHETYPES[kind](spec, opts, scale)
    pc.export_glb(race_content.model_path(spec))


# --- Builders -----------------------------------------------------------------

def builder_actions(body, arm):
    pc.keyframe_action(body, "idle", "location", [(0.0, (0, 0, 0)), (0.8, (0, 0, 0.02)), (1.6, (0, 0, 0))])
    pc.keyframe_action(body, "walk", "location", [(0.0, (0, 0, 0)), (0.15, (0, 0, 0.05)), (0.3, (0, 0, 0))])
    pc.keyframe_action(arm, "build", "rotation_euler", [
        (0.0, pc.radians(-20, 0, 0)), (0.15, pc.radians(-120, 0, 0)), (0.3, pc.radians(-20, 0, 0)),
        (0.45, pc.radians(-120, 0, 0)), (0.6, pc.radians(-20, 0, 0)),
    ])
    pc.keyframe_action(body, "trip", "rotation_euler", [
        (0.0, pc.radians(0, 0, 0)), (0.2, pc.radians(-85, 0, 0)), (1.2, pc.radians(-85, 0, 0)), (1.5, pc.radians(0, 0, 0)),
    ])
    arm.rotation_euler = pc.radians(-20, 0, 0)
    body.rotation_euler = pc.radians(0, 0, 0)


def peon():
    pc.reset_scene()
    skin = pc.material("Skin", (0.4, 0.6, 0.3))
    rags = pc.material("Rags", (0.5, 0.38, 0.25))
    wood = pc.material("Wood", (0.4, 0.26, 0.14))
    steel = pc.material("Steel", (0.7, 0.72, 0.75), roughness=0.35)
    body = pc.empty("Body", pc.empty("orc_peon"))
    pc.part("cylinder", "Legs", rags, body, (0, 0, 0.1), scale=(0.1, 0.09, 0.1), vertices=8)
    pc.part("sphere", "Torso", skin, body, (0, 0, 0.3), scale=(0.15, 0.13, 0.13), segments=10, ring_count=6)
    pc.part("sphere", "Head", skin, body, (0, -0.04, 0.5), scale=(0.1, 0.1, 0.09), segments=8, ring_count=5)
    arm = pc.empty("Arm", body, (0.15, 0, 0.36))
    pc.part("cylinder", "Pick", wood, arm, (0, -0.05, -0.12), scale=(0.02, 0.02, 0.14), vertices=6)
    pc.part("cube", "PickHead", steel, arm, (0, -0.05, 0.02), scale=(0.1, 0.02, 0.02))
    builder_actions(body, arm)
    pc.export_glb("builders/orc_peon.glb")


def wisp():
    pc.reset_scene()
    glow = pc.material("Wisp", (0.6, 1.0, 0.85), roughness=0.1, emission=0.9)
    trail = pc.material("Trail", (0.4, 0.8, 0.9), roughness=0.1, emission=0.5)
    body = pc.empty("Body", pc.empty("elf_wisp"))
    pc.part("sphere", "Core", glow, body, (0, 0, 0.4), scale=(0.12, 0.12, 0.12), segments=10, ring_count=6)
    pc.part("sphere", "Tail", trail, body, (0, 0.12, 0.33), scale=(0.06, 0.12, 0.06), segments=8, ring_count=5)
    arm = pc.empty("Arm", body, (0, 0, 0.4))
    for index, (x, z) in enumerate(((-0.16, 0.05), (0.16, 0.05), (0, 0.18))):
        pc.part("sphere", "Mote%d" % index, trail, arm, (x, 0, z), scale=(0.03, 0.03, 0.03), segments=6, ring_count=4)
    builder_actions(body, arm)
    pc.export_glb("builders/elf_wisp.glb")


def grub():
    pc.reset_scene()
    flesh = pc.material("Grub", (0.95, 0.88, 0.7))
    hardhat = pc.material("HardHat", (1.0, 0.8, 0.1), roughness=0.3)
    dark = pc.material("Dark", (0.15, 0.1, 0.08))
    body = pc.empty("Body", pc.empty("bug_grub"))
    for index in range(4):
        pc.part("sphere", "Segment%d" % index, flesh, body, (0, 0.12 * index, 0.1), scale=(0.1 - 0.012 * index, 0.08, 0.09 - 0.01 * index), segments=8, ring_count=5)
    pc.part("sphere", "Head", flesh, body, (0, -0.1, 0.14), scale=(0.08, 0.08, 0.08), segments=8, ring_count=5)
    pc.part("cylinder", "Hat", hardhat, body, (0, -0.1, 0.22), scale=(0.08, 0.08, 0.04), vertices=10)
    arm = pc.empty("Arm", body, (0.08, -0.1, 0.16))
    pc.part("cube", "Trowel", dark, arm, (0, -0.06, -0.04), scale=(0.02, 0.05, 0.01))
    builder_actions(body, arm)
    pc.export_glb("builders/bug_grub.glb")


BUILDER_RECIPES = {"peon": peon, "wisp": wisp, "grub": grub}

only = [arg for arg in sys.argv[1:] if not arg.startswith("-")]
for spec in race_content.TOWERS:
    if spec["model"][0] == "keep" or (only and spec["id"] not in only):
        continue
    build_tower(spec)
for builder_id, recipe in race_content.BUILDERS:
    if not only or builder_id in only:
        BUILDER_RECIPES[recipe]()
