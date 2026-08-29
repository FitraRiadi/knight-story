extends Resource
class_name QuestData


# ============================================================
# QUEST DATA
# Resource untuk quest system. Edit di Inspector atau .tres.
# ============================================================

enum QuestType {
	PLAY_GAMES,
	COLLECT_ITEMS,
	KILL,
	GATHER,
	EXPLORE
}


@export_group("Basic Info")

@export var quest_id: String = ""

@export var quest_name: String = ""

@export_multiline var description: String = ""


@export_group("Objective")

@export var quest_type: QuestType = QuestType.PLAY_GAMES

@export var target_count: int = 1


@export_group("Target")

## Untuk quest type KILL — pilih enemy
@export_enum("skeleton:Skeleton", "warewolf:Warewolf", "grimward:Grimward", "grooter:Grooter")
var kill_target: String = ""

## Untuk quest type COLLECT_ITEMS / GATHER — pilih item
@export_enum("health_potion:Health Potion", "attack_potion:Attack Potion", "protection_potion:Protection Potion")
var item_target: String = ""

## Untuk quest type PLAY_GAMES — pilih game
@export_enum("Find The Card", "Word Chain", "Brew Challenge")
var game_target: String = ""

## Untuk quest type EXPLORE — pilih lokasi
@export_enum("lotus_forest:Lotus Forest", "ruins:Old Ruins", "village:Village Center")
var explore_target: String = ""


@export_group("Rewards")

@export var reward_gold: int = 0

@export var reward_exp: int = 0

## Item ID reward (opsional, kosongkan jika tidak ada)
@export_enum("None", "health_potion:Health Potion", "attack_potion:Attack Potion", "protection_potion:Protection Potion")
var reward_item_id: String = ""


# ============================================================
# HELPER — Dapatkan target aktif berdasarkan quest_type
# ============================================================

func get_target() -> String:
	match quest_type:
		QuestType.KILL:
			return kill_target
		QuestType.COLLECT_ITEMS, QuestType.GATHER:
			return item_target
		QuestType.PLAY_GAMES:
			return game_target
		QuestType.EXPLORE:
			return explore_target
		_:
			return ""


func get_target_display() -> String:
	var t = get_target()
	match quest_type:
		QuestType.KILL:
			return "Kill %d %s" % [target_count, _capitalize_id(t)]
		QuestType.COLLECT_ITEMS:
			return "Collect %d %s" % [target_count, _capitalize_id(t)]
		QuestType.GATHER:
			return "Gather %d %s" % [target_count, _capitalize_id(t)]
		QuestType.PLAY_GAMES:
			return "Win %d %s games" % [target_count, t]
		QuestType.EXPLORE:
			return "Explore %s" % _capitalize_id(t)
		_:
			return description


func get_type_display() -> String:
	match quest_type:
		QuestType.KILL:
			return "Kill Quest"
		QuestType.COLLECT_ITEMS:
			return "Collect Quest"
		QuestType.GATHER:
			return "Gather Quest"
		QuestType.PLAY_GAMES:
			return "Game Quest"
		QuestType.EXPLORE:
			return "Explore Quest"
		_:
			return "Unknown"


func get_progress_text(current: int) -> String:
	return str(current) + "/" + str(target_count)


func get_reward_text() -> String:
	var parts: PackedStringArray = []
	if reward_gold > 0:
		parts.append(str(reward_gold) + "G")
	if reward_exp > 0:
		parts.append(str(reward_exp) + " EXP")
	if reward_item_id != "" and reward_item_id != "None":
		parts.append(_capitalize_id(reward_item_id))
	return " + ".join(parts)


func _capitalize_id(id: String) -> String:
	return id.replace("_", " ").capitalize()
