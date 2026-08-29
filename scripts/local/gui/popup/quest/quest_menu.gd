extends Control

@onready var quest1: Control = get_node_or_null("quest1")
@onready var quest2: Control = get_node_or_null("quest2")
@onready var quest3: Control = get_node_or_null("quest3")
@onready var back_btn: Button = get_node_or_null("backBtn")

var origin_positions: Dictionary = {}


func _ready() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_btn_pressed)

	var quest_nodes: Array[Control] = []
	if quest1: quest_nodes.append(quest1)
	if quest2: quest_nodes.append(quest2)
	if quest3: quest_nodes.append(quest3)

	# Load quests dari QuestDatabase, tampilkan max 3
	var all_quests = QuestDatabase.get_all_quests()
	var display_count = mini(quest_nodes.size(), all_quests.size())

	for i in range(display_count):
		_setup_quest_data(quest_nodes[i], all_quests[i])

	for node in quest_nodes:
		origin_positions[node] = node.position.y
		node.modulate.a = 0.0
		node.position.y -= 20.0

	play_pure_fade_intro(quest_nodes)


func _on_back_btn_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_CIRC)\
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _setup_quest_data(quest_node: Control, quest: QuestData) -> void:
	if quest_node == null or quest == null:
		return

	var type_label = quest_node.get_node_or_null("typeQuest") as Label
	var title_label = quest_node.get_node_or_null("questTitle") as Label
	var info_label = quest_node.get_node_or_null("questInfo/Label") as Label
	var purpose_label = quest_node.get_node_or_null("questPurpose/Label") as Label
	var reward_label = quest_node.get_node_or_null("rewardPanel/reward/Label") as Label

	if type_label:
		type_label.text = quest.get_type_display()
	if title_label:
		title_label.text = quest.quest_name
	if info_label:
		info_label.text = quest.description
	if purpose_label:
		purpose_label.text = quest.get_target_display()
	if reward_label:
		reward_label.text = quest.get_reward_text()


func play_pure_fade_intro(quest_nodes: Array[Control]) -> void:
	var tween = create_tween()

	for i in range(quest_nodes.size()):
		var node = quest_nodes[i]
		var target_y: float = origin_positions.get(node, node.position.y)
		var delay: float = i * 0.10

		tween.parallel().tween_property(node, "modulate:a", 1.0, 0.4)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_CIRC)\
			.set_ease(Tween.EASE_OUT)

		tween.parallel().tween_property(node, "position:y", target_y, 0.4)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_CIRC)\
			.set_ease(Tween.EASE_OUT)
