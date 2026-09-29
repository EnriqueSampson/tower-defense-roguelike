# Asset Licenses and Provenance

Every asset distributed with the game is listed here. Add a row before shipping any new font, texture, sound, or music file.

| Asset | Type | Source | License |
| --- | --- | --- | --- |
| `icon.svg` | Texture | Created for this project | Project license |
| Map, tower, creep, projectile, and effect visuals | Procedural (`draw_*` calls in `scripts/map`, `scripts/actors`) | Created for this project | Project license |
| All sound effects and the ambient music loop | Procedural (`scripts/autoload/audio_director.gd` synthesizes `AudioStreamWAV` at startup) | Created for this project | Project license |
| UI font | Godot built-in fallback font (`ThemeDB.fallback_font`) | Godot Engine | MIT (Godot) / OFL (bundled Noto fonts) |
| `addons/godotsteam/` | GDExtension binaries and scripts | GodotSteam 4.22 | MIT — see `addons/godotsteam/license.md` |
| Steamworks SDK redistributables (`libsteam_api.*`, `steam_api64.dll`) | Runtime library | Valve Steamworks SDK 1.65 | Steamworks SDK Access Agreement |

No third-party textures, sprites, fonts, or audio files are distributed. The classic Wintermaul layout is used as structural inspiration only; no original map assets are copied.
