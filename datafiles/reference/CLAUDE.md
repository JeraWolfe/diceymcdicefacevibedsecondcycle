# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**DiceyMcDiceFaces — Charma for Alternity**: A character manager for the Alternity Science Fiction RPG (TSR, 1998), built in GameMaker 2024.14.4.222. Single-object architecture (`obj_game`) with 8 GML scripts, 10 player tabs + 5 GM tabs, and a JSON-driven data pipeline. Resolution: scales to display, mouse-only input. ~8,100 lines across 11 source files, 23 datafiles.

## Build & Run

Open `diceymcdicefacevibed.yyp` in GameMaker 2024. Press F5 to run. No external dependencies. On first launch, JSON config files auto-generate in the game's save directory (`%AppData%/Local/diceymcdicefacevibed/`). Delete any JSON file to force regeneration from hardcoded defaults.

## Code Style

- **Variable names**: Verbose descriptive camelCase. NEVER use single-letter variable names except `_i`, `_j`, `_k` as loop counters. Examples: `_factionName` not `_f`, `_partyChar` not `_pc`, `_loreData` not `_lr`, `_templateIndex` not `_tidx`.
- **GML convention**: All locals prefixed with underscore (`_variableName`).
- **Layout ordering**: Static-length content first, variable-length content last in scrollable views.

## Architecture

All game logic lives in one object (`obj_game`) with three events:
- **Create_0.gml** — Initialization: `init_all_data()`, `load_campaign()`, all UI state, GM state variables
- **Step_0.gml** — Input: mouse-driven. Right panel buttons process first (all modes). Then routes to GM tools (`gm_state="gm"`), player char edit (`gm_state="edit"`), or player mode. Dispatches to tab handlers.
- **Draw_64.gml** — Render: gradient background, GM tools screen OR player character sheet, right panel with dice roller. Registers button rects in `btn` struct each frame.

### Script Hierarchy

| Script | Role |
|---|---|
| `scr_ui_helpers` | **Core UI**: `btn_clicked()`, dropdown system, `meta_roll()`, `apply_fx_modifiers()`, all roll request builders |
| `scr_data_loader` | **JSON pipeline**: `init_all_data()`, `read_json()`/`write_json()`, campaign persistence (`save_campaign`/`load_campaign`/`scan_characters_directory`) |
| `scr_alternity_statblock` | **Character data**: `create_statblock()`, `update_hero()`, export/import, portrait system, party/NPC management (`add_to_party`, `add_to_npcs`, `move_npc_to_party`, `export_campaign_full`), damage parser, lore struct |
| `scr_draw_tabs` | **Tab renderers**: 10 player tab draw functions + 5 GM tab draw functions + GM helper functions |
| `scr_tab_handlers` | **Tab input**: 10 player tab handlers (incl. `handle_tab_aura`) + 4 GM tab handlers |
| `scr_skill_costs` | **Skill economy**: PHB two-tier costs, rank escalation, FX management (perks/flaws/cybertech) |
| `scr_chargen` | **Character generation**: species/profession lookup, `generate_random_character()`, `generate_quick_npc()`, career application |
| `scr_dice` | **Dice engine**: `alternity_check()`, `alternity_action_check()`, situation die from `global.config.dice.steps` |

## GM Mode

GM mode replaces the character sheet with a dedicated 5-tab GM screen:
- **Party tab** (0): Party members with senses, Resolve, resistance mods, enhanced senses, psionics
- **NPCs tab** (1): NPCs organized by faction/team. Quick NPC generation from GMG templates.
- **Encounter tab** (2): Initiative bar (4 phases with names), per-character AC/phase/actions/res mods/durability. Roll All Init / New Round / Clear Init.
- **Campaign tab** (3): Master roster of all character file paths. Scan/Import/Export.
- **Resources tab** (4): Scrollable GM customization guide — how to edit equipment, skills, FX, templates, species JSON files.

State: `gm_mode` (bool), `gm_state` ("gm" or "edit"), `gm_tab` (0-4). Edit enters player char sheet. "Back to GM" returns.

## Player Tabs

0=Character, 1=Equipment, 2=Combat, 3=Psionics, 4=Perks/Flaws, 5=Cybertech, 6=Roll Log, 7=Info, 8=Grid, 9=Aura/Lore

### Aura/Lore Tab (Tab 9)
Character identity and PHB Step 8 attributes. `hero.lore` struct: height, weight, hair, gender, moral_attitude, temperament[], motivations[], personality, lifepath. Interactive for all characters except Sergeant Voss (read-only template). Clickable pill buttons for temperament (25 options, pick 2-3) and motivations (16 options, pick 1-2). Edit buttons for freeform fields.

## Critical Patterns

### btn_clicked(key)
Draw_64 registers button rects: `btn.myButton = [x1, y1, x2, y2]`. Step_0 checks: `if (btn_clicked("myButton")) { ... }`.

### meta_roll(stat, request)
**Single entry point for ALL dice checks.** `build_*_request()` → `apply_fx_modifiers()` → wound penalty → `alternity_check()` → `log_roll()`.

### update_hero(stat)
**Must be called after ANY character modification.** Recalculates action check, durability, skill scores, portrait.

### Unified FX System
`{name, type, quality, active}` for perks/flaws/cybertech. Definitions in `fx_database.json`. Three modes: `keyword_tiers`, `quality_scale`, `fixed`. Resolved via `apply_fx_modifiers()`.

## Data Model

### JSON Data Files (12 in datafiles/)
`config.json`, `professions.json`, `skills.json`, `species.json`, `careers.json`, `names.json`, `fx_database.json`, `keyword_tree.json`, `equipment.json`, `programs.json`, `npc_templates.json`, `changelog.json`

### Reference Files (8 in datafiles/reference/)
`CLAUDE.md`, `CODEBASE_REFERENCE.txt`, `Changelog.txt`, `Master-Sidebar.json`, `Master-Sidebar.txt`, `about.txt`, `statblockfunctionlist.txt`, `the_story_so_far.txt`

### Campaign Persistence
Characters save to `working_directory + "characters/"` (game folder, not AppData). Stored in `global.save_path`. `campaign.json` and `recent_characters.json` remain in the sandbox save area (`%AppData%/Local/diceymcdicefacevibed/`). `characters/*.json` — individual saves.

### Character Save Format
Compact JSON v4: skills as arrays, weapons as 7-element arrays, abilities as uppercase keys. Lore struct with PHB Step 8 attributes. Import handles v2/v3/v4.

## Changelog

Entries in `datafiles/changelog.json`. Add new entry at top of `entries` array with version, title, date, notes[], dev_commentary. Dev commentaries compiled in `the_story_so_far.txt`.
