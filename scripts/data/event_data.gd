extends Resource
class_name EventData

# ============================================================
# BASIC INFO
# ============================================================

@export_group("Basic Info")

@export var event_id: String = ""

@export var event_name: String = ""

@export_multiline var description: String = ""

# ============================================================
# VISUAL
# ============================================================

@export_group("Visual")

@export var icon: Texture2D
