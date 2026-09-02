extends Resource
class_name ActionCardData


# ============================================================
# CARD INFO
# ============================================================

@export_group("Card Info")

@export var card_name: String = ""
@export var description: String = ""
@export var icon: Texture2D


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
# EXECUTE (Virtual — override di subclass)
# ============================================================

## Dipanggil saat card dipakai. Override di subclass card.
## @param target — BattleEnemy yang dipilih
## @param battle_manager — reference ke BattleManager
func execute(target: Node, battle_manager: Node) -> void:
	pass
