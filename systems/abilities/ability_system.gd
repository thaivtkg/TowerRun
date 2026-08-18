class_name AbilitySystem
extends Node

var combat_system: CombatSystem
var targeting_system: TargetingSystem

# [ADDED] Lắng nghe Event từ Combat System
func setup_hooks() -> void:
    if not combat_system.damage_dealt.is_connected(_on_damage_dealt):
        combat_system.damage_dealt.connect(_on_damage_dealt)
    if not combat_system.entity_killed.is_connected(_on_entity_killed):
        combat_system.entity_killed.connect(_on_entity_killed)

var _passive_execution_depth: int = 0 # [FIX ISSUE #3] Cờ chống đệ quy

# Trả về bool để biết ability có thực sự thi triển không (có target không)
func execute_ability(ability: Ability) -> bool:
    if ability == null or not ability.owner is HeroEntity: return false
    
    var source = ability.owner as HeroEntity
    # [FIX ISSUE #2] Kiểm tra năng lượng thực tế truyền từ Hero
    if not ability.is_ready(source.current_energy): return false 
    
    var targets: Array[CombatEntity] = targeting_system.get_targets_for_rule(source, ability.data.target_rule)
    # [FIX ISSUE #4] Ngăn Start Cooldown và trừ Energy nếu không có mục tiêu
    if targets.is_empty(): return false 
    
    print("\n[AbilitySystem] 💥 %s casts [%s] %s!" % [source.name, AbilityData.AbilityType.keys()[ability.data.ability_type], ability.data.name])
    
    # [FIX ISSUE #5] AbilitySystem thực thi Energy Contract
    if ability.data.ability_type == AbilityData.AbilityType.ULTIMATE:
        source.current_energy = 0.0 # Ultimate luôn xả cạn năng lượng
    else:
        source.current_energy = max(0.0, source.current_energy - ability.data.energy_cost)
        
    ability.start_cooldown()
    
    for target in targets:
        for effect in ability.data.effects:
            _apply_effect(effect, source, target)
            
    return true # Cast thành công

func trigger_passives(source: CombatEntity, condition: AbilityData.TriggerCondition) -> void:
    if _passive_execution_depth > 0: return # [FIX ISSUE #3] Guard chặn đệ quy vô hạn
    if not source is HeroEntity: return
    
    var hero = source as HeroEntity
    for ability in hero.unlocked_abilities:
        if ability.data.ability_type == AbilityData.AbilityType.PASSIVE:
            if ability.data.trigger_condition == condition and ability.is_ready(hero.current_energy):
                
                var targets = targeting_system.get_targets_for_rule(hero, ability.data.target_rule)
                if targets.is_empty(): continue
                
                _passive_execution_depth += 1 # Khóa guard
                
                if ability.data.cooldown > 0:
                    ability.start_cooldown()
                    
                print("[AbilitySystem] ⚙️ PASSIVE TRIGGERED: [%s] by %s" % [ability.data.name, hero.name])
                
                for target in targets:
                    for effect in ability.data.effects:
                        _apply_effect(effect, hero, target)
                        
                _passive_execution_depth -= 1 # Mở guard

func _on_damage_dealt(source: CombatEntity, target: CombatEntity, _amount: float, is_crit: bool) -> void:
    trigger_passives(source, AbilityData.TriggerCondition.ON_ATTACK)
    if is_crit:
        trigger_passives(source, AbilityData.TriggerCondition.ON_CRIT)
        
    if target != null and not target.is_dead:
        trigger_passives(target, AbilityData.TriggerCondition.ON_TAKE_DAMAGE)
        
        # SPRINT 4: Tướng bị ăn đòn sẽ được hồi 10 Năng lượng (chuẩn Auto-battler)
        if target is HeroEntity:
            (target as HeroEntity)._gain_energy(10.0)

func _on_entity_killed(killer: CombatEntity, _victim: CombatEntity) -> void:
    trigger_passives(killer, AbilityData.TriggerCondition.ON_KILL)

# ==========================================
# EFFECTS EXECUTION
# ==========================================
func _apply_effect(effect: EffectData, source: CombatEntity, target: CombatEntity) -> void:
    if effect is DamageEffectData:
        var dmg_effect = effect as DamageEffectData
        var event = DamageEvent.new(source, target, dmg_effect.base_damage, dmg_effect.damage_type)
        event.is_crit = dmg_effect.can_crit and (randf() <= source.get_crit_chance())
        event.crit_multiplier = source.get_crit_damage()
        combat_system.process_attack(event)
        
    elif effect is HealEffectData:
        var heal_effect = effect as HealEffectData
        target.current_hp = min(target.current_hp + heal_effect.heal_amount, 9999.0) 
        print("[AbilitySystem] 💚 %s heals %s for %.1f HP. (New HP: %.1f)" % [source.name, target.name, heal_effect.heal_amount, target.current_hp])
