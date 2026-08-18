class_name HeroEntity
extends CombatEntity

signal pending_skill_choice(hero: HeroEntity, milestone: int, choices: Array[AbilityData])
signal ability_requested(ability: Ability) 

@export var data: HeroData
@onready var attack_timer: Timer = $AttackTimer
var progression: HeroProgression = null

# SPRINT 4: RUNTIME ABILITIES STATE
var unlocked_abilities: Array[Ability] = [] 
var basic_attack_ability: Ability           
var runtime_pools: Dictionary = {} 
var pending_milestones: Array[int] = []

# ==========================================
# SPRINT 4: ENERGY SYSTEM (HỆ THỐNG NĂNG LƯỢNG)
# ==========================================
var current_energy: float = 0.0
var max_energy: float = 100.0
var energy_per_attack: float = 25.0 # Đánh 4 phát là xả Ultimate

func initialize(initial_data: HeroData) -> void:
    data = initial_data
    if data == null: return
        
    name = data.name 
    current_hp = data.base_hp
    
    progression = HeroProgression.new()
    progression.leveled_up.connect(_on_level_up)
    progression.milestone_reached.connect(_on_milestone_reached)
    
    if data.basic_attack != null:
        basic_attack_ability = Ability.new(self, data.basic_attack)
    
    runtime_pools[5] = data.pool_lv5_passives.duplicate()
    runtime_pools[10] = data.pool_lv10_actives.duplicate()
    runtime_pools[15] = data.pool_lv15_utilities.duplicate()
    runtime_pools[20] = data.pool_lv20_upgrades.duplicate()
    runtime_pools[25] = data.pool_lv25_signatures.duplicate()
    
    var safe_speed: float = max(0.1, data.attack_speed)
    attack_timer.wait_time = 1.0 / safe_speed
    if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
        attack_timer.timeout.connect(_on_attack_timer_timeout)
    attack_timer.start()

func _die() -> void:
    attack_timer.stop()
    super()

func _process(delta: float) -> void:
    if is_dead: return
    
    for ability in unlocked_abilities:
        ability.process_cooldown(delta)
        # [FIX ISSUE #2] Truyền current_energy vào
        if ability.data.ability_type == AbilityData.AbilityType.ACTIVE and ability.is_ready(current_energy):
            # [FIX ISSUE #4] Nếu AbilitySystem trả về false (do không có target), nó sẽ chờ frame tiếp theo
            ability_requested.emit(ability)

func _on_attack_timer_timeout() -> void:
    if is_dead or data == null: return
    
    # [FIX ISSUE #5] KIỂM TRA ULTIMATE
    if current_energy >= max_energy:
        for ability in unlocked_abilities:
            if ability.data.ability_type == AbilityData.AbilityType.ULTIMATE and ability.is_ready(current_energy):
                ability_requested.emit(ability)
                # BỎ dòng `current_energy = 0` ở đây. Việc xả Energy đã giao cho AbilitySystem.
                return 
    
    # ĐÁNH THƯỜNG VÀ TÍCH NĂNG LƯỢNG
    if basic_attack_ability != null:
        ability_requested.emit(basic_attack_ability)
        _gain_energy(energy_per_attack)
    else:
        if is_instance_valid(target) and not target.is_dead:
            var event := DamageEvent.new(self, target, data.base_attack, DamageEvent.DamageType.PHYSICAL)
            attack_requested.emit(event)
            _gain_energy(energy_per_attack)

# Hàm tăng Năng lượng công khai (để hệ thống khác có thể gọi)
func _gain_energy(amount: float) -> void:
    if current_energy < max_energy:
        current_energy = min(current_energy + amount, max_energy)
        # Tạm tắt log này để Console đỡ rác, bạn có thể bật lại nếu muốn xem Năng lượng nảy
        # print("⚡ %s Energy: %d/%d" % [name, current_energy, max_energy])

func _on_level_up(_new_level: int) -> void: pass

func _on_milestone_reached(milestone: int) -> void:
    pending_milestones.append(milestone)
    print("[HeroEntity] %s reached Milestone Lv%d. Choice pending." % [name, milestone])

func pull_milestone_choices(milestone: int) -> Array[AbilityData]:
    var pool: Array = runtime_pools.get(milestone, [])
    if pool.is_empty(): return []
        
    pool.shuffle() 
    var choices: Array[AbilityData] = []
    var reveal_count: int = min(3, pool.size())
    
    for i in range(reveal_count): 
        choices.append(pool[i])
    return choices

func apply_skill_choice(milestone: int, chosen: AbilityData, revealed: Array[AbilityData]) -> void:
    if not chosen in revealed:
        printerr("[HeroEntity] Invalid skill choice. Rejected.")
        return
        
    var runtime_ability = Ability.new(self, chosen)
    unlocked_abilities.append(runtime_ability)
    
    print("[HeroEntity] %s unlocked ability: [%s] %s" % [name, AbilityData.AbilityType.keys()[chosen.ability_type], chosen.name])
    
    var pool: Array = runtime_pools.get(milestone, [])
    for ability in revealed: pool.erase(ability)

func get_defense() -> float: return data.base_defense if data != null else 0.0
func get_crit_chance() -> float: return data.crit_chance if data != null else 0.0
func get_crit_damage() -> float: return data.crit_damage if data != null else 2.0
