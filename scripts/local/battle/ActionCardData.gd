extends Resource
class_name ActionCardData


# ============================================================
# CARD INFO
# ============================================================

@export_group("Card Info")

@export var card_name: String = ""
@export var description: String = ""
@export var card_art: Texture2D
@export var icon: Texture2D
@export var level: int = 1
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"


# ============================================================
# COSTS & COOLDOWN
# ============================================================

@export_group("Costs")

@export var stamina_cost: float = 25.0
@export var cooldown: int = 3


# ============================================================
# VISUAL — ACCENT
# ============================================================

@export_group("Visual")

@export var accent_color: Color = Color.WHITE


# ============================================================
# VISUAL — BACKGROUND
# ============================================================

@export_group("Background")

@export var bg_texture: Texture2D
@export var bg_color: Color = Color(0.12, 0.10, 0.15, 0.95)


# ============================================================
# VISUAL — SHADOW (IDLE)
# ============================================================

@export_group("Shadow")

@export var shadow_color: Color = Color(0, 0, 0, 0.4)
@export var shadow_offset: Vector2 = Vector2(2, 4)
@export var shadow_size: int = 8


# ============================================================
# VISUAL — SHADOW (ACTIVE / SELECTED)
# ============================================================

@export_group("Active Shadow")

@export var active_shadow_color: Color = Color(0, 0, 0, 0.6)
@export var active_shadow_offset: Vector2 = Vector2(0, 8)
@export var active_shadow_size: int = 16


# ============================================================
# RARITY COLORS (Static)
# ============================================================

const RARITY_COLORS: Dictionary = {
	"Common": Color(0.35, 0.35, 0.35),
	"Uncommon": Color(0.49, 0.38, 0.32),
	"Rare": Color(0.12, 0.38, 0.68),
	"Epic": Color(0.45, 0.18, 0.58),
	"Legendary": Color(0.75, 0.42, 0.08)
}


# ============================================================
# HELPER
# ============================================================

func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color(0.35, 0.35, 0.35))


# ============================================================
# EXECUTE (Virtual — override di subclass)
# ============================================================

## Dipanggil saat card dipakai. Override di subclass card.
## @param target — BattleEnemy yang dipilih
## @param battle_manager — reference ke BattleManager
func execute(target: Node, battle_manager: Node) -> void:
	pass
