class_name BuffManager
extends RefCounted

# Menyimpan daftar buff aktif
var active_buffs: Array[Dictionary] = []

# Stat permanen tambahan (jika item duration = 0 memberikan stat bertambah)
var base_bonus_damage: float = 0.0
var base_bonus_defense: float = 0.0


# ============================================================
# APPLY ITEM
# ============================================================

func apply_item(item: ItemData, target_unit: Object) -> Dictionary:
	var result = {
		"healed": 0.0,
		"shield_added": 0.0,
		"buff_applied": false,
		"item_name": _get_item_name(item)
	}

	if item == null or target_unit == null:
		return result

	# 1. Pemulihan HP (Instant)
	if item.heal_value > 0.0:
		var old_hp: float = target_unit.current_hp
		target_unit.current_hp = minf(target_unit.scaled_max_hp, target_unit.current_hp + item.heal_value)
		result["healed"] = target_unit.current_hp - old_hp

	# 2. Penambahan Max HP
	if item.max_hp_bonus != 0.0:
		target_unit.scaled_max_hp = maxf(1.0, target_unit.scaled_max_hp + item.max_hp_bonus)
		target_unit.current_hp = minf(target_unit.scaled_max_hp, target_unit.current_hp)

	# 3. Shield
	if item.shield_value > 0.0:
		target_unit.shield_value += item.shield_value
		result["shield_added"] = item.shield_value

	# 4. Stat Buffs & Duration Logic
	var item_duration: int = item.duration if "duration" in item else 0
	var atk_bonus: float = item.attack_bonus + item.damage_bonus
	var def_bonus: float = item.defense_bonus
	var red_bonus: float = (item.damage_reduction / 100.0) if item.damage_reduction > 0 else 0.0

	var has_stat_buff: bool = (atk_bonus != 0.0 or def_bonus != 0.0 or red_bonus > 0.0)

	if item_duration > 0 and has_stat_buff:
		# Item dengan durasi turn dimasukkan ke active_buffs beserta tipenya
		active_buffs.append({
			"name": result["item_name"],
			"type": _determine_buff_type(atk_bonus, def_bonus, item),
			"duration": item_duration,
			"attack_bonus": atk_bonus,
			"defense_bonus": def_bonus,
			"damage_reduction": red_bonus,
			"is_new": true
		})
		result["buff_applied"] = true
	elif item_duration == 0 and has_stat_buff:
		# Item duration 0 = Stat bertambah permanen/instant untuk pertempuran ini
		base_bonus_damage += atk_bonus
		base_bonus_defense += def_bonus

	return result


# ============================================================
# TURN PROCESSOR
# ============================================================

func process_turn_start() -> Array[String]:
	var expired_buff_names: Array[String] = []
	var remaining_buffs: Array[Dictionary] = []

	for buff in active_buffs:
		if buff.get("is_new", false):
			buff["is_new"] = false
			remaining_buffs.append(buff)
			continue

		buff["duration"] -= 1
		if buff["duration"] <= 0:
			expired_buff_names.append(buff["name"])
		else:
			remaining_buffs.append(buff)

	active_buffs = remaining_buffs
	return expired_buff_names


# ============================================================
# STAT & BUFF CHECKERS
# ============================================================

func get_active_buff_types() -> Array[String]:
	var types: Array[String] = []
	for buff in active_buffs:
		var type = buff.get("type", "")
		if type != "" and not types.has(type):
			types.append(type)
	return types


func has_buff(buff_type: String) -> bool:
	for buff in active_buffs:
		if buff.get("type", "") == buff_type or buff.get("name", "").to_lower() == buff_type.to_lower():
			return true
	return false


func has_status(status_name: String) -> bool:
	return has_buff(status_name)


func _determine_buff_type(atk_bonus: float, def_bonus: float, item: ItemData) -> String:
	if "buff_type" in item and item.buff_type != "":
		return item.buff_type
	if atk_bonus > 0.0:
		return "attack_up"
	if def_bonus > 0.0:
		return "defense_up"
	return "generic"


# ============================================================
# STAT GETTERS
# ============================================================

func get_total_attack_bonus() -> float:
	var total: float = base_bonus_damage
	for buff in active_buffs:
		total += buff.get("attack_bonus", 0.0)
	return total


func get_total_defense_bonus() -> float:
	var total: float = base_bonus_defense
	for buff in active_buffs:
		total += buff.get("defense_bonus", 0.0)
	return total


func get_total_damage_reduction() -> float:
	var total: float = 0.0
	for buff in active_buffs:
		total += buff.get("damage_reduction", 0.0)
	return clampf(total, 0.0, 0.90)


func clear() -> void:
	active_buffs.clear()
	base_bonus_damage = 0.0
	base_bonus_defense = 0.0


func _get_item_name(item: ItemData) -> String:
	if item.item_name != "": return item.item_name
	if item.item_id != "": return item.item_id
	return "Unknown Item"
