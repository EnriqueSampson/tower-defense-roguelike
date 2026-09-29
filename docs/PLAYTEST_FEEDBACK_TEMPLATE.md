# Playtest Feedback and Log Collection

## Collecting logs and crash information

File logging is enabled in `project.godot` (`debug/file_logging/enable_file_logging=true`).

| Platform | Log location |
| --- | --- |
| macOS | `~/Library/Application Support/Godot/app_userdata/tower defense roguelike/logs/` |
| Windows | `%APPDATA%\Godot\app_userdata\tower defense roguelike\logs\` |
| Settings file | same `app_userdata` folder, `settings.cfg` |

1. Reproduce the issue once if possible.
2. Copy the newest `godot.log` (and any `godot_*.log` rotated files) from the folder above.
3. Note the **seed** and **wave** from the sidebar (`SEED  ####`) or the end screen.
4. On a crash, also capture the OS crash report (macOS: Console → Crash Reports; Windows: Event Viewer → Application) and the terminal output if launched from a console wrapper.
5. Attach screenshots or a short recording when the report is about readability or UI overlap.

## Feedback form (one per run)

```
Build version / protocol:      v0.2.0 / 2
Platform + hardware:           
Players (solo / host+N):       
Your position(s):              
Seed:                          
Result and wave reached:       
Run duration:                  

Onboarding
- Could you identify your area without help?          yes / no / notes
- Did you understand why a placement failed?          yes / no / notes
- Did you understand the wave preview and boss warning?

Mazing and towers
- Which tower felt best / worst and why?
- Did any placement feel wrong (blocked when it should not be, or vice versa)?
- Was selling / upgrading / target priority clear?

Co-op
- Did you know which positions were yours vs. host-controlled?
- Did shared gold cause friction?
- Any desync you noticed (creep alive on one screen, dead on another)?

Roguelike
- Which upgrades did you take? Were the offers interesting?
- Did any upgrade feel mandatory or useless?

Readability and audio
- Anything unreadable at your resolution?
- Any missing or annoying sound?

Performance
- Lowest fps you noticed and when:
- Any stutter during wave start or boss?

Defects (one per line, with seed + wave):
```
