extends Node


# ============================================================
# EVENT BUS (Autoload)
# Global signal bus untuk komunikasi antar sistem.
# Contoh: EventBus.enemy_killed.emit("skeleton")
# ============================================================

signal enemy_killed(enemy_id: String)
