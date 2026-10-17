class_name SkillUpgradeCard
extends RefCounted

# ==============================================================================
# SKILL UPGRADE CARD - WEIGHTED GACHA UPGRADE SYSTEM (SPRINT 4 - TASK S4.2)
# ==============================================================================

enum UpgradeType {
	FLAT_BOOST,       # Tăng base_amount của kỹ năng (Phổ biến, Trọng số: 75)
	SCALE_BOOST,      # Tăng hệ số scalings[stat_key] (Hiếm, Trọng số: 20)
	NEW_ABILITY,      # Mở khóa kỹ năng mới từ runtime_pools (Hiếm, Trọng số: 40)
	ULTIMATE_EVOLVE   # Cường hóa đặc biệt cho Ultimate (Cực hiếm, Trọng số: 5)
}

var upgrade_type: UpgradeType = UpgradeType.FLAT_BOOST
var rarity_tier: String = "COMMON" # "COMMON", "RARE", "EPIC"
var weight: int = 75
var title: String = ""
var description: String = ""

# Dành cho FLAT_BOOST, SCALE_BOOST, ULTIMATE_EVOLVE:
var target_ability: AbilityData = null
var stat_key: String = "" # "AD", "AP", "HP", "ARM"
var bonus_value: float = 0.0

# Dành cho NEW_ABILITY:
var new_ability_data: AbilityData = null
var milestone: int = 0

func apply_to_hero(hero: HeroEntity) -> void:
	if hero == null:
		return
		
	match upgrade_type:
		UpgradeType.FLAT_BOOST:
			if target_ability != null:
				for effect in target_ability.effects:
					if effect != null:
						effect.base_amount += bonus_value
						if effect is DamageEffectData:
							effect.base_damage = effect.base_amount
						elif effect is HealEffectData:
							effect.heal_amount = effect.base_amount
							
		UpgradeType.SCALE_BOOST:
			if target_ability != null:
				for effect in target_ability.effects:
					if effect != null:
						var current_scale: float = float(effect.scalings.get(stat_key, 0.0))
						effect.scalings[stat_key] = current_scale + bonus_value
						
		UpgradeType.NEW_ABILITY:
			if new_ability_data != null:
				var cloned := HeroEntity.clone_ability_runtime(new_ability_data)
				hero.unlocked_abilities.append(Ability.new(hero, cloned))
				var pool: Array = hero.runtime_pools.get(milestone, [])
				for item in pool:
					if item == new_ability_data or (item != null and item.name == new_ability_data.name):
						pool.erase(item)
						break
						
		UpgradeType.ULTIMATE_EVOLVE:
			if target_ability != null:
				for effect in target_ability.effects:
					if effect != null:
						effect.base_amount += bonus_value
						if effect is DamageEffectData:
							effect.base_damage = effect.base_amount
						elif effect is HealEffectData:
							effect.heal_amount = effect.base_amount
						for k in effect.scalings.keys():
							effect.scalings[k] = float(effect.scalings[k]) * 1.5
				target_ability.cooldown = max(0.5, target_ability.cooldown * 0.8)

func get_card_bbcode(hero: HeroEntity = null) -> String:
	match upgrade_type:
		UpgradeType.FLAT_BOOST:
			if target_ability != null and not target_ability.effects.is_empty():
				var eff = target_ability.effects[0]
				var old_val: float = eff.base_amount
				var new_val: float = old_val + bonus_value
				return "Cường hóa [b]%s[/b]:\n[color=#aaaaaa]Cơ bản: %d[/color] ➔ [color=#2ecc71][b]%d[/b][/color] ([color=#2ecc71]+%d[/color])" % [
					target_ability.name, int(round(old_val)), int(round(new_val)), int(round(bonus_value))
				]
		UpgradeType.SCALE_BOOST:
			if target_ability != null and not target_ability.effects.is_empty():
				var eff = target_ability.effects[0]
				var old_ratio: float = float(eff.scalings.get(stat_key, 0.0))
				var new_ratio: float = old_ratio + bonus_value
				var stat_name: String = EffectData.STAT_NAMES.get(stat_key, stat_key)
				var color: String = EffectData.STAT_COLORS.get(stat_key, "#ffffff")
				return "Cường hóa [b]%s[/b]:\n[color=#aaaaaa]%s: %d%%[/color] ➔ [color=%s][b]%d%%[/b][/color] ([color=%s]+%d%%[/color])" % [
					target_ability.name, stat_name, int(round(old_ratio * 100.0)),
					color, int(round(new_ratio * 100.0)),
					color, int(round(bonus_value * 100.0))
				]
		UpgradeType.NEW_ABILITY:
			if new_ability_data != null:
				return "Mở khóa kỹ năng mới:\n%s" % new_ability_data.get_formatted_tooltip(hero)
		UpgradeType.ULTIMATE_EVOLVE:
			if target_ability != null:
				return "Tiến hóa Tuyệt kỹ [b]%s[/b]:\n[color=#f1c40f][b]+%d Sát thương & Tăng 50%% Hệ số Scale[/b][/color]" % [
					target_ability.name, int(round(bonus_value))
				]
	return description

func get_border_color() -> Color:
	match rarity_tier:
		"EPIC":
			return Color("#f1c40f") # Vàng kim
		"RARE":
			return Color("#9b59b6") # Tím phát sáng
		_:
			return Color("#3498db") # Xanh lam/xám

func get_badge_text() -> String:
	match upgrade_type:
		UpgradeType.SCALE_BOOST:
			return "[ HIẾM - TĂNG TỶ LỆ ]"
		UpgradeType.ULTIMATE_EVOLVE:
			return "[ TIẾN HÓA HUYỀN THOẠI ]"
		UpgradeType.NEW_ABILITY:
			return "[ KỸ NĂNG MỚI ]"
		_:
			return "[ NÂNG CẤP CƠ BẢN ]"
