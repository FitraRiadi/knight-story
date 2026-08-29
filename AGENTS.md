# User Info

- **Nama:** Fitra Riadi
- **Panggilan:** Fit
- **Sekolah:** SMK Merdeka Bandung, Kelas 12 RPL (Rekayasa Perangkat Lunak)

# Asisten

- **Nama:** Chapt
- Panggil saya Chapt, bukan opencode atau asisten.

# Gaya Bicara

- Santai, natural, gak kaku, gak kayak robot.
- Anggap aja lo partner project gue, bukan asisten resmi.
- Gausah terlalu humble, langsung cair aja.
- Gunakan bahasa Indonesia.

---

# AGENTS.md - Knight Story (Godot 4.7)

## Project Overview
- **Engine**: Godot 4.7 (config_version=5, features: "4.7", "Mobile")
- **Target**: Android (export preset: `com.iamfit.knightstory` → `Knight Story - V0.0.9.apk`)
- **Main Scene**: Set via UID in project.godot (`uid://hfftddt5j55h`)
- **Language**: GDScript with Indonesian comments, English identifiers

## Architecture & Directory Structure
```
scripts/
├── global/          # Autoload singletons (managers)
│   ├── sound_manager.gd         # Auto-attaches click sounds to all Buttons/TextureButtons
│   ├── transition_manager.gd    # Scene transitions with animated curtain
│   ├── TypewriterPlayer.gd      # Typewriter dialog system (signals: finished)
│   └── Typewritter.gd           # Legacy typewriter (unused?)
├── local/           # Scene-specific logic, organized by feature
│   ├── battle/                  # BattleManager (Control), turn-based combat
│   ├── mainmenu/                # Main menu UI
│   ├── characters/enemy/        # Enemy (BattleEnemy), EnemyAI, EnemyData
│   ├── gui/                     # UI components (popups, base classes, enchantment)
│   ├── items/                   # ItemData resource
│   ├── location/                # Map/room scripts
│   ├── cutscene/                # Prologue cutscene scripts
│   └── particles/               # Village particles
├── data/            # Static databases (RefCounted/Resources)
│   ├── weapon_database.gd       # WeaponDatabase (WeaponType, Rarity enums)
│   ├── enemies/EnemyDatabase.gd # Loads all .tres from res://data/enemies/
│   └── enchant_database.gd      # Enchantment data
data/
├── enemies/         # EnemyData .tres resources (loaded by EnemyDatabase)
└── items/           # ItemData .tres resources
scenes/              # .tscn scene files
assets/              # UI, fonts, art assets
```

## Autoload Singletons (project.godot)
| Name | Class | Purpose |
|------|-------|---------|
| `Typewritter` | `Typewritter` | Legacy? |
| `TypewriterPlayer` | `TypewriterPlayers` | Dialog typewriter (call `setup()` then `play()`) |
| `TransitionManager` | `TransitionManager` | `pindah_scene(path)` - animated scene change |
| `SoundManager` | `SoundManager` | Auto-binds click sound to all Buttons/TextureButtons |
| `EnemyDatabase` | `EnemyDatabase` | Loads all enemy .tres files at startup |
| `QuestDatabase` | `QuestDatabase` | Loads all quest .tres files at startup |

## Key Systems & Patterns

### Battle System
- **BattleManager** (`scripts/local/battle/BattleManager.gd`): Main battle scene (Control), manages player/enemy turns, UI bars, camera shake, blood vignette
- **Enemy** (`scripts/local/characters/enemy/Enemy.gd`): `class_name BattleEnemy`, AnimatedSprite2D, AI-driven actions (attack/defend/heal)
- **EnemyData** (`scripts/local/characters/enemy/EnemyData.gd`): Resource with base stats, `get_scaled_stats(level)` for level scaling
- **EnemyDatabase**: Scans `res://data/enemies/` for .tres files, caches by `enemy_id`

### Data Resources Pattern
All databases use static arrays of Dictionaries with `duplicate(true)` for safety:
- `WeaponDatabase.WEAPON_DATABASE` - weapons with id, type, rarity, stats, enchantments, materials
- `EnemyDatabase._enemies_cache` - loaded at runtime from .tres files
- Access via static methods: `get_weapon_by_id(id)`, `get_enemy_data(id)`

### Scene Transitions
```gdscript
TransitionManager.pindah_scene("res://scenes/location.tscn")
# Creates CanvasLayer curtain, animates close → change_scene_to_file → animate open
```

### Typewriter Dialog
```gdscript
TypewriterPlayer.setup(label, dialogs_array, char_delay, dialog_delay, use_click, cursor_char, keep_last)
TypewriterPlayer.play()  # emits "finished" signal when done
```

### Sound Manager
Auto-scans scene tree on `_ready` and `node_added` to bind `putar_suara_klik()` to all Button/TextureButton `pressed` signals. Also forces `mouse_filter = STOP` and `cursor = POINTING_HAND`.

## Important Conventions
- **UID-based references**: project.godot uses UIDs for main_scene, autoloads, font, icon
- **Indonesian comments**: Code comments are in Indonesian; variable/method names are English
- **Resource loading**: Uses `load()` for dynamic, `preload()` for constants, `DirAccess` for directory scanning
- **Signals over callbacks**: Battle system uses signals extensively (`action_finished`, `clicked`, `attack_hit`, `hp_changed`, `enemy_defeated`)
- **Tween-heavy animation**: UI animations use `create_tween()` with `set_parallel()`, `set_trans()`, `set_ease()`

## Export / Build
- **Android only**: Single export preset configured for arm64-v8a
- **Export path**: `./Knight Story - V0.0.9.apk`
- **Script export mode**: 2 (compiled/encrypted)
- **Run via Godot Editor**: F5 or Project → Run

## Gotchas for Agents
1. **No build/lint/test commands** - This is a Godot project; verify by running in editor
2. **UID references** - Don't hardcode paths for autoload/main_scene; they use UIDs
3. **Enemy data is file-based** - Adding enemies requires creating .tres files in `data/enemies/`
4. **SoundManager mutates scene tree** - Changes `mouse_filter` and `cursor` on all buttons globally
5. **BattleManager expects specific node structure** - Uses `@onready` with `$` paths like `$Camera2D`, `$atkBtn`, `$player-information/HPstatus/bar`
6. **Indonesian variable names in some scripts** - e.g., `pindah_scene`, `pindai_dan_koneksikan_tombol`, `putar_suara_klik`

## Running the Project
```bash
# Open in Godot 4.7+ editor and press F5
# Or from command line:
godot --path "D:\folder_fitra\Godot Project\knight-story"
```

## Adding New Enemies
1. Create `.tres` file in `data/enemies/` with `EnemyData` resource
2. Set `enemy_id`, `enemy_name`, stats, `sprite_frames`, `icon_enemy`
3. EnemyDatabase auto-loads on startup (scans directory)

## Adding New Quests
1. Create `.tres` file in `data/quests/` with `QuestData` resource
2. Set `quest_id`, `quest_name`, `description`, `quest_type`, `target`, `target_count`, rewards
3. QuestDatabase auto-loads on startup (scans directory)
4. Quest types: `play_games`, `collect_items`, `kill`, `gather`, `explore`

## Adding New Weapons
1. Add entry to `WeaponDatabase.WEAPON_DATABASE` array in `scripts/data/weapon_database.gd`
2. Follow existing structure: id, name, type, rarity, description, icon, enchantment[], stats{}, materials[]
