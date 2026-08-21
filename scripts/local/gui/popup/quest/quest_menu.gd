extends Control

@onready var quest1: Control = get_node_or_null("quest1")
@onready var quest2: Control = get_node_or_null("quest2")
@onready var quest3: Control = get_node_or_null("quest3")
@onready var back_btn: Button = get_node_or_null("backBtn")

var origin_positions: Dictionary = {}

# Data Statis Quest
var static_quests: Array[Dictionary] = [
	{
		"type": "Kill Quest",
		"title": "The Battleborn Subordinate",
		"info": "The Battleborn Threat Has been edge gang sprung",
		"purpose": "Kill 5 Skeleton",
		"reward": "x4"
	},
	{
		"type": "Gather Quest",
		"title": "Herbal Remedy",
		"info": "Gather rare herbs needed by the village alchemist",
		"purpose": "Collect 10 Green Herbs",
		"reward": "x100"
	},
	{
		"type": "Explore Quest",
		"title": "Scouting the Ruins",
		"info": "Investigate the mysterious noise near the old ruins",
		"purpose": "Explore Lotus Forest",
		"reward": "x4"
	}
]

func _ready() -> void:
	# Hubungkan tombol backBtn
	if back_btn:
		back_btn.pressed.connect(_on_back_btn_pressed)

	var quest_nodes: Array[Control] = []
	if quest1: quest_nodes.append(quest1)
	if quest2: quest_nodes.append(quest2)
	if quest3: quest_nodes.append(quest3)

	# Populate data statis ke dalam Label masing-masing quest
	for i in range(quest_nodes.size()):
		if i < static_quests.size():
			_setup_quest_data(quest_nodes[i], static_quests[i])

	for node in quest_nodes:
		# Catat posisi awal Y
		origin_positions[node] = node.position.y
		
		# Set transparan & geser sedikit ke atas (offset 20px)
		node.modulate.a = 0.0
		node.position.y -= 20.0

	play_pure_fade_intro(quest_nodes)

# Fungsi saat backBtn ditekan (dengan efek fade out cepat)
func _on_back_btn_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_CIRC)\
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

# Fungsi untuk mengisi Label sesuai hirarki Scene Tree
func _setup_quest_data(quest_node: Control, data: Dictionary) -> void:
	if quest_node == null:
		return
		
	var type_label = quest_node.get_node_or_null("typeQuest") as Label
	var title_label = quest_node.get_node_or_null("questTitle") as Label
	var info_label = quest_node.get_node_or_null("questInfo/Label") as Label
	var purpose_label = quest_node.get_node_or_null("questPurpose/Label") as Label
	var reward_label = quest_node.get_node_or_null("rewardPanel/reward/Label") as Label

	if type_label:
		type_label.text = data.get("type", "")
	if title_label:
		title_label.text = data.get("title", "")
	if info_label:
		info_label.text = data.get("info", "")
	if purpose_label:
		purpose_label.text = data.get("purpose", "")
	if reward_label:
		reward_label.text = data.get("reward", "")

func play_pure_fade_intro(quest_nodes: Array[Control]) -> void:
	var tween = create_tween()
	
	for i in range(quest_nodes.size()):
		var node = quest_nodes[i]
		var target_y: float = origin_positions.get(node, node.position.y)
		var delay: float = i * 0.10

		# Fade In dengan CIRC
		tween.parallel().tween_property(node, "modulate:a", 1.0, 0.4)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_CIRC)\
			.set_ease(Tween.EASE_OUT)
			
		# Slide turun halus ke posisi asli dengan CIRC
		tween.parallel().tween_property(node, "position:y", target_y, 0.4)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_CIRC)\
			.set_ease(Tween.EASE_OUT)
