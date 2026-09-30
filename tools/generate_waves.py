#!/usr/bin/env python3
"""Generates the 30 classic levels in resources/waves/ and the wave list in
resources/content_catalog.tres.

    python3 tools/generate_waves.py

Rerunning overwrites hand edits to wave files: tune the curves and table here
instead, then check the result with tests/balance_harness.gd.

Creep health and bounty scale per level: every group's health multiplier is
HEALTH_GROWTH ** (level - 1) times its own factor, and its bounty multiplier
BOUNTY_GROWTH ** (level - 1) (bosses keep their own bounty). Bosses carry their health in their own
definition, so their groups use BOSS_HEALTH_GROWTH, a gentler curve.
"""
import re
from pathlib import Path

HEALTH_GROWTH = 1.17
BOSS_HEALTH_GROWTH = 1.03
BOUNTY_GROWTH = 1.06
DEFAULT_BUILD_SECONDS = 0  # 0 = BalanceConfig.BUILD_DURATION
BOSS_BUILD_SECONDS = 35
OFFER_EVERY = 3

BOSSES = {"regional_manager", "warlord", "overtime_wyrm", "compliance_lich", "phantom_auditor", "the_board"}

# (title, [(creep_id, count, spawn_interval, extra_health_factor, delay_before)])
LEVELS = [
    ("Scouts", [("grunt", 5, 0.8, 1.0, 0.0)]),
    ("Grunt Column", [("grunt", 8, 0.7, 1.0, 0.0)]),
    ("Runners", [("runner", 8, 0.45, 1.0, 0.0), ("grunt", 4, 0.8, 1.0, 2.0)]),
    ("First Brutes", [("brute", 3, 1.4, 1.0, 0.0), ("grunt", 6, 0.7, 1.0, 1.5)]),
    ("The Regional Manager", [("grunt", 6, 0.7, 1.0, 0.0), ("regional_manager", 1, 1.0, 1.0, 4.0)]),
    ("Menders", [("mender", 5, 1.0, 1.0, 0.0), ("brute", 3, 1.4, 1.0, 2.0)]),
    ("Frequent Flyers", [("gargoyle", 8, 0.8, 1.0, 0.0)]),
    ("Intern Orientation", [("imp", 20, 0.25, 1.0, 0.0)]),
    ("Middle Management", [("slime", 6, 1.1, 1.0, 0.0)]),
    ("The Frost Warlord", [("mender", 4, 1.0, 1.0, 0.0), ("warlord", 1, 1.0, 1.0, 6.0)]),
    ("Rush", [("runner", 14, 0.4, 1.0, 0.0)]),
    ("Remote Workers", [("shade", 6, 1.0, 1.0, 0.0), ("grunt", 6, 0.7, 1.0, 1.0)]),
    ("Warded Golems", [("golem", 5, 1.4, 1.0, 0.0), ("grunt", 6, 0.7, 1.0, 1.0)]),
    ("Layover", [("gargoyle", 12, 0.7, 1.0, 0.0)]),
    ("Wyrm of Unpaid Overtime", [("gargoyle", 6, 0.8, 1.0, 0.0), ("overtime_wyrm", 1, 1.0, 1.0, 5.0)]),
    ("Siege Line", [("brute", 8, 1.1, 1.0, 0.0), ("mender", 4, 1.0, 1.0, 3.0)]),
    ("Hostile Takeover", [("slime", 6, 1.0, 1.0, 0.0), ("runner", 10, 0.4, 1.0, 1.0)]),
    ("Open Office Plan", [("imp", 30, 0.2, 1.0, 0.0)]),
    ("Hybrid Work", [("shade", 8, 0.9, 1.0, 0.0), ("runner", 8, 0.4, 1.0, 1.0)]),
    ("The Compliance Lich", [("golem", 6, 1.2, 1.0, 0.0), ("compliance_lich", 1, 1.0, 1.0, 5.0)]),
    ("Red-Eye", [("gargoyle", 16, 0.6, 1.0, 0.0)]),
    ("Restructuring", [("slime", 10, 0.9, 1.0, 0.0)]),
    ("Iron Wall", [("golem", 8, 1.2, 1.0, 0.0), ("brute", 6, 1.1, 1.0, 1.0)]),
    ("Stealth Layoffs", [("shade", 12, 0.8, 1.0, 0.0)]),
    ("The Phantom Auditor", [("shade", 6, 0.9, 1.0, 0.0), ("phantom_auditor", 1, 1.0, 1.0, 5.0)]),
    ("Everything Everywhere", [("grunt", 10, 0.5, 1.0, 0.0), ("runner", 8, 0.4, 1.0, 1.0), ("gargoyle", 6, 0.7, 1.0, 1.0)]),
    ("Quarterly Crunch", [("imp", 40, 0.18, 1.0, 0.0), ("mender", 6, 0.9, 1.0, 1.0)]),
    ("Mass Delegation", [("slime", 12, 0.8, 1.0, 0.0), ("golem", 4, 1.2, 1.0, 1.0)]),
    ("Full Assault", [("brute", 10, 0.9, 1.0, 0.0), ("shade", 8, 0.8, 1.0, 1.0), ("gargoyle", 8, 0.7, 1.0, 1.0)]),
    ("The Board of Directors", [("golem", 6, 1.2, 1.0, 0.0), ("the_board", 1, 1.0, 1.0, 6.0)]),
]

ROOT = Path(__file__).resolve().parent.parent
WAVES_DIR = ROOT / "resources" / "waves"
CATALOG = ROOT / "resources" / "content_catalog.tres"


def write_wave(number, title, groups):
    wave_id = f"wave_{number:02d}"
    creep_ids = []
    for creep_id, *_ in groups:
        if creep_id not in creep_ids:
            creep_ids.append(creep_id)
    is_boss = any(creep_id in BOSSES for creep_id, *_ in groups)
    lines = [
        f'[gd_resource type="Resource" script_class="WaveDefinition" load_steps={2 + len(creep_ids) + len(groups) + 1} format=3]',
        "",
        '[ext_resource type="Script" path="res://scripts/data/wave_definition.gd" id="1_wave"]',
        '[ext_resource type="Script" path="res://scripts/data/wave_spawn_group.gd" id="2_group"]',
    ]
    for creep_id in creep_ids:
        lines.append(f'[ext_resource type="Resource" path="res://resources/creeps/{creep_id}.tres" id="creep_{creep_id}"]')
    lines.append("")
    group_ids = []
    for index, (creep_id, count, interval, factor, delay) in enumerate(groups, start=1):
        growth = BOSS_HEALTH_GROWTH if creep_id in BOSSES else HEALTH_GROWTH
        health = round(factor * growth ** (number - 1), 2)
        # Boss bounties already scale with the boss; only regular creeps grow.
        bounty = 1.0 if creep_id in BOSSES else round(BOUNTY_GROWTH ** (number - 1), 2)
        group_id = f"group_{index}"
        group_ids.append(group_id)
        lines += [
            f'[sub_resource type="Resource" id="{group_id}"]',
            'script = ExtResource("2_group")',
            f'creep = ExtResource("creep_{creep_id}")',
            f"count = {count}",
            f"spawn_interval = {interval}",
            f"health_multiplier = {health}",
            f"bounty_multiplier = {bounty}",
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
        f"is_boss_wave = {'true' if is_boss else 'false'}",
        f"offers_upgrade_after = {'true' if number % OFFER_EVERY == 0 and number < len(LEVELS) else 'false'}",
        f"build_seconds = {BOSS_BUILD_SECONDS if is_boss else DEFAULT_BUILD_SECONDS}.0",
        "",
    ]
    (WAVES_DIR / f"{wave_id}.tres").write_text("\n".join(lines))
    return wave_id


def update_catalog(wave_ids):
    text = CATALOG.read_text()
    text = re.sub(r'\[ext_resource type="Resource" path="res://resources/waves/[^"]+" id="w_\d+"\]\n', "", text)
    wave_ext = "".join(f'[ext_resource type="Resource" path="res://resources/waves/{w}.tres" id="w_{w[5:]}"]\n' for w in wave_ids)
    text = text.replace("\n[resource]", wave_ext + "\n[resource]", 1)
    refs = ", ".join(f'ExtResource("w_{w[5:]}")' for w in wave_ids)
    text = re.sub(r"waves = Array\[ExtResource\(\"3_wave\"\)\]\(\[.*?\]\)", f'waves = Array[ExtResource("3_wave")]([{refs}])', text)
    ext_count = text.count("[ext_resource")
    text = re.sub(r"load_steps=\d+", f"load_steps={ext_count + 1}", text, count=1)
    CATALOG.write_text(text)


WAVES_DIR.mkdir(parents=True, exist_ok=True)
ids = [write_wave(number, title, groups) for number, (title, groups) in enumerate(LEVELS, start=1)]
update_catalog(ids)
print(f"wrote {len(ids)} waves and the catalog wave list")
