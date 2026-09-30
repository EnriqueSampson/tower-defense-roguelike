"""Placeholder: detection tower, a nosy retiree on a porch with binoculars.

Blender -b --python tools/blender/human_nosy_neighbor.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import placeholder_common as pc  # noqa: E402

pc.reset_scene()
planks = pc.material("Porch", (0.55, 0.42, 0.3))
chair = pc.material("LawnChair", (0.3, 0.7, 0.55))
skin = pc.material("Skin", (0.88, 0.7, 0.6))
cardigan = pc.material("Cardigan", (0.75, 0.55, 0.65))
hair = pc.material("Hair", (0.92, 0.92, 0.95))
lens = pc.material("Lens", (0.55, 0.85, 1.0), roughness=0.2, emission=0.6)
dark = pc.material("Binoculars", (0.12, 0.12, 0.14))

root = pc.empty("human_nosy_neighbor")
pc.part("cube", "Porch", planks, root, (0, 0, 0.08), scale=(0.92, 0.92, 0.08))
pc.part("cube", "Railing", planks, root, (0, -0.8, 0.3), scale=(0.85, 0.04, 0.14))

# The neighbour swivels to stare at whatever is walking past.
turret = pc.empty("Turret", root, (0, 0, 0.16))
pc.part("cube", "ChairSeat", chair, turret, (0, 0.1, 0.3), scale=(0.3, 0.28, 0.04))
pc.part("cube", "ChairBack", chair, turret, (0, 0.38, 0.6), scale=(0.3, 0.04, 0.3))
pc.part("cylinder", "Body", cardigan, turret, (0, 0.12, 0.6), scale=(0.22, 0.18, 0.26), vertices=8)
pc.part("sphere", "Head", skin, turret, (0, 0.08, 1.0), scale=(0.16, 0.16, 0.16), segments=10, ring_count=6)
pc.part("sphere", "Hair", hair, turret, (0, 0.14, 1.08), scale=(0.17, 0.15, 0.1), segments=10, ring_count=6)

# Binoculars raise to the eyes on "attack" (the tower's weak jab of shame).
glasses = pc.empty("Binoculars", turret, (0, -0.1, 0.98))
pc.part("cylinder", "BinoL", dark, glasses, (-0.06, -0.06, 0), scale=(0.045, 0.045, 0.07), rotation=pc.radians(90, 0, 0), vertices=8)
pc.part("cylinder", "BinoR", dark, glasses, (0.06, -0.06, 0), scale=(0.045, 0.045, 0.07), rotation=pc.radians(90, 0, 0), vertices=8)
pc.part("cylinder", "LensL", lens, glasses, (-0.06, -0.13, 0), scale=(0.035, 0.035, 0.005), rotation=pc.radians(90, 0, 0), vertices=8)
pc.part("cylinder", "LensR", lens, glasses, (0.06, -0.13, 0), scale=(0.035, 0.035, 0.005), rotation=pc.radians(90, 0, 0), vertices=8)

pc.keyframe_action(glasses, "idle", "location", [
    (0.0, (0.0, -0.1, 0.98)),
    (1.0, (0.02, -0.1, 0.99)),
    (2.0, (0.0, -0.1, 0.98)),
])
pc.keyframe_action(glasses, "attack", "location", [
    (0.0, (0.0, -0.1, 0.98)),
    (0.1, (0.0, -0.22, 1.0)),
    (0.35, (0.0, -0.1, 0.98)),
])
glasses.location = (0.0, -0.1, 0.98)

pc.export_glb("towers/human_nosy_neighbor.glb")
