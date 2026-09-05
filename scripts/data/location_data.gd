extends Resource
class_name LocationData

# ============================================================
# BASIC INFO
# ============================================================

@export_group("Basic Info")

@export var location_id: String = ""

@export var location_name: String = ""

@export var description: String = ""

# ============================================================
# LORE
# ============================================================

@export_group("Lore")

@export_multiline var lore: String = ""

# ============================================================
# EVENTS (Future Use)
# ============================================================

@export_group("Events")

@export var events: Array[EventData] = []
