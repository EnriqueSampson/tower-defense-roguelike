"""Placeholder: Human race tier-1 tower, a guy with an oversized sword.

Blender -b --python tools/blender/human_swordsman.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import placeholder_common as pc  # noqa: E402

pc.reset_scene()
stone = pc.material("Stone", (0.32, 0.34, 0.33))
skin = pc.material("Skin", (0.85, 0.62, 0.48))
tunic = pc.material("Tunic", (0.18, 0.32, 0.62))
steel = pc.material("Steel", (0.75, 0.77, 0.8), roughness=0.35)
leather = pc.material("Leather", (0.35, 0.22, 0.12))

root = pc.empty("human_swordsman")
pc.part("cube", "Base", stone, root, (0, 0, 0.1), scale=(0.92, 0.92, 0.1))

# Everything that turns toward the target sits under "Turret".
turret = pc.empty("Turret", root, (0, 0, 0.2))
pc.part("cylinder", "Legs", leather, turret, (0, 0, 0.25), scale=(0.22, 0.22, 0.25), vertices=8)
pc.part("cylinder", "Torso", tunic, turret, (0, 0, 0.7), scale=(0.3, 0.26, 0.25), vertices=8)
pc.part("sphere", "Head", skin, turret, (0, 0, 1.15), scale=(0.2, 0.2, 0.2), segments=10, ring_count=6)
pc.part("cylinder", "ArmL", skin, turret, (-0.36, 0, 0.75), scale=(0.07, 0.07, 0.2), vertices=6)

# Sword arm pivots at the shoulder so the attack swings the whole arm.
sword_arm = pc.empty("SwordArm", turret, (0.36, 0, 0.92))
pc.part("cylinder", "ArmR", skin, sword_arm, (0, 0, -0.17), scale=(0.07, 0.07, 0.2), vertices=6)
pc.part("cube", "Guard", leather, sword_arm, (0.05, -0.04, -0.34), scale=(0.14, 0.03, 0.03))
pc.part("cube", "Blade", steel, sword_arm, (0.05, -0.04, 0.12), scale=(0.04, 0.02, 0.45))

pc.keyframe_action(sword_arm, "idle", "rotation_euler", [
    (0.0, pc.radians(-15, 0, 0)),
    (0.75, pc.radians(-22, 0, 0)),
    (1.5, pc.radians(-15, 0, 0)),
])
pc.keyframe_action(sword_arm, "attack", "rotation_euler", [
    (0.0, pc.radians(-15, 0, 0)),
    (0.08, pc.radians(25, 0, 0)),
    (0.2, pc.radians(-95, 0, 0)),
    (0.45, pc.radians(-15, 0, 0)),
])
sword_arm.rotation_euler = pc.radians(-15, 0, 0)

pc.export_glb("towers/human_swordsman.glb")
