# FPS Location Asset Prompt Generator

## Cara Pakai

1. **Pilih base prompt** dari `base_prompt.md`
2. **Isi placeholder** sesuai kebutuhan lokasi
3. **Copy prompt** ke AI generator (Stable Diffusion, Midjourney, Leonardo.ai)
4. **Import hasil** ke Aseprite/Piskel untuk touch-up
5. **Export PNG** → Import ke Godot

---

## Placeholder Reference

| Placeholder | Pilihan | Contoh |
|-------------|---------|--------|
| `[LOCATION_TYPE]` | village, tavern, blacksmith, forest, ruins, road, cave, castle, swamp, desert | `forest` |
| `[ATMOSPHERE]` | peaceful, ominous, mysterious, eerie, warm, desolate, tense, melancholic, hopeful, dread | `ominous` |
| `[TIME_OF_DAY]` | morning, afternoon, evening, night, dawn, dusk, midnight | `night` |
| `[LIGHTING]` | lantern light, moonlight, sunlight, forge glow, candlelight, dim, torchlight, shadow | `moonlight` |
| `[DETAIL_ELEMENTS]` | cobblestone, wooden beams, vines, fog, smoke, weapons, barrels, chains, ruins, overgrown | `fog` |
| `[COLOR_PALETTE]` | muted earth tones, dark grays, warm oranges, cold blues, sickly greens, blood reds | `cold blues` |
| `[FOCUS_OBJECT]` | door, window, path, altar, anvil, counter, campfire, signpost, gate, chest | `path` |
| `[WEATHER]` | clear, rainy, foggy, snowy, windy, stormy, misty | `foggy` |
| `[ENEMY_HINT]` | none, shadow movement, glowing eyes, distant figure, claw marks, bones | `shadow movement` |

---

## Workflow

```
Prompt (AI) → Base Image → Touch-up (Aseprite) → Export PNG → Godot Scene
```

### Tips AI Generation

- **Stable Diffusion**: Gunakan negative prompt untuk hindari unwanted style
- **Midjourney**: Tambahkan `--style pixel --ar 740:340`
- **Leonardo.ai**: Pilih "Pixel Art" style preset

### Touch-up Checklist

- [ ] Palette warna match dengan game
- [ ] Pixel size konsisten (1px, 2px, atau 4px)
- [ ] Resolution sesuai viewport (740x340 atau 2x)
- [ ] Tidak ada artifacts/ganjil
- [ ] Atmospheric lighting konsisten

---

## File Structure

```
/gen/
├── README.md                    # Dokumentasi ini
├── base_prompt.md               # Template utama
├── location_templates.md        # Template per tipe lokasi
├── atmosphere_variants.md       # Variasi suasana
├── time_of_day_variants.md      # Variasi waktu
├── optional_elements.md         # Elemen tambahan (opsional)
└── examples/
    ├── safe_hub_example.md      # Contoh: Village/Tavern
    ├── combat_zone_example.md   # Contoh: Forest/Ruins
    └── story_zone_example.md    # Contoh: Cave/Castle
```

---

## Quick Start

1. Copy prompt dari `base_prompt.md`
2. Ganti placeholder sesuai kebutuhan
3. Generate di AI tool favorit lo
4. Touch-up di Aseprite
5. Export → Import ke Godot

Happy generating! 🎨
