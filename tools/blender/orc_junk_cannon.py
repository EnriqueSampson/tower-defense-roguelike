"""Placeholder: Orc splash tower, a junk cart with a cannon bolted on (Cannon).

Blender -b --python tools/blender/orc_junk_cannon.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import placeholder_common as pc  # noqa: E402

pc.reset_scene()
stone = pc.material("Stone", (0.3, 0.29, 0.27))
plank = pc.material("Plank", (0.42, 0.28, 0.15))
iron = pc.material("Iron", (0.16, 0.16, 0.18), roughness=0.45)
rust = pc.material("Rust", (0.55, 0.28, 0.12))
orc = pc.material("OrcSkin", (0.36, 0.5, 0.22))
fuse = pc.material("Fuse", (0.95, 0.55, 0.2), emission=0.8)

root = pc.empty("orc_junk_cannon")
pc.part("cube", "Base", stone, root, (0, 0, 0.08), scale=(0.92, 0.92, 0.08))

turret = pc.empty("Turret", root, (0, 0, 0.16))
# Cart bed on four mismatched wheels.
pc.part("cube", "Cart", plank, turret, (0, 0.05, 0.28), scale=(0.5, 0.6, 0.12))
for i, (x, y, r) in enumerate([(-0.55, -0.35, 0.2), (0.55, -0.35, 0.17), (-0.55, 0.45, 0.17), (0.55, 0.45, 0.22)]):
    pc.part("cylinder", f"Wheel{i}", iron, turret, (x, y, r), scale=(r, r, 0.05), rotation=pc.radians(0, 90, 0), vertices=10)
pc.part("cube", "ScrapPlate", rust, turret, (0.3, 0.35, 0.48), scale=(0.18, 0.02, 0.14), rotation=pc.radians(0, 0, 25))

# Barrel on a pivot so the attack animation can kick it back.
barrel = pc.empty("Barrel", turret, (0, 0, 0.55))
pc.part("cylinder", "Tube", iron, barrel, (0, -0.35, 0.12), scale=(0.16, 0.16, 0.5), rotation=pc.radians(-75, 0, 0), vertices=12)
pc.part("cylinder", "Muzzle", rust, barrel, (0, -0.83, 0.25), scale=(0.2, 0.2, 0.05), rotation=pc.radians(-75, 0, 0), vertices=12)
pc.part("sphere", "FuseSpark", fuse, barrel, (0, 0.12, 0.05), scale=(0.05, 0.05, 0.05), segments=8, ring_count=4)

# A very confident orc gunner standing in the cart.
pc.part("cylinder", "GunnerBody", orc, turret, (-0.25, 0.35, 0.62), scale=(0.16, 0.14, 0.2), vertices=8)
pc.part("sphere", "GunnerHead", orc, turret, (-0.25, 0.33, 0.92), scale=(0.13, 0.13, 0.12), segments=10, ring_count=6)

pc.keyframe_action(barrel, "idle", "rotation_euler", [
    (0.0, pc.radians(0, 0, 0)),
    (1.0, pc.radians(-4, 0, 0)),
    (2.0, pc.radians(0, 0, 0)),
])
pc.keyframe_action(barrel, "attack", "location", [
    (0.0, (0.0, 0.0, 0.55)),
    (0.05, (0.0, 0.22, 0.6)),
    (0.4, (0.0, 0.0, 0.55)),
])

pc.export_glb("towers/orc_junk_cannon.glb")
