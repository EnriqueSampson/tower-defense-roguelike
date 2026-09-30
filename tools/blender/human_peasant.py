"""Placeholder: Human race builder, a peasant with a hammer.

Blender -b --python tools/blender/human_peasant.py

Animations: idle, walk (on Body), build (hammer swing on HammerArm) and trip
(the builder easter egg: stumbles face-first and gets back up).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import placeholder_common as pc  # noqa: E402

pc.reset_scene()
skin = pc.material("Skin", (0.86, 0.66, 0.5))
tunic = pc.material("Tunic", (0.55, 0.42, 0.26))
cap = pc.material("Cap", (0.75, 0.2, 0.18))
wood = pc.material("Wood", (0.4, 0.26, 0.14))
iron = pc.material("Iron", (0.55, 0.57, 0.6), roughness=0.4)

# Builders are a bit bigger than a grunt so they stay easy to find.
root = pc.empty("human_peasant")
body = pc.empty("Body", root)
pc.part("cylinder", "Legs", wood, body, (0, 0, 0.14), scale=(0.13, 0.11, 0.14), vertices=8)
pc.part("cylinder", "Torso", tunic, body, (0, 0, 0.42), scale=(0.18, 0.15, 0.17), vertices=8)
pc.part("sphere", "Head", skin, body, (0, -0.02, 0.7), scale=(0.13, 0.13, 0.13), segments=10, ring_count=6)
pc.part("cylinder", "Cap", cap, body, (0, 0.01, 0.8), scale=(0.12, 0.12, 0.05), vertices=8)
pc.part("cylinder", "ArmL", skin, body, (-0.21, 0, 0.44), scale=(0.05, 0.05, 0.14), vertices=6)
arm = pc.empty("HammerArm", body, (0.21, 0, 0.56))
pc.part("cylinder", "ArmR", skin, arm, (0, 0, -0.12), scale=(0.05, 0.05, 0.14), vertices=6)
pc.part("cylinder", "Handle", wood, arm, (0, -0.1, -0.24), scale=(0.025, 0.025, 0.14), rotation=pc.radians(-70, 0, 0), vertices=6)
pc.part("cube", "HammerHead", iron, arm, (0, -0.24, -0.2), scale=(0.07, 0.04, 0.045))

pc.keyframe_action(body, "idle", "location", [
    (0.0, (0.0, 0.0, 0.0)),
    (0.9, (0.0, 0.0, 0.015)),
    (1.8, (0.0, 0.0, 0.0)),
])
pc.keyframe_action(body, "walk", "location", [
    (0.0, (0.0, 0.0, 0.0)),
    (0.15, (0.0, 0.0, 0.05)),
    (0.3, (0.0, 0.0, 0.0)),
])
pc.keyframe_action(arm, "build", "rotation_euler", [
    (0.0, pc.radians(0, 0, 0)),
    (0.2, pc.radians(-110, 0, 0)),
    (0.32, pc.radians(20, 0, 0)),
    (0.5, pc.radians(0, 0, 0)),
])
# Trip: pitch forward (-Y is the front) onto the face, lie there, pop back up.
pc.keyframe_action(body, "trip", "rotation_euler", [
    (0.0, pc.radians(0, 0, 0)),
    (0.18, pc.radians(95, 0, 0)),
    (0.25, pc.radians(85, 0, 0)),
    (0.7, pc.radians(88, 0, 0)),
    (0.95, pc.radians(0, 0, 0)),
])

pc.export_glb("builders/human_peasant.glb")
