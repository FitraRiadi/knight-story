extends Resource
class_name EnemyData


# ============================================================
# AI
# ============================================================

enum AIType {
	BASIC,
	AGGRESSIVE,
	TACTICAL,
	BOSS
}


@export_group("AI Strategy")

@export var ai_type: AIType = AIType.BASIC


# ============================================================
# INVENTORY & LOOT
# ============================================================

@export_group("Inventory & Loot")

@export var starting_inventory: Array[ItemData] = []


# ============================================================
# BASIC INFO
# ============================================================

@export_group("Basic Info")

@export var enemy_id: String = ""

@export var enemy_name: String = ""

@export var min_level: int = 1


# ============================================================
# VISUAL & ANIMATIONS
# ============================================================

@export_group("Visual & Animations")

@export var icon_enemy: Texture2D

@export var sprite_frames: SpriteFrames

@export var sprite_scale: Vector2 = Vector2(0.8, 0.8)


# ============================================================
# AUDIO EFFECTS
# ============================================================

@export_group("Audio Effects")

@export var sfx_idle: AudioStream

@export var sfx_attack: AudioStream

@export var sfx_hit: AudioStream

@export var sfx_death: AudioStream


# ============================================================
# STATS
# ============================================================

@export_group("Stats (Base at Minimum Level)")

@export var max_hp: float = 100.0

@export var damage_to_player: float = 15.0

@export var defense: float = 0.0


# ============================================================
# REWARDS & DROPS
# ============================================================

@export_group("Rewards & Drops")

@export var exp_reward: int = 20

@export var gold_reward: int = 10

@export var drop_table: Array[String] = []

@export var drop_chance: float = 0.5


# ============================================================
# PROFILE ICON
# ============================================================

func get_profile_icon() -> Texture2D:

	if icon_enemy != null:
		return icon_enemy

	if sprite_frames:
		if sprite_frames.has_animation("idle"):
			return sprite_frames.get_frame_texture(
				"idle",
				0
			)

	return null


# ============================================================
# SCALED STATS
# ============================================================

func get_scaled_stats(
	target_level: int
) -> Dictionary:

	var final_hp: float = max_hp

	var final_dmg: float = damage_to_player

	var final_def: float = defense

	var final_exp: int = exp_reward

	var final_gold: int = gold_reward

	if target_level > min_level:

		var level_diff: int = (
			target_level - min_level
		)

		var stat_bonus: float = 0.0

		for step in range(level_diff):

			var tier = step / 10

			stat_bonus += (
				10.0 +
				(tier * 5.0)
			)

		final_hp += (
			stat_bonus * 2.0
		)

		final_dmg += stat_bonus

		final_def += (
			level_diff * 0.5
		)

		final_exp += (
			level_diff * 5
		)

		final_gold += (
			level_diff * 5
		)

	return {
		"max_hp": final_hp,
		"damage": final_dmg,
		"defense": final_def,
		"exp": final_exp,
		"gold": final_gold
	}
