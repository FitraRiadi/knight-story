extends Node


# ============================================================
# QUEST TRACKER (Autoload)
# Listen ke EventBus signals untuk track quest progress.
# ============================================================


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(enemy_id: String) -> void:
	var active_id = PlayerDataManager.active_quest_id
	if active_id == "":
		return

	var quest = QuestDatabase.get_quest(active_id)
	if quest == null:
		return

	if quest.quest_type == QuestData.QuestType.KILL and quest.get_target() == enemy_id:
		PlayerDataManager.increment_quest_progress(active_id)


## Cek ulang progress collect_items quest berdasarkan inventory saat ini
func check_collect_quest_progress() -> void:
	var active_id = PlayerDataManager.active_quest_id
	if active_id == "":
		return

	var quest = QuestDatabase.get_quest(active_id)
	if quest == null:
		return

	if quest.quest_type == QuestData.QuestType.COLLECT_ITEMS:
		var count = PlayerDataManager.count_item_in_inventory(quest.get_target())
		PlayerDataManager.set_quest_progress(active_id, count)
