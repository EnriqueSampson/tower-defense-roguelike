#!/usr/bin/env python3
"""One-off generator for the run-upgrade resources."""
from pathlib import Path

CATEGORY = {"TOWER": 0, "ECONOMY": 1, "DEFENSE": 2, "TRADEOFF": 3}

# id, name, description, category, tags, overrides
UPGRADES = [
    ("bolt_damage", "Hardened Bolts", "Bolt Towers deal 30% more damage.", "TOWER", ["bolt"],
     {"tower_id": "bolt", "damage_multiplier": 1.3}),
    ("bolt_rapid", "Rapid Loaders", "Bolt Towers fire 20% faster.", "TOWER", ["bolt"],
     {"tower_id": "bolt", "cooldown_multiplier": 0.8}),
    ("cannon_splash", "Wide Shells", "Cannon Tower splash radius grows by half a tile.", "TOWER", ["cannon"],
     {"tower_id": "cannon", "splash_radius_bonus": 14.0}),
    ("cannon_damage", "Heavy Shells", "Cannon Towers deal 35% more damage.", "TOWER", ["cannon"],
     {"tower_id": "cannon", "damage_multiplier": 1.35}),
    ("cannon_shock", "Shockwave Shells", "Cannon hits also chill creeps by 15%. Requires a Cannon upgrade.", "TOWER", ["cannon"],
     {"tower_id": "cannon", "slow_factor_bonus": 0.15, "requires_tags": ["cannon"]}),
    ("frost_deep", "Deep Freeze", "Frost Towers slow 12% more.", "TOWER", ["frost"],
     {"tower_id": "frost", "slow_factor_bonus": 0.12}),
    ("frost_range", "Frost Reach", "Frost Towers gain 20 range.", "TOWER", ["frost"],
     {"tower_id": "frost", "range_bonus": 20.0}),
    ("all_range", "Watchtowers", "Every tower gains 10 range.", "TOWER", ["range"],
     {"range_bonus": 10.0}),
    ("bounty_bonus", "Bounty Contracts", "Kills award 20% more team gold.", "ECONOMY", ["economy"],
     {"bounty_multiplier": 1.2}),
    ("cheap_upgrades", "Master Smiths", "Tower upgrades cost 25% less.", "ECONOMY", ["economy"],
     {"upgrade_cost_multiplier": 0.75}),
    ("better_refunds", "Salvage Crews", "Selling refunds 20% more of the invested gold.", "ECONOMY", ["economy"],
     {"sell_refund_bonus": 20}),
    ("war_chest", "War Chest", "Immediately gain 150 team gold.", "ECONOMY", ["economy"],
     {"immediate_gold": 150}),
    ("extra_lives", "Reinforced Gate", "The final gate gains 5 shared lives.", "DEFENSE", ["defense"],
     {"extra_lives": 5}),
    ("p9_bastion", "Bastion of Nine", "Towers built inside Position 9 deal 40% more damage.", "DEFENSE", ["defense"],
     {"final_position_damage_multiplier": 1.4}),
    ("overclock", "Overclocked Foundries", "All towers deal 25% more damage, but creeps move 15% faster.", "TRADEOFF", ["damage_tradeoff"],
     {"damage_multiplier": 1.25, "creep_speed_multiplier": 1.15, "excludes_tags": ["damage_tradeoff"]}),
    ("glass_cannons", "Glass Cannons", "All towers deal 50% more damage, but building costs 30% more.", "TRADEOFF", ["damage_tradeoff"],
     {"damage_multiplier": 1.5, "build_cost_multiplier": 1.3, "excludes_tags": ["damage_tradeoff"]}),
    ("frugal", "Frugal Engineers", "Towers cost 15% less to build, but bounties shrink 15%.", "TRADEOFF", ["economy_tradeoff"],
     {"build_cost_multiplier": 0.85, "bounty_multiplier": 0.85}),
]

DEFAULTS = {
    "tower_id": "",
    "damage_multiplier": 1.0,
    "range_bonus": 0.0,
    "cooldown_multiplier": 1.0,
    "splash_radius_bonus": 0.0,
    "slow_factor_bonus": 0.0,
    "bounty_multiplier": 1.0,
    "build_cost_multiplier": 1.0,
    "upgrade_cost_multiplier": 1.0,
    "sell_refund_bonus": 0,
    "extra_lives": 0,
    "immediate_gold": 0,
    "final_position_damage_multiplier": 1.0,
    "creep_speed_multiplier": 1.0,
    "requires_tags": [],
    "excludes_tags": [],
}


def fmt(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, list):
        inner = ", ".join(f'"{item}"' for item in value)
        return f"PackedStringArray({inner})"
    if isinstance(value, str):
        return f'"{value}"'
    return str(value)


out_dir = Path(__file__).resolve().parent.parent / "resources" / "upgrades"
out_dir.mkdir(parents=True, exist_ok=True)

for upgrade_id, name, description, category, tags, overrides in UPGRADES:
    values = dict(DEFAULTS)
    values.update(overrides)
    lines = [
        '[gd_resource type="Resource" script_class="RunUpgradeDefinition" load_steps=2 format=3]',
        "",
        '[ext_resource type="Script" path="res://scripts/data/run_upgrade_definition.gd" id="1_upgrade"]',
        "",
        "[resource]",
        'script = ExtResource("1_upgrade")',
        f'id = "{upgrade_id}"',
        f'display_name = "{name}"',
        f'description = "{description}"',
        f"category = {CATEGORY[category]}",
        f"tags = {fmt(tags)}",
    ]
    for key in DEFAULTS:
        lines.append(f"{key} = {fmt(values[key])}")
    lines.append("")
    (out_dir / f"{upgrade_id}.tres").write_text("\n".join(lines))
    print("wrote", upgrade_id)
