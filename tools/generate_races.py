#!/usr/bin/env python3
"""Writes every race tower (resources/towers/), the races (resources/races/)
and the catalog's tower and race lists from tools/race_content.py.

    python3 tools/generate_races.py

Rerunning overwrites hand edits to those files: tune tools/race_content.py
instead, then check the result with tests/balance_harness.gd --race=<id>.
Models come from tools/blender/race_towers.py; run it first for new towers,
then `godot --headless --path . --import`.
"""
import re
from pathlib import Path

import race_content as rc

ROOT = Path(__file__).resolve().parent.parent
TOWERS_DIR = ROOT / "resources" / "towers"
RACES_DIR = ROOT / "resources" / "races"
CATALOG = ROOT / "resources" / "content_catalog.tres"
# Existing tower files keep their names so git history follows them.
FILE_NAMES = {"bolt": "bolt_tower", "cannon": "cannon_tower", "frost": "frost_tower", "sentry": "sentry_tower"}


def file_name(tower_id):
    return FILE_NAMES.get(tower_id, tower_id)


def uid_attr(asset_path):
    import_file = ROOT / "assets" / "models" / (asset_path + ".import")
    if import_file.exists():
        match = re.search(r'^uid="([^"]+)"', import_file.read_text(), re.M)
        if match:
            return f' uid="{match.group(1)}"'
    return ""


def color(rgb):
    return "Color(%s, %s, %s, 1)" % tuple(round(c, 3) for c in rgb)


def quote(text):
    return text.replace("\\", "\\\\").replace('"', '\\"')


def write_tower(spec):
    s = rc.tower(spec["id"])
    model = rc.model_path(s)
    options = ", ".join(f'"{o}"' for o in s["options"])
    text = f'''[gd_resource type="Resource" script_class="TowerDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/tower_definition.gd" id="1_tower"]
[ext_resource type="PackedScene"{uid_attr(model)} path="res://assets/models/{model}" id="2_model"]

[resource]
script = ExtResource("1_tower")
id = "{s["id"]}"
display_name = "{quote(s["name"])}"
role = "{quote(s["role"])}"
description = "{quote(s["desc"])}"
primary_color = {color(s["colors"][0])}
accent_color = {color(s["colors"][1])}
footprint = Vector2i(2, 2)
visual_scene = ExtResource("2_model")
cost = {s["cost"]}
damage = {s["damage"]}
attack_range = {round(s["range"] * rc.TOWER_PX, 1)}
attack_cooldown = {s["cooldown"]}
projectile_speed = {s["projectile_speed"]}
splash_radius = {round(s["splash"] * rc.TOWER_PX, 1)}
slow_factor = {s["slow"]}
slow_duration = {s["slow_duration"]}
armor_pierce = {s["pierce"]}
can_target_ground = {"true" if s["ground"] else "false"}
can_target_air = {"true" if s["air"] else "false"}
is_magic = {"true" if s["magic"] else "false"}
detection_range = {round(s["detection"] * rc.TOWER_PX, 1)}
default_targeting = {s["targeting"]}
tier = {s["tier"]}
upgrade_options = PackedStringArray({options})
sell_refund_percent = 70
'''
    (TOWERS_DIR / f"{file_name(s['id'])}.tres").write_text(text)


def write_race(race):
    roots = race["roots"]
    ext = [
        '[ext_resource type="Script" path="res://scripts/data/race_definition.gd" id="1_race"]',
        '[ext_resource type="Script" path="res://scripts/data/tower_definition.gd" id="2_tower"]',
        f'[ext_resource type="PackedScene"{uid_attr(race["builder"])} path="res://assets/models/{race["builder"]}" id="3_builder"]',
    ]
    for index, tower_id in enumerate(roots):
        ext.append(f'[ext_resource type="Resource" path="res://resources/towers/{file_name(tower_id)}.tres" id="t_{index}"]')
    refs = ", ".join(f'ExtResource("t_{index}")' for index in range(len(roots)))
    text = f'''[gd_resource type="Resource" script_class="RaceDefinition" load_steps={len(ext) + 1} format=3]

{chr(10).join(ext)}

[resource]
script = ExtResource("1_race")
id = "{race["id"]}"
display_name = "{quote(race["name"])}"
description = "{quote(race["description"])}"
color = {color(race["color"])}
builder_scene = ExtResource("3_builder")
towers = Array[ExtResource("2_tower")]([{refs}])
'''
    (RACES_DIR / f"{race['id']}.tres").write_text(text)


def update_catalog():
    text = CATALOG.read_text()
    text = re.sub(r'\[ext_resource type="Resource" path="res://resources/(towers|races)/[^"]+" id="(t|r)_[^"]+"\]\n', "", text)
    if "race_definition.gd" not in text:
        text = text.replace(
            '[ext_resource type="Script" path="res://scripts/data/run_upgrade_definition.gd" id="4_upgrade"]',
            '[ext_resource type="Script" path="res://scripts/data/run_upgrade_definition.gd" id="4_upgrade"]\n[ext_resource type="Script" path="res://scripts/data/race_definition.gd" id="5_race"]',
        )
    lines = [f'[ext_resource type="Resource" path="res://resources/towers/{file_name(s["id"])}.tres" id="t_{s["id"]}"]' for s in rc.TOWERS]
    lines += [f'[ext_resource type="Resource" path="res://resources/races/{r["id"]}.tres" id="r_{r["id"]}"]' for r in rc.RACES]
    anchor = text.index("[ext_resource", text.index("5_race"))
    anchor = text.index("\n", anchor) + 1
    text = text[:anchor] + "\n".join(lines) + "\n" + text[anchor:]
    tower_refs = ", ".join(f'ExtResource("t_{s["id"]}")' for s in rc.TOWERS)
    race_refs = ", ".join(f'ExtResource("r_{r["id"]}")' for r in rc.RACES)
    text = re.sub(r'towers = Array\[ExtResource\("2_tower"\)\]\(\[.*?\]\)', f'towers = Array[ExtResource("2_tower")]([{tower_refs}])', text)
    if "races = Array" in text:
        text = re.sub(r'races = Array\[ExtResource\("5_race"\)\]\(\[.*?\]\)', f'races = Array[ExtResource("5_race")]([{race_refs}])', text)
    else:
        text = text.replace("\nwaves = Array", f'\nraces = Array[ExtResource("5_race")]([{race_refs}])\nwaves = Array', 1)
    text = re.sub(r"load_steps=\d+", f"load_steps={text.count('[ext_resource') + 1}", text, count=1)
    CATALOG.write_text(text)


RACES_DIR.mkdir(parents=True, exist_ok=True)
for spec in rc.TOWERS:
    write_tower(spec)
for race in rc.RACES:
    write_race(race)
update_catalog()
print(f"wrote {len(rc.TOWERS)} towers, {len(rc.RACES)} races and the catalog lists")
