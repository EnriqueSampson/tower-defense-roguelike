#!/usr/bin/env python3
"""One-off generator for the ten MVP wave resources."""
from pathlib import Path

WAVES = [
    ("wave_01", 1, "Scouts", False, False, [("grunt", 5, 0.8, 1.0, 0.0)]),
    ("wave_02", 2, "Grunt Column", False, True, [("grunt", 8, 0.7, 1.3, 0.0)]),
    ("wave_03", 3, "Runners", False, False, [("runner", 8, 0.45, 1.0, 0.0), ("grunt", 4, 0.8, 1.5, 2.0)]),
    ("wave_04", 4, "First Brutes", False, True, [("brute", 3, 1.4, 1.0, 0.0), ("grunt", 6, 0.7, 1.7, 1.5)]),
    ("wave_05", 5, "Mixed Push", False, False, [("grunt", 8, 0.6, 2.0, 0.0), ("runner", 6, 0.4, 1.5, 1.0)]),
    ("wave_06", 6, "Menders", False, True, [("mender", 5, 1.0, 1.0, 0.0), ("brute", 3, 1.4, 1.4, 2.0)]),
    ("wave_07", 7, "Rush", False, False, [("runner", 12, 0.4, 2.0, 0.0)]),
    ("wave_08", 8, "Siege Line", False, True, [("brute", 6, 1.2, 1.8, 0.0), ("mender", 4, 1.0, 1.5, 3.0)]),
    ("wave_09", 9, "Full Assault", False, False, [("grunt", 10, 0.5, 3.5, 0.0), ("runner", 8, 0.4, 2.5, 1.0), ("brute", 4, 1.2, 2.2, 2.0)]),
    ("wave_10", 10, "The Frost Warlord", True, False, [("mender", 4, 1.0, 2.0, 0.0), ("warlord", 1, 1.0, 1.0, 6.0)]),
]

out_dir = Path(__file__).resolve().parent.parent / "resources" / "waves"
out_dir.mkdir(parents=True, exist_ok=True)

for wave_id, number, title, boss, offers, groups in WAVES:
    creep_ids = []
    for creep_id, *_ in groups:
        if creep_id not in creep_ids:
            creep_ids.append(creep_id)
    load_steps = 2 + len(creep_ids) + len(groups) + 1
    lines = [
        f'[gd_resource type="Resource" script_class="WaveDefinition" load_steps={load_steps} format=3]',
        "",
        '[ext_resource type="Script" path="res://scripts/data/wave_definition.gd" id="1_wave"]',
        '[ext_resource type="Script" path="res://scripts/data/wave_spawn_group.gd" id="2_group"]',
    ]
    for creep_id in creep_ids:
        lines.append(f'[ext_resource type="Resource" path="res://resources/creeps/{creep_id}.tres" id="creep_{creep_id}"]')
    lines.append("")
    group_ids = []
    for index, (creep_id, count, interval, health_mult, delay) in enumerate(groups, start=1):
        group_id = f"group_{index}"
        group_ids.append(group_id)
        lines += [
            f'[sub_resource type="Resource" id="{group_id}"]',
            'script = ExtResource("2_group")',
            f'creep = ExtResource("creep_{creep_id}")',
            f"count = {count}",
            f"spawn_interval = {interval}",
            f"health_multiplier = {health_mult}",
            f"delay_before = {delay}",
            "",
        ]
    group_refs = ", ".join(f'SubResource("{group_id}")' for group_id in group_ids)
    lines += [
        "[resource]",
        'script = ExtResource("1_wave")',
        f'id = "{wave_id}"',
        f"number = {number}",
        f'title = "{title}"',
        f'spawn_groups = Array[ExtResource("2_group")]([{group_refs}])',
        f"is_boss_wave = {'true' if boss else 'false'}",
        f"offers_upgrade_after = {'true' if offers else 'false'}",
        "",
    ]
    (out_dir / f"{wave_id}.tres").write_text("\n".join(lines))
    print("wrote", wave_id)
