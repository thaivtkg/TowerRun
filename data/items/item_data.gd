class_name ItemData
extends Resource

# ==========================================
# ITEM DATA CORE (SPRINT 6 - TASK S6.1 & S6.2)
# Phong cách Dark Fantasy RPG
# ==========================================

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export var tier: int = 1 # 1: Mảnh cơ bản, 2: Cổ vật, 3: Thần thoại
@export var is_component: bool = true
@export var is_pure_stat: bool = false # Đánh dấu món thuần chỉ số (Trảm Hồn Đao, Hư Không Cầu)
@export var recipe: Array[String] = []

# Chỉ số cơ bản & mở rộng
@export var bonus_ad: float = 0.0
@export var bonus_ap: float = 0.0
@export var bonus_armor: float = 0.0
@export var bonus_hp: float = 0.0
@export var starting_energy: float = 0.0
@export var crit_chance: float = 0.0
@export var bonus_attack_speed: float = 0.0 # Tỉ lệ % (ví dụ 0.10 = +10%)
@export var bonus_omnivamp: float = 0.0     # Tỉ lệ % (ví dụ 0.05 = +5%)

# Tương thích ngược với định dạng stat_modifiers dictionary cũ
@export var stat_modifiers: Dictionary = {}

# Nội tại Bậc 2
@export var passive_id: String = ""
@export var passive_name: String = ""
@export var passive_desc: String = ""

# Nội tại Bậc 3 (2 Tầng hiển thị)
@export var sub_passive_name: String = ""
@export var sub_passive_desc: String = ""
@export var mythic_passive_name: String = ""
@export var mythic_passive_desc: String = ""

func get_bonus_ad() -> float:
	return bonus_ad if bonus_ad != 0.0 else float(stat_modifiers.get("bonus_ad", 0.0))

func get_bonus_ap() -> float:
	return bonus_ap if bonus_ap != 0.0 else float(stat_modifiers.get("bonus_ap", 0.0))

func get_bonus_armor() -> float:
	return bonus_armor if bonus_armor != 0.0 else float(stat_modifiers.get("bonus_armor", 0.0))

func get_bonus_hp() -> float:
	return bonus_hp if bonus_hp != 0.0 else float(stat_modifiers.get("bonus_hp", 0.0))

func get_starting_energy() -> float:
	return starting_energy if starting_energy != 0.0 else float(stat_modifiers.get("starting_energy", 0.0))

func get_crit_chance() -> float:
	return crit_chance if crit_chance != 0.0 else float(stat_modifiers.get("crit_chance", 0.0))

func get_bonus_attack_speed() -> float:
	return bonus_attack_speed if bonus_attack_speed != 0.0 else float(stat_modifiers.get("bonus_attack_speed", 0.0))

func get_bonus_omnivamp() -> float:
	return bonus_omnivamp if bonus_omnivamp != 0.0 else float(stat_modifiers.get("bonus_omnivamp", 0.0))
