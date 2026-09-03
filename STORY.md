# Knight Story — Game Story Flow

## 📋 Overview

**Genre:** Dark Fantasy RPG (Turn-Based, Storytelling, Pixel Art)
**POK:** First-Person View (FPS) untuk semua lokasi
**Tone:** Dark & Serious, Melancholic, Mysterious

---

## 🎮 Game Flow

```
MAIN MENU (= PROLOGUE SCENE)
  → New Game
	→ PROLOGUE (seamless, langsung lanjut)
	  → LOTUS VILLAGE (Home Base)
		→ MAP SCREEN (Navigate)
		  → COMBAT ZONES (Explore + Battle)
			→ STORY PROGRESSION
```

---

## 🖥️ Main Menu (= Prologue Scene)

### Scene Setup
- **View:** FPS — Knight duduk di api unggun
- **Waktu:** Malam
- **Suasana:** Gelap, sunyi, api unggun berkedip
- **Musik:** Ambient, melancholic
- **Particle:** Api unggun berkedip, asap naik, bintang berkelip

### UI Elements
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│              KNIGHT STORY                               │
│              (fade in perlahan, 1-2 detik)              │
│                                                         │
│              [ New Game ]                               │
│              [ Continue ] (hanya jika ada save)         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Button Logic
- **New Game:** Fade out menu → Knight berdiri → Prologue berlanjut
- **Continue:** Load save → Fade to Village
- **Achievement:** (belum implement)

---

## 📜 Prologue

### Scene 1: The Fire (Awal)
```
Knight duduk di api unggun
Suasana: Malam, angin bertiup, api berkedip
Tidak ada dialog, cuma atmosphere
Durasi: 3-5 detik (atau sampai player klik "New Game")
```

### Scene 2: The Departure (Setelah New Game)
```
Knight berdiri dari api unggun
Teks muncul (typewriter):
  "The road forgets those who walk it..."
  "But some roads refuse to be forgotten."

Knight mulai berjalan ke arah jalan
Fade to black
Durasi: 10 detik
```

### Scene 3: The Journey
```
Scene: Jalan sepi di malam hari (pixel art road)
Knight berjalan dari kiri ke kanan
Teks (typewriter):
  "The night was quiet... too quiet."
  "But somewhere in the darkness, a light flickered."

Knight melihat cahaya di kejauhan (Lotus Village)
Durasi: 10 detik
```

### Scene 4: Approaching Village
```
Scene: Lotus Village terlihat dari kejauhan (FPS view)
Knight mendekat ke arah village
Teks (typewriter):
  "Lotus Village. A place where travelers rest..."
  "And where secrets linger in the shadows."

Knight masuk village gates
Fade to black
Durasi: 8 detik
```

### Scene 5: Chapter Title
```
Chapter 1: Lotus Village
(muncul perlahan, lalu fade out)
Durasi: 3 detik
```

---

## 🏘️ Lotus Village (Home Base)

### Arrival
```
Scene: Lotus Village (FPS POV)
Suasana: Malam, lampu-lampu menyala, tenang
Tidak ada combat di sini (SAFE ZONE)
```

### NPC Meeting (Pertama Kali)

#### Robert (Tavern Keeper)
```
Lokasi: Tavern
Sapaan:
  "Welcome, traveler. I'm Robert."
  "You look like you've been on the road for quite some time."
  "What brings a knight like you to a place like this?"

Personality:
  - Ramah tapi tajam
  - Suka gosip, tau banyak tentang desa
  - Kadang mysterious
```

#### Gareth (Blacksmith)
```
Lokasi: Blacksmith
Sapaan:
  "Ah, a traveler. Your armor tells stories..."
  "And your eyes tell more."
  "I'm Gareth. If you need anything forged or mended, you've come to the right place."

Personality:
  - Tenang, bijaksana
  - Sedikit mysterious
  - Master craftsman
```

### Story Trigger
```
Setelah meet kedua NPC:

Robert: "Be careful out there. The road has changed since you arrived."
Gareth: "The forest has been restless lately. Something stirs in the shadows."

→ Player sadar: ada yang salah di sekitar desa
→ Terserah player: explore village dulu atau langsung ke forest
```

---

## 🗺️ Map Screen

### Akses
```
Klik [Maps] di HUD → Buka Map Screen
```

### Layout
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   [Forest of Shadow]                                    │
│          |                                              │
│   [Ruins]---[LOTUS VILLAGE]---[Old Road]                │
│          |                                              │
│   [Cave] (locked)                                       │
│                                                         │
│   ▲ Player Location                                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Lokasi

| Lokasi | Status | Type | Akses |
|--------|--------|------|-------|
| Lotus Village | Unlocked | Safe Hub | Home base |
| Forest of Shadow | Unlocked | Combat Zone | Klik untuk travel |
| Old Road | Unlocked | Combat Zone | Klik untuk travel |
| Ruins | Unlocked | Story Zone | Klik untuk travel |
| Cave | Locked | Mixed | Belum terbuka |

### Travel Logic
```
Klik lokasi → TransitionManager.pindah_scene()
  → Arrival text (first visit only)
	→ Masuk scene lokasi
```

---

## 🌲 Forest of Shadow (Combat Zone)

### First Visit - Arrival Text
```
Random atmospheric text (first time only):
  "The shadows deepen here. Something watches..."
  "The air grows cold. You are not alone."
  "Twisted trees block the moonlight. Danger lurks."

→ 2-3 detik, lalu scene playable
```

### Exploration
```
Player bisa explore forest scene
Random encounter trigger (timer-based):
  → Tiap 15-30 detik, chance encounter
  → "Something stirs in the shadows..."
	→ [Fight] → Battle
	→ [Flee] → Kembali ke forest (chance kecil enemy follow)
```

### Return
```
Klik [Maps] → Return ke Map Screen
```

---

## ⚔️ Battle (FPS POV)

### Battle Intro
```
Teks: "The darkness finds those who wander..."
Camera shake, enemy spawn animation
```

### Turn-Based Combat
```
Player Actions:
  [Attack] → Quick Time Event (QTE bar)
  [Defend] → Recover stamina, reduce damage
  [Skill] → Action cards (Poison, etc.)
  [Backpack] → Use items
  [Run] → (hidden/disabled)

Enemy Actions:
  AI-driven (attack/defend/heal)
  Emotion system (calm, angry, fearful, etc.)

Wave System:
  2-5 waves per battle
  1-3 enemies per wave
```

### Battle End
```
Scoreboard:
  - Enemies defeated
  - Accuracy %
  - Parry %

[Continue] → Return ke Forest / Map / Village
```

---

## 🔄 Post-Battle Flow

### Setelah Battle Selesai
```
Option A: Return ke Forest (explore lagi)
Option B: Return ke Map Screen (pilih lokasi lain)
Option C: Return ke Village (rest, shop, NPC)
```

### Story Progression
```
Jika first battle selesai:
  Teks: "For now, the road is quiet. But only for now..."
  
Jika story mission selesai:
  → Return ke Village
	→ NPC dialog baru
	  → Story unfolds
		→ Mission baru unlocked
```

---

## 📊 Side Content

### Tavern (Robert)
```
[Shop] → Beli items (health potion, attack potion)
[Sell] → Jual items
[Games] → Mini-games (3G entry fee):
  - Find The Card
  - Word Chain
  - Brew Challenge
[Quests] → Side quests (optional)
```

### Quest Board
```
Side quests (repeatable):
  - Kill X enemies
  - Collect X items
  - Win X games
  - Explore X locations

Reward: Gold, items, EXP
```

### Blacksmith (Gareth)
```
[Weapons] → Browse weapons
[Armor] → (belum implement)
[Tools] → (belum implement)
[Rings] → (belum implement)

Crafting: (belum implement)
```

---

## 💾 Save/Load System

### Save Data
```
PlayerData (binary):
  - Player stats
  - Inventory (battle + chest)
  - Gold
  - Level, EXP

Quest State (JSON):
  - Active quests
  - Quest progress
  - Completed quests
```

### Save Location
```
user://.knight/sys/cache/data.res (binary)
user://.knight/sys/cache/quests.json (JSON)
```

---

## 🎯 Mission System

### Story Missions (Linear)
```
Mission 1: Investigate the Forest
  → Trigger: Setelah meet NPCs
  → Lokasi: Forest of Shadow
  → Battle: 1-2 waves, skeleton enemies
  → Return: Village, story continues

Mission 2: Explore the Ruins
  → Trigger: Setelah Mission 1 selesai
  → Lokasi: Ruins
  → Battle + Lore discovery
  → Return: Village, new info unlocked

Mission 3: ???
  → Belum ditentukan
```

### Side Quests (Optional)
```
Quest Board → Accept quest
  → Complete → Reward
  → Repeatable
```

---

## 🎬 Scene Transition

### Transisi antar Scene
```
TransitionManager.pindah_scene(path):
  1. Create CanvasLayer (black curtain)
  2. Show location name text
  3. Animate curtain close (0.6s)
  4. Change scene
  5. Animate curtain open (0.6s)
  6. Free transition objects
```

---

## 📁 File Structure

### Scenes
```
scenes/
├── menu/mainmenu.tscn (prologue scene)
├── cutscene/scene_prologue.tscn
├── locations/maps/lotus_village/lotus_village.tscn
├── locations/room/tavern/tavern.tscn
├── locations/room/blacksmith/blacksmith.tscn
├── battle/battlemode.tscn
└── gui/map/world_map.tscn
```

### Scripts
```
scripts/
├── local/mainmenu/main_menu.gd
├── local/cutscene/prologue/*.gd
├── local/location/map/lotus_village/lotus_village.gd
├── local/location/room/tavern/tavern.gd
├── local/location/room/blacksmith/*.gd
├── local/battle/BattleManager.gd
└── global/transition_manager.gd
```

---

## 🔧 Implementation Checklist

| Prioritas | Sistem | Status |
|-----------|--------|--------|
| 1 | Main Menu = Prologue Scene | ⏳ |
| 2 | Prologue Flow ( Departure → Journey → Arrival) | ⏳ |
| 3 | NPC Dialog System | ⏳ |
| 4 | Map Screen | ⏳ |
| 5 | FPS Art Assets (Village, Forest, Tavern, Blacksmith) | ⏳ |
| 6 | Random Encounter System | ⏳ |
| 7 | BattleManager Config (start_battle function) | ⏳ |
| 8 | Post-Battle Return Flow | ⏳ |
| 9 | Story Mission System | ⏳ |
| 10 | Side Quest System | ⏳ |

---

## 📝 Notes

- **Main Menu** = Prologue scene (immersive, seamless)
- **First Battle** = Random encounter di Forest (bukan story-forced)
- **Side Content** = Optional (tavern games, quests)
- **Story** = Linear, mission-based
- **View** = FPS untuk semua lokasi, top-down untuk map
