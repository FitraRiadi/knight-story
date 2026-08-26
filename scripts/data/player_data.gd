extends Resource
class_name PlayerData


# ============================================================
# PLAYER IDENTITY
# ============================================================

@export_group("Player Identity")

@export var player_name: String = "Knight"

@export var player_level: int = 1

@export var player_exp: int = 0

@export var player_max_exp: int = 100

@export var player_profile: Texture2D


# ============================================================
# PLAYER VITALS
# ============================================================

@export_group("Player Vitals")

@export var max_hp: float = 500.0

@export var max_stamina: float = 200.0

@export var attack_stamina_cost: float = 15.0

@export var max_morale: float = 200.0


# ============================================================
# PLAYER COMBAT STATS
# ============================================================

@export_group("Player Combat Stats")

@export var player_damage: float = 80.0

@export var player_crit_damage: float = 50.0

@export var player_critical_chance: float = 30.0

@export var player_hit_rate: float = 50.0

@export var defense_flat_reduction: float = 20.0

@export var parry_flat_reduction: float = 10.0


# ============================================================
# BATTLE INVENTORY
# ============================================================

@export_group("Battle Inventory")

@export var battle_inventory: InventoryBattleData
