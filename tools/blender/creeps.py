"""Placeholders: runner, brute, mender and warlord creeps.

Blender -b --python tools/blender/creeps.py

Sizes follow each CreepDefinition.radius (sim pixels / 28 = tiles): about
twice the radius across. Every creep has a looping "walk" on its "Body".
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


def runner():
    """Radius 5: a skinny goblin sprinting in oversized sneakers."""
    pc.reset_scene()
    skin = pc.material("Skin", (0.55, 0.62, 0.25))
    shirt = pc.material("Shirt", (0.95, 0.8, 0.3))
    shoe = pc.material("Sneaker", (0.95, 0.95, 0.95))
    body = pc.empty("Body", pc.empty("runner"))
    body.rotation_euler = pc.radians(-15, 0, 0)  # leaning into the sprint
    pc.part("cube", "ShoeL", shoe, body, (-0.06, -0.04, 0.03), scale=(0.05, 0.09, 0.03))
    pc.part("cube", "ShoeR", shoe, body, (0.06, -0.04, 0.03), scale=(0.05, 0.09, 0.03))
    pc.part("cylinder", "Legs", skin, body, (0, 0, 0.13), scale=(0.07, 0.06, 0.09), vertices=6)
    pc.part("cylinder", "Torso", shirt, body, (0, 0, 0.3), scale=(0.1, 0.08, 0.1), vertices=8)
    pc.part("sphere", "Head", skin, body, (0, -0.04, 0.47), scale=(0.1, 0.1, 0.09), segments=10, ring_count=6)
    pc.part("cube", "EarL", skin, body, (-0.12, -0.02, 0.5), scale=(0.05, 0.01, 0.02), rotation=pc.radians(0, 20, 0))
    pc.part("cube", "EarR", skin, body, (0.12, -0.02, 0.5), scale=(0.05, 0.01, 0.02), rotation=pc.radians(0, -20, 0))
    walk(body, 0.06, 0.25)
    body.rotation_euler = pc.radians(-15, 0, 0)
    pc.export_glb("creeps/runner.glb")


def brute():
    """Radius 8, armored: an ogre in a bucket helmet and scrap plates."""
    pc.reset_scene()
    skin = pc.material("Skin", (0.5, 0.55, 0.62))
    plate = pc.material("Plate", (0.35, 0.37, 0.4), roughness=0.4)
    belt = pc.material("Belt", (0.3, 0.2, 0.12))
    body = pc.empty("Body", pc.empty("brute"))
    pc.part("cylinder", "Legs", belt, body, (0, 0, 0.14), scale=(0.2, 0.16, 0.14), vertices=8)
    pc.part("sphere", "Gut", skin, body, (0, 0, 0.42), scale=(0.28, 0.24, 0.24), segments=12, ring_count=8)
    pc.part("cube", "ChestPlate", plate, body, (0, -0.2, 0.46), scale=(0.2, 0.04, 0.16))
    pc.part("cube", "ShoulderL", plate, body, (-0.28, 0, 0.6), scale=(0.1, 0.12, 0.05), rotation=pc.radians(0, 20, 0))
    pc.part("cube", "ShoulderR", plate, body, (0.28, 0, 0.6), scale=(0.1, 0.12, 0.05), rotation=pc.radians(0, -20, 0))
    pc.part("sphere", "Head", skin, body, (0, -0.05, 0.72), scale=(0.13, 0.13, 0.12), segments=10, ring_count=6)
    pc.part("cylinder", "Bucket", plate, body, (0, -0.05, 0.8), scale=(0.14, 0.14, 0.08), vertices=10)
    walk(body, 0.03, 0.6)
    pc.export_glb("creeps/brute.glb")


def mender():
    """Radius 6.5, regenerates: a goblin shaman with a glowing orb staff."""
    pc.reset_scene()
    skin = pc.material("Skin", (0.4, 0.6, 0.35))
    robe = pc.material("Robe", (0.35, 0.2, 0.45))
    wood = pc.material("Wood", (0.35, 0.22, 0.12))
    orb = pc.material("Orb", (0.4, 1.0, 0.5), roughness=0.2, emission=0.8)
    body = pc.empty("Body", pc.empty("mender"))
    pc.part("cylinder", "Robe", robe, body, (0, 0, 0.18), scale=(0.16, 0.15, 0.18), vertices=10)
    pc.part("sphere", "Head", skin, body, (0, -0.02, 0.45), scale=(0.11, 0.11, 0.1), segments=10, ring_count=6)
    pc.part("cylinder", "Hood", robe, body, (0, 0.02, 0.53), scale=(0.1, 0.1, 0.07), vertices=8)
    pc.part("cylinder", "Staff", wood, body, (0.2, -0.05, 0.3), scale=(0.02, 0.02, 0.3), vertices=6)
    pc.part("sphere", "Orb", orb, body, (0.2, -0.05, 0.64), scale=(0.06, 0.06, 0.06), segments=10, ring_count=6)
    walk(body, 0.04, 0.45)
    pc.export_glb("creeps/mender.glb")


def warlord():
    """Radius 12, boss: the Frost Warlord, a horned ogre king with a huge axe."""
    pc.reset_scene()
    skin = pc.material("Skin", (0.6, 0.25, 0.3))
    fur = pc.material("Fur", (0.85, 0.9, 0.95))
    iron = pc.material("Iron", (0.3, 0.32, 0.36), roughness=0.4)
    gold = pc.material("Gold", (1.0, 0.8, 0.25), roughness=0.3)
    ice = pc.material("Ice", (0.6, 0.9, 1.0), roughness=0.1, emission=0.5)
    bone = pc.material("Bone", (0.9, 0.86, 0.75))
    body = pc.empty("Body", pc.empty("warlord"))
    pc.part("cylinder", "Legs", iron, body, (0, 0, 0.22), scale=(0.28, 0.22, 0.22), vertices=10)
    pc.part("sphere", "Torso", skin, body, (0, 0, 0.66), scale=(0.4, 0.32, 0.34), segments=14, ring_count=8)
    pc.part("cylinder", "FurCollar", fur, body, (0, 0, 0.92), scale=(0.36, 0.3, 0.07), vertices=12)
    pc.part("sphere", "Head", skin, body, (0, -0.06, 1.1), scale=(0.18, 0.18, 0.17), segments=12, ring_count=8)
    pc.part("cylinder", "Crown", gold, body, (0, -0.06, 1.26), scale=(0.14, 0.14, 0.05), vertices=8)
    pc.part("cylinder", "HornL", bone, body, (-0.2, -0.04, 1.2), scale=(0.035, 0.035, 0.14), rotation=pc.radians(0, -40, 0), vertices=6)
    pc.part("cylinder", "HornR", bone, body, (0.2, -0.04, 1.2), scale=(0.035, 0.035, 0.14), rotation=pc.radians(0, 40, 0), vertices=6)
    pc.part("cylinder", "AxeHaft", iron, body, (0.45, -0.1, 0.7), scale=(0.035, 0.035, 0.5), vertices=6)
    pc.part("cube", "AxeBlade", ice, body, (0.45, -0.28, 1.08), scale=(0.03, 0.18, 0.16))
    walk(body, 0.04, 0.9)
    pc.export_glb("creeps/warlord.glb")


runner()
brute()
mender()
warlord()
