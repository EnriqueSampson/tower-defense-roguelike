"""Placeholder: Elf slow tower, a water spirit rising from a pool (Frost).

Blender -b --python tools/blender/elf_water_spirit.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import placeholder_common as pc  # noqa: E402

pc.reset_scene()
marble = pc.material("Marble", (0.78, 0.8, 0.76))
moss = pc.material("Moss", (0.3, 0.45, 0.25))
pool = pc.material("Pool", (0.12, 0.35, 0.55), roughness=0.1)
spirit = pc.material("Spirit", (0.55, 0.85, 1.0), roughness=0.15, emission=0.35)

root = pc.empty("elf_water_spirit")
pc.part("cylinder", "Base", marble, root, (0, 0, 0.1), scale=(0.9, 0.9, 0.1), vertices=16)
pc.part("cylinder", "Rim", moss, root, (0, 0, 0.22), scale=(0.72, 0.72, 0.04), vertices=16)
pc.part("cylinder", "Pool", pool, root, (0, 0, 0.23), scale=(0.66, 0.66, 0.04), vertices=16)

# The spirit floats and turns toward its target; the attack is a surge.
turret = pc.empty("Turret", root, (0, 0, 0.3))
body = pc.empty("Spirit", turret, (0, 0, 0.0))
pc.part("cylinder", "Tail", spirit, body, (0, 0, 0.25), scale=(0.18, 0.18, 0.28), vertices=10)
pc.part("sphere", "Torso", spirit, body, (0, 0, 0.7), scale=(0.24, 0.2, 0.26), segments=12, ring_count=8)
pc.part("sphere", "Head", spirit, body, (0, -0.02, 1.08), scale=(0.16, 0.16, 0.16), segments=12, ring_count=8)
pc.part("sphere", "HandL", spirit, body, (-0.3, -0.18, 0.78), scale=(0.07, 0.07, 0.07), segments=8, ring_count=4)
pc.part("sphere", "HandR", spirit, body, (0.3, -0.18, 0.78), scale=(0.07, 0.07, 0.07), segments=8, ring_count=4)

pc.keyframe_action(body, "idle", "location", [
    (0.0, (0.0, 0.0, 0.0)),
    (1.2, (0.0, 0.0, 0.08)),
    (2.4, (0.0, 0.0, 0.0)),
])
pc.keyframe_action(body, "attack", "scale", [
    (0.0, (1.0, 1.0, 1.0)),
    (0.08, (1.2, 1.2, 0.9)),
    (0.35, (1.0, 1.0, 1.0)),
])

pc.export_glb("towers/elf_water_spirit.glb")
