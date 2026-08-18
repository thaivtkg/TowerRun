extends Node2D

@export var hero_scene: PackedScene
@export var enemy_scene: PackedScene

@onready var hero_spawn: Marker2D = $HeroSpawn
@onready var enemy_spawn: Marker2D = $EnemySpawn

var heroes: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []
var corpses: Array[CombatEntity] = []

var combat_system: CombatSystem
var targeting_system: TargetingSystem
var progression_system: ProgressionSystem
var ability_system: AbilitySystem
var skill_ui: SkillChoiceUI
var choice_queue: Array[Dictionary] = []

# Trạng thái điều phối cuối trận
var battle_ended: bool = false
var next_game_state: GameManager.GameState

func _ready() -> void:
    GameManager.change_state(GameManager.GameState.BATTLE)
    _start_battle()

func _start_battle() -> void:
    print("=====================================")
    print("[BattleManager] ⚔️ BATTLE STARTED ⚔️")
    print("=====================================")
    
    if hero_scene == null or enemy_scene == null:
        printerr("[BattleManager] FATAL: Hero or Enemy scene not assigned.")
        return
        
    _init_systems()
    _spawn_mock_teams()

func _init_systems() -> void:
    combat_system = CombatSystem.new()
    combat_system.name = "CombatSystem"
    add_child(combat_system)
    
    targeting_system = TargetingSystem.new()
    targeting_system.name = "TargetingSystem"
    targeting_system.heroes = self.heroes
    targeting_system.enemies = self.enemies
    add_child(targeting_system)
    
    progression_system = ProgressionSystem.new()
    progression_system.name = "ProgressionSystem"
    add_child(progression_system)
    progression_system.initialize(combat_system)
    
    ability_system = AbilitySystem.new()
    ability_system.name = "AbilitySystem"
    ability_system.combat_system = combat_system
    ability_system.targeting_system = targeting_system
    add_child(ability_system)
    
    ability_system.setup_hooks()
    
    skill_ui = SkillChoiceUI.new()
    add_child(skill_ui)
    skill_ui.skill_chosen.connect(_on_skill_chosen)

func _spawn_mock_teams() -> void:
    # 1. Tướng THẬT (Kira) nạp từ file Resource
    var kira_data = load("res://data/kira_data.tres") as HeroData
    if kira_data:
        _spawn_hero(kira_data, Vector2(0, -40))
        
    # 2. Sinh nhanh 4 Tướng ẢO (để Kira không bị hội đồng)
    _spawn_hero(_create_mock_hero_data("Arthur", HeroData.HeroClass.TANK, 250.0, 5.0, 30.0, 0.8), Vector2(0, -80))
    _spawn_hero(_create_mock_hero_data("Jaina", HeroData.HeroClass.MAGE, 80.0, 25.0, 2.0, 0.7), Vector2(0, 0))
    _spawn_hero(_create_mock_hero_data("Robin", HeroData.HeroClass.MARKSMAN, 90.0, 15.0, 5.0, 1.5), Vector2(0, 40))
    _spawn_hero(_create_mock_hero_data("Soraka", HeroData.HeroClass.SUPPORT, 120.0, 3.0, 10.0, 0.6), Vector2(0, 80))
    
    # 3. Quái vật
    for i in range(5):
        _spawn_enemy("Slime " + str(i+1), 80.0, 8.0, 5.0, 1.0, 0.0, 2.0, Vector2(0, -80 + (i * 40)))

# Hàm hỗ trợ sinh Data nhanh bằng code
func _create_mock_hero_data(h_name: String, h_class: HeroData.HeroClass, hp: float, atk: float, def: float, spd: float) -> HeroData:
    var data: HeroData = HeroData.new()
    data.name = h_name
    data.hero_class = h_class
    data.base_hp = hp
    data.base_attack = atk
    data.base_defense = def
    data.attack_speed = spd
    return data

func _spawn_hero(data: HeroData, offset: Vector2) -> void:
    # Khai báo "var hero" đúng 1 lần duy nhất ở đây
    var hero: HeroEntity = hero_scene.instantiate() as HeroEntity
    add_child(hero)
    
    if hero_spawn != null:
        hero.global_position = hero_spawn.global_position + offset
    else:
        hero.global_position = offset
    
    hero.died.connect(_on_entity_died.bind(true))
    hero.attack_requested.connect(combat_system.process_attack)
    hero.ability_requested.connect(ability_system.execute_ability)
    
    hero.initialize(data)
    heroes.append(hero)

func _spawn_enemy(e_name: String, hp: float, atk: float, def: float, spd: float, crit_c: float, crit_d: float, offset: Vector2) -> void:
    var data: EnemyData = EnemyData.new()
    data.name = e_name
    data.base_hp = hp
    data.base_attack = atk
    data.base_defense = def
    data.attack_speed = spd
    data.crit_chance = crit_c
    data.crit_damage = crit_d
    
    var enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
    add_child(enemy)
    
    if enemy_spawn != null:
        enemy.global_position = enemy_spawn.global_position + offset
    else:
        enemy.global_position = offset
    
    enemy.died.connect(_on_entity_died.bind(false))
    enemy.attack_requested.connect(combat_system.process_attack)
    enemy.initialize(data)
    enemies.append(enemy)

func _on_entity_died(entity: CombatEntity, is_hero: bool) -> void:
    if is_hero:
        heroes.erase(entity)
    else:
        enemies.erase(entity)
        
    corpses.append(entity)
    _check_battle_end()

func _check_battle_end() -> void:
    if GameManager.current_state != GameManager.GameState.BATTLE:
        return
        
    if heroes.is_empty():
        _end_battle(GameManager.GameState.GAME_OVER, "❌ DEFEAT - All Heroes have fallen.")
    elif enemies.is_empty():
        _end_battle(GameManager.GameState.REWARD, "🏆 VICTORY - Floor Cleared!")

# ==========================================
# POST-BATTLE REWARD PHASE (Xử lý cuối trận)
# ==========================================
func _end_battle(state: GameManager.GameState, log_message: String) -> void:
    if battle_ended: return
    battle_ended = true
    next_game_state = state
    
    print("[BattleManager] ", log_message)
    print("--- REWARD PHASE STARTED ---")
    
    var is_victory: bool = (state == GameManager.GameState.REWARD)
    if progression_system != null:
        # Lệnh này sẽ cấp XP, có thể khiến Tướng nhảy cấp và lưu pending_milestone
        progression_system.finalize_battle_xp(is_victory)
    
    _build_post_battle_choice_queue()
    
    if not choice_queue.is_empty():
        _process_next_choice()
    else:
        _finish_battle_cleanup()

func _build_post_battle_choice_queue() -> void:
    choice_queue.clear()
    # Gộp cả Tướng còn sống và Tướng đã chết (vì xác chết vẫn được chia XP và lên cấp)
    var all_heroes: Array[CombatEntity] = heroes + corpses 
    
    for entity in all_heroes:
        if entity is HeroEntity:
            var hero = entity as HeroEntity
            for milestone in hero.pending_milestones:
                # Lúc này mới rút bài từ Pool
                var choices = hero.pull_milestone_choices(milestone)
                if not choices.is_empty():
                    choice_queue.append({
                        "hero": hero,
                        "milestone": milestone,
                        "choices": choices
                    })
            hero.pending_milestones.clear()

func _process_next_choice() -> void:
    if choice_queue.is_empty(): return
    var next = choice_queue[0]
    skill_ui.show_choices(next.hero.name, next.milestone, next.choices)

func _on_skill_chosen(chosen: AbilityData, all_choices: Array[AbilityData]) -> void:
    var current = choice_queue.pop_front()
    current.hero.apply_skill_choice(current.milestone, chosen, all_choices)
    
    if choice_queue.size() > 0:
        _process_next_choice()
    else:
        _finish_battle_cleanup()

func _finish_battle_cleanup() -> void:
    print("[BattleManager] Reward Phase Complete. Cleaning up ", corpses.size(), " corpses.")
    for corpse in corpses:
        if is_instance_valid(corpse):
            corpse.queue_free()
    corpses.clear()
    
    # Gọi chuyển sang màn tiếp theo sau 1 giây
    get_tree().create_timer(1.0).timeout.connect(_start_next_floor)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        print("\n[DEBUG] 🚀 BƠM 800 XP CHO TOÀN BỘ HEROES!")
        for hero in heroes:
            if is_instance_valid(hero) and hero.progression != null:
                hero.progression.add_xp(800.0)
                
func _start_next_floor() -> void:
    battle_ended = false
    print("\n=====================================")
    print("[BattleManager] 🚀 BẮT ĐẦU MÀN MỚI / TẦNG TIẾP THEO 🚀")
    print("=====================================")
    
    # Sinh lại quái vật cho tầng mới
    for i in range(5):
        _spawn_enemy("Slime Lv2 - " + str(i+1), 120.0, 10.0, 6.0, 1.0, 0.0, 2.0, Vector2(0, -80 + (i * 40)))
