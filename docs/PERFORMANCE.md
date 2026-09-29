# Performance Budgets and Profiling

Targets are for the busiest wave (wave 9 "Full Assault" at nine-player scale, or wave 10 with bosses) on the two reference machines:

- **Reference low end:** 2016 MacBook Pro, Intel Iris Graphics 550, GL Compatibility renderer.
- **Reference Windows:** mid-range laptop with integrated graphics, Windows 10/11, GL Compatibility.

## Budgets

| Metric | Budget | Notes |
| --- | --- | --- |
| Frame rate floor | 60 fps at 1280x800 and 1920x1080 | Measured with `Engine.get_frames_per_second()` during the busiest 10 seconds |
| Host frame time | ≤ 12 ms total; ≤ 4 ms in GDScript `_process` | Host also runs targeting, combat, snapshots |
| Client frame time | ≤ 10 ms total | Clients only simulate movement and render |
| Active creeps | ≤ 300 simultaneously | Nine positions × largest group at full scale |
| Towers | ≤ 400 | 72x80 map, roughly a sixth of build tiles |
| Projectiles + effects | ≤ 250 live projectiles, ≤ 200 effects | `EffectsLayer` draws from one node |
| Network (host upstream) | ≤ 40 KB/s per client | Creep snapshot ≈ 60 B/creep at 0.15 s; state snapshot ≤ 8 KB at 0.5 s |
| Startup | ≤ 3 s to lobby, ≤ 2 s lobby → game | Includes procedural audio synthesis |

## Profiling procedure

1. Run the windowed smoke test and confirm fps: `godot --path . --script res://tests/visual_smoke.gd` (prints fps and `frames_drawn` at frame 200 and writes `/tmp/wintermaul_smoke.png` plus `/tmp/wintermaul_zoomed.png`). Keep the window in the foreground: macOS stops drawing occluded windows, so `frames_drawn` far below the frame count means the numbers are meaningless. `Performance.TIME_PROCESS` includes rendering and the vsync wait, so it reads ≈ 16.7 ms at a steady 60 fps.
2. Open the project in the editor, enable **Debugger → Profiler** and **Monitors**, run a solo game, and skip waves with **Launch Wave** until wave 9.
3. Record: frame time, `Process` time for `game_controller.gd`, `wintermaul_map.gd`, `tower.gd`, `route_runner.gd`; object count; draw calls; `Network → Bandwidth`.
4. For multiplayer, host on the reference low-end machine with two clients and repeat, reading **Monitors → Network** on the host.
5. File results in the playtest log alongside the build version and seed.

## Optimization policy

Optimize only where profiling shows a budget breach. Current hot paths and their mitigations:

- **Targeting:** each tower scans active creeps once per cooldown expiry, not every frame. If tower count × creep count exceeds budget, add a grid bucket in `WintermaulMap.get_active_creeps()`.
- **Terrain:** the static 72x80 terrain is baked into one mipmapped texture (ground, pads, ownership tint) on an unshaded ground quad and only rebakes when ownership changes. Hedge walls are one baked `ArrayMesh`, route hints are one line mesh, and the hover preview moves two decal quads instead of repainting.
- **Actors:** towers and creeps are `Node3D`s whose primitive geometry is baked per kind into cached `ArrayMesh`es (`MeshBuilder`), so each actor is one or two draw calls sharing a handful of `MeshPalette` materials. Slow/hit feedback swaps a shared `material_override` rather than rebuilding meshes.
- **Canvas overlays:** labels redraw only when the camera view changes (`StaticCanvas`); creep health bars and the placement reason redraw every frame (`DynamicCanvas`) via `Camera3D.unproject_position`.
- **Effects:** transient feedback is drawn by `EffectsLayer` from a single array, projected to the screen; no per-effect nodes.
- **Projectiles:** simple `Node3D` actors with a shared sphere mesh. Pool them only if instantiation shows up in the profiler.
- **Snapshots:** creep snapshots are unreliable/ordered and only sent when peers exist; state snapshots are event-driven plus a 0.5 s heartbeat.
- **Audio:** all streams are synthesized once at startup; the music pad is skipped in headless runs.
