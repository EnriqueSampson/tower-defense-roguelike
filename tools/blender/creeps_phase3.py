"""Placeholders: Phase 3 creeps (swarm, air, splitters, invisible, magic
immune) and the bosses of levels 5, 15, 20, 25 and 30.

Blender -b --python tools/blender/creeps_phase3.py

Sizes follow each CreepDefinition.radius (sim pixels / 28 = tiles): about
twice the radius across. Air creeps are authored on the ground; the game
lifts them to flying height. Every creep has a looping "walk" and a "death"
on its "Body" pivot.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import placeholder_common as pc  # noqa: E402


def walk(body, height, period):
    pc.keyframe_action(body, "walk", "location", [
        (0.0, (0.0, 0.0, 0.0)),
        (period * 0.5, (0.0, 0.0, height)),
        (period, (0.0, 0.0, 0.0)),
    ])
    pc.death_fall(body)


def eyes(body, mat, y, z, spread, size=0.018):
    pc.part("cube", "EyeL", mat, body, (-spread, y, z), scale=(size, 0.01, size))
    pc.part("cube", "EyeR", mat, body, (spread, y, z), scale=(size, 0.01, size))


def imp():
    """Radius 4, swarm: an intern imp with a lanyard and a coffee cup."""
    pc.reset_scene()
    skin = pc.material("Skin", (0.85, 0.3, 0.25))
    shirt = pc.material("Shirt", (0.9, 0.9, 0.95))
    lanyard = pc.material("Lanyard", (0.2, 0.45, 0.9))
    cup = pc.material("Cup", (0.95, 0.85, 0.6))
    body = pc.empty("Body", pc.empty("imp"))
    pc.part("cylinder", "Legs", skin, body, (0, 0, 0.06), scale=(0.05, 0.04, 0.06), vertices=6)
    pc.part("cylinder", "Torso", shirt, body, (0, 0, 0.17), scale=(0.08, 0.06, 0.07), vertices=8)
    pc.part("cube", "Badge", lanyard, body, (0, -0.07, 0.16), scale=(0.02, 0.005, 0.03))
    pc.part("sphere", "Head", skin, body, (0, -0.02, 0.3), scale=(0.08, 0.08, 0.07), segments=8, ring_count=5)
    pc.part("cylinder", "HornL", skin, body, (-0.05, 0, 0.38), scale=(0.012, 0.012, 0.04), rotation=pc.radians(0, -25, 0), vertices=5)
    pc.part("cylinder", "HornR", skin, body, (0.05, 0, 0.38), scale=(0.012, 0.012, 0.04), rotation=pc.radians(0, 25, 0), vertices=5)
    pc.part("cylinder", "Coffee", cup, body, (0.1, -0.04, 0.2), scale=(0.025, 0.025, 0.035), vertices=6)
    walk(body, 0.05, 0.2)
    pc.export_glb("creeps/imp.glb")


def gargoyle():
    """Radius 6, air: a stone gargoyle with a neck pillow and a carry-on."""
    pc.reset_scene()
    stone = pc.material("Stone", (0.5, 0.52, 0.56))
    wing = pc.material("Wing", (0.36, 0.38, 0.43))
    pillow = pc.material("Pillow", (0.95, 0.55, 0.2))
    glow = pc.material("Eyes", (1.0, 0.35, 0.2), roughness=0.3, emission=0.8)
    body = pc.empty("Body", pc.empty("gargoyle"))
    pc.part("sphere", "Torso", stone, body, (0, 0, 0.22), scale=(0.14, 0.18, 0.12), segments=10, ring_count=6)
    pc.part("sphere", "Head", stone, body, (0, -0.18, 0.3), scale=(0.09, 0.09, 0.08), segments=8, ring_count=5)
    pc.part("cylinder", "NeckPillow", pillow, body, (0, -0.12, 0.28), scale=(0.1, 0.1, 0.025), vertices=10)
    eyes(body, glow, -0.26, 0.32, 0.035)
    pc.part("cube", "WingL", wing, body, (-0.26, 0.02, 0.28), scale=(0.2, 0.1, 0.01), rotation=pc.radians(0, 15, 0))
    pc.part("cube", "WingR", wing, body, (0.26, 0.02, 0.28), scale=(0.2, 0.1, 0.01), rotation=pc.radians(0, -15, 0))
    pc.part("cube", "Suitcase", pillow, body, (0, 0.08, 0.08), scale=(0.07, 0.03, 0.05))
    # Flapping reads as a bob when seen from the WC3 camera.
    walk(body, 0.08, 0.35)
    pc.export_glb("creeps/gargoyle.glb")


def slime(name, radius_tiles, tie_color, export_name):
    """Splitter family: a wobbling slime wearing a necktie."""
    pc.reset_scene()
    goo = pc.material("Goo", (0.45, 0.85, 0.35), roughness=0.25)
    tie = pc.material("Tie", tie_color)
    dark = pc.material("Eyes", (0.08, 0.1, 0.08))
    body = pc.empty("Body", pc.empty(name))
    r = radius_tiles
    pc.part("sphere", "Blob", goo, body, (0, 0, r * 0.75), scale=(r, r, r * 0.75), segments=12, ring_count=8)
    pc.part("cube", "Tie", tie, body, (0, -r * 0.98, r * 0.7), scale=(r * 0.12, 0.01, r * 0.35))
    eyes(body, dark, -r * 0.9, r * 1.05, r * 0.3, size=r * 0.08)
    pc.keyframe_action(body, "walk", "scale", [
        (0.0, (1.0, 1.0, 1.0)),
        (0.25, (1.12, 1.12, 0.85)),
        (0.5, (1.0, 1.0, 1.0)),
    ])
    pc.death_fall(body)
    pc.export_glb("creeps/%s.glb" % export_name)


def shade():
    """Radius 6, invisible: a remote worker ghost in a hoodie with a laptop."""
    pc.reset_scene()
    hoodie = pc.material("Hoodie", (0.28, 0.22, 0.4))
    void = pc.material("Void", (0.05, 0.04, 0.08))
    laptop = pc.material("Laptop", (0.7, 0.72, 0.75), roughness=0.3)
    glow = pc.material("Eyes", (0.6, 0.85, 1.0), roughness=0.3, emission=0.9)
    body = pc.empty("Body", pc.empty("shade"))
    pc.part("cylinder", "Robe", hoodie, body, (0, 0, 0.2), scale=(0.15, 0.13, 0.2), vertices=10)
    pc.part("sphere", "Hood", hoodie, body, (0, 0, 0.45), scale=(0.12, 0.12, 0.11), segments=10, ring_count=6)
    pc.part("sphere", "Face", void, body, (0, -0.06, 0.44), scale=(0.08, 0.06, 0.08), segments=8, ring_count=5)
    eyes(body, glow, -0.12, 0.46, 0.03)
    pc.part("cube", "Laptop", laptop, body, (0, -0.16, 0.25), scale=(0.1, 0.07, 0.008), rotation=pc.radians(-20, 0, 0))
    walk(body, 0.05, 0.8)
    pc.export_glb("creeps/shade.glb")


def golem():
    """Radius 9, magic immune: a rune-warded rock golem holding a signed waiver."""
    pc.reset_scene()
    rock = pc.material("Rock", (0.45, 0.4, 0.36))
    rune = pc.material("Rune", (0.4, 0.75, 1.0), roughness=0.2, emission=0.7)
    paper = pc.material("Paper", (0.95, 0.94, 0.88))
    body = pc.empty("Body", pc.empty("golem"))
    pc.part("cube", "Legs", rock, body, (0, 0, 0.14), scale=(0.2, 0.14, 0.14))
    pc.part("cube", "Torso", rock, body, (0, 0, 0.46), scale=(0.3, 0.2, 0.2), rotation=pc.radians(0, 0, 8))
    pc.part("cube", "Head", rock, body, (0, -0.04, 0.74), scale=(0.12, 0.11, 0.09))
    pc.part("cube", "RuneChest", rune, body, (0, -0.21, 0.48), scale=(0.08, 0.01, 0.08), rotation=pc.radians(0, 45, 0))
    pc.part("cube", "ArmL", rock, body, (-0.38, 0, 0.4), scale=(0.08, 0.08, 0.2))
    pc.part("cube", "ArmR", rock, body, (0.38, 0, 0.4), scale=(0.08, 0.08, 0.2))
    pc.part("cube", "Waiver", paper, body, (0.38, -0.12, 0.3), scale=(0.07, 0.005, 0.1))
    walk(body, 0.03, 0.8)
    pc.export_glb("creeps/golem.glb")


def regional_manager():
    """Radius 11, boss (level 5): an ogre in a suit with a clipboard and a mug."""
    pc.reset_scene()
    skin = pc.material("Skin", (0.55, 0.65, 0.4))
    suit = pc.material("Suit", (0.22, 0.24, 0.3))
    shirt = pc.material("Shirt", (0.95, 0.95, 0.95))
    tie = pc.material("Tie", (0.8, 0.15, 0.15))
    mug = pc.material("Mug", (0.95, 0.85, 0.3), emission=0.3)
    body = pc.empty("Body", pc.empty("regional_manager"))
    pc.part("cylinder", "Legs", suit, body, (0, 0, 0.2), scale=(0.24, 0.2, 0.2), vertices=10)
    pc.part("sphere", "Torso", suit, body, (0, 0, 0.6), scale=(0.36, 0.3, 0.3), segments=12, ring_count=8)
    pc.part("cube", "Shirt", shirt, body, (0, -0.27, 0.66), scale=(0.1, 0.03, 0.18))
    pc.part("cube", "Tie", tie, body, (0, -0.3, 0.64), scale=(0.035, 0.01, 0.15))
    pc.part("sphere", "Head", skin, body, (0, -0.05, 0.98), scale=(0.17, 0.17, 0.16), segments=12, ring_count=8)
    pc.part("cube", "Clipboard", shirt, body, (-0.4, -0.12, 0.6), scale=(0.1, 0.01, 0.14))
    pc.part("cylinder", "Mug", mug, body, (0.4, -0.12, 0.62), scale=(0.06, 0.06, 0.08), vertices=8)
    walk(body, 0.04, 0.8)
    pc.export_glb("creeps/regional_manager.glb")


def overtime_wyrm():
    """Radius 13, air boss (level 15): a tired dragon in a headset."""
    pc.reset_scene()
    scale = pc.material("Scale", (0.35, 0.2, 0.5))
    belly = pc.material("Belly", (0.85, 0.7, 0.45))
    wing = pc.material("Wing", (0.5, 0.3, 0.6))
    headset = pc.material("Headset", (0.12, 0.12, 0.14))
    glow = pc.material("Eyes", (1.0, 0.85, 0.2), roughness=0.3, emission=0.9)
    body = pc.empty("Body", pc.empty("overtime_wyrm"))
    pc.part("sphere", "Torso", scale, body, (0, 0.05, 0.4), scale=(0.3, 0.5, 0.26), segments=12, ring_count=8)
    pc.part("sphere", "Belly", belly, body, (0, -0.05, 0.3), scale=(0.2, 0.36, 0.16), segments=10, ring_count=6)
    pc.part("sphere", "Head", scale, body, (0, -0.55, 0.62), scale=(0.18, 0.24, 0.15), segments=10, ring_count=6)
    eyes(body, glow, -0.72, 0.68, 0.08, size=0.03)
    pc.part("cylinder", "Headset", headset, body, (0, -0.52, 0.72), scale=(0.2, 0.03, 0.03), rotation=pc.radians(0, 90, 0), vertices=8)
    pc.part("cube", "WingL", wing, body, (-0.62, 0.05, 0.55), scale=(0.45, 0.3, 0.015), rotation=pc.radians(0, 20, 0))
    pc.part("cube", "WingR", wing, body, (0.62, 0.05, 0.55), scale=(0.45, 0.3, 0.015), rotation=pc.radians(0, -20, 0))
    pc.part("cylinder", "Tail", scale, body, (0, 0.7, 0.35), scale=(0.07, 0.07, 0.3), rotation=pc.radians(75, 0, 0), vertices=6)
    walk(body, 0.1, 0.9)
    pc.export_glb("creeps/overtime_wyrm.glb")


def compliance_lich():
    """Radius 12, magic-immune boss (level 20): a lich with a rulebook and a stamp."""
    pc.reset_scene()
    robe = pc.material("Robe", (0.15, 0.3, 0.25))
    bone = pc.material("Bone", (0.9, 0.88, 0.8))
    book = pc.material("Book", (0.55, 0.12, 0.1))
    rune = pc.material("Ward", (0.4, 1.0, 0.7), roughness=0.2, emission=0.8)
    body = pc.empty("Body", pc.empty("compliance_lich"))
    pc.part("cylinder", "Robe", robe, body, (0, 0, 0.4), scale=(0.3, 0.26, 0.4), vertices=12)
    pc.part("sphere", "Skull", bone, body, (0, -0.03, 0.95), scale=(0.16, 0.16, 0.17), segments=12, ring_count=8)
    pc.part("cylinder", "Mitre", robe, body, (0, -0.03, 1.15), scale=(0.1, 0.1, 0.12), vertices=6)
    pc.part("cube", "Rulebook", book, body, (-0.36, -0.15, 0.62), scale=(0.12, 0.05, 0.16))
    pc.part("cylinder", "Stamp", bone, body, (0.36, -0.15, 0.6), scale=(0.07, 0.07, 0.06), vertices=8)
    pc.part("cylinder", "WardRing", rune, body, (0, 0, 0.55), scale=(0.42, 0.42, 0.015), vertices=16)
    walk(body, 0.03, 1.0)
    pc.export_glb("creeps/compliance_lich.glb")


def phantom_auditor():
    """Radius 11, invisible boss (level 25): a spectral auditor with a calculator."""
    pc.reset_scene()
    coat = pc.material("Coat", (0.55, 0.6, 0.7))
    void = pc.material("Void", (0.06, 0.06, 0.1))
    calc = pc.material("Calculator", (0.2, 0.2, 0.22))
    glow = pc.material("Screen", (0.5, 1.0, 0.6), roughness=0.3, emission=0.9)
    body = pc.empty("Body", pc.empty("phantom_auditor"))
    pc.part("cylinder", "Coat", coat, body, (0, 0, 0.42), scale=(0.28, 0.24, 0.42), vertices=12)
    pc.part("sphere", "Head", void, body, (0, -0.02, 0.98), scale=(0.16, 0.16, 0.16), segments=12, ring_count=8)
    pc.part("cylinder", "Hat", calc, body, (0, -0.02, 1.16), scale=(0.2, 0.2, 0.02), vertices=12)
    pc.part("cylinder", "HatTop", calc, body, (0, -0.02, 1.24), scale=(0.12, 0.12, 0.08), vertices=12)
    pc.part("cube", "Calculator", calc, body, (0.3, -0.2, 0.6), scale=(0.08, 0.02, 0.12))
    pc.part("cube", "Display", glow, body, (0.3, -0.225, 0.68), scale=(0.06, 0.005, 0.025))
    walk(body, 0.06, 1.1)
    pc.export_glb("creeps/phantom_auditor.glb")


def the_board():
    """Radius 14, final boss (level 30): a boardroom table carried by five
    executives; it splits into Directors when destroyed."""
    pc.reset_scene()
    wood = pc.material("Mahogany", (0.4, 0.2, 0.1), roughness=0.35)
    suit = pc.material("Suit", (0.12, 0.12, 0.16))
    skin = pc.material("Skin", (0.8, 0.6, 0.5))
    gold = pc.material("Gold", (1.0, 0.8, 0.25), roughness=0.3, emission=0.3)
    body = pc.empty("Body", pc.empty("the_board"))
    pc.part("cube", "Table", wood, body, (0, 0, 0.5), scale=(0.45, 0.75, 0.05))
    pc.part("cube", "Legs", wood, body, (0, 0, 0.25), scale=(0.35, 0.65, 0.22))
    for index, y in enumerate((-0.6, -0.3, 0.0, 0.3, 0.6)):
        side = -1 if index % 2 == 0 else 1
        pc.part("cylinder", "Exec%d" % index, suit, body, (side * 0.55, y, 0.45), scale=(0.1, 0.1, 0.25), vertices=8)
        pc.part("sphere", "ExecHead%d" % index, skin, body, (side * 0.55, y, 0.8), scale=(0.08, 0.08, 0.08), segments=8, ring_count=5)
    pc.part("cube", "Gavel", gold, body, (0, -0.4, 0.6), scale=(0.08, 0.03, 0.03))
    walk(body, 0.03, 1.2)
    pc.export_glb("creeps/the_board.glb")


def director():
    """Radius 8: one board member, briefcase in hand, walking off with a bonus."""
    pc.reset_scene()
    suit = pc.material("Suit", (0.12, 0.12, 0.16))
    skin = pc.material("Skin", (0.8, 0.6, 0.5))
    case = pc.material("Briefcase", (0.35, 0.22, 0.12))
    gold = pc.material("Gold", (1.0, 0.8, 0.25), roughness=0.3, emission=0.3)
    body = pc.empty("Body", pc.empty("director"))
    pc.part("cylinder", "Legs", suit, body, (0, 0, 0.14), scale=(0.12, 0.1, 0.14), vertices=8)
    pc.part("cylinder", "Torso", suit, body, (0, 0, 0.4), scale=(0.18, 0.14, 0.14), vertices=10)
    pc.part("sphere", "Head", skin, body, (0, -0.02, 0.64), scale=(0.1, 0.1, 0.1), segments=10, ring_count=6)
    pc.part("cube", "Briefcase", case, body, (0.24, -0.02, 0.22), scale=(0.08, 0.03, 0.07))
    pc.part("cube", "Bonus", gold, body, (-0.2, -0.08, 0.4), scale=(0.05, 0.01, 0.03))
    walk(body, 0.04, 0.5)
    pc.export_glb("creeps/director.glb")


imp()
gargoyle()
slime("slime", 0.25, (0.8, 0.15, 0.15), "slime")
slime("slimelet", 0.14, (0.2, 0.4, 0.85), "slimelet")
shade()
golem()
regional_manager()
overtime_wyrm()
compliance_lich()
phantom_auditor()
the_board()
director()
