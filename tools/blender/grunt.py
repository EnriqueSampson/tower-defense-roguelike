"""Placeholder: Grunt creep, a squat goblin with a club.

Blender -b --python tools/blender/grunt.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import placeholder_common as pc  # noqa: E402

pc.reset_scene()
hide = pc.material("Hide", (0.42, 0.55, 0.26))
rags = pc.material("Rags", (0.45, 0.3, 0.2))
wood = pc.material("Wood", (0.3, 0.19, 0.1))
eyes = pc.material("Eyes", (0.95, 0.85, 0.2), roughness=0.3)

# Creeps are about half a tile across; the game scales nothing, so author at size.
root = pc.empty("grunt")
body = pc.empty("Body", root)
pc.part("cylinder", "Legs", rags, body, (0, 0, 0.1), scale=(0.13, 0.11, 0.1), vertices=8)
pc.part("sphere", "Belly", hide, body, (0, 0, 0.3), scale=(0.2, 0.17, 0.17), segments=10, ring_count=6)
pc.part("sphere", "Head", hide, body, (0, -0.04, 0.52), scale=(0.13, 0.12, 0.11), segments=10, ring_count=6)
pc.part("cube", "EyeL", eyes, body, (-0.05, -0.15, 0.55), scale=(0.02, 0.01, 0.015))
pc.part("cube", "EyeR", eyes, body, (0.05, -0.15, 0.55), scale=(0.02, 0.01, 0.015))
pc.part("cylinder", "Club", wood, body, (0.22, -0.05, 0.38), scale=(0.035, 0.035, 0.16), rotation=pc.radians(-30, 0, 0), vertices=6)

pc.keyframe_action(body, "walk", "location", [
    (0.0, (0.0, 0.0, 0.0)),
    (0.2, (0.0, 0.0, 0.05)),
    (0.4, (0.0, 0.0, 0.0)),
])

pc.export_glb("creeps/grunt.glb")
