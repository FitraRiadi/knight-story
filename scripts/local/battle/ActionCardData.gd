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

@export var stamina_cost: float = 20.0
@export var cooldown: int = 2


# ============================================================
# VISUAL
# ============================================================

@export_group("Visual")

@export var accent_color: Color = Color.WHITE
