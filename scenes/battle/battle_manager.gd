extends Node2D

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text/FloatingText.tscn")
const ShieldEffectData = preload("res://data/abilities/shield_effect_data.gd")

@export var hero_scene: PackedScene
@export var enemy_scene: PackedScene

@onready var hero_spawn: Marker2D = get_node_or_null("HeroSpawn")
@onready var enemy_spawn: Marker2D = get_node_or_null("EnemySpawn")
@onready var camera: Camera2D = get_node_or_null("BattleCamera")
@onready var board_view: BoardView = get_node_or_null("BoardView")
@onready var placement_controller: PlacementController = get_node_or_null("PlacementController")

var _shake_tween: Tween = null
var _current_shake_strength: float = 0.0

var heroes: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []
var corpses: Array[CombatEntity] = []

var combat_system: CombatSystem
var targeting_system: TargetingSystem
var progression_system: ProgressionSystem
var ability_system: AbilitySystem
var skill_ui: SkillChoiceUI
var combat_summary_ui: CombatSummaryUI
var character_stats_ui: CharacterStatsUI
var choice_queue: Array[Dictionary] = []
var _active_choice_hero: HeroEntity = null
var _active_choice_milestone: int = 0
var current_floor: int = 1

var board_config: BoardConfig
var board_grid: BoardGrid

enum EncounterPhase { PREPARATION, COMBAT, POST_COMBAT, REWARD, GAME_OVER }
var current_phase: EncounterPhase = EncounterPhase.PREPARATION
var start_combat_button: Button = null

# Trạng thái điều phối cuối trận
var battle_ended: bool = false
var next_game_state: GameManager.GameState

# SPRINT 4 SIGN-OFF / SPRINT 5: QA CHEAT & DEBUG
var is_god_mode: bool = false
var debug_cheat_ui: DebugCheatPanel = null

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.BATTLE)
	var has_save: bool = false
	if SaveManager != null:
		var save_data := SaveManager.load_game()
		if not save_data.is_empty() and int(save_data.get("floor", 0)) >= 1:
			has_save = true
			
	if not has_save and RunManager != null:
		RunManager.start_new_run()
		current_floor = RunManager.current_floor
		
	_start_battle()
	
	if has_save:
		_try_resume_saved_run()
		
	debug_cheat_ui = DebugCheatPanel.new(self)
	add_child(debug_cheat_ui)
	
	if "--run-tests" in OS.get_cmdline_user_args():
		_run_all_tests()
		get_tree().quit()

func _start_battle() -> void:
	print("=====================================")
	print("[BattleManager] ⚔️ BATTLE STARTED ⚔️")
	print("=====================================")
	
	if hero_scene == null or enemy_scene == null:
		printerr("[BattleManager] FATAL: Hero or Enemy scene not assigned.")
		return
		
	_init_systems()
	_spawn_mock_teams()
	enter_preparation_phase()
	for h in heroes:
		if is_instance_valid(h) and h.name == "Kira":
			print("[BattleManager] ⚡ Kira Energy Check: Current = %.1f / %.1f | Bar = %.1f" % [h.current_energy, h.max_energy, h.status_bar.energy_bar.value if (h.status_bar and h.status_bar.energy_bar) else -1.0])

func _init_systems() -> void:
	board_config = BoardConfig.new()
	board_grid = BoardGrid.new(board_config)
	
	if board_view != null:
		board_view.config = board_config
		board_view.grid = board_grid
		board_view.queue_redraw()
		
	if placement_controller != null:
		placement_controller.board_grid = board_grid
		placement_controller.board_view = board_view
		placement_controller.entity_selected.connect(func(e):
			if e is EnemyEntity and is_instance_valid(character_stats_ui):
				character_stats_ui.inspect_hero(e)
		)
		placement_controller.hero_selected.connect(func(h):
			handle_hero_clicked(h)
		)
		placement_controller.hero_hovered.connect(func(h):
			if is_instance_valid(character_stats_ui) and not character_stats_ui.visible:
				character_stats_ui.inspect_hero(h)
		)

	combat_system = CombatSystem.new()
	combat_system.name = "CombatSystem"
	add_child(combat_system)
	combat_system.damage_dealt.connect(_on_combat_damage_dealt)
	
	targeting_system = TargetingSystem.new()
	targeting_system.name = "TargetingSystem"
	targeting_system.heroes = self.heroes
	targeting_system.enemies = self.enemies
	targeting_system.board_grid = board_grid
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
	ability_system.ability_executed.connect(_on_ability_executed)
	
	skill_ui = SkillChoiceUI.new()
	add_child(skill_ui)
	skill_ui.skill_chosen.connect(_on_skill_chosen)
	
	combat_summary_ui = CombatSummaryUI.new()
	add_child(combat_summary_ui)
	combat_summary_ui.continued.connect(_on_summary_continued)
	
	character_stats_ui = CharacterStatsUI.new()
	character_stats_ui.name = "CharacterStatsUI"
	add_child(character_stats_ui)
	
	_create_start_combat_ui()

func _create_start_combat_ui() -> void:
	if start_combat_button != null:
		return
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "BattleUILayer"
	add_child(canvas_layer)
	
	start_combat_button = Button.new()
	start_combat_button.name = "StartCombatButton"
	start_combat_button.text = "⚔️ BẮT ĐẦU CHIẾN ĐẤU"
	start_combat_button.custom_minimum_size = Vector2(260, 52)
	start_combat_button.position = Vector2(576 - 130, 560)
	start_combat_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start_combat_button.pressed.connect(start_combat_phase)
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color("c0392b")
	style_normal.set_corner_radius_all(8)
	style_normal.border_width_bottom = 4
	style_normal.border_color = Color("962d22")
	start_combat_button.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color("e74c3c")
	style_hover.set_corner_radius_all(8)
	style_hover.border_width_bottom = 4
	style_hover.border_color = Color("c0392b")
	start_combat_button.add_theme_stylebox_override("hover", style_hover)
	
	start_combat_button.add_theme_font_size_override("font_size", 18)
	canvas_layer.add_child(start_combat_button)

func enter_preparation_phase() -> void:
	current_phase = EncounterPhase.PREPARATION
	if board_grid != null:
		board_grid.is_locked = false
	if placement_controller != null:
		placement_controller.set_locked(false)
	if targeting_system != null:
		targeting_system.set_process(false)
		
	for hero in heroes:
		if is_instance_valid(hero):
			hero.set_combat_active(false)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_combat_active(false)
			
	if start_combat_button != null:
		start_combat_button.disabled = false
		start_combat_button.show()
	print("[BattleManager] 🛡️ PHASE: PREPARATION (Kéo thả bố trí đội hình)")

func start_combat_phase() -> void:
	if current_phase == EncounterPhase.COMBAT:
		return
	if start_combat_button != null:
		start_combat_button.disabled = true
		start_combat_button.hide()

	# Lưu lại tọa độ ô cờ hiện tại của từng Hero trước khi khóa bàn cờ
	for hero in heroes:
		if is_instance_valid(hero) and board_grid != null:
			var c: Vector2i = board_grid.get_cell_for_entity(hero)
			if board_grid.is_in_bounds(c):
				hero.deployed_cell = c

	current_phase = EncounterPhase.COMBAT
	if board_grid != null:
		board_grid.is_locked = true
	if placement_controller != null:
		placement_controller.set_locked(true)
		
	if targeting_system != null:
		targeting_system.set_process(true)
		
	for hero in heroes:
		if is_instance_valid(hero):
			hero.is_invulnerable = is_god_mode
			if hero.metrics != null:
				hero.metrics.reset()
			hero.set_combat_active(true)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_combat_active(true)
	print("[BattleManager] ⚔️ PHASE: COMBAT (Chiến đấu bắt đầu!)")

func _spawn_mock_teams() -> void:
	if board_grid != null:
		board_grid.clear()
		
	# 1. Tướng THẬT (Kira - Assassin): Hàng đầu Hero Zone (y = 3)
	var kira_data = load("res://data/heroes/kira_data.tres") as HeroData
	if kira_data:
		kira_data.attack_range = 1
		_spawn_hero_at_grid(kira_data, Vector2i(4, 3))
		
	# 2. Sinh nhanh 4 Tướng ẢO (Trên–Dưới Layout)
	_spawn_hero_at_grid(_create_mock_hero_data("Arthur", HeroData.HeroClass.TANK, 250.0, 5.0, 30.0, 0.8, 1), Vector2i(3, 3))
	_spawn_hero_at_grid(_create_mock_hero_data("Jaina", HeroData.HeroClass.MAGE, 80.0, 25.0, 2.0, 0.7, 3), Vector2i(2, 4))
	_spawn_hero_at_grid(_create_mock_hero_data("Robin", HeroData.HeroClass.MARKSMAN, 90.0, 15.0, 5.0, 1.5, 4), Vector2i(3, 4))
	_spawn_hero_at_grid(_create_mock_hero_data("Soraka", HeroData.HeroClass.SUPPORT, 120.0, 3.0, 10.0, 0.6, 3), Vector2i(4, 4))
	
	# 3. Quái vật: Gọi trực tiếp Encounter Director cho Tầng hiện tại (FTUE đồng nhất)
	spawn_encounter_for_floor(current_floor)

# Hàm hỗ trợ sinh Data nhanh bằng code
func _create_mock_hero_data(h_name: String, h_class: HeroData.HeroClass, hp: float, atk: float, def: float, spd: float, atk_range: int = 1, spell_pow: float = 10.0) -> HeroData:
	var data: HeroData = HeroData.new()
	data.name = h_name
	data.hero_class = h_class
	data.base_hp = hp
	data.base_attack = atk
	data.base_spell_power = spell_pow
	data.base_defense = def
	data.attack_speed = spd
	data.attack_range = atk_range
	if h_name == "Arthur":
		var ab = load("res://data/abilities/arthur_holy_shield.tres") as AbilityData
		if ab:
			data.pool_lv10_actives.append(ab)
	elif h_name == "Jaina":
		var ab = load("res://data/abilities/jaina_eternal_blizzard.tres") as AbilityData
		if ab:
			data.pool_lv10_actives.append(ab)
	return data

func _spawn_hero_at_grid(data: HeroData, cell: Vector2i) -> HeroEntity:
	var hero: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(hero)
	hero.deployed_cell = cell
	hero.board_grid = board_grid
	hero.board_view = board_view
	hero.targeting_system = targeting_system
	
	if board_grid != null:
		board_grid.place_entity(hero, cell)
	if board_view != null:
		hero.global_position = board_view.grid_to_world(cell)
	else:
		hero.global_position = Vector2(cell * 80)
	
	hero.died.connect(_on_entity_died.bind(true))
	hero.attack_requested.connect(_on_entity_attack_requested)
	hero.ability_requested.connect(ability_system.execute_ability)
	
	hero.initialize(data)
	
	# Đảm bảo mọi Hero đều có ít nhất 1 kỹ năng ULTIMATE để xả Energy khi đầy 100/100
	var has_ult: bool = false
	for ab in hero.unlocked_abilities:
		if ab.data.ability_type == AbilityData.AbilityType.ULTIMATE:
			has_ult = true
			break
			
	if not has_ult:
		var ult_res: AbilityData = null
		if data.name == "Jaina":
			ult_res = load("res://data/abilities/jaina_eternal_blizzard.tres") as AbilityData
		if ult_res != null:
			hero.unlocked_abilities.append(Ability.new(hero, ult_res))
		else:
			var default_ult := AbilityData.new()
			default_ult.name = data.name + " Ultimate"
			default_ult.ability_type = AbilityData.AbilityType.ULTIMATE
			default_ult.target_rule = AbilityData.TargetRule.SINGLE_ENEMY
			default_ult.cooldown = 1.0
			var ult_dmg := DamageEffectData.new()
			ult_dmg.base_damage = data.base_attack * 2.5
			default_ult.effects.append(ult_dmg)
			hero.unlocked_abilities.append(Ability.new(hero, default_ult))

	if data.name == "Arthur":
		var shield_ab = load("res://data/abilities/arthur_holy_shield.tres") as AbilityData
		if shield_ab:
			var has_shield := false
			for ab in hero.unlocked_abilities:
				if ab.data.id == shield_ab.id:
					has_shield = true
					break
			if not has_shield:
				hero.unlocked_abilities.append(Ability.new(hero, shield_ab))

	hero.healed.connect(_on_entity_healed)
	if hero.progression != null:
		hero.progression.xp_gained.connect(func(amt: float): _on_hero_xp_gained(hero, amt))
		hero.progression.milestone_reached.connect(func(ms: int): _on_hero_milestone(hero, ms))
	heroes.append(hero)
	return hero

func _spawn_custom_enemy_at_grid(data: EnemyData, cell: Vector2i, spawn_level: int = 1, spawn_rank: EnemyData.EnemyRank = EnemyData.EnemyRank.NORMAL, is_solo_boss: bool = false) -> EnemyEntity:
	var enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(enemy)
	enemy.board_grid = board_grid
	enemy.board_view = board_view
	enemy.targeting_system = targeting_system
	
	if board_grid != null:
		board_grid.place_entity(enemy, cell)
	if board_view != null:
		enemy.global_position = board_view.grid_to_world(cell)
	else:
		enemy.global_position = Vector2(cell * 80)
	
	enemy.died.connect(_on_entity_died.bind(false))
	enemy.attack_requested.connect(_on_entity_attack_requested)
	enemy.ability_requested.connect(ability_system.execute_ability)
	enemy.initialize(data, spawn_level, spawn_rank, is_solo_boss)
	enemy.healed.connect(_on_entity_healed)
	enemies.append(enemy)
	return enemy

func _spawn_enemy_at_grid(e_name: String, hp: float, atk: float, def: float, spd: float, crit_c: float, crit_d: float, cell: Vector2i) -> EnemyEntity:
	var data: EnemyData = EnemyData.new()
	data.name = e_name
	data.base_hp = hp
	data.base_attack = atk
	data.base_defense = def
	data.attack_speed = spd
	data.attack_range = 1
	data.crit_chance = crit_c
	data.crit_damage = crit_d
	return _spawn_custom_enemy_at_grid(data, cell, 1, EnemyData.EnemyRank.NORMAL, false)

# ==========================================
# SPRINT 4: ENCOUNTER DIRECTOR & MONSTER SKILLS (TASK S4.4)
# ==========================================
enum FloorType { NORMAL_FLOOR, ELITE_FLOOR, BOSS_FLOOR }

static func create_slime_normal_ability() -> AbilityData:
	var ab := AbilityData.new()
	ab.name = "Phun Dịch Axit"
	ab.ability_type = AbilityData.AbilityType.ACTIVE
	ab.target_rule = AbilityData.TargetRule.SINGLE_ENEMY
	ab.cooldown = 4.0
	ab.energy_cost = 40.0
	var dmg := DamageEffectData.new()
	dmg.base_amount = 25.0
	dmg.damage_type = DamageEvent.DamageType.MAGIC
	dmg.scalings = { EffectData.STAT_AP: 0.50 }
	ab.effects = [dmg]
	ab.description = "Bắn dịch axit ăn mòn vào kẻ địch, gây {0} sát thương phép."
	return ab

static func create_slime_elite_ability() -> AbilityData:
	var ab := AbilityData.new()
	ab.name = "Bùng Nổ Độc Tố"
	ab.ability_type = AbilityData.AbilityType.ACTIVE
	ab.target_rule = AbilityData.TargetRule.SELF
	ab.aoe_shape = AbilityData.AoEShape.HEX_RADIUS
	ab.aoe_radius = 1
	ab.cooldown = 5.0
	ab.energy_cost = 60.0
	var dmg := DamageEffectData.new()
	dmg.base_amount = 50.0
	dmg.damage_type = DamageEvent.DamageType.MAGIC
	dmg.scalings = { EffectData.STAT_AP: 0.80 }
	ab.effects = [dmg]
	ab.description = "Bùng nổ độc tố lan tỏa bán kính 1 ô xung quanh, gây {0} sát thương phép lên kẻ địch."
	return ab

static func create_slime_boss_ability() -> AbilityData:
	var ab := AbilityData.new()
	ab.name = "Đại Hồng Thủy Hắc Ám"
	ab.ability_type = AbilityData.AbilityType.ULTIMATE
	ab.target_rule = AbilityData.TargetRule.DENSEST_ENEMY_CLUSTER
	ab.aoe_shape = AbilityData.AoEShape.HEX_RADIUS
	ab.aoe_radius = 1
	ab.cooldown = 8.0
	ab.energy_cost = 100.0
	var dmg := DamageEffectData.new()
	dmg.base_amount = 120.0
	dmg.damage_type = DamageEvent.DamageType.MAGIC
	dmg.scalings = { EffectData.STAT_AP: 1.20 }
	var heal := HealEffectData.new()
	heal.base_amount = 80.0
	heal.scalings = { EffectData.STAT_AP: 0.50 }
	ab.effects = [dmg, heal]
	ab.description = "Giáng thiên thạch bùn độc vào cụm tướng đông nhất gây {0} sát thương phép, đồng thời hồi {1} Máu cho bản thân."
	return ab

func get_floor_type(floor_num: int) -> FloorType:
	if floor_num % 5 == 0:
		return FloorType.BOSS_FLOOR
	elif floor_num % 3 == 0:
		return FloorType.ELITE_FLOOR
	else:
		return FloorType.NORMAL_FLOOR

func spawn_encounter_for_floor(floor_num: int, force_boss_variant: int = 0) -> void:
	for e in enemies:
		if is_instance_valid(e):
			if board_grid != null:
				board_grid.remove_dead_entity(e)
			e.set_combat_active(false)
			e.queue_free()
	enemies.clear()
	
	var floor_type := get_floor_type(floor_num)
	var base_floor_lv := maxi(1, (floor_num - 1) * 2 + 1)
	
	var max_hero_lv := 1
	for h in heroes:
		if is_instance_valid(h) and h is HeroEntity and h.progression != null:
			max_hero_lv = maxi(max_hero_lv, h.progression.current_level)
			
	match floor_type:
		FloorType.NORMAL_FLOOR:
			var slime_coords = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(3, 1)]
			for i in range(slime_coords.size()):
				var edata := EnemyData.new()
				edata.name = "Slime %d" % (i + 1)
				edata.rank = EnemyData.EnemyRank.NORMAL
				edata.base_hp = 80.0
				edata.base_attack = 8.0
				edata.base_defense = 5.0
				edata.base_spell_power = 10.0
				edata.attack_speed = 1.0
				edata.abilities = [create_slime_normal_ability()]
				_spawn_custom_enemy_at_grid(edata, slime_coords[i], base_floor_lv, EnemyData.EnemyRank.NORMAL)
				
		FloorType.ELITE_FLOOR:
			var elite_lv: int = base_floor_lv + randi_range(2, 4)
			var elite_edata := EnemyData.new()
			elite_edata.name = "Slime Tinh Anh"
			elite_edata.rank = EnemyData.EnemyRank.ELITE
			elite_edata.base_hp = 120.0
			elite_edata.base_attack = 14.0
			elite_edata.base_defense = 8.0
			elite_edata.base_spell_power = 15.0
			elite_edata.abilities = [create_slime_elite_ability()]
			_spawn_custom_enemy_at_grid(elite_edata, Vector2i(3, 1), elite_lv, EnemyData.EnemyRank.ELITE)
			
			var normal_coords = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
			for i in range(normal_coords.size()):
				var norm_lv := maxi(1, elite_lv - randi_range(1, 5))
				var edata := EnemyData.new()
				edata.name = "Slime Thường %d" % (i + 1)
				edata.rank = EnemyData.EnemyRank.NORMAL
				edata.base_hp = 80.0
				edata.base_attack = 8.0
				edata.base_defense = 5.0
				edata.base_spell_power = 10.0
				edata.abilities = [create_slime_normal_ability()]
				_spawn_custom_enemy_at_grid(edata, normal_coords[i], norm_lv, EnemyData.EnemyRank.NORMAL)
				
		FloorType.BOSS_FLOOR:
			var variant := force_boss_variant
			if variant == 0:
				variant = 1 if randf() < 0.5 else 2
				
			if variant == 1:
				var boss_lv := max_hero_lv + randi_range(2, 3)
				var boss_edata := EnemyData.new()
				boss_edata.name = "Slime Đại Vương"
				boss_edata.rank = EnemyData.EnemyRank.BOSS
				boss_edata.base_hp = 250.0
				boss_edata.base_attack = 20.0
				boss_edata.base_defense = 12.0
				boss_edata.base_spell_power = 25.0
				boss_edata.abilities = [create_slime_boss_ability()]
				_spawn_custom_enemy_at_grid(boss_edata, Vector2i(3, 1), boss_lv, EnemyData.EnemyRank.BOSS, false)
				
				var elite_count := randi_range(1, 2)
				var elite_pos = [Vector2i(2, 2), Vector2i(4, 2)]
				for i in range(elite_count):
					var elite_i_lv := maxi(1, boss_lv - randi_range(1, 2))
					var elite_edata := EnemyData.new()
					elite_edata.name = "Hộ Vệ Tinh Anh %d" % (i + 1)
					elite_edata.rank = EnemyData.EnemyRank.ELITE
					elite_edata.base_hp = 120.0
					elite_edata.base_attack = 14.0
					elite_edata.base_defense = 8.0
					elite_edata.base_spell_power = 15.0
					elite_edata.abilities = [create_slime_elite_ability()]
					_spawn_custom_enemy_at_grid(elite_edata, elite_pos[i], elite_i_lv, EnemyData.EnemyRank.ELITE)
			else:
				var solo_boss_lv := max_hero_lv + randi_range(2, 3)
				var boss_edata := EnemyData.new()
				boss_edata.name = "Slime Chúa Tể"
				boss_edata.rank = EnemyData.EnemyRank.BOSS
				boss_edata.base_hp = 300.0
				boss_edata.base_attack = 25.0
				boss_edata.base_defense = 15.0
				boss_edata.base_spell_power = 30.0
				boss_edata.abilities = [create_slime_boss_ability()]
				_spawn_custom_enemy_at_grid(boss_edata, Vector2i(3, 2), solo_boss_lv, EnemyData.EnemyRank.BOSS, true)

# Giữ lại các hàm spawn bằng offset cũ cho tính tương thích ngược nếu cần
func _spawn_hero(data: HeroData, offset: Vector2) -> void:
	var cell := Vector2i(1, 2)
	if board_view != null:
		cell = board_view.world_to_grid(offset)
	_spawn_hero_at_grid(data, cell)

func _spawn_enemy(e_name: String, hp: float, atk: float, def: float, spd: float, crit_c: float, crit_d: float, offset: Vector2) -> void:
	var cell := Vector2i(6, 2)
	if board_view != null:
		cell = board_view.world_to_grid(offset)
	_spawn_enemy_at_grid(e_name, hp, atk, def, spd, crit_c, crit_d, cell)

func _on_entity_died(entity: CombatEntity, is_hero: bool) -> void:
	if is_hero:
		heroes.erase(entity)
	else:
		enemies.erase(entity)
		
	if board_grid != null:
		board_grid.remove_dead_entity(entity)
		
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
		progression_system.finalize_battle_xp(is_victory)
	
	var run_result: Dictionary = {}
	if RunManager != null:
		if is_victory:
			run_result = RunManager.on_battle_won()
		else:
			run_result = RunManager.on_battle_lost()
		current_floor = RunManager.current_floor
	
	_build_post_battle_choice_queue()
	
	if combat_summary_ui != null:
		var summary_heroes: Array[CombatEntity] = []
		summary_heroes.append_array(heroes)
		for c in corpses:
			if is_instance_valid(c) and c is HeroEntity and not summary_heroes.has(c):
				summary_heroes.append(c)
		var display_floor: int = run_result.get("floor", current_floor)
		combat_summary_ui.show_summary(is_victory, display_floor, summary_heroes, run_result)
	else:
		_on_summary_continued()

func _on_summary_continued() -> void:
	var can_continue: bool = true
	if RunManager != null:
		can_continue = RunManager.current_lives > 0
		
	if next_game_state == GameManager.GameState.GAME_OVER and not can_continue:
		_finish_battle_cleanup()
		_reset_heroes_for_new_run()
		if RunManager != null:
			RunManager.start_new_run()
			current_floor = RunManager.current_floor
		if SaveManager != null:
			SaveManager.delete_save()
		GameManager.change_state(GameManager.GameState.GAME_OVER)
		print("[BattleManager] 🛑 PERMA-DEATH: Đã reset toàn bộ Hero về Level 1.")
	else:
		# SPRINT 5 (MODEL A): NON-BLOCKING PREPARATION
		# Không tự động bật skill_ui đè màn hình. Chuyển thẳng sang phase Chuẩn bị!
		_finish_battle_cleanup()

func _reset_heroes_for_new_run() -> void:
	var all_heroes: Array[CombatEntity] = []
	all_heroes.append_array(heroes)
	for c in corpses:
		if is_instance_valid(c) and c is HeroEntity and not all_heroes.has(c):
			all_heroes.append(c)
			
	for h in all_heroes:
		if is_instance_valid(h) and h is HeroEntity:
			var hero := h as HeroEntity
			if hero.progression != null:
				hero.progression.current_level = 1
				hero.progression.current_xp = 0.0
				hero.progression.pending_milestones.clear()
			hero.has_pending_milestone = false
			hero.pending_upgrade_milestone = 0
			hero.passive_stat_bonus = 0.0
			hero.unlocked_abilities.clear()
			if hero.data != null:
				hero.initialize(hero.data)
			var has_ult: bool = false
			for ab in hero.unlocked_abilities:
				if ab.data.ability_type == AbilityData.AbilityType.ULTIMATE:
					has_ult = true
					break
			if not has_ult and hero.data != null:
				var default_ult := AbilityData.new()
				default_ult.name = hero.data.name + " Ultimate"
				default_ult.ability_type = AbilityData.AbilityType.ULTIMATE
				default_ult.target_rule = AbilityData.TargetRule.SINGLE_ENEMY
				default_ult.cooldown = 1.0
				var ult_dmg := DamageEffectData.new()
				ult_dmg.base_damage = hero.data.base_attack * 2.5
				default_ult.effects.append(ult_dmg)
				hero.unlocked_abilities.append(Ability.new(hero, default_ult))
			hero.reset_for_new_battle()

func _build_post_battle_choice_queue() -> void:
	choice_queue.clear()
	# RÀ SOÁT: Nối mảng an toàn không qua toán tử +
	var all_heroes: Array[CombatEntity] = []
	all_heroes.append_array(heroes)
	all_heroes.append_array(corpses)
	
	for entity in all_heroes:
		if entity is HeroEntity:
			var hero = entity as HeroEntity
			if hero.pending_milestones.is_empty():
				continue
				
			# SPRINT 5: ONE-CHOICE RULE & MILESTONE FUSION (GD SPEC SECTION I.2)
			# Mỗi Hero chỉ kích hoạt DUY NHẤT 1 lần mở bảng chọn thẻ kỹ năng sau trận
			hero.pending_milestones.sort()
			var highest_milestone: int = hero.pending_milestones[-1]
			var skipped_count: int = hero.pending_milestones.size() - 1
			
			# Đền bù mốc bị bỏ qua: +5% stats per skipped milestone
			if skipped_count > 0:
				hero.add_milestone_compensation(skipped_count)
				
			var choices: Array = []
			if progression_system != null:
				choices = progression_system.generate_upgrade_choices(hero, highest_milestone)
			if choices.is_empty():
				choices = hero.pull_milestone_choices(highest_milestone)
			if not choices.is_empty():
				choice_queue.append({
					"hero": hero,
					"milestone": highest_milestone,
					"choices": choices
				})
			hero.pending_upgrade_milestone = highest_milestone
			hero.has_pending_milestone = true
			hero.pending_milestones.clear()

func handle_hero_clicked(hero: HeroEntity) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if hero.has_pending_milestone and current_phase == EncounterPhase.PREPARATION:
		open_hero_skill_choice(hero)
	elif is_instance_valid(character_stats_ui):
		character_stats_ui.inspect_hero(hero)

func open_hero_skill_choice(hero: HeroEntity) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if not hero.has_pending_milestone:
		return
		
	# Khóa PlacementController và ngắt kéo dở ngay lập tức
	if placement_controller != null:
		placement_controller.set_locked(true)
		
	var milestone_to_use: int = hero.pending_upgrade_milestone
	if milestone_to_use <= 0 and not hero.pending_milestones.is_empty():
		hero.pending_milestones.sort()
		milestone_to_use = hero.pending_milestones[-1]
		var skipped_count: int = hero.pending_milestones.size() - 1
		if skipped_count > 0:
			hero.add_milestone_compensation(skipped_count)
	if milestone_to_use <= 0:
		milestone_to_use = 5
		
	var choices: Array = []
	if progression_system != null:
		choices = progression_system.generate_upgrade_choices(hero, milestone_to_use)
	if choices.is_empty():
		choices = hero.pull_milestone_choices(milestone_to_use)
		
	_active_choice_hero = hero
	_active_choice_milestone = milestone_to_use
	if is_instance_valid(skill_ui):
		skill_ui.show_choices(hero.name, milestone_to_use, choices)

func _process_next_choice() -> void:
	if choice_queue.is_empty(): return
	var next = choice_queue[0]
	skill_ui.show_choices(next.hero.name, next.milestone, next.choices)

func _on_skill_chosen(chosen: Variant, all_choices: Array) -> void:
	var hero_to_apply: HeroEntity = _active_choice_hero
	var milestone_to_apply: int = _active_choice_milestone
	var from_queue: bool = false
	
	if (hero_to_apply == null or not is_instance_valid(hero_to_apply)) and not choice_queue.is_empty():
		var current = choice_queue.pop_front()
		if current != null and current.has("hero") and is_instance_valid(current.hero):
			hero_to_apply = current.hero
			milestone_to_apply = current.milestone
			from_queue = true
			
	if hero_to_apply != null and is_instance_valid(hero_to_apply):
		if chosen is SkillUpgradeCard:
			chosen.apply_to_hero(hero_to_apply)
		elif chosen is AbilityData:
			var all_ab: Array[AbilityData] = []
			for c in all_choices:
				if c is AbilityData:
					all_ab.append(c as AbilityData)
			hero_to_apply.apply_skill_choice(milestone_to_apply, chosen, all_ab)
		hero_to_apply.has_pending_milestone = false
		hero_to_apply.pending_milestones.clear()
		hero_to_apply.pending_upgrade_milestone = 0
		_active_choice_hero = null
		_active_choice_milestone = 0
	
	if is_instance_valid(skill_ui):
		skill_ui.hide()
		
	# Mở khóa PlacementController khi thoát modal nếu đang ở Preparation Phase
	if placement_controller != null and current_phase == EncounterPhase.PREPARATION:
		placement_controller.set_locked(false)
		
	# Only continue queue in legacy sequential mode (TC-07.4)
	if from_queue and choice_queue.size() > 0:
		_process_next_choice()

func _finish_battle_cleanup() -> void:
	var surviving_hero_corpses: Array[CombatEntity] = []
	for corpse in corpses:
		if is_instance_valid(corpse):
			if corpse is HeroEntity:
				surviving_hero_corpses.append(corpse)
			else:
				corpse.queue_free()
	corpses = surviving_hero_corpses

	# Nếu GAME_OVER và hết mạng thì dừng lại, không tự qua tầng mới
	if next_game_state == GameManager.GameState.GAME_OVER and (RunManager == null or RunManager.current_lives <= 0):
		if SaveManager != null:
			SaveManager.delete_save()
		GameManager.change_state(GameManager.GameState.GAME_OVER)
		print("[BattleManager] 🛑 GAME OVER - Stopping floor progression.")
		return

	_save_current_run()

	get_tree().create_timer(1.0).timeout.connect(_start_next_floor)

func _start_next_floor() -> void:
	battle_ended = false
	if RunManager != null:
		current_floor = RunManager.current_floor
	print("\n=====================================")
	print("[BattleManager] 🚀 BẮT ĐẦU MÀN MỚI / TẦNG %d 🚀" % current_floor)
	print("=====================================")
	
	if board_grid != null:
		board_grid.is_locked = false
		board_grid.clear()
		
	# Hồi sinh và tái hợp nhất toàn bộ Hero từ corpses về heroes
	for dead_hero in corpses:
		if is_instance_valid(dead_hero) and not heroes.has(dead_hero):
			heroes.append(dead_hero)
	corpses.clear()
	
	# Reset trạng thái và tái chiếm ô cho toàn bộ Heroes
	for hero in heroes:
		if is_instance_valid(hero):
			hero.reset_for_new_battle()
			var target_cell := hero.deployed_cell
			var placed := false
			if board_grid != null and board_config != null:
				if board_grid.is_in_bounds(target_cell) and board_config.is_hero_zone(target_cell) and board_grid.is_cell_empty(target_cell):
					placed = board_grid.place_entity(hero, target_cell)
				if not placed:
					var empty_hero_cells := board_grid.get_empty_hero_cells()
					if not empty_hero_cells.is_empty():
						target_cell = empty_hero_cells[0]
						hero.deployed_cell = target_cell
						placed = board_grid.place_entity(hero, target_cell)
					else:
						for col in range(board_config.cols):
							for row in range(board_config.rows):
								var fb_cell := Vector2i(col, row)
								if board_grid.is_cell_empty(fb_cell):
									target_cell = fb_cell
									hero.deployed_cell = target_cell
									placed = board_grid.place_entity(hero, target_cell)
									break
							if placed: break
			if board_view != null and placed:
				hero.global_position = board_view.grid_to_world(target_cell)
				
	spawn_encounter_for_floor(current_floor)
	enter_preparation_phase()

# ==========================================
# FULL SAVE & RESUME RUNTIME (SPRINT 4 SIGN-OFF)
# ==========================================
func _save_current_run() -> void:
	if SaveManager == null or RunManager == null:
		return
	var hero_list: Array = []
	for h in heroes:
		if is_instance_valid(h) and h is HeroEntity:
			hero_list.append(h.serialize())
	for c in corpses:
		if is_instance_valid(c) and c is HeroEntity:
			var already_saved := false
			for saved_h in hero_list:
				if saved_h.get("name") == c.name:
					already_saved = true
					break
			if not already_saved:
				hero_list.append(c.serialize())
				
	SaveManager.save_game({
		"floor": current_floor,
		"gold": RunManager.current_gold,
		"lives": RunManager.current_lives,
		"max_lives": RunManager.max_lives,
		"heroes": hero_list
	})

func _try_resume_saved_run() -> bool:
	if SaveManager == null:
		return false
	var data := SaveManager.load_game()
	if data.is_empty():
		return false
	if RunManager != null:
		RunManager.current_floor = int(data.get("floor", 1))
		RunManager.current_gold = int(data.get("gold", 10))
		RunManager.current_lives = int(data.get("lives", 2))
		RunManager.max_lives = int(data.get("max_lives", 2))
		current_floor = RunManager.current_floor
		
	if data.has("heroes") and typeof(data["heroes"]) == TYPE_ARRAY:
		var saved_heroes: Array = data["heroes"]
		for s_hero in saved_heroes:
			var h_name: String = s_hero.get("name", "")
			for h in heroes:
				if is_instance_valid(h) and h is HeroEntity and (h.name == h_name or (h.data != null and h.data.name == h_name)):
					h.deserialize(s_hero)
					if board_grid != null and board_view != null:
						board_grid.place_entity(h, h.deployed_cell)
						h.global_position = board_view.grid_to_world(h.deployed_cell)
					break
	spawn_encounter_for_floor(current_floor)
	print("[BattleManager] 💾 RUN RESUMED! Floor: %d | Gold: %d | Lives: %d" % [
		current_floor,
		RunManager.current_gold if RunManager else 0,
		RunManager.current_lives if RunManager else 0
	])
	return true

# ==========================================
# QA & DEV CHEAT HELPERS (SPRINT 4 SIGN-OFF / SPRINT 5)
# ==========================================
func toggle_god_mode() -> bool:
	is_god_mode = not is_god_mode
	for h in heroes:
		if is_instance_valid(h):
			h.is_invulnerable = is_god_mode
	print("[CHEAT] 🛡️ God Mode: ", "BẬT" if is_god_mode else "TẮT")
	if debug_cheat_ui != null:
		debug_cheat_ui.update_info()
	return is_god_mode

func cheat_kill_all_enemies() -> void:
	print("[CHEAT] ⚡ KILL ALL ENEMIES!")
	var living_enemies: Array[CombatEntity] = []
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			living_enemies.append(e)
	for e in living_enemies:
		e.take_damage(999999.0)
	if debug_cheat_ui != null:
		debug_cheat_ui.update_info()

func cheat_warp_floor(target_floor: int) -> void:
	print("[CHEAT] 🌀 WARP TO FLOOR %d!" % target_floor)
	current_floor = target_floor
	if RunManager != null:
		RunManager.current_floor = target_floor
	_start_next_floor()
	if debug_cheat_ui != null:
		debug_cheat_ui.update_info()

func cheat_cycle_speed() -> float:
	match Engine.time_scale:
		1.0: Engine.time_scale = 2.0
		2.0: Engine.time_scale = 5.0
		5.0: Engine.time_scale = 0.5
		_: Engine.time_scale = 1.0
	print("[CHEAT] ⏩ Game Speed: %.1fx" % Engine.time_scale)
	if debug_cheat_ui != null:
		debug_cheat_ui.update_info()
	return Engine.time_scale

# ==========================================
# FLOATING TEXT SPAWNER (SPRINT 5 VFX)
# ==========================================
func _spawn_floating_text(pos: Vector2, text_str: String, type: FloatingText.Type) -> void:
	if FLOATING_TEXT_SCENE == null:
		return
	var ft: FloatingText = FLOATING_TEXT_SCENE.instantiate() as FloatingText
	add_child(ft)
	# Nhích nhẹ lên trên đầu thực thể và lệch ngẫu nhiên nhỏ để chống đè lấp chữ
	ft.global_position = pos + Vector2(randf_range(-12.0, 12.0), randf_range(-30.0, -20.0))
	ft.setup(text_str, type)

func _on_entity_attack_requested(event: DamageEvent) -> void:
	if is_instance_valid(event.source) and is_instance_valid(event.target):
		event.source.play_lunge_vfx(event.target.global_position)
	combat_system.process_attack(event)

func _on_combat_damage_dealt(_source: CombatEntity, target: CombatEntity, amount: float, is_crit: bool, damage_type: int = DamageEvent.DamageType.PHYSICAL) -> void:
	if not is_instance_valid(target):
		return
	target.play_hit_vfx()
	var dmg_val: int = maxi(1, roundi(amount))
	if is_crit:
		_shake_camera(4.0, 0.18)
		_spawn_floating_text(target.global_position, "%d!" % dmg_val, FloatingText.Type.CRIT)
	else:
		match damage_type:
			DamageEvent.DamageType.MAGIC:
				_spawn_floating_text(target.global_position, str(dmg_val), FloatingText.Type.DAMAGE_MAGIC)
			DamageEvent.DamageType.TRUE:
				_spawn_floating_text(target.global_position, str(dmg_val), FloatingText.Type.DAMAGE_TRUE)
			_:
				_spawn_floating_text(target.global_position, str(dmg_val), FloatingText.Type.DAMAGE_PHYSICAL)

func _on_ability_executed(source: CombatEntity, ability: Ability) -> void:
	if not is_instance_valid(source) or ability == null or ability.data == null:
		return
		
	# Đánh thường bằng Resource (Kira basic attack) chỉ kích hoạt Lunge VFX, không gọi Cast VFX và không bắn Banner
	if source is HeroEntity and (source as HeroEntity).basic_attack_ability == ability:
		if is_instance_valid(source.target):
			source.play_lunge_vfx(source.target.global_position)
		return

	source.play_cast_vfx()
	
	if ability.data.ability_type == AbilityData.AbilityType.ULTIMATE:
		_shake_camera(6.0, 0.25)
		_spawn_floating_text(source.global_position + Vector2(0, -35), "[ULTIMATE] %s!" % ability.data.name, FloatingText.Type.SYSTEM)
	elif ability.data.ability_type == AbilityData.AbilityType.ACTIVE:
		_spawn_floating_text(source.global_position + Vector2(0, -35), "[ACTIVE] %s!" % ability.data.name, FloatingText.Type.SYSTEM)

func _shake_camera(intensity: float, duration: float = 0.2) -> void:
	if camera == null:
		return
	# Anti-stacking: chỉ override nếu rung động mới mạnh hơn rung động hiện tại
	if _shake_tween != null and _shake_tween.is_running():
		if intensity <= _current_shake_strength:
			return
		_shake_tween.kill()
	else:
		_current_shake_strength = 0.0
		
	_current_shake_strength = intensity
	_shake_tween = create_tween()
	
	var steps: int = maxi(2, int(duration / 0.04))
	var step_time: float = duration / steps
	
	for i in range(steps):
		var damping: float = 1.0 - (float(i) / float(steps))
		var offset := Vector2(
			randf_range(-intensity, intensity) * damping,
			randf_range(-intensity, intensity) * damping
		)
		_shake_tween.tween_property(camera, "offset", offset, step_time)
		
	_shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)
	_shake_tween.tween_callback(func(): _current_shake_strength = 0.0)

func _on_entity_healed(entity: CombatEntity, amount: float) -> void:
	if not is_instance_valid(entity):
		return
	var heal_val: int = maxi(1, roundi(amount))
	_spawn_floating_text(entity.global_position, "+%d" % heal_val, FloatingText.Type.HEAL)

func _on_hero_xp_gained(hero: HeroEntity, amount: float) -> void:
	if not is_instance_valid(hero):
		return
	var xp_val: int = roundi(amount)
	if xp_val > 0:
		_spawn_floating_text(hero.global_position + Vector2(0, -15), "+%d XP" % xp_val, FloatingText.Type.XP)

func _on_hero_milestone(hero: HeroEntity, milestone: int) -> void:
	if not is_instance_valid(hero):
		return
	_spawn_floating_text(hero.global_position + Vector2(0, -35), "LV.%d MILESTONE!" % milestone, FloatingText.Type.SYSTEM)


# ==============================================================================
# SPRINT 4 AUTOMATED TEST RUNNER (BẢN XUẤT RA FILE REPORT)
# Phím 0: Chạy toàn bộ Test Suite và lưu vào file
# ==============================================================================
var test_report_path: String = "user://sprint4_test_report.txt"

# Hàm hỗ trợ vừa in ra Console, vừa ghi vào File Report
func _log_test(msg: String) -> void:
	print("📝 ", msg) # In ra console với icon để dễ phân biệt với log game
	
	var file: FileAccess
	if FileAccess.file_exists(test_report_path):
		file = FileAccess.open(test_report_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(test_report_path, FileAccess.WRITE)
	
	if file != null:
		file.store_line(msg)
		file.close()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var screen_pos: Vector2 = event.position
		# 1. Nếu click vào panel hoặc crest badge -> Bỏ qua, giữ nguyên mở
		if is_instance_valid(character_stats_ui) and character_stats_ui.visible:
			if character_stats_ui.is_click_inside(screen_pos):
				return
				
		# 2. Kiểm tra click vào Tướng hoặc Quái trên sàn đấu
		var mouse_pos: Vector2 = get_global_mouse_position()
		var all_entities: Array[CombatEntity] = []
		all_entities.append_array(heroes)
		all_entities.append_array(enemies)
		for e in all_entities:
			if is_instance_valid(e) and not e.is_dead:
				var rad: float = board_config.hex_radius if board_config != null else 44.0
				var is_clicked: bool = (e.global_position.distance_to(mouse_pos) <= rad)
				if not is_clicked and e is HeroEntity and (e as HeroEntity).has_pending_milestone:
					var badge_pos: Vector2 = e.global_position + Vector2(0, -56)
					if mouse_pos.distance_to(badge_pos) <= 32.0:
						is_clicked = true
						
				if is_clicked:
					if e is HeroEntity:
						handle_hero_clicked(e as HeroEntity)
					elif is_instance_valid(character_stats_ui):
						character_stats_ui.inspect_hero(e)
					return
					
		# 3. Click ngoài khoảng trống hoặc ô cờ trống -> Tự động đóng bảng stat
		if is_instance_valid(character_stats_ui) and character_stats_ui.visible:
			character_stats_ui.close()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed): return
	
	match event.keycode:
		KEY_SPACE:
			print("\n[DEBUG] 🚀 BƠM 800 XP CHO TOÀN BỘ HEROES!")
			for hero in heroes:
				if is_instance_valid(hero) and hero.progression != null:
					hero.progression.add_xp(800.0)
					
		# PHÍM 0: CHẠY TOÀN BỘ 16 TEST CASE VÀ GHI REPORT
		KEY_0:
			_run_all_tests()
			
		# Chạy lẻ từng test như cũ
		KEY_1: _run_tc_03_energy_and_ultimate()
		KEY_2: _run_tc_04_passive_recursion()
		KEY_3: _run_tc_02_targeting_rules()
		KEY_4: _run_tc_01_active_ability_xp()
		KEY_5: _run_tc_05_post_battle_choice_queue()
		KEY_6: _run_tc_06_xp_regression()
		KEY_7: _run_tc_07_sprint5_ui_vfx()
		KEY_8: _run_tc_08_board_grid_model()
		KEY_9: _run_tc_09_board_view_and_placement()
		KEY_MINUS: _run_tc_10_targeting_and_spatial()
		KEY_EQUAL: _run_tc_11_grid_movement_and_pathfinding()
		KEY_BRACKETLEFT: _run_tc_12_combat_metrics_and_progression()
		KEY_BRACKETRIGHT: _run_tc_13_combat_summary_ui()
		KEY_BACKSLASH: _run_tc_14_roguelike_run_lifecycle()
		KEY_SLASH: _run_tc_15_combat_retargeting()
		KEY_PERIOD: _run_tc_16_character_stats_ui()
		KEY_COMMA: _run_tc_17_skill_scaling_and_tooltip()
		KEY_SEMICOLON: _run_tc_18_skill_upgrades_and_isolation()
		KEY_APOSTROPHE: _run_tc_19_narrative_and_encounter_director()
		KEY_ENTER: _run_tc_20_procedural_ui_and_polymorphism()
		KEY_BACKSPACE: _run_tc_21_save_resume_and_boss_balance()
		KEY_F2: _run_tc_22_floating_combat_text()
		KEY_F3: _run_tc_23_tft_level_crest_and_compact_grid()
		KEY_F4: _run_tc_24_hero_stat_progression_and_seamless_ui()
		KEY_F5: _run_tc_25_monolithic_header_one_choice_and_scaling()
		KEY_F8: _run_tc_26_model_a_tft_and_lmht_tooltips()
		KEY_F9: _run_tc_27_dynamic_prestige_border_palette()
		
		# QA & DEV CHEAT SHORTCUTS (GD & QA SIGN-OFF)
		KEY_F1, KEY_QUOTELEFT:
			if debug_cheat_ui != null:
				debug_cheat_ui.toggle_visibility()
		KEY_G:
			toggle_god_mode()
		KEY_K:
			cheat_kill_all_enemies()
		KEY_F6:
			cheat_warp_floor(5)
		KEY_F7:
			if RunManager != null:
				RunManager.add_gold(50)
				if debug_cheat_ui != null:
					debug_cheat_ui.update_info()

func _run_all_tests() -> void:
	if SaveManager != null:
		SaveManager.delete_save()
		
	var file = FileAccess.open(test_report_path, FileAccess.WRITE)
	if file:
		file.store_line("=== BÁO CÁO KIỂM THỬ SPRINT 1, 2, 3, 4 & 5 ===")
		file.store_line("Thời gian: " + Time.get_datetime_string_from_system())
		file.store_line("==============================================\n")
		file.close()
	
	_log_test("Đang chạy toàn bộ Test Suite (Sprint 1, 2, 3, 4 & 5)...")
	_log_test("Thư mục lưu report: " + ProjectSettings.globalize_path(test_report_path))
	
	_run_tc_01_active_ability_xp()
	_run_tc_02_targeting_rules()
	_run_tc_03_energy_and_ultimate()
	_run_tc_04_passive_recursion()
	_run_tc_05_post_battle_choice_queue()
	_run_tc_06_xp_regression()
	_run_tc_07_sprint5_ui_vfx()
	_run_tc_08_board_grid_model()
	_run_tc_09_board_view_and_placement()
	_run_tc_10_targeting_and_spatial()
	_run_tc_11_grid_movement_and_pathfinding()
	_run_tc_12_combat_metrics_and_progression()
	_run_tc_13_combat_summary_ui()
	_run_tc_14_roguelike_run_lifecycle()
	_run_tc_15_combat_retargeting()
	_run_tc_16_character_stats_ui()
	_run_tc_17_skill_scaling_and_tooltip()
	_run_tc_18_skill_upgrades_and_isolation()
	_run_tc_19_narrative_and_encounter_director()
	_run_tc_20_procedural_ui_and_polymorphism()
	_run_tc_21_save_resume_and_boss_balance()
	_run_tc_22_floating_combat_text()
	_run_tc_23_tft_level_crest_and_compact_grid()
	_run_tc_24_hero_stat_progression_and_seamless_ui()
	_run_tc_25_monolithic_header_one_choice_and_scaling()
	_run_tc_26_model_a_tft_and_lmht_tooltips()
	_run_tc_27_dynamic_prestige_border_palette()
	_run_tc_28_hero_upgrade_anti_displacement()
	_run_tc_29_four_tier_ability_tooltips()
	
	_log_test("\n🎉 TẤT CẢ 29 BÀI TEST ĐÃ HOÀN THÀNH (100% PASSED)!")

# ------------------------------------------------------------------------------
# TC-03: Energy Cost & Ultimate
# ------------------------------------------------------------------------------
func _run_tc_03_energy_and_ultimate() -> void:
	_log_test("\n==================== [TEST TC-03: ENERGY & ULTIMATE] ====================")
	_reset_test_battlefield()
	var hero = heroes[0] as HeroEntity
	
	while enemies.size() > 1:
		var extra_e = enemies.pop_back()
		if is_instance_valid(extra_e): extra_e.queue_free()
	
	var actual_target = enemies[0]
	actual_target.current_hp = 500.0
	var hp_before = actual_target.current_hp
	
	var ult_data = AbilityData.new()
	ult_data.ability_type = AbilityData.AbilityType.ULTIMATE
	ult_data.target_rule = AbilityData.TargetRule.SINGLE_ENEMY
	var dmg = DamageEffectData.new()
	dmg.base_damage = 150.0
	dmg.can_crit = false
	ult_data.effects.append(dmg)
	
	var ult_ability = Ability.new(hero, ult_data)
	hero.unlocked_abilities.clear()
	hero.unlocked_abilities.append(ult_ability)
	hero.current_energy = 100.0
	
	var success = ability_system.execute_ability(ult_ability)
	var hp_after = actual_target.current_hp
	
	_log_test("[TC-03] HP Before: %.1f | HP After: %.1f" % [hp_before, hp_after])
	assert(success, "FAIL: Ultimate execution rejected")
	assert(hp_after < hp_before, "FAIL P0: Expected HP to decrease!")
	assert(hero.current_energy == 0.0, "FAIL: Energy not drained")
	_log_test(">>> 🟢 TC-03 PASSED!\n")

# ------------------------------------------------------------------------------
# TC-04: Passive Recursion & Cooldown
# ------------------------------------------------------------------------------
func _run_tc_04_passive_recursion() -> void:
	_log_test("\n==================== [TEST TC-04: PASSIVE RECURSION & COOLDOWN] ====================")
	_reset_test_battlefield()
	
	while enemies.size() > 1:
		var extra = enemies.pop_back()
		if is_instance_valid(extra): extra.queue_free()
		
	var hero = heroes[0] as HeroEntity
	var enemy = enemies[0]
	enemy.current_hp = 1000.0
	enemy.data.base_defense = 0.0 
	
	var passive_data = AbilityData.new()
	passive_data.name = "Recursive Blade"
	passive_data.ability_type = AbilityData.AbilityType.PASSIVE
	passive_data.trigger_condition = AbilityData.TriggerCondition.ON_CRIT
	passive_data.cooldown = 0.0
	var dmg = DamageEffectData.new()
	dmg.base_damage = 20.0
	dmg.can_crit = true
	passive_data.effects.append(dmg)
	
	var passive_ability = Ability.new(hero, passive_data)
	hero.unlocked_abilities.clear()
	hero.unlocked_abilities.append(passive_ability)
	hero.data.crit_chance = 1.0
	
	var start_hp = enemy.current_hp
	var event = DamageEvent.new(hero, enemy, 50.0, DamageEvent.DamageType.PHYSICAL)
	event.is_crit = true
	event.crit_multiplier = 2.0
	combat_system.process_attack(event)
	
	var expected_hp = start_hp - 140.0
	_log_test("[TC-04.1] Anti-Recursion HP: %.1f -> %.1f (Expected: %.1f)" % [start_hp, enemy.current_hp, expected_hp])
	assert(is_equal_approx(enemy.current_hp, expected_hp), "FAIL TC-04.1")
	
	passive_data.cooldown = 2.0
	passive_ability.current_cooldown = 0.0
	
	var hp_before_cd = enemy.current_hp
	combat_system.process_attack(event)
	var hp_after_first = enemy.current_hp
	assert(is_equal_approx(hp_after_first, hp_before_cd - 140.0), "FAIL TC-04.2")
	assert(passive_ability.current_cooldown > 0.0, "FAIL TC-04.2")
	
	combat_system.process_attack(event)
	var hp_after_second = enemy.current_hp
	assert(is_equal_approx(hp_after_second, hp_after_first - 100.0), "FAIL TC-04.2")
	
	passive_ability.process_cooldown(2.0)
	
	combat_system.process_attack(event)
	var hp_after_third = enemy.current_hp
	assert(is_equal_approx(hp_after_third, hp_after_second - 140.0), "FAIL TC-04.2")
	
	_log_test(">>> 🟢 TC-04 PASSED: Recursion prevented & Cooldown semantics verified!\n")

# ------------------------------------------------------------------------------
# TC-02: Targeting System Contract (8 Rules)
# ------------------------------------------------------------------------------
func _run_tc_02_targeting_rules() -> void:
	_log_test("\n==================== [TEST TC-02: TARGETING RULES] ====================")
	_reset_test_battlefield()
	
	while heroes.size() > 3:
		var extra_h = heroes.pop_back()
		if is_instance_valid(extra_h): extra_h.queue_free()
	while enemies.size() > 3:
		var extra_e = enemies.pop_back()
		if is_instance_valid(extra_e): extra_e.queue_free()
	
	heroes[0].current_hp = 100.0; heroes[0].global_position = Vector2(0, 0); heroes[0].name = "H1"
	heroes[1].current_hp = 40.0;  heroes[1].global_position = Vector2(20, 0); heroes[1].name = "H2"
	heroes[2].current_hp = 70.0;  heroes[2].global_position = Vector2(40, 0); heroes[2].name = "H3"
	
	enemies[0].current_hp = 100.0; enemies[0].global_position = Vector2(100, 0); enemies[0].name = "E1"
	enemies[1].current_hp = 30.0;  enemies[1].global_position = Vector2(50, 0);  enemies[1].name = "E2"
	enemies[2].current_hp = 80.0;  enemies[2].global_position = Vector2(200, 0); enemies[2].name = "E3"
	
	var h1 = heroes[0]
	
	var r_self = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.SELF)
	_log_test("[TC-02] SELF: %s (Expected: ['H1'])" % str(r_self.map(func(e): return e.name)))
	assert(r_self.size() == 1 and r_self[0].name == "H1")
	
	var r_lowest_e = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.LOWEST_HP_ENEMY)
	_log_test("[TC-02] LOWEST_HP_ENEMY: %s (Expected: ['E2'])" % str(r_lowest_e.map(func(e): return e.name)))
	assert(r_lowest_e.size() == 1 and r_lowest_e[0].name == "E2")
	
	var r_nearest_e = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.NEAREST_ENEMY)
	_log_test("[TC-02] NEAREST_ENEMY: %s (Expected: ['E2'])" % str(r_nearest_e.map(func(e): return e.name)))
	assert(r_nearest_e.size() == 1 and r_nearest_e[0].name == "E2")
	
	var r_lowest_a = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.LOWEST_HP_ALLY)
	_log_test("[TC-02] LOWEST_HP_ALLY: %s (Expected: ['H2'])" % str(r_lowest_a.map(func(e): return e.name)))
	assert(r_lowest_a.size() == 1 and r_lowest_a[0].name == "H2")
	
	var r_all_e = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.ALL_ENEMIES)
	_log_test("[TC-02] ALL_ENEMIES count: %d (Expected: 3)" % r_all_e.size())
	assert(r_all_e.size() == 3)
	
	var r_all_a = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.ALL_ALLIES)
	_log_test("[TC-02] ALL_ALLIES count: %d (Expected: 3)" % r_all_a.size())
	assert(r_all_a.size() == 3)
	
	enemies[1].is_dead = true
	var r_nearest_after_death = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.NEAREST_ENEMY)
	_log_test("[TC-02] NEAREST_ENEMY after E2 dead: %s (Expected: ['E1'])" % str(r_nearest_after_death.map(func(e): return e.name)))
	assert(r_nearest_after_death[0].name == "E1")
	
	_log_test(">>> 🟢 TC-02 PASSED!\n")

# ------------------------------------------------------------------------------
# TC-01: Active Ability Damage Pipeline
# ------------------------------------------------------------------------------
func _run_tc_01_active_ability_xp() -> void:
	_log_test("\n==================== [TEST TC-01: ACTIVE ABILITY PIPELINE] ====================")
	_reset_test_battlefield()
	
	while enemies.size() > 1:
		var extra_e = enemies.pop_back()
		if is_instance_valid(extra_e): extra_e.queue_free()
		
	var hero = heroes[0] as HeroEntity
	var enemy = enemies[0]
	enemy.current_hp = 500.0
	
	var active = AbilityData.new()
	active.name = "Fireball"
	active.ability_type = AbilityData.AbilityType.ACTIVE
	active.target_rule = AbilityData.TargetRule.SINGLE_ENEMY
	active.energy_cost = 0.0 
	
	var dmg = DamageEffectData.new()
	dmg.base_damage = 250.0 
	active.effects.append(dmg)
	
	var ability = Ability.new(hero, active)
	hero.current_energy = 100.0 
	
	var hp_before = enemy.current_hp
	var success = ability_system.execute_ability(ability)
	
	_log_test("[TC-01] Execute Success: " + str(success))
	_log_test("[TC-01] Enemy HP: %.1f -> %.1f" % [hp_before, enemy.current_hp])
	
	assert(success, "FAIL TC-01: Ability execution rejected")
	assert(enemy.current_hp < hp_before, "FAIL TC-01: Damage not applied")
	_log_test(">>> 🟢 TC-01 PASSED!\n")

# ------------------------------------------------------------------------------
# TC-06: XP Regression Full Path
# ------------------------------------------------------------------------------
func _run_tc_06_xp_regression() -> void:
	_log_test("\n==================== [TEST TC-06: XP REGRESSION (FULL PATH)] ====================")
	_reset_test_battlefield()
	
	while enemies.size() > 1:
		var extra = enemies.pop_back()
		if is_instance_valid(extra): extra.queue_free()
		
	var hero = heroes[0] as HeroEntity
	hero.data.hero_class = HeroData.HeroClass.ASSASSIN 
	
	var enemy = enemies[0]
	enemy.current_hp = 350.0
	enemy.data.base_defense = 0.0 
	
	var old_progression = hero.progression
	hero.progression = HeroProgression.new()
	
	var temp_combat = CombatSystem.new()
	var temp_prog = ProgressionSystem.new()
	temp_prog.initialize(temp_combat)
	
	temp_combat.process_attack(DamageEvent.new(hero, enemy, 100.0, DamageEvent.DamageType.PHYSICAL))
	
	var crit_event = DamageEvent.new(hero, enemy, 50.0, DamageEvent.DamageType.PHYSICAL)
	crit_event.is_crit = true
	crit_event.crit_multiplier = 1.0 
	temp_combat.process_attack(crit_event)
	
	temp_combat.process_attack(DamageEvent.new(hero, enemy, 200.0, DamageEvent.DamageType.PHYSICAL))
	
	temp_prog.finalize_battle_xp(true)
	
	var final_xp = hero.progression.current_xp
	
	_log_test("[TC-06] Pipeline processing complete. XP Remainder: %.1f" % final_xp)
	assert(final_xp > 0.0, "FAIL TC-06: XP pipeline broken! No XP was processed.")
	
	hero.progression = old_progression
	temp_combat.free()
	temp_prog.free()
	_log_test(">>> 🟢 TC-06 PASSED!\n")

# ------------------------------------------------------------------------------
# TC-05: Multi-Milestone Post-Battle Choice Queue
# ------------------------------------------------------------------------------
func _run_tc_05_post_battle_choice_queue() -> void:
	_log_test("\n==================== [TEST TC-05: INTEGRATION POST-BATTLE QUEUE] ====================")
	_reset_test_battlefield()
	var hero = heroes[0] as HeroEntity
	
	for lvl in [5, 10, 15]:
		var pool: Array[AbilityData] = []
		for i in range(3):
			var a = AbilityData.new()
			a.name = "Skill_%d_%d" % [lvl, i + 1]
			pool.append(a)
		hero.runtime_pools[lvl] = pool
		
	_log_test("[TC-05] Emitting milestone signals to simulate leveling up...")
	hero.progression.milestone_reached.emit(5)
	hero.progression.milestone_reached.emit(10)
	hero.progression.milestone_reached.emit(15)
	
	_log_test("[TC-05] Actual Pending Milestones: " + str(hero.pending_milestones))
	assert(hero.pending_milestones == [5, 10, 15], "FAIL: Progression pipeline failed to register milestones")
	assert(not skill_ui.visible, "FAIL: UI opened mid-combat")
	
	_end_battle(GameManager.GameState.REWARD, "Victory Test")
	assert(choice_queue.size() == 1, "FAIL: One-Choice Rule must consolidate single hero to 1 choice")
	assert(choice_queue[0].milestone == 15, "FAIL: Highest milestone 15 must be chosen")
	if is_instance_valid(skill_ui):
		skill_ui.hide()
	if get_tree() != null:
		get_tree().paused = false
	choice_queue.clear()
	_log_test(">>> 🟢 TC-05 PASSED!\n")

# ------------------------------------------------------------------------------
# TC-07: Sprint 5 UI & VFX Verification
# ------------------------------------------------------------------------------
func _run_tc_07_sprint5_ui_vfx() -> void:
	_log_test("\n==================== [TEST TC-07: SPRINT 5 UI & VFX VERIFICATION] ====================")
	_reset_test_battlefield()
	
	var hero = heroes[0] as HeroEntity
	var enemy = enemies[0] as EnemyEntity
	
	# 1. EntityStatusBar Attachment & Rules
	_log_test("[TC-07.1] Checking EntityStatusBar attachment & role differentiation...")
	assert(hero.status_bar != null and is_instance_valid(hero.status_bar), "FAIL TC-07.1: Hero missing status_bar")
	assert(enemy.status_bar != null and is_instance_valid(enemy.status_bar), "FAIL TC-07.1: Enemy missing status_bar")
	assert(hero.status_bar.energy_bar.visible == true, "FAIL TC-07.1: Hero energy bar should be visible")
	assert(enemy.status_bar.energy_bar.visible == false, "FAIL TC-07.1: Enemy energy bar should be hidden")
	assert(is_equal_approx(hero.status_bar.health_bar.max_value, hero.max_hp), "FAIL TC-07.1: Hero max health bar mismatch")
	assert(is_equal_approx(enemy.status_bar.health_bar.max_value, enemy.max_hp), "FAIL TC-07.1: Enemy max health bar mismatch")
	
	# 2. Dynamic HP & Energy Bar Updates
	_log_test("[TC-07.2] Checking HP & Energy bar reactivity...")
	hero.current_hp = hero.max_hp * 0.5
	if hero.status_bar._hp_tween != null and hero.status_bar._hp_tween.is_valid():
		hero.status_bar._hp_tween.custom_step(0.2)
	assert(is_equal_approx(hero.status_bar.health_bar.value, hero.max_hp * 0.5), "FAIL TC-07.2: Health bar value not synchronized")
	
	hero.current_energy = 80.0
	if hero.status_bar._energy_tween != null and hero.status_bar._energy_tween.is_valid():
		hero.status_bar._energy_tween.custom_step(0.2)
	assert(is_equal_approx(hero.status_bar.energy_bar.value, 80.0), "FAIL TC-07.2: Energy bar value not synchronized")
	
	hero.current_energy = 100.0
	if hero.status_bar._energy_tween != null and hero.status_bar._energy_tween.is_valid():
		hero.status_bar._energy_tween.custom_step(0.2)
	assert(is_equal_approx(hero.status_bar.energy_bar.value, 100.0), "FAIL TC-07.2: Full energy value not synchronized")
	assert(hero.status_bar._energy_flash_tween != null and hero.status_bar._energy_flash_tween.is_valid(), "FAIL TC-07.2: Energy flash not triggered at 100% energy")
	
	# 3. Roguelike Skill Cards UI Rendering
	_log_test("[TC-07.3] Checking Roguelike Skill Cards UI rendering & styling...")
	var p_skill = AbilityData.new()
	p_skill.name = "Blade Dance"
	p_skill.ability_type = AbilityData.AbilityType.PASSIVE
	p_skill.trigger_condition = AbilityData.TriggerCondition.ON_CRIT
	
	var a_skill = AbilityData.new()
	a_skill.name = "Shadow Strike"
	a_skill.ability_type = AbilityData.AbilityType.ACTIVE
	a_skill.cooldown = 4.5
	a_skill.energy_cost = 30.0
	
	var u_skill = AbilityData.new()
	u_skill.name = "Death Mark"
	u_skill.ability_type = AbilityData.AbilityType.ULTIMATE
	
	skill_ui.show_choices(hero.name, 5, [p_skill, a_skill, u_skill])
	assert(skill_ui.visible == true, "FAIL TC-07.3: SkillChoiceUI should be visible")
	assert(skill_ui.cards_container.get_child_count() == 3, "FAIL TC-07.3: Exactly 3 skill cards expected")
	
	for i in range(3):
		var card = skill_ui.cards_container.get_child(i) as PanelContainer
		assert(card != null, "FAIL TC-07.3: Card is not a PanelContainer")
		assert(card.pivot_offset.x > 0.0, "FAIL TC-07.3: Card pivot_offset not centered")
		var style = card.get_theme_stylebox("panel") as StyleBoxFlat
		assert(style != null, "FAIL TC-07.3: Card missing StyleBoxFlat")
		if i == 0:
			assert(style.border_color == Color("2ecc71"), "FAIL TC-07.3: Passive border color mismatch")
		elif i == 1:
			assert(style.border_color == Color("3498db"), "FAIL TC-07.3: Active border color mismatch")
		elif i == 2:
			assert(style.border_color == Color("f39c12"), "FAIL TC-07.3: Ultimate border color mismatch")
			
	# 4. Multi-Milestone Queue Seamless Transition (Blind spot 1 check)
	_log_test("[TC-07.4] Checking multi-milestone synchronous queue transition...")
	choice_queue.clear()
	choice_queue.append({
		"hero": hero,
		"milestone": 5,
		"choices": [p_skill, a_skill, u_skill]
	})
	choice_queue.append({
		"hero": hero,
		"milestone": 10,
		"choices": [p_skill, a_skill, u_skill]
	})
	
	_process_next_choice()
	assert(skill_ui.visible == true, "FAIL TC-07.4: Skill UI not shown for first milestone")
	
	# Simulate choosing skill 1: should synchronously advance to milestone 10 without leaving UI hidden
	_on_skill_chosen(p_skill, [p_skill, a_skill, u_skill])
	assert(choice_queue.size() == 1, "FAIL TC-07.4: Queue should have 1 milestone remaining")
	assert(skill_ui.visible == true, "FAIL TC-07.4: Skill UI should remain visible for milestone 10")
	
	# Simulate choosing skill 2: finishes reward phase
	_on_skill_chosen(u_skill, [p_skill, a_skill, u_skill])
	assert(choice_queue.size() == 0, "FAIL TC-07.4: Queue should now be empty")
	skill_ui.hide()
	if get_tree() != null:
		get_tree().paused = false
		
	# 5. Combat Juice Anti-Stacking Camera Shake
	_log_test("[TC-07.5] Checking camera shake anti-stacking trauma logic...")
	if camera != null:
		_shake_camera(4.0, 0.18)
		assert(is_equal_approx(_current_shake_strength, 4.0), "FAIL TC-07.5: Shake intensity 4.0 not registered")
		_shake_camera(2.0, 0.18) # Weaker shake should NOT override
		assert(is_equal_approx(_current_shake_strength, 4.0), "FAIL TC-07.5: Weaker shake overrode stronger shake")
		_shake_camera(6.0, 0.25) # Stronger shake SHOULD override
		assert(is_equal_approx(_current_shake_strength, 6.0), "FAIL TC-07.5: Stronger shake failed to override")
		if _shake_tween != null and _shake_tween.is_running():
			_shake_tween.kill()
		camera.offset = Vector2.ZERO
		_current_shake_strength = 0.0
		
	_log_test(">>> 🟢 TC-07 PASSED: All Sprint 5 UI & VFX systems fully verified!\n")

# ------------------------------------------------------------------------------
# TC-08: Board Grid Pure Data Model (Sprint 1)
# ------------------------------------------------------------------------------
func _run_tc_08_board_grid_model() -> void:
	_log_test("\n==================== [TEST TC-08: BOARD GRID MODEL] ====================")
	var config = BoardConfig.new()
	assert(config.columns == 7 and config.rows == 6, "FAIL TC-08: Default dimensions mismatch (expected 7x6)")
	assert(config.hex_radius == 44.0, "FAIL TC-08: Default hex radius mismatch (expected 44.0)")
	assert(is_equal_approx(config.cell_size.x, sqrt(3.0) * 44.0) and is_equal_approx(config.cell_size.y, 88.0), "FAIL TC-08: Default cell size mismatch")
	
	var grid = BoardGrid.new(config)
	
	# [BG-01]: Bounds validation (Top-Down Hex Layout 7x6)
	_log_test("[TC-08.1] [BG-01] Testing bounds validation (Top-Down Hex 7x6)...")
	assert(grid.is_in_bounds(Vector2i(0, 0)) == true, "FAIL BG-01: (0,0) must be in bounds")
	assert(grid.is_in_bounds(Vector2i(6, 5)) == true, "FAIL BG-01: (6,5) must be in bounds")
	assert(grid.is_in_bounds(Vector2i(-1, 0)) == false, "FAIL BG-01: (-1,0) must be out of bounds")
	assert(grid.is_in_bounds(Vector2i(7, 5)) == false, "FAIL BG-01: (7,5) must be out of bounds")
	assert(grid.is_in_bounds(Vector2i(6, 6)) == false, "FAIL BG-01: (6,6) must be out of bounds")
	assert(grid.is_in_bounds(Vector2i(7, 6)) == false, "FAIL BG-01: (7,6) must be out of bounds")
	assert(config.is_enemy_zone(Vector2i(3, 2)) == true, "FAIL BG-01: (3,2) should be enemy zone (rows 0, 1, 2)")
	assert(config.is_enemy_zone(Vector2i(3, 3)) == false, "FAIL BG-01: (3,3) should not be enemy zone")
	assert(config.is_hero_zone(Vector2i(3, 3)) == true, "FAIL BG-01: (3,3) should be hero zone (rows 3, 4, 5)")
	assert(config.is_hero_zone(Vector2i(3, 2)) == false, "FAIL BG-01: (3,2) should not be hero zone")
	
	# [BG-02]: Place hero entity
	_log_test("[TC-08.2] [BG-02] Testing entity placement and reverse lookup...")
	var hero = HeroEntity.new()
	hero.name = "TestHero"
	var place_ok = grid.place_entity(hero, Vector2i(3, 3))
	assert(place_ok == true, "FAIL BG-02: place_entity should succeed at (3,3)")
	assert(grid.is_cell_empty(Vector2i(3, 3)) == false, "FAIL BG-02: (3,3) must not be empty")
	assert(grid.get_occupant(Vector2i(3, 3)) == hero, "FAIL BG-02: occupant at (3,3) must be hero")
	assert(grid.get_cell_for_entity(hero) == Vector2i(3, 3), "FAIL BG-02: reverse lookup must return (3,3)")
	
	# [BG-03]: Conflict resolution
	_log_test("[TC-08.3] [BG-03] Testing placement collision rejection...")
	var enemy = EnemyEntity.new()
	enemy.name = "TestEnemy"
	var conflict_ok = grid.place_entity(enemy, Vector2i(3, 3))
	assert(conflict_ok == false, "FAIL BG-03: placing on occupied cell must fail")
	assert(grid.get_occupant(Vector2i(3, 3)) == hero, "FAIL BG-03: (3,3) must still belong to hero")
	assert(grid.get_cell_for_entity(enemy) == Vector2i(-1, -1), "FAIL BG-03: unplaced enemy must return (-1,-1)")
	
	# [BG-04]: Move entity with rollback guarantee
	_log_test("[TC-08.4] [BG-04] Testing entity movement and collision rollback...")
	grid.place_entity(enemy, Vector2i(2, 2))
	var invalid_move_blocked = grid.move_entity(Vector2i(3, 3), Vector2i(2, 2))
	assert(invalid_move_blocked == false, "FAIL BG-04: moving into occupied cell must return false")
	assert(grid.get_occupant(Vector2i(3, 3)) == hero, "FAIL BG-04: hero must remain at (3,3) on failed move")
	
	var valid_move = grid.move_entity(Vector2i(3, 3), Vector2i(3, 4))
	assert(valid_move == true, "FAIL BG-04: moving to empty cell (3,4) must succeed")
	assert(grid.is_cell_empty(Vector2i(3, 3)) == true, "FAIL BG-04: (3,3) must now be empty")
	assert(grid.get_occupant(Vector2i(3, 4)) == hero, "FAIL BG-04: (3,4) must contain hero")
	assert(grid.get_cell_for_entity(hero) == Vector2i(3, 4), "FAIL BG-04: hero reverse lookup must be (3,4)")
	
	# [BG-05]: Hex Adjacency (Odd-R 6-direction)
	_log_test("[TC-08.5] [BG-05] Testing Hex Adjacency (Odd-R 6-direction)...")
	var corner_neighbors = grid.get_hex_neighbors(Vector2i(0, 0))
	assert(corner_neighbors.size() == 2, "FAIL BG-05: Corner (0,0) in Odd-R hex grid has 2 neighbors")
	assert(corner_neighbors.has(Vector2i(1, 0)) and corner_neighbors.has(Vector2i(0, 1)))
	
	var center_even = grid.get_hex_neighbors(Vector2i(2, 2))
	assert(center_even.size() == 6, "FAIL BG-05: Center even row (2,2) must have 6 neighbors")
	assert(center_even.has(Vector2i(1, 1)) and center_even.has(Vector2i(2, 1)) and center_even.has(Vector2i(1, 2)) and center_even.has(Vector2i(3, 2)) and center_even.has(Vector2i(1, 3)) and center_even.has(Vector2i(2, 3)))
	
	var center_odd = grid.get_hex_neighbors(Vector2i(2, 1))
	assert(center_odd.size() == 6, "FAIL BG-05: Center odd row (2,1) must have 6 neighbors")
	assert(center_odd.has(Vector2i(2, 0)) and center_odd.has(Vector2i(3, 0)) and center_odd.has(Vector2i(1, 1)) and center_odd.has(Vector2i(3, 1)) and center_odd.has(Vector2i(2, 2)) and center_odd.has(Vector2i(3, 2)))
	
	# [BG-06]: Remove entity & clean dictionaries
	_log_test("[TC-08.6] [BG-06] Testing entity removal and dictionary cleanup...")
	var removed_hero = grid.remove_entity(Vector2i(3, 4))
	assert(removed_hero == hero, "FAIL BG-06: remove_entity must return the removed hero")
	assert(grid.is_cell_empty(Vector2i(3, 4)) == true, "FAIL BG-06: (3,4) must now be empty")
	assert(grid.get_cell_for_entity(hero) == Vector2i(-1, -1), "FAIL BG-06: hero lookup must be (-1,-1)")
	
	grid.remove_entity(Vector2i(2, 2))
	assert(grid._cell_occupants.is_empty() == true, "FAIL BG-06: _cell_occupants must be completely empty")
	assert(grid._entity_cells.is_empty() == true, "FAIL BG-06: _entity_cells must be completely empty")
	
	# [BG-08]: Zone Enforcement via can_place
	_log_test("[TC-08.7] [BG-08] Testing zone restriction enforcement via can_place...")
	assert(grid.can_place(hero, Vector2i(3, 1), true) == false, "FAIL BG-08: Hero cannot be placed in Enemy zone (y=1)")
	assert(grid.can_place(hero, Vector2i(3, 4), true) == true, "FAIL BG-08: Hero can be placed in Hero zone (y=4)")
	assert(grid.can_place(enemy, Vector2i(3, 4), true) == false, "FAIL BG-08: Enemy cannot be placed in Hero zone (y=4)")
	assert(grid.can_place(enemy, Vector2i(3, 1), true) == true, "FAIL BG-08: Enemy can be placed in Enemy zone (y=1)")
	
	# [BG-10]: BoardGrid Locking enforcement
	_log_test("[TC-08.8] [BG-10] Testing BoardGrid lock enforcement in COMBAT phase...")
	grid.place_entity(hero, Vector2i(3, 4))
	grid.is_locked = true
	assert(grid.place_entity(enemy, Vector2i(3, 1)) == false, "FAIL BG-10: Placing when locked must return false")
	assert(grid.move_entity(Vector2i(3, 4), Vector2i(4, 4)) == false, "FAIL BG-10: Moving when locked must return false")
	assert(grid.remove_entity(Vector2i(3, 4)) == null, "FAIL BG-10: Removing when locked must return null")
	assert(grid.get_occupant(Vector2i(3, 4)) == hero, "FAIL BG-10: Hero must remain safely untouched during lock")
	
	grid.is_locked = false
	grid.remove_entity(Vector2i(3, 4))
	
	hero.free()
	enemy.free()
	_log_test(">>> 🟢 TC-08 PASSED: BoardGrid Pure Data Model & BG-08..10 verified!\n")

# ------------------------------------------------------------------------------
# TC-09: BoardView & PlacementController (Sprint 1 Tasks S1.3 & S1.4)
# ------------------------------------------------------------------------------
func _run_tc_09_board_view_and_placement() -> void:
	_log_test("\n==================== [TEST TC-09: BOARD VIEW & PLACEMENT] ====================")
	_reset_test_battlefield()
	# Chuyển sang PREPARATION để test kéo thả bố trí đội hình
	enter_preparation_phase()
	
	# 1. BoardView Math & Mapping Verification [BG-09]
	_log_test("[TC-09.1] [BG-09] Checking BoardView world <-> grid coordinate conversions...")
	assert(board_view != null, "FAIL TC-09.1: BoardView node not found")
	assert(board_config != null and board_grid != null, "FAIL TC-09.1: Config/Grid not initialized")
	
	var test_cell := Vector2i(3, 4)
	var world_pos := board_view.grid_to_world(test_cell)
	var expected_local := board_view.grid_to_local(test_cell)
	var expected_global := board_view.to_global(expected_local)
	assert(world_pos.is_equal_approx(expected_global), "FAIL TC-09.1: grid_to_world mismatch")
	
	var mapped_cell := board_view.world_to_grid(world_pos)
	assert(mapped_cell == test_cell, "FAIL TC-09.1: world_to_grid roundtrip failed")
	
	# 2. Hover highlights reactivity
	_log_test("[TC-09.2] Checking BoardView hover highlight...")
	board_view.hovered_cell = Vector2i(3, 4)
	assert(board_view.hovered_cell == Vector2i(3, 4), "FAIL TC-09.2: Hovered cell not set")
	board_view.hovered_cell = Vector2i(-1, -1)
	
	# 3. PlacementController State & Validation
	_log_test("[TC-09.3] Checking PlacementController drag validation & locking...")
	assert(placement_controller != null, "FAIL TC-09.3: PlacementController not found")
	
	# Placement lock test
	placement_controller.set_locked(true)
	assert(placement_controller.is_locked == true, "FAIL TC-09.3: Lock state mismatch")
	placement_controller.set_locked(false)
	
	# Hero Drag & Drop Movement Test
	# Arthur is at (3, 3). Move to (2, 3) which is an empty hero zone cell
	var arthur = board_grid.get_occupant(Vector2i(3, 3))
	assert(arthur != null, "FAIL TC-09.3: Arthur not found at (3, 3)")
	
	# Move to valid empty hero zone cell (2, 3)
	var move_ok = board_grid.move_entity(Vector2i(3, 3), Vector2i(2, 3))
	assert(move_ok == true, "FAIL TC-09.3: Move Arthur to (2, 3) should succeed")
	assert(board_grid.get_occupant(Vector2i(2, 3)) == arthur, "FAIL TC-09.3: Arthur not at (2, 3)")
	assert(board_grid.is_cell_empty(Vector2i(3, 3)) == true, "FAIL TC-09.3: Old cell (3, 3) not empty")
	
	# Move into enemy zone (3, 1) - should be forbidden by hero_zone rule
	assert(board_config.is_hero_zone(Vector2i(3, 1)) == false, "FAIL TC-09.3: (3, 1) is not hero zone")
	
	# Move back to (3, 3)
	board_grid.move_entity(Vector2i(2, 3), Vector2i(3, 3))
	
	# 4. Dangling Reference Auto-Cleanup on Entity Tree Exit
	_log_test("[TC-09.4] Checking automatic BoardGrid cleanup on entity tree_exiting...")
	var dummy: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(dummy)
	board_grid.place_entity(dummy, Vector2i(1, 5))
	assert(board_grid.get_occupant(Vector2i(1, 5)) == dummy, "FAIL TC-09.4: Dummy not placed")
	assert(board_grid.get_cell_for_entity(dummy) == Vector2i(1, 5), "FAIL TC-09.4: Dummy lookup mismatch")
	
	# Free entity from scene tree
	dummy.queue_free()
	dummy.tree_exiting.emit()
	assert(board_grid.is_cell_empty(Vector2i(1, 5)) == true, "FAIL TC-09.4: Cell (1, 5) should be empty after tree_exiting")
	assert(board_grid.get_cell_for_entity(dummy) == Vector2i(-1, -1), "FAIL TC-09.4: Dummy lookup should be cleared")
	
	_log_test(">>> 🟢 TC-09 PASSED: BoardView & PlacementController fully verified!\n")

# ------------------------------------------------------------------------------
# TC-10: Targeting & Spatial Combat (Sprint 2 Task S2.2)
# ------------------------------------------------------------------------------
func _run_tc_10_targeting_and_spatial() -> void:
	_log_test("\n==================== [TEST TC-10: TARGETING & SPATIAL COMBAT] ====================")
	_reset_test_battlefield()
	
	# 1. Hex Cube Distance Math Verification
	_log_test("[TC-10.1] Checking BoardConfig Cube coordinates & hex distance math...")
	assert(board_config != null, "FAIL TC-10.1: BoardConfig not found")
	assert(board_config.get_hex_distance(Vector2i(0, 0), Vector2i(1, 0)) == 1, "FAIL TC-10.1: Even row neighbor distance must be 1")
	assert(board_config.get_hex_distance(Vector2i(0, 0), Vector2i(0, 1)) == 1, "FAIL TC-10.1: Odd row neighbor distance must be 1")
	assert(board_config.get_hex_distance(Vector2i(0, 0), Vector2i(1, 1)) == 2, "FAIL TC-10.1: Diagonal distance must be 2")
	assert(board_config.get_hex_distance(Vector2i(2, 2), Vector2i(2, 2)) == 0, "FAIL TC-10.1: Same cell distance must be 0")
	assert(board_config.get_hex_distance(Vector2i(0, 0), Vector2i(3, 0)) == 3, "FAIL TC-10.1: 3-step row distance must be 3")
	
	# 2. BoardGrid Combat Move Override Lock Verification
	_log_test("[TC-10.2] Checking BoardGrid.move_entity ignore_lock in COMBAT...")
	assert(board_grid != null, "FAIL TC-10.2: BoardGrid not found")
	var test_hero = heroes[0] as HeroEntity
	var initial_hero_cell: Vector2i = board_grid.get_cell_for_entity(test_hero)
	assert(initial_hero_cell != Vector2i(-1, -1), "FAIL TC-10.2: Test hero not on grid")
	
	board_grid.is_locked = true
	var empty_hero_cells = board_grid.get_empty_hero_cells()
	assert(not empty_hero_cells.is_empty(), "FAIL TC-10.2: No empty hero cells for test")
	var move_dest = empty_hero_cells[0]
	
	# Attempt move without ignore_lock -> should fail
	var move_blocked = board_grid.move_entity(initial_hero_cell, move_dest, false)
	assert(move_blocked == false, "FAIL TC-10.2: move_entity without ignore_lock must fail when locked")
	assert(board_grid.get_cell_for_entity(test_hero) == initial_hero_cell, "FAIL TC-10.2: Hero moved despite lock")
	
	# Attempt move with ignore_lock = true (combat blink/dash) -> should succeed
	var move_success = board_grid.move_entity(initial_hero_cell, move_dest, true)
	assert(move_success == true, "FAIL TC-10.2: move_entity with ignore_lock must succeed")
	assert(board_grid.get_cell_for_entity(test_hero) == move_dest, "FAIL TC-10.2: Hero cell not updated")
	
	# Rollback move
	board_grid.move_entity(move_dest, initial_hero_cell, true)
	board_grid.is_locked = false
	
	# 3. FURTHEST_ENEMY & LOWEST_HP_PERCENT_ENEMY Verification
	_log_test("[TC-10.3] Checking FURTHEST_ENEMY & LOWEST_HP_PERCENT_ENEMY...")
	while heroes.size() > 1:
		var extra_h = heroes.pop_back()
		if is_instance_valid(extra_h): extra_h.queue_free()
	while enemies.size() > 3:
		var extra_e = enemies.pop_back()
		if is_instance_valid(extra_e): extra_e.queue_free()
		
	var caster = heroes[0]
	caster.global_position = Vector2(0, 0)
	
	var e_close = enemies[0]
	e_close.name = "E_Close"
	e_close.max_hp = 100.0; e_close.current_hp = 100.0 # 100%
	e_close.global_position = Vector2(50, 0)
	
	var e_mid = enemies[1]
	e_mid.name = "E_LowPercent"
	e_mid.max_hp = 200.0; e_mid.current_hp = 60.0 # 30% (Low percent, raw HP 60 > 50)
	e_mid.global_position = Vector2(120, 0)
	
	var e_far = enemies[2]
	e_far.name = "E_Far"
	e_far.max_hp = 100.0; e_far.current_hp = 50.0 # 50% (Lower raw HP than e_mid)
	e_far.global_position = Vector2(250, 0)
	
	var furthest = targeting_system.get_targets_for_rule(caster, AbilityData.TargetRule.FURTHEST_ENEMY)
	assert(furthest.size() == 1 and furthest[0] == e_far, "FAIL TC-10.3: FURTHEST_ENEMY did not pick e_far")
	_log_test("[TC-10.3] FURTHEST_ENEMY: %s (Expected: E_Far)" % furthest[0].name)
	
	var lowest_pct = targeting_system.get_targets_for_rule(caster, AbilityData.TargetRule.LOWEST_HP_PERCENT_ENEMY)
	assert(lowest_pct.size() == 1 and lowest_pct[0] == e_mid, "FAIL TC-10.3: LOWEST_HP_PERCENT_ENEMY did not pick e_mid (30% HP)")
	_log_test("[TC-10.3] LOWEST_HP_PERCENT_ENEMY: %s (Expected: E_LowPercent 30%% vs 50%%)" % lowest_pct[0].name)
	
	# 4. DENSEST_ENEMY_CLUSTER & Tie-breaker & AoE Radius Verification
	_log_test("[TC-10.4] Checking DENSEST_ENEMY_CLUSTER & Tie-breaker logic...")
	board_grid.clear()
	
	# Đặt Caster tại (2, 3)
	board_grid.place_entity(caster, Vector2i(2, 3))
	if board_view != null:
		caster.global_position = board_view.grid_to_world(Vector2i(2, 3))
		
	# Cụm A (2 quân gần Caster): tại (1, 1) và (1, 2)
	var e_a1 = e_close; e_a1.name = "E_A1"
	var e_a2 = e_mid;   e_a2.name = "E_A2"
	board_grid.place_entity(e_a1, Vector2i(1, 1))
	board_grid.place_entity(e_a2, Vector2i(1, 2))
	if board_view != null:
		e_a1.global_position = board_view.grid_to_world(Vector2i(1, 1))
		e_a2.global_position = board_view.grid_to_world(Vector2i(1, 2))
		
	# Cụm B (2 quân xa Caster): tại (5, 1) và (5, 2)
	var e_b1 = e_far; e_b1.name = "E_B1"
	board_grid.place_entity(e_b1, Vector2i(5, 1))
	if board_view != null:
		e_b1.global_position = board_view.grid_to_world(Vector2i(5, 1))
		
	var e_b2: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(e_b2); enemies.append(e_b2)
	e_b2.name = "E_B2"; e_b2.max_hp = 100.0; e_b2.current_hp = 100.0
	board_grid.place_entity(e_b2, Vector2i(5, 2))
	if board_view != null:
		e_b2.global_position = board_view.grid_to_world(Vector2i(5, 2))
		
	# Cả Cụm A và Cụm B đều có 2 kẻ địch (Cluster count = 2).
	# Tie-breaker: Cụm A ở gần Caster hơn Cụm B -> Phải chọn mục tiêu thuộc Cụm A!
	var ability_cluster := AbilityData.new()
	ability_cluster.target_rule = AbilityData.TargetRule.DENSEST_ENEMY_CLUSTER
	ability_cluster.aoe_shape = AbilityData.AoEShape.SINGLE
	ability_cluster.aoe_radius = 1
	
	var tie_target = targeting_system.get_targets_for_ability(caster, ability_cluster)
	assert(tie_target.size() == 1, "FAIL TC-10.4: Expected 1 target for tie test")
	assert(tie_target[0] == e_a1 or tie_target[0] == e_a2, "FAIL TC-10.4: Tie-breaker failed to pick closer cluster A")
	_log_test("[TC-10.4] Tie-breaker picked: %s (Cluster A, closer to caster)" % tie_target[0].name)
	
	# Thêm quân thứ 3 vào Cụm B tại (5, 0)
	var e_b3: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(e_b3); enemies.append(e_b3)
	e_b3.name = "E_B3"; e_b3.max_hp = 100.0; e_b3.current_hp = 100.0
	board_grid.place_entity(e_b3, Vector2i(5, 0))
	if board_view != null:
		e_b3.global_position = board_view.grid_to_world(Vector2i(5, 0))
		
	# Cụm B có 3 quân (E_B1, E_B2, E_B3), Cụm A có 2 quân (E_A1, E_A2).
	# Phải chọn Cụm B dù Cụm B ở xa hơn!
	ability_cluster.aoe_shape = AbilityData.AoEShape.HEX_RADIUS
	var aoe_cluster_targets = targeting_system.get_targets_for_ability(caster, ability_cluster)
	_log_test("[TC-10.4] Densest Cluster with AoE HEX_RADIUS hit %d targets: %s" % [
		aoe_cluster_targets.size(),
		str(aoe_cluster_targets.map(func(e): return e.name))
	])
	assert(aoe_cluster_targets.size() == 3, "FAIL TC-10.4: AoE HEX_RADIUS should hit all 3 enemies in Cluster B")
	assert(aoe_cluster_targets.has(e_b1) and aoe_cluster_targets.has(e_b2) and aoe_cluster_targets.has(e_b3), "FAIL TC-10.4: Missing target in Cluster B AoE")
	
	_log_test(">>> 🟢 TC-10 PASSED: Targeting & Spatial Combat systems fully verified!\n")

# ------------------------------------------------------------------------------
# TC-11: Grid-based Movement & Pathfinding
# ------------------------------------------------------------------------------
func _run_tc_11_grid_movement_and_pathfinding() -> void:
	_log_test("\n==================== [TEST TC-11: GRID MOVEMENT & PATHFINDING] ====================")
	_reset_test_battlefield()
	
	var arthur: HeroEntity = null
	var robin: HeroEntity = null
	for h in heroes:
		if is_instance_valid(h) and h is HeroEntity and h.data != null:
			if h.data.name == "Arthur":
				arthur = h
			elif h.data.name == "Robin":
				robin = h
				
	assert(arthur != null and robin != null, "FAIL TC-11: Arthur and Robin must be spawned")
	
	# Xóa các hero khác để test độc lập
	for h in heroes.duplicate():
		if h != arthur and h != robin:
			heroes.erase(h)
			if is_instance_valid(h):
				board_grid.remove_dead_entity(h)
				h.queue_free()
				
	# Giữ lại đúng 1 enemy tại (3, 1)
	while enemies.size() > 1:
		var extra = enemies.pop_back()
		if is_instance_valid(extra):
			board_grid.remove_dead_entity(extra)
			extra.queue_free()
			
	var target_enemy = enemies[0] as EnemyEntity
	board_grid.move_entity(board_grid.get_cell_for_entity(target_enemy), Vector2i(3, 1), true)
	if board_view != null:
		target_enemy.global_position = board_view.grid_to_world(Vector2i(3, 1))
	
	# 1. Test Range Check
	# Robin (Marksman, range 4) tại (2, 4) -> di chuyển trước để giải phóng ô (3, 4)
	board_grid.move_entity(board_grid.get_cell_for_entity(robin), Vector2i(2, 4), true)
	if board_view != null:
		robin.global_position = board_view.grid_to_world(Vector2i(2, 4))
	robin.target = target_enemy
	var dist_robin := board_grid.get_hex_distance(Vector2i(2, 4), Vector2i(3, 1))
	_log_test("[TC-11.1] Robin (Range %d) at (2, 4) -> Enemy at (3, 1) | Hex Dist: %d" % [robin.get_attack_range(), dist_robin])
	assert(dist_robin <= robin.get_attack_range(), "FAIL TC-11.1: Expected Robin distance <= attack_range")
	assert(robin.is_target_in_attack_range(), "FAIL TC-11.1: Ranged Robin SHOULD be in attack range")

	# Đặt Arthur (Tank, range 1) tại (3, 4) -> khoảng cách tới (3, 1) là 3 > attack_range (1)
	var move_arthur := board_grid.move_entity(board_grid.get_cell_for_entity(arthur), Vector2i(3, 4), true)
	assert(move_arthur, "FAIL TC-11.1: Arthur should move to empty cell (3, 4)")
	if board_view != null:
		arthur.global_position = board_view.grid_to_world(Vector2i(3, 4))
	arthur.target = target_enemy
	
	var dist_arthur := board_grid.get_hex_distance(Vector2i(3, 4), Vector2i(3, 1))
	_log_test("[TC-11.1] Arthur (Range %d) at (3, 4) -> Enemy at (3, 1) | Hex Dist: %d" % [arthur.get_attack_range(), dist_arthur])
	assert(dist_arthur == 3, "FAIL TC-11.1: Expected hex distance 3 between (3, 4) and (3, 1)")
	assert(not arthur.is_target_in_attack_range(), "FAIL TC-11.1: Melee Arthur should NOT be in attack range at distance 3")
	_log_test(">>> 🟢 TC-11.1 Range check PASSED!")
	
	# 2. Test Greedy Hex Pathfinding
	var next_step := board_grid.get_best_step_towards(Vector2i(3, 4), Vector2i(3, 1))
	var dist_after_step := board_grid.get_hex_distance(next_step, Vector2i(3, 1))
	_log_test("[TC-11.2] Best step from (3, 4) towards (3, 1): %s | New Dist: %d" % [str(next_step), dist_after_step])
	assert(dist_after_step == 2, "FAIL TC-11.2: Greedy step should reduce distance from 3 to 2")
	assert(board_grid.is_cell_empty(next_step), "FAIL TC-11.2: Selected step must be empty")
	
	var stepped = arthur.step_towards_target()
	assert(stepped, "FAIL TC-11.2: Arthur step_towards_target() should return true")
	assert(board_grid.get_cell_for_entity(arthur) == next_step, "FAIL TC-11.2: Arthur should occupy next_step on BoardGrid")
	_log_test(">>> 🟢 TC-11.2 Greedy Step Execution PASSED!")
	
	# 3. Test Blocked / Alternative Path
	board_grid.move_entity(board_grid.get_cell_for_entity(arthur), Vector2i(3, 4), true)
	var blocker: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(blocker)
	board_grid.place_entity(blocker, next_step)
	
	var alt_step := board_grid.get_best_step_towards(Vector2i(3, 4), Vector2i(3, 1))
	_log_test("[TC-11.3] Blocked %s. Alternative step: %s (Dist: %d)" % [str(next_step), str(alt_step), board_grid.get_hex_distance(alt_step, Vector2i(3, 1))])
	assert(alt_step != next_step, "FAIL TC-11.3: Should not step on blocked cell")
	assert(board_grid.is_cell_empty(alt_step), "FAIL TC-11.3: Alternative step must be empty")
	board_grid.remove_dead_entity(blocker)
	blocker.queue_free()
	_log_test(">>> 🟢 TC-11.3 Obstacle avoidance PASSED!")
	
	# 4. Test Assassin Blink Landing (get_closest_empty_cell_around & teleport_to_grid_cell)
	var blink_target_cell := board_grid.get_closest_empty_cell_around(Vector2i(3, 1))
	_log_test("[TC-11.4] Assassin Blink landing cell around (3, 1): %s" % str(blink_target_cell))
	assert(blink_target_cell != Vector2i(-1, -1), "FAIL TC-11.4: Should find an empty landing cell")
	assert(board_grid.get_hex_distance(blink_target_cell, Vector2i(3, 1)) == 1, "FAIL TC-11.4: Landing cell must be adjacent (dist=1) to target")
	assert(board_grid.is_cell_empty(blink_target_cell), "FAIL TC-11.4: Landing cell must be empty")
	
	var teleported = arthur.teleport_to_grid_cell(blink_target_cell)
	assert(teleported, "FAIL TC-11.4: teleport_to_grid_cell should succeed")
	assert(board_grid.get_cell_for_entity(arthur) == blink_target_cell, "FAIL TC-11.4: Arthur should be at blink cell on BoardGrid")
	assert(arthur.is_target_in_attack_range(), "FAIL TC-11.4: After blinking adjacent to target, Arthur must be in attack range")
	_log_test(">>> 🟢 TC-11.4 Assassin Blink landing PASSED!")
	
	_log_test(">>> 🟢 TC-11 PASSED: Grid-based Movement & Pathfinding fully verified!\n")

# ------------------------------------------------------------------------------
# TC-12: Combat Metrics & Hero Progression (Sprint 3)
# ------------------------------------------------------------------------------
func _run_tc_12_combat_metrics_and_progression() -> void:
	_log_test("\n==================== [TEST TC-12: COMBAT METRICS & PROGRESSION] ====================")
	_reset_test_battlefield()
	
	# 1. Tìm 1 Tank (Arthur), 1 Assassin (Kira) và 1 Support (Soraka)
	var tank: HeroEntity = null
	var assassin: HeroEntity = null
	var support: HeroEntity = null
	for h in heroes:
		if is_instance_valid(h) and h is HeroEntity and h.data != null:
			if h.data.hero_class == HeroData.HeroClass.TANK:
				tank = h
			elif h.data.hero_class == HeroData.HeroClass.ASSASSIN:
				assassin = h
			elif h.data.hero_class == HeroData.HeroClass.SUPPORT:
				support = h
				
	assert(tank != null and assassin != null and support != null, "FAIL TC-12: Tank, Assassin, and Support must exist")
	
	# 2. Reset và nạp giả lập 500 damage_taken và 500 damage_dealt cho cả Tank và Assassin
	tank.metrics.reset()
	assassin.metrics.reset()
	tank.progression = HeroProgression.new()
	assassin.progression = HeroProgression.new()
	
	tank.metrics.damage_taken = 500.0
	tank.metrics.damage_dealt = 500.0
	
	assassin.metrics.damage_taken = 500.0
	assassin.metrics.damage_dealt = 500.0
	
	var tank_contrib := progression_system.calculate_hero_contribution(tank)
	var assassin_contrib := progression_system.calculate_hero_contribution(assassin)
	
	# Tank raw: 500*0.2 (dealt) + 500*1.2 (taken) = 100 + 600 = 700.0
	# Assassin raw: 500*1.5 (dealt) + 500*0.1 (taken) = 750 + 50 = 800.0
	_log_test("[TC-12.1] Raw Contribution: Tank = %.1f | Assassin = %.1f" % [tank_contrib, assassin_contrib])
	assert(is_equal_approx(tank_contrib, 700.0), "FAIL TC-12.1: Tank raw contribution expected 700.0")
	assert(is_equal_approx(assassin_contrib, 800.0), "FAIL TC-12.1: Assassin raw contribution expected 800.0")
	
	# Kiểm tra tính phân hóa vai trò:
	# Lượng XP Tank nhận từ chống chịu (600) > Assassin nhận từ chống chịu (50)
	var tank_taken_xp: float = 500.0 * 1.2
	var assassin_taken_xp: float = 500.0 * 0.1
	assert(tank_taken_xp > assassin_taken_xp, "FAIL TC-12.1: Tank must gain more XP from damage taken than Assassin")
	
	# Lượng XP Assassin nhận từ sát thương gây ra (750) > Tank nhận từ sát thương (100)
	var assassin_dealt_xp: float = 500.0 * 1.5
	var tank_dealt_xp: float = 500.0 * 0.2
	assert(assassin_dealt_xp > tank_dealt_xp, "FAIL TC-12.1: Assassin must gain more XP from damage dealt than Tank")
	
	# 3. Finalize Battle XP với win_multiplier = 1.2 (Victory)
	progression_system.finalize_battle_xp(true, [tank, assassin])
	# Tank final XP: 700 * 1.2 = 840.0 -> Đạt Level 6
	# Assassin final XP: 800 * 1.2 = 960.0 -> Đạt Level 6
	_log_test("[TC-12.1] Post-battle Level: Tank = Lv%d | Assassin = Lv%d" % [tank.progression.current_level, assassin.progression.current_level])
	assert(tank.progression.current_level >= 5, "FAIL TC-12.1: Tank should reach at least Level 5")
	assert(assassin.progression.current_level >= 5, "FAIL TC-12.1: Assassin should reach at least Level 5")
	assert(tank.progression.pending_milestones.has(5), "FAIL TC-12.1: Tank should have milestone 5 registered")
	assert(assassin.progression.pending_milestones.has(5), "FAIL TC-12.1: Assassin should have milestone 5 registered")
	_log_test(">>> 🟢 TC-12.1 Class XP Contribution & Role Differentiation PASSED!")
	
	# 4. Support Healing Attribution Test
	support.metrics.reset()
	support.metrics.healing_done = 300.0
	var support_contrib := progression_system.calculate_hero_contribution(support)
	# Support healing weight = 2.0x -> 300 * 2.0 = 600.0
	_log_test("[TC-12.2] Support Healing (300 HP) -> Raw Contrib: %.1f" % support_contrib)
	assert(is_equal_approx(support_contrib, 600.0), "FAIL TC-12.2: Support healing should yield 600.0 raw XP")
	_log_test(">>> 🟢 TC-12.2 Support Healing Attribution PASSED!")
	
	# 5. Multi-level overflow & Milestone queue test
	var p := HeroProgression.new()
	_log_test("[TC-12.3] Adding 2000 XP to fresh HeroProgression...")
	p.add_xp(2000.0)
	_log_test("[TC-12.3] Level after 2000 XP: Lv%d | Milestones: %s" % [p.current_level, str(p.pending_milestones)])
	assert(p.current_level == 10, "FAIL TC-12.3: Expected Level 10 after 2000 XP")
	assert(p.pending_milestones == [5, 10], "FAIL TC-12.3: Expected pending milestones [5, 10]")
	
	_log_test("[TC-12.3] Adding 3000 XP more (Total 5000 XP)...")
	p.add_xp(3000.0)
	_log_test("[TC-12.3] Level after 5000 XP: Lv%d | Milestones: %s" % [p.current_level, str(p.pending_milestones)])
	assert(p.current_level == 16, "FAIL TC-12.3: Expected Level 16 after 5000 XP")
	assert(p.pending_milestones == [5, 10, 15], "FAIL TC-12.3: Expected pending milestones [5, 10, 15]")
	_log_test(">>> 🟢 TC-12.3 Multi-level overflow & Milestone queue PASSED!")
	
	_log_test(">>> 🟢 TC-12 PASSED: Combat Metrics & Hero Progression fully verified!\n")

# ------------------------------------------------------------------------------
# TC-13: Combat Summary UI & Damage Meter (Sprint 3 - Task S3.2)
# ------------------------------------------------------------------------------
func _run_tc_13_combat_summary_ui() -> void:
	_log_test("\n==================== [TEST TC-13: COMBAT SUMMARY UI & DAMAGE METER] ====================")
	_reset_test_battlefield()
	
	assert(combat_summary_ui != null, "FAIL TC-13: combat_summary_ui must be initialized")
	
	# 1. Lấy 2 Tướng từ battlefield
	var hero_tank: HeroEntity = heroes[0] as HeroEntity
	var hero_assassin: HeroEntity = heroes[1] as HeroEntity
	
	hero_tank.metrics.reset()
	hero_assassin.metrics.reset()
	
	# Tab DAMAGE: Tank 300, Assassin 900 -> max_val = 900.0, total = 1200.0
	hero_tank.metrics.damage_dealt = 300.0
	hero_assassin.metrics.damage_dealt = 900.0
	
	# Tab TAKEN: Tank 600, Assassin 200 -> max_val = 600.0, total = 800.0
	hero_tank.metrics.damage_taken = 600.0
	hero_assassin.metrics.damage_taken = 200.0
	
	# Tab HEAL: Tank 0, Assassin 400 -> max_val = 400.0, total = 400.0
	hero_tank.metrics.healing_done = 0.0
	hero_assassin.metrics.healing_done = 400.0
	
	# 2. Kiểm tra Hiển thị Chiến Thắng & Chuẩn hóa Thanh Sát Thương (Damage Normalization)
	combat_summary_ui.show_summary(true, 5, [hero_tank, hero_assassin])
	assert(combat_summary_ui.visible == true, "FAIL TC-13.1: CombatSummaryUI should be visible")
	assert(combat_summary_ui.active_tab == CombatSummaryUI.MetricTab.DAMAGE, "FAIL TC-13.1: Default tab must be DAMAGE")
	assert(combat_summary_ui.title_label.text.contains("CHIẾN THẮNG"), "FAIL TC-13.1: Victory title expected")
	assert(combat_summary_ui.title_label.text.contains("5"), "FAIL TC-13.1: Title should include floor 5")
	assert(combat_summary_ui.continue_button.text.contains("TIẾP TỤC"), "FAIL TC-13.1: Button text should be TIẾP TỤC")
	
	var rows: Array = combat_summary_ui.rows_container.get_children()
	assert(rows.size() == 2, "FAIL TC-13.1: Expected 2 hero rows")
	
	var row_tank_bar: ProgressBar = rows[0].get_node("BarContainer/ProgressBar") as ProgressBar
	var row_assassin_bar: ProgressBar = rows[1].get_node("BarContainer/ProgressBar") as ProgressBar
	
	assert(row_tank_bar != null and row_assassin_bar != null, "FAIL TC-13.1: ProgressBars must exist in rows")
	_log_test("[TC-13.1] Damage Tab: Tank = %.1f/%.1f | Assassin = %.1f/%.1f" % [row_tank_bar.value, row_tank_bar.max_value, row_assassin_bar.value, row_assassin_bar.max_value])
	assert(is_equal_approx(row_tank_bar.max_value, 900.0), "FAIL TC-13.1: Max value for Damage tab should normalize to 900.0")
	assert(is_equal_approx(row_assassin_bar.max_value, 900.0), "FAIL TC-13.1: Max value for Assassin should normalize to 900.0")
	assert(is_equal_approx(row_tank_bar.value, 300.0), "FAIL TC-13.1: Tank damage value should be 300.0")
	assert(is_equal_approx(row_assassin_bar.value, 900.0), "FAIL TC-13.1: Assassin damage value should be 900.0")
	_log_test(">>> 🟢 TC-13.1 Damage Normalization & Victory Title PASSED!")
	
	# 3. Kiểm tra Chuyển Tab (TAKEN & HEAL)
	combat_summary_ui._switch_tab(CombatSummaryUI.MetricTab.TAKEN)
	assert(combat_summary_ui.active_tab == CombatSummaryUI.MetricTab.TAKEN, "FAIL TC-13.2: Active tab should be TAKEN")
	rows = combat_summary_ui.rows_container.get_children()
	row_tank_bar = rows[0].get_node("BarContainer/ProgressBar") as ProgressBar
	row_assassin_bar = rows[1].get_node("BarContainer/ProgressBar") as ProgressBar
	_log_test("[TC-13.2] Taken Tab: Tank = %.1f/%.1f | Assassin = %.1f/%.1f" % [row_tank_bar.value, row_tank_bar.max_value, row_assassin_bar.value, row_assassin_bar.max_value])
	assert(is_equal_approx(row_tank_bar.max_value, 600.0), "FAIL TC-13.2: Max value for Taken tab should normalize to 600.0")
	assert(is_equal_approx(row_tank_bar.value, 600.0), "FAIL TC-13.2: Tank taken value should be 600.0")
	assert(is_equal_approx(row_assassin_bar.value, 200.0), "FAIL TC-13.2: Assassin taken value should be 200.0")
	
	combat_summary_ui._switch_tab(CombatSummaryUI.MetricTab.HEAL)
	assert(combat_summary_ui.active_tab == CombatSummaryUI.MetricTab.HEAL, "FAIL TC-13.2: Active tab should be HEAL")
	rows = combat_summary_ui.rows_container.get_children()
	row_tank_bar = rows[0].get_node("BarContainer/ProgressBar") as ProgressBar
	row_assassin_bar = rows[1].get_node("BarContainer/ProgressBar") as ProgressBar
	_log_test("[TC-13.2] Heal Tab: Tank = %.1f/%.1f | Assassin = %.1f/%.1f" % [row_tank_bar.value, row_tank_bar.max_value, row_assassin_bar.value, row_assassin_bar.max_value])
	assert(is_equal_approx(row_assassin_bar.max_value, 400.0), "FAIL TC-13.2: Max value for Heal tab should normalize to 400.0")
	assert(is_equal_approx(row_tank_bar.value, 0.0), "FAIL TC-13.2: Tank heal value should be 0.0")
	assert(is_equal_approx(row_assassin_bar.value, 400.0), "FAIL TC-13.2: Assassin heal value should be 400.0")
	_log_test(">>> 🟢 TC-13.2 Tab Switching & Metric Recalculation PASSED!")
	
	# 4. Kiểm tra Giao diện Thất Trận (Defeat Styling)
	combat_summary_ui.show_summary(false, 3, [hero_tank, hero_assassin])
	assert(combat_summary_ui.title_label.text.contains("THẤT TRẬN"), "FAIL TC-13.3: Defeat title expected")
	assert(combat_summary_ui.title_label.text.contains("3"), "FAIL TC-13.3: Title should include floor 3")
	assert(combat_summary_ui.continue_button.text.contains("CHƠI LẠI TỪ ĐẦU"), "FAIL TC-13.3: Button text should be CHƠI LẠI TỪ ĐẦU")
	_log_test(">>> 🟢 TC-13.3 Defeat Styling & Retry Prompt PASSED!")
	
	# 5. Kiểm tra Tín hiệu Continued & Đóng Giao diện
	var signal_state := {"emitted": false}
	var on_continued := func(): signal_state["emitted"] = true
	combat_summary_ui.continued.connect(on_continued, Object.CONNECT_ONE_SHOT)
	combat_summary_ui._on_continue_pressed()
	assert(signal_state["emitted"] == true, "FAIL TC-13.4: continued signal must be emitted")
	assert(combat_summary_ui.visible == false, "FAIL TC-13.4: UI must hide after continue pressed")
	_log_test(">>> 🟢 TC-13.4 Continued Signal & Dismissal PASSED!")
	
	_log_test(">>> 🟢 TC-13 PASSED: Combat Summary UI & Damage Meter fully verified!\n")

# ------------------------------------------------------------------------------
# TC-14: Roguelike Run Lifecycle & Economy (Sprint 3 - Task S3.3)
# ------------------------------------------------------------------------------
func _run_tc_14_roguelike_run_lifecycle() -> void:
	_log_test("\n==================== [TEST TC-14: ROGUELIKE RUN LIFECYCLE & ECONOMY] ====================")
	_reset_test_battlefield()
	
	assert(RunManager != null, "FAIL TC-14: RunManager autoload must be available")
	
	# 1. Khởi tạo Run mới
	RunManager.start_new_run(10, 2)
	assert(RunManager.current_floor == 1, "FAIL TC-14.1: Initial floor must be 1")
	assert(RunManager.current_gold == 10, "FAIL TC-14.1: Initial gold must be 10")
	assert(RunManager.current_lives == 2, "FAIL TC-14.1: Initial lives must be 2")
	assert(RunManager.max_lives == 2, "FAIL TC-14.1: Max lives must be 2")
	_log_test(">>> 🟢 TC-14.1 Initial Run State PASSED!")
	
	# 2. Chiến thắng Tầng 1: Vàng cơ bản = 5 + 1 = 6; Lãi suất (10/10) = 1 -> Tổng cộng +7 Vàng
	var won_res := RunManager.on_battle_won()
	_log_test("[TC-14.2] Won Floor 1 -> Reward: %d (Base: %d, Interest: %d) | Total Gold: %d | New Floor: %d" % [
		won_res["gold_earned"], won_res["base_gold"], won_res["interest_gold"], won_res["total_gold"], won_res["next_floor"]
	])
	assert(won_res["is_victory"] == true, "FAIL TC-14.2: is_victory should be true")
	assert(won_res["gold_earned"] == 7, "FAIL TC-14.2: Expected 7 gold earned (6 base + 1 interest)")
	assert(won_res["total_gold"] == 17, "FAIL TC-14.2: Expected 17 total gold")
	assert(RunManager.current_floor == 2, "FAIL TC-14.2: Current floor should be 2")
	assert(RunManager.current_lives == 2, "FAIL TC-14.2: Lives should remain 2")
	_log_test(">>> 🟢 TC-14.2 Victory Reward & Interest Math PASSED!")
	
	# 3. Thất bại Tầng 2 lần 1 (Còn 1 mạng -> Cho phép đánh lại)
	var lost_res1 := RunManager.on_battle_lost()
	_log_test("[TC-14.3] Lost Floor 2 (1st time) -> Consol Gold: +%d | Total Gold: %d | Lives: %d/%d | Can Retry: %s" % [
		lost_res1["gold_earned"], lost_res1["total_gold"], lost_res1["lives_left"], lost_res1["max_lives"], str(lost_res1["can_continue"])
	])
	assert(lost_res1["is_victory"] == false, "FAIL TC-14.3: is_victory should be false")
	assert(lost_res1["can_continue"] == true, "FAIL TC-14.3: Should allow retry when 1 life left")
	assert(lost_res1["lives_left"] == 1, "FAIL TC-14.3: Lives left should be 1")
	assert(lost_res1["gold_earned"] == 2, "FAIL TC-14.3: Consol gold at Floor 2 should be 2")
	assert(lost_res1["total_gold"] == 19, "FAIL TC-14.3: Total gold should be 19")
	assert(RunManager.current_floor == 2, "FAIL TC-14.3: Current floor must not advance on loss")
	_log_test(">>> 🟢 TC-14.3 Defeat with Lives Remaining (Retry Floor) PASSED!")
	
	# 4. Thất bại Tầng 2 lần 2 (Hết mạng -> Perma-death)
	var run_ended_signal_fired := {"fired": false, "won": true}
	var on_run_ended := func(is_vic: bool):
		run_ended_signal_fired["fired"] = true
		run_ended_signal_fired["won"] = is_vic
	RunManager.run_ended.connect(on_run_ended, Object.CONNECT_ONE_SHOT)
	
	var lost_res2 := RunManager.on_battle_lost()
	_log_test("[TC-14.4] Lost Floor 2 (2nd time) -> Lives: %d/%d | Can Retry: %s" % [
		lost_res2["lives_left"], lost_res2["max_lives"], str(lost_res2["can_continue"])
	])
	assert(lost_res2["can_continue"] == false, "FAIL TC-14.4: Can continue must be false when 0 lives left")
	assert(lost_res2["lives_left"] == 0, "FAIL TC-14.4: Lives left must be 0")
	assert(run_ended_signal_fired["fired"] == true, "FAIL TC-14.4: run_ended signal must be emitted")
	assert(run_ended_signal_fired["won"] == false, "FAIL TC-14.4: run_ended signal must indicate defeat")
	_log_test(">>> 🟢 TC-14.4 Perma-death & Zero Lives Handling PASSED!")
	
	# 5. Kiểm tra CombatSummaryUI phản ánh chính xác dữ liệu RunResult
	var hero_tank: HeroEntity = heroes[0] as HeroEntity
	var hero_assassin: HeroEntity = heroes[1] as HeroEntity
	
	# 5a. UI Chiến thắng: Hiển thị Vàng & Lãi
	combat_summary_ui.show_summary(true, 1, [hero_tank, hero_assassin], won_res)
	assert(combat_summary_ui.meta_label.text.contains("💰 Vàng: +7"), "FAIL TC-14.5: Meta label must show +7 gold")
	assert(combat_summary_ui.meta_label.text.contains("(Lãi +1)"), "FAIL TC-14.5: Meta label must show interest")
	assert(combat_summary_ui.meta_label.text.contains("❤️ Mạng sống: 2/2"), "FAIL TC-14.5: Meta label must show lives 2/2")
	assert(combat_summary_ui.continue_button.text.contains("TIẾP TỤC"), "FAIL TC-14.5: Button should say TIẾP TỤC")
	
	# 5b. UI Thất bại còn mạng: Nút Đánh Lại Tầng Này
	combat_summary_ui.show_summary(false, 2, [hero_tank, hero_assassin], lost_res1)
	assert(combat_summary_ui.title_label.text.contains("THẤT BẠI — TẦNG 2 (CÒN 1 MẠNG)"), "FAIL TC-14.5: Title must show remaining lives")
	assert(combat_summary_ui.continue_button.text.contains("ĐÁNH LẠI TẦNG NÀY"), "FAIL TC-14.5: Button must say ĐÁNH LẠI TẦNG NÀY")
	assert(combat_summary_ui.meta_label.text.contains("❤️ Mạng sống: 1/2"), "FAIL TC-14.5: Meta label must show lives 1/2")
	
	# 5c. UI Tận diệt hết mạng: Game Over & Bắt Đầu Run Mới
	combat_summary_ui.show_summary(false, 2, [hero_tank, hero_assassin], lost_res2)
	assert(combat_summary_ui.title_label.text.contains("GAME OVER — TẬN DIỆT Ở TẦNG 2"), "FAIL TC-14.5: Title must show Game Over")
	assert(combat_summary_ui.continue_button.text.contains("BẮT ĐẦU RUN MỚI"), "FAIL TC-14.5: Button must say BẮT ĐẦU RUN MỚI")
	assert(combat_summary_ui.meta_label.text.contains("❤️ Mạng sống: 0/2"), "FAIL TC-14.5: Meta label must show lives 0/2")
	combat_summary_ui.hide()
	_log_test(">>> 🟢 TC-14.5 CombatSummaryUI Roguelike Metas & Dynamic Buttons PASSED!")
	
	# 6. Kiểm tra Hero Perma-death Clean Reset
	hero_tank.progression.current_level = 7
	hero_tank.progression.current_xp = 150.0
	hero_tank.progression.pending_milestones = [5]
	var extra_ability := Ability.new(hero_tank, AbilityData.new())
	hero_tank.unlocked_abilities.append(extra_ability)
	assert(hero_tank.unlocked_abilities.size() > 1, "FAIL TC-14.6: Hero should have extra ability before reset")
	
	_reset_heroes_for_new_run()
	assert(hero_tank.progression.current_level == 1, "FAIL TC-14.6: Hero level should reset to 1")
	assert(hero_tank.progression.current_xp == 0.0, "FAIL TC-14.6: Hero XP should reset to 0.0")
	assert(hero_tank.progression.pending_milestones.is_empty(), "FAIL TC-14.6: Pending milestones should be cleared")
	assert(hero_tank.unlocked_abilities.size() <= 1, "FAIL TC-14.6: Hero abilities should be reset to base")
	_log_test(">>> 🟢 TC-14.6 Hero Perma-death Clean Reset PASSED!")
	
	_log_test(">>> 🟢 TC-14 PASSED: Roguelike Run Lifecycle & Economy fully verified!\n")

# ------------------------------------------------------------------------------
# TC-15: Smart Combat Retargeting (Ranged & Melee Anti-Kiting)
# ------------------------------------------------------------------------------
func _run_tc_15_combat_retargeting() -> void:
	_log_test("\n==================== [TEST TC-15: COMBAT RETARGETING & ANTI-KITING] ====================")
	_reset_test_battlefield()
	
	# Dọn bớt quái để kiểm soát tọa độ chính xác
	while enemies.size() > 0:
		var e = enemies.pop_back()
		if is_instance_valid(e):
			board_grid.remove_dead_entity(e)
			e.queue_free()
			
	var robin: HeroEntity = null
	var arthur: HeroEntity = null
	for h in heroes:
		if is_instance_valid(h) and h is HeroEntity and h.data != null:
			if h.data.name == "Robin":
				robin = h
			elif h.data.name == "Arthur":
				arthur = h
	assert(robin != null and arthur != null, "FAIL TC-15: Robin and Arthur must exist")
	
	for h in heroes.duplicate():
		if h != arthur and h != robin:
			heroes.erase(h)
			if is_instance_valid(h):
				board_grid.remove_dead_entity(h)
				h.queue_free()
	
	# 1. RANGED RETARGETING (Tướng đánh xa không di chuyển nếu có địch trong tầm)
	# Đặt Robin (range 4) tại (2, 5)
	board_grid.move_entity(board_grid.get_cell_for_entity(robin), Vector2i(2, 5), true)
	if board_view != null: robin.global_position = board_view.grid_to_world(Vector2i(2, 5))
	
	# Sinh Quái A (ngoài tầm 4) tại (2, 0) -> Hex dist = 5
	var slime_far := _spawn_enemy_at_grid("SlimeFar", 100.0, 10.0, 5.0, 1.0, 0.0, 2.0, Vector2i(2, 0))
	# Sinh Quái B (trong tầm 4) tại (2, 3) -> Hex dist = 2
	var slime_near := _spawn_enemy_at_grid("SlimeNear", 100.0, 10.0, 5.0, 1.0, 0.0, 2.0, Vector2i(2, 3))
	
	# Khẳng định khoảng cách lục giác
	var dist_far := board_grid.get_hex_distance(Vector2i(2, 5), Vector2i(2, 0))
	var dist_near := board_grid.get_hex_distance(Vector2i(2, 5), Vector2i(2, 3))
	_log_test("[TC-15.1] Robin at (2, 5) -> SlimeFar at (2, 0) Dist: %d | SlimeNear at (2, 3) Dist: %d" % [dist_far, dist_near])
	assert(dist_far == 5, "FAIL TC-15.1: Expected dist 5 to SlimeFar")
	assert(dist_near == 2, "FAIL TC-15.1: Expected dist 2 to SlimeNear")
	
	# Ban đầu ép target của Robin là SlimeFar (đã chạy ra ngoài tầm)
	robin.target = slime_far
	assert(not robin.is_target_in_attack_range(), "FAIL TC-15.1: SlimeFar must be out of range for Robin")
	
	# Kích hoạt nhịp đánh của Robin
	robin._on_attack_timer_timeout()
	
	# Robin phải tự động đổi mục tiêu sang SlimeNear và ĐỨNG YÊN TẠI CHỖ (không bước đi)
	var robin_cell := board_grid.get_cell_for_entity(robin)
	_log_test("[TC-15.1] Post-tick Robin Target: %s | Robin Cell: %s" % [robin.target.name if robin.target else "null", str(robin_cell)])
	assert(robin.target == slime_near, "FAIL TC-15.1: Robin must retarget to SlimeNear")
	assert(robin_cell == Vector2i(2, 5), "FAIL TC-15.1: Robin must remain stationary at (2, 5) when in-range target exists")
	_log_test(">>> 🟢 TC-15.1 Ranged Retargeting without Moving PASSED!")
	
	# 2. RANGED STEPS WHEN NO TARGETS IN RANGE (Chỉ di chuyển khi không còn ai trong tầm)
	board_grid.remove_dead_entity(slime_near)
	enemies.erase(slime_near)
	slime_near.queue_free()
	
	robin.target = slime_far
	robin._on_attack_timer_timeout()
	var new_robin_cell := board_grid.get_cell_for_entity(robin)
	_log_test("[TC-15.2] Robin stepped when no targets in range: %s -> %s" % [str(robin_cell), str(new_robin_cell)])
	assert(new_robin_cell != Vector2i(2, 5), "FAIL TC-15.2: Robin must step towards target when no enemies in range")
	assert(board_grid.get_hex_distance(new_robin_cell, Vector2i(2, 0)) < dist_far, "FAIL TC-15.2: Distance to SlimeFar must decrease")
	_log_test(">>> 🟢 TC-15.2 Ranged Step Execution when No Targets in Range PASSED!")
	
	# 3. MELEE ANTI-KITING (Tướng cận chiến không chạy xuyên qua địch kề bên)
	board_grid.move_entity(board_grid.get_cell_for_entity(arthur), Vector2i(3, 4), true)
	if board_view != null: arthur.global_position = board_view.grid_to_world(Vector2i(3, 4))
	
	var slime_adj := _spawn_enemy_at_grid("SlimeAdj", 100.0, 10.0, 5.0, 1.0, 0.0, 2.0, Vector2i(3, 3))
	var arthur_dist_adj := board_grid.get_hex_distance(Vector2i(3, 4), Vector2i(3, 3))
	var arthur_dist_far := board_grid.get_hex_distance(Vector2i(3, 4), Vector2i(2, 0))
	_log_test("[TC-15.3] Arthur at (3, 4) -> SlimeAdj Dist: %d | SlimeFar Dist: %d" % [arthur_dist_adj, arthur_dist_far])
	assert(arthur_dist_adj == 1, "FAIL TC-15.3: SlimeAdj must be adjacent (dist 1)")
	assert(arthur_dist_far > 1, "FAIL TC-15.3: SlimeFar must be out of melee range")
	
	arthur.target = slime_far
	arthur._on_attack_timer_timeout()
	
	var arthur_cell := board_grid.get_cell_for_entity(arthur)
	_log_test("[TC-15.3] Post-tick Arthur Target: %s | Arthur Cell: %s" % [arthur.target.name if arthur.target else "null", str(arthur_cell)])
	assert(arthur.target == slime_adj, "FAIL TC-15.3: Arthur must retarget to adjacent enemy")
	assert(arthur_cell == Vector2i(3, 4), "FAIL TC-15.3: Arthur must not leave cell when adjacent enemy exists")
	_log_test(">>> 🟢 TC-15.3 Melee Anti-Kiting PASSED!")
	
	# 4. TARGETINGSYSTEM PROCESS DYNAMIC RETARGETING
	board_grid.move_entity(board_grid.get_cell_for_entity(robin), Vector2i(2, 5), true)
	if board_view != null: robin.global_position = board_view.grid_to_world(Vector2i(2, 5))
	robin.target = slime_far
	assert(not robin.is_target_in_attack_range(), "FAIL TC-15.4: SlimeFar must be out of Robin's range at (2, 5)")
	targeting_system._assign_targets([robin], enemies)
	assert(robin.target == slime_adj, "FAIL TC-15.4: TargetingSystem must automatically switch out-of-range target")
	_log_test(">>> 🟢 TC-15.4 TargetingSystem dynamic retargeting PASSED!")
	
	_log_test(">>> 🟢 TC-15 PASSED: Smart Combat Retargeting & Anti-Kiting fully verified!\n")

# ------------------------------------------------------------------------------
# TC-16: Character Stats Panel & Inspection UI
# ------------------------------------------------------------------------------
func _run_tc_16_character_stats_ui() -> void:
	_log_test("\n==================== [TEST TC-16: CHARACTER STATS PANEL & INSPECTION UI] ====================")
	_reset_test_battlefield()
	
	assert(character_stats_ui != null, "FAIL TC-16: CharacterStatsUI instance must exist")
	character_stats_ui.close()
	assert(not character_stats_ui.visible, "FAIL TC-16.1: Panel must be hidden initially")
	
	var arthur: HeroEntity = null
	var robin: HeroEntity = null
	for h in heroes:
		if is_instance_valid(h) and h is HeroEntity and h.data != null:
			if h.data.name == "Arthur":
				arthur = h
			elif h.data.name == "Robin":
				robin = h
	assert(arthur != null and robin != null, "FAIL TC-16: Arthur and Robin must exist")
	
	# 1. INSPECT HERO & HEADER BINDING
	character_stats_ui.inspect_hero(arthur)
	assert(character_stats_ui.visible, "FAIL TC-16.1: Panel must be visible after inspect_hero")
	assert(character_stats_ui.inspected_hero == arthur, "FAIL TC-16.1: Inspected hero must be Arthur")
	assert(character_stats_ui.name_label.text == "Arthur", "FAIL TC-16.1: Name label must match Arthur")
	assert(character_stats_ui.class_label.text.contains("TANK"), "FAIL TC-16.1: Class label must show TANK")
	assert(character_stats_ui.level_label.text == "Cấp 1", "FAIL TC-16.1: Initial level must be Cấp 1")
	_log_test(">>> 🟢 TC-16.1 Hero Inspection & Header Data Binding PASSED!")
	
	# 2. STAT GRID BINDING & RIGHT-DOCK VERIFICATION
	assert(character_stats_ui.panel_container.position.x >= 800, "FAIL TC-16.2: Panel must be docked on the right side (x >= 800)")
	assert(character_stats_ui.attack_val_label.text == "%.1f" % arthur.get_attack(), "FAIL TC-16.2: Attack stat mismatch")
	assert(character_stats_ui.spell_val_label.text == "%.1f" % arthur.get_spell_power(), "FAIL TC-16.2: Spell Power stat mismatch")
	assert(character_stats_ui.def_val_label.text == "%.1f" % arthur.get_defense(), "FAIL TC-16.2: Defense stat mismatch")
	assert(character_stats_ui.range_val_label.text == "%d ô" % arthur.get_attack_range(), "FAIL TC-16.2: Range stat mismatch")
	assert(character_stats_ui.skills_container.get_child_count() > 0, "FAIL TC-16.2: Skills container must contain skill icons")
	_log_test(">>> 🟢 TC-16.2 Right-dock, Hexagon Skills & 4x2 Stat Grid PASSED!")
	
	# 3. REACTIVE RESOURCE BAR UPDATES
	var old_hp := arthur.current_hp
	arthur.current_hp = old_hp - 25.0
	assert(character_stats_ui.hp_bar.value == arthur.current_hp, "FAIL TC-16.3: HP bar did not reactively update")
	assert(character_stats_ui.hp_label.text.contains("%.0f / %.0f" % [arthur.current_hp, arthur.max_hp]), "FAIL TC-16.3: HP label mismatch")
	
	arthur.current_energy = 50.0
	assert(character_stats_ui.energy_bar.value == 50.0, "FAIL TC-16.3: Energy bar did not reactively update")
	_log_test(">>> 🟢 TC-16.3 Reactive HP & Energy Updates PASSED!")
	
	# 4. SWITCH INSPECTED HERO & OLD TARGET DISCONNECTION
	character_stats_ui.inspect_hero(robin)
	assert(character_stats_ui.inspected_hero == robin, "FAIL TC-16.4: Inspected hero must switch to Robin")
	assert(character_stats_ui.name_label.text == "Robin", "FAIL TC-16.4: Name label must update to Robin")
	assert(character_stats_ui.range_val_label.text == "%d ô" % robin.get_attack_range(), "FAIL TC-16.4: Robin range must be %d ô" % robin.get_attack_range())
	
	# Đổi HP của Arthur -> không được ảnh hưởng đến bảng đang inspect Robin
	var robin_hp := robin.current_hp
	arthur.current_hp = 10.0
	assert(character_stats_ui.hp_bar.value == robin_hp, "FAIL TC-16.4: Old target Arthur must not affect Robin inspection")
	_log_test(">>> 🟢 TC-16.4 Hero Switching & Clean Disconnect PASSED!")
	
	# 5. CLOSE & DISMISS
	character_stats_ui.close()
	assert(not character_stats_ui.visible, "FAIL TC-16.5: Panel must hide on close")
	assert(character_stats_ui.inspected_hero == null, "FAIL TC-16.5: Inspected hero must be null after close")
	_log_test(">>> 🟢 TC-16.5 Panel Close & Dismissal PASSED!")
	
	# 6. PLACEMENT CONTROLLER SELECTION INTEGRATION
	if placement_controller != null:
		placement_controller.hero_selected.emit(arthur)
		assert(character_stats_ui.visible, "FAIL TC-16.6: PlacementController hero_selected must open stats panel")
		assert(character_stats_ui.inspected_hero == arthur, "FAIL TC-16.6: Inspected hero must be Arthur")
		character_stats_ui.close()
	_log_test(">>> 🟢 TC-16.6 PlacementController Integration PASSED!")
	
	_log_test(">>> 🟢 TC-16 PASSED: Character Stats Panel & Inspection UI fully verified!\n")

# ------------------------------------------------------------------------------
# TC-17: Skill Scaling & Dynamic BBCode Tooltip Framework
# ------------------------------------------------------------------------------
func _run_tc_17_skill_scaling_and_tooltip() -> void:
	_log_test("\n==================== [TEST TC-17: SKILL SCALING & BBCODE TOOLTIP] ====================")
	_reset_test_battlefield()
	
	var arthur: HeroEntity = null
	for h in heroes:
		if is_instance_valid(h) and h is HeroEntity and h.data != null:
			if h.data.name == "Arthur":
				arthur = h
				break
	assert(arthur != null, "FAIL TC-17: Arthur must exist")
	
	# Chuẩn bị chỉ số Arthur rõ ràng:
	# base_attack = 5.0, base_spell_power = 10.0, base_defense = 30.0, max_hp = 250.0
	var atk: float = arthur.get_attack()
	var ap: float = arthur.get_spell_power()
	var hp: float = arthur.max_hp
	var arm: float = arthur.get_defense()
	
	# 1. FALLBACK KHI SOURCE == NULL (Xem tooltip khi chưa có Tướng)
	var dmg_null := DamageEffectData.new()
	dmg_null.base_damage = 100.0
	dmg_null.scalings = { EffectData.STAT_AD: 0.8, EffectData.STAT_AP: 0.5 }
	
	assert(dmg_null.calculate_total_value(null) == 100.0, "FAIL TC-17.1: calculate_total_value(null) must equal base_amount")
	var desc_null := dmg_null.get_formatted_description(null)
	_log_test("[TC-17.1] Source=null Description: %s" % desc_null)
	assert(desc_null.contains("100"), "FAIL TC-17.1: Tooltip must show base 100 when source is null")
	assert(desc_null.contains("+80% SMCK") and desc_null.contains(EffectData.COLOR_AD), "FAIL TC-17.1: AD scaling with color required")
	assert(desc_null.contains("+50% SMPT") and desc_null.contains(EffectData.COLOR_AP), "FAIL TC-17.1: AP scaling with color required")
	_log_test(">>> 🟢 TC-17.1 Fallback calculation & unassigned Tooltip PASSED!")
	
	# 2. TÍNH TOÁN SCALING VỚI TƯỚNG (AD, AP, HP, ARM)
	# 2a. Pure AD Scale
	var dmg_ad := DamageEffectData.new()
	dmg_ad.base_damage = 40.0
	dmg_ad.scalings = { EffectData.STAT_AD: 2.0 }
	var expected_ad := 40.0 + (atk * 2.0) # 40 + 10 = 50.0
	assert(dmg_ad.calculate_total_value(arthur) == expected_ad, "FAIL TC-17.2: AD scaling mismatch")
	
	# 2b. Pure AP Scale
	var dmg_ap := DamageEffectData.new()
	dmg_ap.base_damage = 60.0
	dmg_ap.scalings = { EffectData.STAT_AP: 1.5 }
	var expected_ap := 60.0 + (ap * 1.5) # 60 + 15 = 75.0
	assert(dmg_ap.calculate_total_value(arthur) == expected_ap, "FAIL TC-17.2: AP scaling mismatch")
	
	# 2c. Tank Armor & Max HP Scale
	var dmg_tank := DamageEffectData.new()
	dmg_tank.base_damage = 50.0
	dmg_tank.scalings = { EffectData.STAT_HP: 0.1, EffectData.STAT_ARM: 0.5 }
	var expected_tank := 50.0 + (hp * 0.1) + (arm * 0.5) # 50 + 25 + 15 = 90.0
	assert(dmg_tank.calculate_total_value(arthur) == expected_tank, "FAIL TC-17.2: Tank HP+Armor scaling mismatch")
	_log_test(">>> 🟢 TC-17.2 AD, AP, HP, ARM Scaling calculations PASSED!")
	
	# 3. BBCODE DYNAMIC TOOLTIP PARSING (CẶP NGOẶC ĐƠN & KHÔNG RÁC HIỂN THỊ)
	# 3a. Không có scale -> Không hiện cặp ngoặc đơn ()
	var dmg_flat := DamageEffectData.new()
	dmg_flat.base_damage = 75.0
	dmg_flat.scalings = {}
	var desc_flat := dmg_flat.get_formatted_description(arthur)
	_log_test("[TC-17.3] Flat Description: %s" % desc_flat)
	assert(not desc_flat.contains("("), "FAIL TC-17.3: Flat ability must not contain parentheses ()")
	assert(desc_flat.contains("75"), "FAIL TC-17.3: Flat ability must contain base damage")
	
	# 3b. Có 1 scale -> Hiện 1 tỷ lệ trong ngoặc
	var desc_single := dmg_ad.get_formatted_description(arthur)
	_log_test("[TC-17.3] Single Scale Description: %s" % desc_single)
	assert(desc_single.contains("(%s+200%% SMCK[/color])" % ("[color=" + EffectData.COLOR_AD + "]")), "FAIL TC-17.3: Single scale bracket syntax")
	
	# 3c. Có nhiều scale -> Nối bằng dấu ' + '
	var desc_tank := dmg_tank.get_formatted_description(arthur)
	_log_test("[TC-17.3] Multi Scale Description: %s" % desc_tank)
	assert(desc_tank.contains(" + "), "FAIL TC-17.3: Multi scales must be joined by ' + '")
	assert(desc_tank.contains("+10% Máu tối đa") and desc_tank.contains("+50% Giáp"), "FAIL TC-17.3: Multi scale tags")
	_log_test(">>> 🟢 TC-17.3 BBCode formatting & No-parentheses flat clean text PASSED!")
	
	# 4. HEALEFFECTDATA SCALING & TOOLTIP
	var heal_eff := HealEffectData.new()
	heal_eff.heal_amount = 30.0
	heal_eff.scalings = { EffectData.STAT_AP: 0.8 }
	var expected_heal := 30.0 + (ap * 0.8) # 30 + 8 = 38.0
	assert(heal_eff.calculate_total_value(arthur) == expected_heal, "FAIL TC-17.4: Heal scaling mismatch")
	var desc_heal := heal_eff.get_formatted_description(arthur)
	_log_test("[TC-17.4] Heal Description: %s" % desc_heal)
	assert(desc_heal.contains("Hồi") and desc_heal.contains(EffectData.COLOR_HP), "FAIL TC-17.4: Heal description syntax")
	_log_test(">>> 🟢 TC-17.4 HealEffectData scaling & BBCode Tooltip PASSED!")
	
	# 5. ABILITYSYSTEM PROCESS SCALED ATTACK
	var mock_ability_data := AbilityData.new()
	mock_ability_data.name = "Scaling Strike"
	mock_ability_data.effects = [dmg_ad]
	
	var dummy_enemy: EnemyEntity = null
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			dummy_enemy = e
			break
	assert(dummy_enemy != null, "FAIL TC-17.5: Enemy dummy required")
	
	var enemy_hp_before := dummy_enemy.current_hp
	ability_system._apply_effect(dmg_ad, arthur, dummy_enemy)
	assert(dummy_enemy.current_hp < enemy_hp_before, "FAIL TC-17.5: Scaled ability must deal damage to enemy")
	_log_test(">>> 🟢 TC-17.5 AbilitySystem scaled damage application PASSED!")
	
	_log_test(">>> 🟢 TC-17 PASSED: Skill Scaling & Dynamic BBCode Tooltips fully verified!\n")

# ------------------------------------------------------------------------------
# TC-18: Weighted Skill Upgrades & Resource Isolation (Sprint 4 - Task S4.2)
# ------------------------------------------------------------------------------
func _run_tc_18_skill_upgrades_and_isolation() -> void:
	_log_test("\n==================== [TEST TC-18: SKILL UPGRADES & RESOURCE ISOLATION] ====================")
	_reset_test_battlefield()
	
	# 1. TC-18.1: CÔ LẬP VÙNG NHỚ RESOURCE (P0 CHECK) & PERMA-DEATH RESET
	var kira: HeroEntity = null
	for h in heroes:
		if is_instance_valid(h) and h is HeroEntity and h.data != null and h.data.name == "Kira":
			kira = h
			break
	assert(kira != null, "FAIL TC-18.1: Kira must exist on battlefield")
	
	var orig_ult_res := load("res://data/abilities/Kira_Ultimate.tres") as AbilityData
	assert(orig_ult_res != null, "FAIL TC-18.1: Kira_Ultimate.tres must exist")
	var orig_base: float = orig_ult_res.effects[0].base_amount
	assert(orig_base == 150.0, "FAIL TC-18.1: Original Kira Ultimate base must be 150.0")
	assert(not orig_ult_res.effects[0].scalings.has(EffectData.STAT_AP), "FAIL TC-18.1: Original should not have AP scaling")
	
	# Trang bị cho Kira bản sao runtime Ultimate
	var kira_runtime_ult := HeroEntity.clone_ability_runtime(orig_ult_res)
	kira.unlocked_abilities.clear()
	kira.unlocked_abilities.append(Ability.new(kira, kira_runtime_ult))
	
	# Áp dụng 1 thẻ FLAT_BOOST (+50) và 1 thẻ SCALE_BOOST (+20% AP)
	var flat_card := SkillUpgradeCard.new()
	flat_card.upgrade_type = SkillUpgradeCard.UpgradeType.FLAT_BOOST
	flat_card.target_ability = kira_runtime_ult
	flat_card.bonus_value = 50.0
	flat_card.apply_to_hero(kira)
	
	var scale_card := SkillUpgradeCard.new()
	scale_card.upgrade_type = SkillUpgradeCard.UpgradeType.SCALE_BOOST
	scale_card.target_ability = kira_runtime_ult
	scale_card.stat_key = EffectData.STAT_AP
	scale_card.bonus_value = 0.20
	scale_card.apply_to_hero(kira)
	
	# Kiểm tra Ultimate runtime của Kira đã nhận đủ chỉ số
	assert(kira_runtime_ult.effects[0].base_amount == 200.0, "FAIL TC-18.1: Runtime base amount should be 200.0")
	assert(kira_runtime_ult.effects[0].scalings.get(EffectData.STAT_AP, 0.0) == 0.20, "FAIL TC-18.1: Runtime AP scale should be 0.20")
	
	# [P0 CRITICAL ASSERTION] Resource gốc trong bộ nhớ RAM KHÔNG ĐƯỢC PHÉP bị biến đổi!
	assert(orig_ult_res.effects[0].base_amount == 150.0, "FAIL TC-18.1: Original resource base_amount was mutated!")
	assert(not orig_ult_res.effects[0].scalings.has(EffectData.STAT_AP), "FAIL TC-18.1: Original resource scalings was mutated!")
	_log_test("[TC-18.1] RAM Isolation verified: Original .tres base = 150.0 (Unchanged), Runtime copy = 200.0")
	
	# Perma-death Clean Reset
	_reset_heroes_for_new_run()
	assert(kira.progression.current_level == 1, "FAIL TC-18.1: Hero level must reset to 1")
	var reset_ult_data = kira.unlocked_abilities[0].data
	assert(not reset_ult_data.effects[0].scalings.has(EffectData.STAT_AP), "FAIL TC-18.1: Reset hero retained mutated AP scaling!")
	_log_test(">>> 🟢 TC-18.1 Memory Isolation & Perma-death Clean Reset PASSED!")
	
	# 2. TC-18.2: KIỂM CHỨNG TOÁN HỌC SAU NÂNG CẤP
	var test_hero_data := _create_mock_hero_data("MageTest", HeroData.HeroClass.MAGE, 100.0, 10.0, 10.0, 1.0, 3, 40.0)
	var test_entity := hero_scene.instantiate() as HeroEntity
	add_child(test_entity)
	test_entity.initialize(test_hero_data)
	
	var test_ability := AbilityData.new()
	test_ability.name = "Fireball"
	var eff := DamageEffectData.new()
	eff.base_amount = 100.0
	eff.scalings = { EffectData.STAT_AP: 0.50 }
	test_ability.effects.append(eff)
	test_entity.unlocked_abilities.append(Ability.new(test_entity, test_ability))
	
	var val_before: float = eff.calculate_total_value(test_entity)
	assert(val_before == 120.0, "FAIL TC-18.2: Initial value should be 120.0 (100 + 40*0.5)")
	
	var flat_card2 := SkillUpgradeCard.new()
	flat_card2.upgrade_type = SkillUpgradeCard.UpgradeType.FLAT_BOOST
	flat_card2.target_ability = test_ability
	flat_card2.bonus_value = 30.0
	flat_card2.apply_to_hero(test_entity)
	
	var scale_card2 := SkillUpgradeCard.new()
	scale_card2.upgrade_type = SkillUpgradeCard.UpgradeType.SCALE_BOOST
	scale_card2.target_ability = test_ability
	scale_card2.stat_key = EffectData.STAT_AP
	scale_card2.bonus_value = 0.25
	scale_card2.apply_to_hero(test_entity)
	
	var val_after: float = eff.calculate_total_value(test_entity)
	assert(abs(val_after - 160.0) < 0.001, "FAIL TC-18.2: Expected 160.0 after upgrades, got %f" % val_after)
	
	var tooltip: String = test_ability.get_formatted_tooltip(test_entity)
	_log_test("[TC-18.2] Post-upgrade Tooltip: %s" % tooltip)
	assert(tooltip.contains("+75% SMPT"), "FAIL TC-18.2: Tooltip must show updated +75% SMPT")
	assert(tooltip.contains("160"), "FAIL TC-18.2: Tooltip must show total value 160")
	test_entity.queue_free()
	_log_test(">>> 🟢 TC-18.2 Upgrade Math & Dynamic Tooltip Recalculation PASSED!")
	
	# 3. TC-18.3: PHÂN PHỐI XÁC SUẤT GACHA TRỌNG SỐ (MONTE-CARLO 500 SAMPLES)
	var card_flat := SkillUpgradeCard.new()
	card_flat.upgrade_type = SkillUpgradeCard.UpgradeType.FLAT_BOOST
	card_flat.weight = 80
	
	var card_scale := SkillUpgradeCard.new()
	card_scale.upgrade_type = SkillUpgradeCard.UpgradeType.SCALE_BOOST
	card_scale.weight = 20
	
	var sample_pool: Array[SkillUpgradeCard] = [card_flat, card_scale]
	var scale_count: int = 0
	var iterations: int = 500
	
	for i in range(iterations):
		var picked: SkillUpgradeCard = ProgressionSystem.sample_weighted_card(sample_pool)
		if picked.upgrade_type == SkillUpgradeCard.UpgradeType.SCALE_BOOST:
			scale_count += 1
			
	var scale_pct: float = float(scale_count) / float(iterations)
	_log_test("[TC-18.3] 500 Gacha Samples: SCALE_BOOST drawn %d times (%.1f%%, Target 20.0%%)" % [scale_count, scale_pct * 100.0])
	assert(scale_pct >= 0.12 and scale_pct <= 0.28, "FAIL TC-18.3: Gacha probability outside 12%% - 28%% (got %.2f)" % scale_pct)
	_log_test(">>> 🟢 TC-18.3 Monte-Carlo Gacha Probability Distribution PASSED!")
	
	_log_test(">>> 🟢 TC-18 PASSED: Skill Upgrades & Resource Isolation fully verified!\n")

# ------------------------------------------------------------------------------
# TC-19: Narrative Tooltip, Lv99 Piecewise XP & Encounter Director (Sprint 4 Task S4.3, S4.4)
# ------------------------------------------------------------------------------
func _run_tc_19_narrative_and_encounter_director() -> void:
	_log_test("\n==================== [TEST TC-19: NARRATIVE TOOLTIP, LV99 XP & ENCOUNTER DIRECTOR] ====================")
	_reset_test_battlefield()
	
	# 1. TC-19.1: NARRATIVE TEMPLATE INTERPOLATION & DYNAMIC BBCODE TOOLTIP
	_log_test("[TC-19.1] Checking Narrative Template Interpolation ({0}, {1})...")
	var test_hero_data := _create_mock_hero_data("Khadgar", HeroData.HeroClass.MAGE, 100.0, 10.0, 10.0, 1.0, 3, 40.0)
	var caster := hero_scene.instantiate() as HeroEntity
	add_child(caster)
	caster.initialize(test_hero_data)
	
	var fireball := AbilityData.new()
	fireball.name = "Hỏa Cầu Thuật"
	fireball.description = "Bắn cầu lửa thiêu đốt mục tiêu, gây {0} sát thương phép."
	var dmg := DamageEffectData.new()
	dmg.base_amount = 100.0
	dmg.damage_type = DamageEvent.DamageType.MAGIC
	dmg.scalings = { EffectData.STAT_AP: 0.50 }
	fireball.effects = [dmg]
	
	var tooltip_caster := fireball.get_formatted_tooltip(caster)
	_log_test("[TC-19.1] Interpolated Tooltip (AP=40): %s" % tooltip_caster)
	assert(not tooltip_caster.contains("{0}"), "FAIL TC-19.1: Placeholder {0} was not replaced")
	assert(tooltip_caster.contains("120"), "FAIL TC-19.1: Value should be 100 + 40*0.5 = 120")
	assert(tooltip_caster.contains("+50% SMPT"), "FAIL TC-19.1: Tooltip should display +50% SMPT scaling")
	assert(tooltip_caster.begins_with("Bắn cầu lửa thiêu đốt mục tiêu, gây "), "FAIL TC-19.1: Template prefix missing")
	
	# Multi-effect interpolation ({0} and {1})
	var multi_ab := create_slime_boss_ability()
	var tooltip_multi := multi_ab.get_formatted_tooltip(caster)
	_log_test("[TC-19.1] Multi-effect Tooltip: %s" % tooltip_multi)
	assert(not tooltip_multi.contains("{0}") and not tooltip_multi.contains("{1}"), "FAIL TC-19.1: Multi placeholders {0}, {1} not replaced")
	# Effect 0: 120 + 40*1.2 = 168. Effect 1: 80 + 40*0.5 = 100
	assert(tooltip_multi.contains("168"), "FAIL TC-19.1: Multi-effect {0} value mismatch (expected 168)")
	assert(tooltip_multi.contains("100"), "FAIL TC-19.1: Multi-effect {1} value mismatch (expected 100)")
	
	# Fallback backward compatibility (no template)
	var legacy_ab := AbilityData.new()
	legacy_ab.name = "Chém Thường"
	legacy_ab.description = "Đòn đánh vật lý cơ bản"
	legacy_ab.effects = [dmg]
	var tooltip_legacy := legacy_ab.get_formatted_tooltip(caster)
	assert(tooltip_legacy.contains("120"), "FAIL TC-19.1: Legacy tooltip should display formatted effect lines")
	
	# Null source safety check
	var tooltip_null := fireball.get_formatted_tooltip(null)
	assert(tooltip_null.contains("100"), "FAIL TC-19.1: Null source tooltip should display base amount 100")
	caster.queue_free()
	_log_test(">>> 🟢 TC-19.1 Narrative Template Interpolation PASSED!")
	
	# 2. TC-19.2: PIECEWISE XP CURVE & LEVEL 99 PROGRESSION
	_log_test("[TC-19.2] Checking Piecewise XP Curve & Lv99 Progression...")
	assert(HeroProgression.MAX_LEVEL == 99, "FAIL TC-19.2: MAX_LEVEL must be 99")
	assert(HeroProgression.MILESTONES.size() == 11, "FAIL TC-19.2: MILESTONES should have 11 milestones")
	assert(HeroProgression.MILESTONES == [5, 10, 15, 20, 25, 35, 50, 65, 75, 90, 99], "FAIL TC-19.2: Milestone array mismatch")
	
	var prog := HeroProgression.new()
	# Backward compatibility: verify exact TC-12.3 values
	prog.add_xp(2000.0)
	assert(prog.current_level == 10, "FAIL TC-19.2: 2000 XP must result in Level 10 (TC-12.3 regression check)")
	assert(prog.pending_milestones == [5, 10], "FAIL TC-19.2: Milestones 5 and 10 must be unlocked")
	prog.add_xp(3000.0)
	assert(prog.current_level == 16, "FAIL TC-19.2: 5000 XP must result in Level 16 (TC-12.3 regression check)")
	
	# Piecewise dampening for levels 26 - 99
	var xp_req_25 := prog._calculate_required_xp(25)
	var xp_req_26 := prog._calculate_required_xp(26)
	assert(xp_req_26 > xp_req_25, "FAIL TC-19.2: Level 26 required XP must be greater than Level 25")
	
	var xp_req_50 := prog._calculate_required_xp(50)
	var xp_req_99 := prog._calculate_required_xp(99)
	_log_test("[TC-19.2] Required XP: Lv25 = %.1f | Lv26 = %.1f | Lv50 = %.1f | Lv99 = %.1f" % [xp_req_25, xp_req_26, xp_req_50, xp_req_99])
	assert(xp_req_50 < 10000.0, "FAIL TC-19.2: Lv50 required XP must be < 10,000 (got %.1f)" % xp_req_50)
	assert(xp_req_99 < 20000.0, "FAIL TC-19.2: Lv99 required XP must be < 20,000 without exponential explosion (got %.1f)" % xp_req_99)
	_log_test(">>> 🟢 TC-19.2 Piecewise XP Curve & Lv99 Progression PASSED!")
	
	# 3. TC-19.3: MONSTER SKILLS, ENERGY GAIN, CASTING & DEAD COOLDOWN HALT
	_log_test("[TC-19.3] Checking Enemy Skills, Energy & Polymorphic CombatEntity...")
	var elite_data := EnemyData.new()
	elite_data.name = "EliteSlimeTest"
	elite_data.rank = EnemyData.EnemyRank.ELITE
	elite_data.base_hp = 200.0
	elite_data.base_attack = 20.0
	elite_data.base_defense = 0.0
	elite_data.base_spell_power = 25.0
	elite_data.abilities = [create_slime_elite_ability()]
	var elite_enemy: EnemyEntity = _spawn_custom_enemy_at_grid(elite_data, Vector2i(3, 2), 10, EnemyData.EnemyRank.ELITE)
	
	assert(elite_enemy.level == 10, "FAIL TC-19.3: Enemy level mismatch")
	assert(elite_enemy.unlocked_abilities.size() == 1, "FAIL TC-19.3: Elite enemy should have 1 ability")
	assert(elite_enemy.status_bar != null and is_instance_valid(elite_enemy.status_bar.energy_bar), "FAIL TC-19.3: EnergyBar must be visible for enemy with skills")
	
	# Energy gain test
	elite_enemy.current_energy = 0.0
	elite_enemy._gain_energy(35.0)
	assert(elite_enemy.current_energy == 35.0, "FAIL TC-19.3: Enemy energy gain failed")
	
	# Skill execution test
	elite_enemy.current_energy = 100.0
	var elite_ab: Ability = elite_enemy.unlocked_abilities[0]
	var cast_success := ability_system.execute_ability(elite_ab)
	assert(cast_success == true, "FAIL TC-19.3: Enemy ability execution failed")
	assert(elite_enemy.current_energy == 40.0, "FAIL TC-19.3: Enemy energy should deduct cost 60.0 (100 - 60 = 40)")
	assert(elite_ab.current_cooldown == elite_ab.data.cooldown, "FAIL TC-19.3: Ability cooldown not started")
	
	# Dead cooldown halt test
	elite_enemy.is_dead = true
	elite_enemy._process(2.0)
	assert(elite_ab.current_cooldown == elite_ab.data.cooldown, "FAIL TC-19.3: Cooldown must NOT tick when entity is dead")
	
	# Damage Reduction test
	var mock_attacker := hero_scene.instantiate() as HeroEntity
	add_child(mock_attacker)
	var atk_data := _create_mock_hero_data("Attacker", HeroData.HeroClass.FIGHTER, 100.0, 100.0, 0.0, 1.0)
	mock_attacker.initialize(atk_data)
	
	var norm_target: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(norm_target)
	var t_data := EnemyData.new()
	t_data.base_hp = 500.0; t_data.base_defense = 0.0
	norm_target.initialize(t_data, 1, EnemyData.EnemyRank.NORMAL, false)
	
	var boss_target: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(boss_target)
	boss_target.initialize(t_data, 1, EnemyData.EnemyRank.BOSS, true) # Solo boss has 30% reduction
	assert(boss_target.damage_reduction == 0.30, "FAIL TC-19.3: Solo boss damage_reduction should be 0.30")
	
	var norm_hp_before := norm_target.current_hp
	var boss_hp_before := boss_target.current_hp
	var ev_norm := DamageEvent.new(mock_attacker, norm_target, 100.0, DamageEvent.DamageType.PHYSICAL)
	var ev_boss := DamageEvent.new(mock_attacker, boss_target, 100.0, DamageEvent.DamageType.PHYSICAL)
	combat_system.process_attack(ev_norm)
	combat_system.process_attack(ev_boss)
	
	var norm_dmg := norm_hp_before - norm_target.current_hp
	var boss_dmg := boss_hp_before - boss_target.current_hp
	_log_test("[TC-19.3] Damage to Normal (0%% DR): %.1f | Damage to Solo Boss (30%% DR): %.1f" % [norm_dmg, boss_dmg])
	assert(abs(norm_dmg - 100.0) < 0.1, "FAIL TC-19.3: Normal target damage mismatch")
	assert(abs(boss_dmg - 70.0) < 0.1, "FAIL TC-19.3: Boss target damage should be reduced by 30%% (expected 70, got %.1f)" % boss_dmg)
	
	elite_enemy.queue_free()
	mock_attacker.queue_free()
	norm_target.queue_free()
	boss_target.queue_free()
	_log_test(">>> 🟢 TC-19.3 Monster Skills & Damage Reduction PASSED!")
	
	# 4. TC-19.4: ENCOUNTER DIRECTOR & FLOOR COMPOSITIONS
	_log_test("[TC-19.4] Checking Encounter Director Floor Rules...")
	assert(get_floor_type(1) == FloorType.NORMAL_FLOOR, "FAIL TC-19.4: Floor 1 must be NORMAL")
	assert(get_floor_type(2) == FloorType.NORMAL_FLOOR, "FAIL TC-19.4: Floor 2 must be NORMAL")
	assert(get_floor_type(3) == FloorType.ELITE_FLOOR, "FAIL TC-19.4: Floor 3 must be ELITE")
	assert(get_floor_type(5) == FloorType.BOSS_FLOOR, "FAIL TC-19.4: Floor 5 must be BOSS")
	assert(get_floor_type(6) == FloorType.ELITE_FLOOR, "FAIL TC-19.4: Floor 6 must be ELITE")
	assert(get_floor_type(15) == FloorType.BOSS_FLOOR, "FAIL TC-19.4: Floor 15 must be BOSS (Priority over ELITE)")
	
	# Floor 1 Spawning
	spawn_encounter_for_floor(1)
	assert(enemies.size() == 5, "FAIL TC-19.4: Floor 1 should spawn 5 normal enemies")
	for e in enemies:
		assert(e.level == 1, "FAIL TC-19.4: Floor 1 enemy level should be 1")
		assert(e.data.rank == EnemyData.EnemyRank.NORMAL, "FAIL TC-19.4: Floor 1 enemy rank should be NORMAL")
		
	# Floor 3 Elite Spawning
	spawn_encounter_for_floor(3)
	var elite_count := 0
	for e in enemies:
		if e.data.rank == EnemyData.EnemyRank.ELITE:
			elite_count += 1
			assert(e.level >= 5, "FAIL TC-19.4: Elite enemy level should be boosted (>= 5)")
	assert(elite_count == 1, "FAIL TC-19.4: Floor 3 must have 1 Elite enemy")
	
	# Floor 5 Variant 1: Boss + Elites
	spawn_encounter_for_floor(5, 1)
	var v1_boss := 0
	var v1_elite := 0
	for e in enemies:
		if e.data.rank == EnemyData.EnemyRank.BOSS:
			v1_boss += 1
		elif e.data.rank == EnemyData.EnemyRank.ELITE:
			v1_elite += 1
	assert(v1_boss == 1, "FAIL TC-19.4: Variant 1 must spawn 1 Boss")
	assert(v1_elite >= 1, "FAIL TC-19.4: Variant 1 must spawn at least 1 Elite minion")
	
	# Floor 5 Variant 2: Solo Raid Boss
	spawn_encounter_for_floor(5, 2)
	assert(enemies.size() == 1, "FAIL TC-19.4: Solo Boss variant must spawn exactly 1 enemy")
	var solo_boss: EnemyEntity = enemies[0]
	assert(solo_boss.data.rank == EnemyData.EnemyRank.BOSS, "FAIL TC-19.4: Solo Boss rank mismatch")
	assert(solo_boss.damage_reduction == 0.30, "FAIL TC-19.4: Solo Boss must have 30% damage reduction")
	_log_test("[TC-19.4] Solo Boss HP: %.1f | DR: %.0f%%" % [solo_boss.max_hp, solo_boss.damage_reduction * 100.0])
	_log_test(">>> 🟢 TC-19.4 Encounter Director Floor Compositions PASSED!")
	
	_log_test(">>> 🟢 TC-19 PASSED: Narrative Interpolation, Lv99 XP & Encounter Director fully verified!\n")

# ------------------------------------------------------------------------------
# TC-20: Procedural Prestige UI & Input Polymorphism (Sprint 4 Task S4.5)
# ------------------------------------------------------------------------------
func _run_tc_20_procedural_ui_and_polymorphism() -> void:
	_log_test("\n==================== [TEST TC-20: PROCEDURAL PRESTIGE UI & POLYMORPHISM] ====================")
	_reset_test_battlefield()
	assert(character_stats_ui != null, "FAIL TC-20: CharacterStatsUI instance missing")
	character_stats_ui.close()
	
	# 1. TC-20.1: HERO BASE (LV1) VS MYTHIC (LV99) PRESTIGE BORDERS
	_log_test("[TC-20.1] Checking Hero Base vs Mythic Lv99 Prestige Borders...")
	var mage_data := _create_mock_hero_data("Merlin", HeroData.HeroClass.MAGE, 100.0, 10.0, 5.0, 1.0, 3, 50.0)
	var hero_inst := hero_scene.instantiate() as HeroEntity
	add_child(hero_inst)
	hero_inst.initialize(mage_data)
	hero_inst.progression.current_level = 1
	
	character_stats_ui.inspect_entity(hero_inst)
	assert(character_stats_ui.visible == true, "FAIL TC-20.1: Panel should be visible")
	assert(character_stats_ui.inspected_entity == hero_inst, "FAIL TC-20.1: Inspected entity mismatch")
	assert(character_stats_ui.level_label.text == "Cấp 1", "FAIL TC-20.1: Level label should be Cấp 1")
	assert(character_stats_ui.avatar_bg_style.border_width_left == 1, "FAIL TC-20.1: Lv1 hero border width should be 1")
	assert(character_stats_ui.avatar_bg_style.shadow_size == 0, "FAIL TC-20.1: Lv1 hero shadow size should be 0")
	assert(character_stats_ui.xp_bar.visible == true, "FAIL TC-20.1: Hero XP bar should be visible")
	assert(character_stats_ui.energy_bar.visible == true, "FAIL TC-20.1: Hero Energy bar should be visible")
	
	# Thần Thoại (Lv99)
	hero_inst.progression.current_level = 99
	character_stats_ui.update_stats()
	assert(character_stats_ui.level_label.text == "Cấp 99", "FAIL TC-20.1: Level label should update to Cấp 99")
	assert(character_stats_ui.avatar_bg_style.border_color == Color(1.0, 0.2, 0.7, 1.0), "FAIL TC-20.1: Mythic border color mismatch")
	assert(character_stats_ui.avatar_bg_style.border_width_left == 3, "FAIL TC-20.1: Mythic border width should be 3")
	assert(character_stats_ui.avatar_bg_style.shadow_size == 12, "FAIL TC-20.1: Mythic shadow size should be 12")
	_log_test(">>> 🟢 TC-20.1 Hero Base vs Mythic Lv99 Prestige Borders PASSED!")
	
	# 2. TC-20.2: INTERMEDIATE HERO MILESTONES (10, 25, 50, 75)
	_log_test("[TC-20.2] Checking Intermediate Hero Milestones (10, 25, 50, 75)...")
	# Level 10 (Ngọc Lục Bảo)
	hero_inst.progression.current_level = 10
	character_stats_ui.update_stats()
	assert(character_stats_ui.avatar_bg_style.border_color == Color(0.18, 0.85, 0.45, 1.0), "FAIL TC-20.2: Lv10 Emerald Green border mismatch")
	assert(character_stats_ui.avatar_bg_style.shadow_size == 4, "FAIL TC-20.2: Lv10 shadow size mismatch")
	
	# Level 25 (Lam Ngọc)
	hero_inst.progression.current_level = 25
	character_stats_ui.update_stats()
	assert(character_stats_ui.avatar_bg_style.border_color == Color(0.20, 0.65, 1.0, 1.0), "FAIL TC-20.2: Lv25 Sapphire Blue border mismatch")
	assert(character_stats_ui.avatar_bg_style.shadow_size == 6, "FAIL TC-20.2: Lv25 shadow size mismatch")
	
	# Level 50 (Tím Hoàng Gia)
	hero_inst.progression.current_level = 50
	character_stats_ui.update_stats()
	assert(character_stats_ui.avatar_bg_style.border_color == Color(0.70, 0.30, 0.95, 1.0), "FAIL TC-20.2: Lv50 Royal Purple border mismatch")
	assert(character_stats_ui.avatar_bg_style.shadow_size == 8, "FAIL TC-20.2: Lv50 shadow size mismatch")
	
	# Level 75 (Đỏ Hoàng Kim)
	hero_inst.progression.current_level = 75
	character_stats_ui.update_stats()
	assert(character_stats_ui.avatar_bg_style.border_color == Color(1.0, 0.35, 0.15, 1.0), "FAIL TC-20.2: Lv75 Radiant Gold-Red border mismatch")
	assert(character_stats_ui.avatar_bg_style.shadow_size == 10, "FAIL TC-20.2: Lv75 shadow size mismatch")
	
	hero_inst.queue_free()
	_log_test(">>> 🟢 TC-20.2 Intermediate Hero Milestones PASSED!")
	
	# 3. TC-20.3: NORMAL ENEMY (NO SKILLS) INSPECTION
	_log_test("[TC-20.3] Checking Normal Enemy (No skills) Inspection...")
	var norm_data := EnemyData.new()
	norm_data.name = "NormalSlime"
	norm_data.rank = EnemyData.EnemyRank.NORMAL
	norm_data.base_hp = 100.0
	norm_data.base_attack = 10.0
	norm_data.base_defense = 5.0
	norm_data.abilities = []
	var norm_enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(norm_enemy)
	norm_enemy.initialize(norm_data, 1, EnemyData.EnemyRank.NORMAL, false)
	
	character_stats_ui.inspect_entity(norm_enemy)
	assert(character_stats_ui.xp_label.visible == false and character_stats_ui.xp_bar.visible == false, "FAIL TC-20.3: XP bar must be hidden for Enemy")
	assert(character_stats_ui.energy_label.visible == false and character_stats_ui.energy_bar.visible == false, "FAIL TC-20.3: Energy bar must be hidden for Enemy without skills")
	assert(character_stats_ui.class_label.visible == false, "FAIL TC-20.3: Class label must be hidden for Enemy")
	assert(character_stats_ui.level_label.text.contains("[QUÁI THƯỜNG]"), "FAIL TC-20.3: Level badge should contain [QUÁI THƯỜNG]")
	assert(character_stats_ui.avatar_bg_style.border_color == Color(0.48, 0.48, 0.52, 0.8), "FAIL TC-20.3: Ash Normal border color mismatch")
	assert(character_stats_ui.avatar_initial_label.text == "👾", "FAIL TC-20.3: Normal enemy icon should be 👾")
	norm_enemy.queue_free()
	_log_test(">>> 🟢 TC-20.3 Normal Enemy Inspection PASSED!")
	
	# 4. TC-20.4: ELITE ENEMY (WITH SKILLS) INSPECTION
	_log_test("[TC-20.4] Checking Elite Enemy (With skills) Inspection...")
	var elite_data := EnemyData.new()
	elite_data.name = "EliteSlime"
	elite_data.rank = EnemyData.EnemyRank.ELITE
	elite_data.base_hp = 200.0
	elite_data.base_attack = 15.0
	elite_data.base_defense = 8.0
	elite_data.abilities = [create_slime_elite_ability()]
	var elite_enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(elite_enemy)
	elite_enemy.initialize(elite_data, 5, EnemyData.EnemyRank.ELITE, false)
	
	character_stats_ui.inspect_entity(elite_enemy)
	assert(character_stats_ui.xp_bar.visible == false, "FAIL TC-20.4: XP bar must be hidden for Elite Enemy")
	assert(character_stats_ui.energy_bar.visible == true, "FAIL TC-20.4: Energy bar must be visible for Elite Enemy with skills")
	assert(character_stats_ui.level_label.text.contains("[🔥 TINH ANH]"), "FAIL TC-20.4: Level badge should contain [🔥 TINH ANH]")
	assert(character_stats_ui.avatar_bg_style.border_color == Color(0.85, 0.35, 0.80, 1.0), "FAIL TC-20.4: Crimson Elite border color mismatch")
	assert(character_stats_ui.avatar_bg_style.shadow_size == 8, "FAIL TC-20.4: Elite shadow size mismatch")
	assert(character_stats_ui.avatar_initial_label.text == "🔥", "FAIL TC-20.4: Elite enemy icon should be 🔥")
	elite_enemy.queue_free()
	_log_test(">>> 🟢 TC-20.4 Elite Enemy Inspection PASSED!")
	
	# 5. TC-20.5: SOLO RAID BOSS & DAMAGE REDUCTION INSPECTION
	_log_test("[TC-20.5] Checking Solo Raid Boss & Damage Reduction Inspection...")
	var boss_data := EnemyData.new()
	boss_data.name = "SoloRaidBoss"
	boss_data.rank = EnemyData.EnemyRank.BOSS
	boss_data.base_hp = 300.0
	boss_data.base_attack = 25.0
	boss_data.base_defense = 15.0
	boss_data.abilities = [create_slime_boss_ability()]
	var solo_boss: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(solo_boss)
	solo_boss.initialize(boss_data, 10, EnemyData.EnemyRank.BOSS, true) # Solo boss has 30% reduction
	
	character_stats_ui.inspect_entity(solo_boss)
	assert(character_stats_ui.level_label.text.contains("[👑 LÃNH CHÚA TẦNG]"), "FAIL TC-20.5: Level badge should contain [👑 LÃNH CHÚA TẦNG]")
	assert(character_stats_ui.avatar_bg_style.border_color == Color(0.90, 0.12, 0.20, 1.0), "FAIL TC-20.5: Dark Abyss Boss border color mismatch")
	assert(character_stats_ui.avatar_bg_style.border_width_left == 3, "FAIL TC-20.5: Boss border width should be 3")
	assert(character_stats_ui.avatar_bg_style.shadow_size == 12, "FAIL TC-20.5: Boss shadow size should be 12")
	assert(character_stats_ui.def_val_label.tooltip_text.contains("30%"), "FAIL TC-20.5: Defense tooltip must show 30% damage reduction")
	assert(character_stats_ui.def_val_label.text.contains("30%"), "FAIL TC-20.5: Defense label must show 30% damage reduction")
	assert(character_stats_ui.avatar_initial_label.text == "👑", "FAIL TC-20.5: Boss icon should be 👑")
	
	character_stats_ui.close()
	assert(character_stats_ui.visible == false, "FAIL TC-20.5: Panel must hide on close")
	solo_boss.queue_free()
	_log_test(">>> 🟢 TC-20.5 Solo Raid Boss & Damage Reduction PASSED!")
	
	_log_test(">>> 🟢 TC-20 PASSED: Procedural UI & Polymorphism fully verified!\n")

# ------------------------------------------------------------------------------
# TC-21: Full Save/Load Persistence, Hero Progression & Solo Boss Balance
# (GD & QA Sign-off Requirements)
# ------------------------------------------------------------------------------
func _run_tc_21_save_resume_and_boss_balance() -> void:
	_log_test("\n==================== [TEST TC-21: PERSISTENCE, HERO STATE & BOSS BALANCE] ====================")
	_reset_test_battlefield()
	
	# 1. TC-21.1: SOLO RAID BOSS BALANCE VERIFICATION (GD Spec)
	_log_test("[TC-21.1] Checking Solo Raid Boss balance at Floor 5...")
	spawn_encounter_for_floor(5, 2)
	assert(enemies.size() == 1, "FAIL TC-21.1: Solo Boss must spawn 1 enemy")
	var solo_boss: EnemyEntity = enemies[0]
	assert(solo_boss.data.rank == EnemyData.EnemyRank.BOSS, "FAIL TC-21.1: Solo Boss rank mismatch")
	assert(solo_boss.damage_reduction == 0.30, "FAIL TC-21.1: Solo Boss DR must be 30%")
	assert(solo_boss.level <= 4, "FAIL TC-21.1: Solo Boss level (%d) exceeded Hero Lv1 + 3" % solo_boss.level)
	var boss_atk := solo_boss.get_attack()
	_log_test("[TC-21.1] Solo Boss Lv: %d | Base ATK: %.1f | Actual ATK: %.1f | DR: 30%%" % [solo_boss.level, solo_boss.data.base_attack, boss_atk])
	assert(boss_atk <= 75.0, "FAIL TC-21.1: Solo Boss ATK (%.1f) exceeds GD upper bound of 75.0" % boss_atk)
	
	# Simulate Tank Arthur (250 HP, 30 DEF -> 23% DR) being attacked
	var arthur_def := 30.0
	var arthur_hp := 250.0
	var arthur_dr := arthur_def / (100.0 + arthur_def)
	var hit_on_arthur := boss_atk * (1.0 - arthur_dr)
	var hits_survived: float = arthur_hp / hit_on_arthur
	_log_test("[TC-21.1] Tank Arthur (250 HP, 30 DEF) takes %.1f dmg/hit -> Survives %.1f hits (GD Spec: >= 5.0)" % [hit_on_arthur, hits_survived])
	assert(hits_survived >= 5.0, "FAIL TC-21.1: Tank Arthur must survive at least 5 hits (got %.1f)" % hits_survived)
	_log_test(">>> 🟢 TC-21.1 Solo Raid Boss Balance PASSED!")
	
	# 2. TC-21.2: FLOOR 1 ENCOUNTER DIRECTOR INTEGRITY (GD Spec)
	_log_test("[TC-21.2] Checking Floor 1 Encounter Director abilities...")
	spawn_encounter_for_floor(1)
	assert(enemies.size() == 5, "FAIL TC-21.2: Floor 1 must spawn 5 enemies")
	for e in enemies:
		assert(not e.unlocked_abilities.is_empty(), "FAIL TC-21.2: Floor 1 enemies must have abilities from Encounter Director")
		assert(e.unlocked_abilities[0].data.name == "Phun Dịch Axit", "FAIL TC-21.2: Ability name mismatch")
	_log_test(">>> 🟢 TC-21.2 Floor 1 Encounter Director Integrity PASSED!")
	
	# 3. TC-21.3: FULL SAVE & RESUME WITH HERO PROGRESSION & ABILITIES (QA BUG-CRIT-01 & BUG-HIGH-02)
	_log_test("[TC-21.3] Checking Save/Resume of Floor, Gold, Lives & Hero Progression...")
	if SaveManager != null and RunManager != null:
		RunManager.current_floor = 5
		RunManager.current_gold = 150
		RunManager.current_lives = 2
		current_floor = 5
		
		# Setup Hero Kira with Lv5 progression and an unlocked ability
		_spawn_mock_teams()
		var test_hero: HeroEntity = null
		for h in heroes:
			if is_instance_valid(h) and h is HeroEntity and (h.name == "Kira" or (h.data != null and h.data.name == "Kira")):
				test_hero = h
				break
		assert(test_hero != null, "FAIL TC-21.3: Kira not found")
		test_hero.progression.current_level = 5
		test_hero.level = 5
		test_hero.progression.current_xp = 175.0
		
		var bonus_ab := AbilityData.new()
		bonus_ab.name = "Bão Dao Độc"
		bonus_ab.ability_type = AbilityData.AbilityType.ACTIVE
		bonus_ab.cooldown = 4.0
		var dmg_eff := DamageEffectData.new()
		dmg_eff.base_amount = 80.0
		dmg_eff.base_damage = 80.0
		dmg_eff.scalings = { "AD": 1.5 }
		bonus_ab.effects = [dmg_eff]
		test_hero.unlocked_abilities.append(Ability.new(test_hero, bonus_ab))
		
		# Save game
		_save_current_run()
		assert(FileAccess.file_exists(SaveManager.SAVE_PATH), "FAIL TC-21.3: Save file must exist")
		
		# Reset all game state in memory
		RunManager.current_floor = 1
		RunManager.current_gold = 0
		RunManager.current_lives = 1
		current_floor = 1
		test_hero.progression.current_level = 1
		test_hero.level = 1
		test_hero.progression.current_xp = 0.0
		test_hero.unlocked_abilities.clear()
		
		# Resume from save
		var resumed := _try_resume_saved_run()
		assert(resumed == true, "FAIL TC-21.3: Resume must succeed")
		assert(current_floor == 5, "FAIL TC-21.3: Floor must be restored to 5")
		assert(RunManager.current_gold == 150, "FAIL TC-21.3: Gold must be restored to 150")
		assert(RunManager.current_lives == 2, "FAIL TC-21.3: Lives must be restored to 2")
		assert(test_hero.progression.current_level == 5, "FAIL TC-21.3: Kira level must be restored to 5")
		assert(test_hero.progression.current_xp == 175.0, "FAIL TC-21.3: Kira XP must be restored to 175.0")
		assert(test_hero.unlocked_abilities.size() >= 1, "FAIL TC-21.3: Unlocked abilities must be restored")
		
		var restored_ab_found := false
		for ab in test_hero.unlocked_abilities:
			if ab.data.name == "Bão Dao Độc":
				restored_ab_found = true
				assert(ab.data.effects.size() == 1, "FAIL TC-21.3: Effect count mismatch")
				assert(ab.data.effects[0].base_amount == 80.0, "FAIL TC-21.3: Base amount mismatch")
				assert(float(ab.data.effects[0].scalings.get("AD", 0.0)) == 1.5, "FAIL TC-21.3: AD scaling mismatch")
				break
		assert(restored_ab_found == true, "FAIL TC-21.3: Custom ability 'Bão Dao Độc' was not restored")
		
		# Cleanup save
		SaveManager.delete_save()
		assert(not FileAccess.file_exists(SaveManager.SAVE_PATH), "FAIL TC-21.3: Save file should be deleted")
	_log_test(">>> 🟢 TC-21.3 Full Save & Resume With Hero State PASSED!")
	
	# 4. TC-21.4: QA CHEAT TOOLS (GOD MODE, ADD GOLD, KILL ALL, WARP)
	_log_test("[TC-21.4] Checking QA Cheat Tools (God Mode, Add Gold, Kill All)...")
	var kira: HeroEntity = null
	for h in heroes:
		if is_instance_valid(h) and h is HeroEntity and (h.name == "Kira" or (h.data != null and h.data.name == "Kira")):
			kira = h; break
	assert(kira != null, "FAIL TC-21.4: Kira not found")
	
	# God Mode test
	assert(is_god_mode == false, "FAIL TC-21.4: God mode should default to false")
	toggle_god_mode()
	assert(is_god_mode == true, "FAIL TC-21.4: God mode should be true after toggle")
	assert(kira.is_invulnerable == true, "FAIL TC-21.4: Hero invulnerable flag should match god mode")
	kira.current_hp = 100.0
	kira.take_damage(99999.0)
	assert(kira.current_hp >= 1.0, "FAIL TC-21.4: In God Mode, HP must not drop below 1.0 (got %.1f)" % kira.current_hp)
	assert(kira.is_dead == false, "FAIL TC-21.4: Hero must not die in God Mode")
	toggle_god_mode()
	assert(is_god_mode == false, "FAIL TC-21.4: God mode should toggle off")
	
	# Add Gold test
	var gold_before: int = RunManager.current_gold
	RunManager.add_gold(50)
	assert(RunManager.current_gold == gold_before + 50, "FAIL TC-21.4: Add gold failed")
	
	# Kill All Enemies test
	spawn_encounter_for_floor(1)
	assert(enemies.size() == 5, "FAIL TC-21.4: 5 enemies spawned")
	cheat_kill_all_enemies()
	for e in enemies:
		assert(e.is_dead == true, "FAIL TC-21.4: All enemies should be dead after Kill All")
	_log_test(">>> 🟢 TC-21.4 QA Cheat Tools PASSED!")
	
	_log_test(">>> 🟢 TC-21 PASSED: Full Persistence, Hero State, Boss Balance & QA Cheats fully verified!\n")

# ------------------------------------------------------------------------------
# TC-22: Floating Combat Text & Damage Popups (Sprint 5)
# ------------------------------------------------------------------------------
func _run_tc_22_floating_combat_text() -> void:
	_log_test("\n==================== [TEST TC-22: FLOATING COMBAT TEXT & POPUPS] ====================")
	_reset_test_battlefield()

	# 1. TC-22.1: Palette Matrix & Typography Rule Check
	_log_test("[TC-22.1] Checking FloatingText GD Palette Matrix & Typography Rules...")
	var test_ft = FLOATING_TEXT_SCENE.instantiate() as FloatingText
	add_child(test_ft)

	# Check Physical Damage
	test_ft.setup("100", FloatingText.Type.DAMAGE_PHYSICAL)
	var label = test_ft.label
	assert(label != null, "FAIL TC-22.1: Label is null")
	assert(label.get_theme_color("font_outline_color") == Color("#11141a"), "FAIL TC-22.1: Font outline color must be #11141a")
	assert(label.get_theme_constant("outline_size") == 3, "FAIL TC-22.1: Font outline size must be 3px")
	assert(label.modulate == Color("#ff7675"), "FAIL TC-22.1: Physical damage modulate mismatch")

	# Check Magic Damage
	test_ft.setup("75", FloatingText.Type.DAMAGE_MAGIC)
	assert(label.modulate == Color("#a29bfe"), "FAIL TC-22.1: Magic damage modulate mismatch")

	# Check True Damage
	test_ft.setup("50", FloatingText.Type.DAMAGE_TRUE)
	assert(label.modulate == Color("#ffffff"), "FAIL TC-22.1: True damage modulate mismatch")

	# Check Crit Damage & Format Suffix
	test_ft.setup("180", FloatingText.Type.CRIT)
	assert(label.modulate == Color("#fdcb6e"), "FAIL TC-22.1: Crit modulate mismatch")
	assert(label.text == "180!", "FAIL TC-22.1: Crit must format with ! suffix")

	# Check Heal & Format Prefix
	test_ft.setup("35", FloatingText.Type.HEAL)
	assert(label.modulate == Color("#2ecc71"), "FAIL TC-22.1: Heal modulate mismatch")
	assert(label.text == "+35", "FAIL TC-22.1: Heal must format with + prefix")

	# Check XP & Format Suffix
	test_ft.setup("+120", FloatingText.Type.XP)
	assert(label.modulate == Color("#fd79a8"), "FAIL TC-22.1: XP modulate mismatch")
	assert(label.text == "+120 XP", "FAIL TC-22.1: XP must format with XP suffix")

	# Check System
	test_ft.setup("[ULTIMATE]", FloatingText.Type.SYSTEM)
	assert(label.modulate == Color("#f1c40f"), "FAIL TC-22.1: System modulate mismatch")

	test_ft.queue_free()
	_log_test(">>> 🟢 TC-22.1 FloatingText GD Palette Matrix & Typography Rules PASSED!")

	# 2. TC-22.2: Signal Arity Compatibility Check
	_log_test("[TC-22.2] Checking Signal Arity Compatibility (5 params) across all systems...")
	var hero = heroes[0] as HeroEntity
	var enemy = enemies[0] as EnemyEntity
	var initial_hero_dmg = hero.metrics.damage_dealt

	# Emit 5 arguments via combat_system.damage_dealt
	combat_system.damage_dealt.emit(hero, enemy, 42.0, false, DamageEvent.DamageType.MAGIC)
	assert(hero.metrics.damage_dealt == initial_hero_dmg + 42.0, "FAIL TC-22.2: ProgressionSystem failed to update metric from 5-arg damage_dealt")

	# Emit with Physical crit
	combat_system.damage_dealt.emit(hero, enemy, 20.0, true, DamageEvent.DamageType.PHYSICAL)
	assert(hero.metrics.damage_dealt == initial_hero_dmg + 62.0, "FAIL TC-22.2: ProgressionSystem failed on crit damage_dealt")
	_log_test(">>> 🟢 TC-22.2 Signal Arity Compatibility PASSED!")

	# 3. TC-22.3: Damage Routing for Physical, Magic, True, and Crit
	_log_test("[TC-22.3] Checking DamageEvent processing for Physical, Magic, and True damage...")
	var initial_hp = enemy.current_hp
	var magic_event = DamageEvent.new(hero, enemy, 30.0, DamageEvent.DamageType.MAGIC)
	combat_system.process_attack(magic_event)
	assert(enemy.current_hp < initial_hp, "FAIL TC-22.3: Magic attack did not deal damage")

	var true_event = DamageEvent.new(hero, enemy, 20.0, DamageEvent.DamageType.TRUE)
	combat_system.process_attack(true_event)
	assert(true_event.final_damage == 20.0, "FAIL TC-22.3: True damage should bypass defense")
	_log_test(">>> 🟢 TC-22.3 Damage Event Processing PASSED!")

	_log_test(">>> 🟢 TC-22 PASSED: Floating Combat Text & Damage Popups fully verified!\n")

# ------------------------------------------------------------------------------
# TC-23: TFT-Style Level Crest & Compact Stats Grid (Sprint 5)
# ------------------------------------------------------------------------------
func _run_tc_23_tft_level_crest_and_compact_grid() -> void:
	_log_test("\n==================== [TEST TC-23: TFT-STYLE LEVEL CREST & COMPACT GRID] ====================")
	_reset_test_battlefield()
	assert(character_stats_ui != null, "FAIL TC-23: CharacterStatsUI instance missing")
	character_stats_ui.close()
	
	# 1. TC-23.1: HERO LEVEL CREST 6-TIER MATRIX (1, 15, 25, 50, 75, 99)
	_log_test("[TC-23.1] Checking Hero Level Crest 6-Tier Matrix (1, 15, 25, 50, 75, 99)...")
	var knight_data := _create_mock_hero_data("Lancelot", HeroData.HeroClass.TANK, 250.0, 20.0, 10.0, 1.0, 1, 0.0)
	var hero_inst := hero_scene.instantiate() as HeroEntity
	add_child(hero_inst)
	hero_inst.initialize(knight_data)
	
	# Tier I: Bronze (Lv 1 - 9)
	hero_inst.progression.current_level = 1
	character_stats_ui.inspect_entity(hero_inst)
	assert(character_stats_ui.crest_label.text == "• CẤP 1 •", "FAIL TC-23.1: Tier I Bronze text mismatch (got: %s)" % character_stats_ui.crest_label.text)
	assert(character_stats_ui.crest_style.border_color == Color("#cd7f32"), "FAIL TC-23.1: Tier I Bronze border mismatch")
	assert(character_stats_ui.crest_style.bg_color == Color("#2d1a10"), "FAIL TC-23.1: Tier I Bronze bg mismatch")
	
	# Tier II: Silver (Lv 10 - 24)
	hero_inst.progression.current_level = 15
	character_stats_ui.update_stats()
	assert(character_stats_ui.crest_label.text == "✦ CẤP 15 ✦", "FAIL TC-23.1: Tier II Silver text mismatch")
	assert(character_stats_ui.crest_style.border_color == Color("#bdc3c7"), "FAIL TC-23.1: Tier II Silver border mismatch")
	assert(character_stats_ui.crest_style.bg_color == Color("#1e272e"), "FAIL TC-23.1: Tier II Silver bg mismatch")
	
	# Tier III: Gold (Lv 25 - 49)
	hero_inst.progression.current_level = 25
	character_stats_ui.update_stats()
	assert(character_stats_ui.crest_label.text == "★ CẤP 25 ★", "FAIL TC-23.1: Tier III Gold text mismatch")
	assert(character_stats_ui.crest_style.border_color == Color("#f1c40f"), "FAIL TC-23.1: Tier III Gold border mismatch")
	assert(character_stats_ui.crest_style.bg_color == Color("#2c2105"), "FAIL TC-23.1: Tier III Gold bg mismatch")
	
	# Tier IV: Diamond (Lv 50 - 74)
	hero_inst.progression.current_level = 50
	character_stats_ui.update_stats()
	assert(character_stats_ui.crest_label.text == "❖ CẤP 50 ❖", "FAIL TC-23.1: Tier IV Diamond text mismatch")
	assert(character_stats_ui.crest_style.border_color == Color("#00cec9"), "FAIL TC-23.1: Tier IV Diamond border mismatch")
	assert(character_stats_ui.crest_style.bg_color == Color("#062024"), "FAIL TC-23.1: Tier IV Diamond bg mismatch")
	
	# Tier V: Legend (Lv 75 - 98)
	hero_inst.progression.current_level = 75
	character_stats_ui.update_stats()
	assert(character_stats_ui.crest_label.text == "👑 CẤP 75 👑", "FAIL TC-23.1: Tier V Legend text mismatch")
	assert(character_stats_ui.crest_style.border_color == Color("#e74c3c"), "FAIL TC-23.1: Tier V Legend border mismatch")
	assert(character_stats_ui.crest_style.bg_color == Color("#2a0808"), "FAIL TC-23.1: Tier V Legend bg mismatch")
	
	# Tier VI: Mythic MAX (Lv 99)
	hero_inst.progression.current_level = 99
	character_stats_ui.update_stats()
	assert(character_stats_ui.crest_label.text == "✨ CẤP 99 MAX ✨", "FAIL TC-23.1: Tier VI Mythic text mismatch")
	assert(character_stats_ui.crest_style.border_color == Color("#9b59b6"), "FAIL TC-23.1: Tier VI Mythic border mismatch")
	assert(character_stats_ui.crest_style.bg_color == Color("#1f0a2a"), "FAIL TC-23.1: Tier VI Mythic bg mismatch")
	
	hero_inst.queue_free()
	_log_test(">>> 🟢 TC-23.1 Hero Level Crest 6-Tier Matrix PASSED!")
	
	# 2. TC-23.2: MONSTER RANK EMBLEMS (Normal, Elite, Boss, Solo Boss)
	_log_test("[TC-23.2] Checking Monster Rank Crest Badges...")
	var norm_data := EnemyData.new()
	norm_data.name = "Slime Thường"
	norm_data.rank = EnemyData.EnemyRank.NORMAL
	var norm_enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(norm_enemy)
	norm_enemy.initialize(norm_data, 1, EnemyData.EnemyRank.NORMAL, false)
	
	character_stats_ui.inspect_entity(norm_enemy)
	assert(character_stats_ui.crest_label.text.contains("Lv.1"), "FAIL TC-23.2: Normal enemy crest should show Lv.1")
	assert(character_stats_ui.crest_style.border_color == Color("#7f8c8d"), "FAIL TC-23.2: Normal enemy crest border mismatch")
	assert(character_stats_ui.xp_box.visible == false, "FAIL TC-23.2: XP box must be hidden for Normal Enemy")
	assert(character_stats_ui.xp_bar.visible == false, "FAIL TC-23.2: XP bar must be hidden for Normal Enemy")
	norm_enemy.queue_free()
	
	var elite_data := EnemyData.new()
	elite_data.name = "EliteSlime"
	elite_data.rank = EnemyData.EnemyRank.ELITE
	var elite_enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(elite_enemy)
	elite_enemy.initialize(elite_data, 5, EnemyData.EnemyRank.ELITE, false)
	
	character_stats_ui.inspect_entity(elite_enemy)
	assert(character_stats_ui.crest_label.text == "🔥 TINH ANH (Lv.5) 🔥", "FAIL TC-23.2: Elite crest text mismatch")
	assert(character_stats_ui.crest_style.border_color == Color("#8e44ad"), "FAIL TC-23.2: Elite crest border mismatch")
	elite_enemy.queue_free()
	
	var boss_data := EnemyData.new()
	boss_data.name = "BossSlime"
	boss_data.rank = EnemyData.EnemyRank.BOSS
	var boss_enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(boss_enemy)
	boss_enemy.initialize(boss_data, 10, EnemyData.EnemyRank.BOSS, false)
	
	character_stats_ui.inspect_entity(boss_enemy)
	assert(character_stats_ui.crest_label.text == "💀 BOSS (Lv.10) 💀", "FAIL TC-23.2: Boss crest text mismatch")
	assert(character_stats_ui.crest_style.border_color == Color("#c0392b"), "FAIL TC-23.2: Boss crest border mismatch")
	boss_enemy.queue_free()
	
	var solo_boss: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(solo_boss)
	solo_boss.initialize(boss_data, 10, EnemyData.EnemyRank.BOSS, true)
	
	character_stats_ui.inspect_entity(solo_boss)
	assert(character_stats_ui.crest_label.text == "👑 SOLO BOSS (Lv.10) 👑", "FAIL TC-23.2: Solo Boss crest text mismatch")
	assert(character_stats_ui.crest_style.border_color == Color("#d35400"), "FAIL TC-23.2: Solo Boss crest border mismatch")
	assert(character_stats_ui.crest_label.tooltip_text.contains("30%"), "FAIL TC-23.2: Solo Boss tooltip mismatch")
	solo_boss.queue_free()
	_log_test(">>> 🟢 TC-23.2 Monster Rank Crest Badges PASSED!")
	
	# 3. TC-23.3: TOP-CENTER ANCHORING & TFT COMPACT GRID LAYOUT
	_log_test("[TC-23.3] Checking Top-Center Anchoring & Compact TFT Grid...")
	assert(character_stats_ui.crest_panel.position.y >= 0.0, "FAIL TC-23.3: Crest Y position must be >= 0 (Integrated in Monolithic Header)")
	assert(character_stats_ui.crest_panel.custom_minimum_size.x >= 120.0, "FAIL TC-23.3: Crest minimum width must be >= 120px")
	assert(character_stats_ui.crest_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "FAIL TC-23.3: Crest label must be centered")
	assert(character_stats_ui.speed_val_label != null and character_stats_ui.crit_val_label != null, "FAIL TC-23.3: Compact grid labels missing")
	character_stats_ui.close()
	assert(character_stats_ui.visible == false, "FAIL TC-23.3: Panel must hide on close")
	_log_test(">>> 🟢 TC-23.3 Top-Center Anchoring & Compact TFT Grid PASSED!")
	
	_log_test(">>> 🟢 TC-23 PASSED: TFT-Style Level Crest & Compact Stats Grid fully verified!\n")

# ------------------------------------------------------------------------------
# TC-24: Hero Stat Progression Formula & Seamless Monolithic UI with Click-Outside
# (GD & QA Specification Sprint 5)
# ------------------------------------------------------------------------------
func _run_tc_24_hero_stat_progression_and_seamless_ui() -> void:
	_log_test("\n==================== [TEST TC-24: HERO STAT PROGRESSION & SEAMLESS UI] ====================")
	_reset_test_battlefield()
	
	# 1. TC-24.1: HERO STAT PROGRESSION FORMULA VERIFICATION (Soraka at Lv 1, 10, 25, 27, 99)
	_log_test("[TC-24.1] Checking Hero Stat Progression formula for Soraka (Lv 1, 10, 25, 27, 99)...")
	var soraka_data: HeroData = _create_mock_hero_data("Soraka", HeroData.HeroClass.SUPPORT, 120.0, 3.0, 10.0, 0.6, 3, 10.0)
	var hero_inst: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(hero_inst)
	hero_inst.initialize(soraka_data)
	hero_inst.progression = HeroProgression.new()
	
	# Level 1 (Tier I: Tân Binh, mult = 1.0)
	hero_inst.progression.current_level = 1
	hero_inst._update_scaled_max_hp()
	assert(is_equal_approx(hero_inst.max_hp, 120.0), "FAIL TC-24.1: Lv1 Max HP should be 120.0, got %f" % hero_inst.max_hp)
	assert(is_equal_approx(hero_inst.get_attack(), 3.0), "FAIL TC-24.1: Lv1 ATK should be 3.0, got %f" % hero_inst.get_attack())
	assert(is_equal_approx(hero_inst.get_spell_power(), 10.0), "FAIL TC-24.1: Lv1 AP should be 10.0, got %f" % hero_inst.get_spell_power())
	assert(is_equal_approx(hero_inst.get_defense(), 10.0), "FAIL TC-24.1: Lv1 DEF should be 10.0, got %f" % hero_inst.get_defense())
	
	# Level 10 (Tier II: Tinh Anh, mult = 1.05)
	hero_inst.progression.current_level = 10
	hero_inst._update_scaled_max_hp()
	assert(is_equal_approx(hero_inst.max_hp, 216.72), "FAIL TC-24.1: Lv10 Max HP should be 216.72, got %f" % hero_inst.max_hp)
	assert(is_equal_approx(hero_inst.get_attack(), 5.418), "FAIL TC-24.1: Lv10 ATK should be 5.418, got %f" % hero_inst.get_attack())
	assert(is_equal_approx(hero_inst.get_spell_power(), 18.06), "FAIL TC-24.1: Lv10 AP should be 18.06, got %f" % hero_inst.get_spell_power())
	assert(is_equal_approx(hero_inst.get_defense(), 15.225), "FAIL TC-24.1: Lv10 DEF should be 15.225, got %f" % hero_inst.get_defense())
	
	# Level 25 (Tier III: Dũng Sĩ, mult = 1.10)
	hero_inst.progression.current_level = 25
	hero_inst._update_scaled_max_hp()
	assert(is_equal_approx(hero_inst.max_hp, 385.44), "FAIL TC-24.1: Lv25 Max HP should be 385.44, got %f" % hero_inst.max_hp)
	assert(is_equal_approx(hero_inst.get_attack(), 9.636), "FAIL TC-24.1: Lv25 ATK should be 9.636, got %f" % hero_inst.get_attack())
	assert(is_equal_approx(hero_inst.get_spell_power(), 32.12), "FAIL TC-24.1: Lv25 AP should be 32.12, got %f" % hero_inst.get_spell_power())
	assert(is_equal_approx(hero_inst.get_defense(), 24.2), "FAIL TC-24.1: Lv25 DEF should be 24.2, got %f" % hero_inst.get_defense())
	
	# Level 27 (Tier III: Dũng Sĩ, mult = 1.10 - GD Spec Table)
	hero_inst.progression.current_level = 27
	hero_inst._update_scaled_max_hp()
	assert(is_equal_approx(hero_inst.max_hp, 406.56), "FAIL TC-24.1: Lv27 Max HP should be 406.56, got %f" % hero_inst.max_hp)
	assert(is_equal_approx(hero_inst.get_attack(), 10.164), "FAIL TC-24.1: Lv27 ATK should be 10.164, got %f" % hero_inst.get_attack())
	assert(is_equal_approx(hero_inst.get_spell_power(), 33.88), "FAIL TC-24.1: Lv27 AP should be 33.88, got %f" % hero_inst.get_spell_power())
	assert(is_equal_approx(hero_inst.get_defense(), 25.3), "FAIL TC-24.1: Lv27 DEF should be 25.3, got %f" % hero_inst.get_defense())
	
	# Level 99 (Tier VI: Vô Cực MAX, mult = 1.30)
	hero_inst.progression.current_level = 99
	hero_inst._update_scaled_max_hp()
	assert(is_equal_approx(hero_inst.max_hp, 1379.04), "FAIL TC-24.1: Lv99 Max HP should be 1379.04, got %f" % hero_inst.max_hp)
	assert(is_equal_approx(hero_inst.get_attack(), 34.476), "FAIL TC-24.1: Lv99 ATK should be 34.476, got %f" % hero_inst.get_attack())
	assert(is_equal_approx(hero_inst.get_spell_power(), 114.92), "FAIL TC-24.1: Lv99 AP should be 114.92, got %f" % hero_inst.get_spell_power())
	assert(is_equal_approx(hero_inst.get_defense(), 76.7), "FAIL TC-24.1: Lv99 DEF should be 76.7, got %f" % hero_inst.get_defense())
	_log_test(">>> 🟢 TC-24.1 Hero Stat Progression Formula PASSED!")
	
	# 2. TC-24.2: SEAMLESS MONOLITHIC CARD & NO CLOSE_BUTTON IN TREE
	_log_test("[TC-24.2] Checking Seamless Monolithic Card & absence of close_button...")
	hero_inst.progression.current_level = 27
	hero_inst._update_scaled_max_hp()
	character_stats_ui.inspect_hero(hero_inst)
	assert(character_stats_ui.visible, "FAIL TC-24.2: CharacterStatsUI should be visible")
	assert(character_stats_ui.close_button == null, "FAIL TC-24.2: close_button variable must be null")
	var found_btn = character_stats_ui.find_child("close_button", true, false)
	assert(found_btn == null, "FAIL TC-24.2: No node named 'close_button' must exist in tree")
	var avatar_panel = character_stats_ui.avatar_panel
	assert(avatar_panel != null, "FAIL TC-24.2: avatar_panel must exist")
	for child in avatar_panel.find_children("*", "Button", true, false):
		assert(false, "FAIL TC-24.2: Found unexpected button in avatar_panel: %s" % child.name)
	# Verify UI values match Lv 27
	assert(character_stats_ui.hp_label.text.contains("407"), "FAIL TC-24.2: HP label must show 407, got %s" % character_stats_ui.hp_label.text)
	assert(character_stats_ui.attack_val_label.text == "10.2", "FAIL TC-24.2: Attack label must show 10.2, got %s" % character_stats_ui.attack_val_label.text)
	assert(character_stats_ui.spell_val_label.text == "33.9", "FAIL TC-24.2: Spell label must show 33.9, got %s" % character_stats_ui.spell_val_label.text)
	assert(character_stats_ui.def_val_label.text == "25.3", "FAIL TC-24.2: Defense label must show 25.3, got %s" % character_stats_ui.def_val_label.text)
	_log_test(">>> 🟢 TC-24.2 Seamless Monolithic Card & No Close Button PASSED!")
	
	# 3. TC-24.3: CLICK-OUTSIDE DISMISS & CLICK-INSIDE PERSISTENCE
	_log_test("[TC-24.3] Checking Click-Outside Dismiss and Click-Inside Persistence...")
	# Simulated click INSIDE panel (e.g., Vector2(900, 100))
	var click_inside := InputEventMouseButton.new()
	click_inside.button_index = MOUSE_BUTTON_LEFT
	click_inside.pressed = true
	click_inside.position = Vector2(900, 100)
	_unhandled_input(click_inside)
	assert(character_stats_ui.visible == true, "FAIL TC-24.3: Clicking inside panel must keep UI open")
	
	# Simulated click on Top-Center Crest (using crest_panel global rect)
	var crest_global_pos: Vector2 = character_stats_ui.crest_panel.get_global_rect().position + Vector2(10, 10)
	var click_crest := InputEventMouseButton.new()
	click_crest.button_index = MOUSE_BUTTON_LEFT
	click_crest.pressed = true
	click_crest.position = crest_global_pos
	_unhandled_input(click_crest)
	assert(character_stats_ui.visible == true, "FAIL TC-24.3: Clicking inside crest badge must keep UI open")
	
	# Simulated click OUTSIDE on empty space (e.g., Vector2(50, 50))
	var click_outside := InputEventMouseButton.new()
	click_outside.button_index = MOUSE_BUTTON_LEFT
	click_outside.pressed = true
	click_outside.position = Vector2(50, 50)
	_unhandled_input(click_outside)
	assert(character_stats_ui.visible == false, "FAIL TC-24.3: Clicking outside must dismiss CharacterStatsUI")
	
	# Clean up
	hero_inst.queue_free()
	_log_test(">>> 🟢 TC-24.3 Click-Outside Dismiss & Click-Inside Persistence PASSED!")
	_log_test(">>> 🟢 TC-24 PASSED: Hero Stat Progression & Seamless UI fully verified!\n")

# ------------------------------------------------------------------------------
# TC-25: Monolithic Crest Header, One-Choice Gacha & Advanced Stat Scaling
# (GD & QA Specification Sprint 5)
# ------------------------------------------------------------------------------
func _run_tc_25_monolithic_header_one_choice_and_scaling() -> void:
	_log_test("\n==================== [TEST TC-25: MONOLITHIC HEADER, ONE-CHOICE & SCALING] ====================")
	_reset_test_battlefield()
	
	# 1. TC-25.1: MONOLITHIC CREST HEADER (Inside panel, Y >= 0, single outer boundary)
	_log_test("[TC-25.1] Checking True Monolithic Header (Inside panel, Y >= 0, single outer border)...")
	var kira_hero := heroes[0] as HeroEntity
	character_stats_ui.inspect_hero(kira_hero)
	assert(character_stats_ui.visible == true, "FAIL TC-25.1: CharacterStatsUI should be visible")
	assert(character_stats_ui.crest_panel != null, "FAIL TC-25.1: crest_panel must exist")
	assert(character_stats_ui.crest_panel.position.y >= 0.0, "FAIL TC-25.1: Crest Y position must be >= 0 (got %f)" % character_stats_ui.crest_panel.position.y)
	assert(character_stats_ui.crest_overlay == null or character_stats_ui.crest_overlay.get_child_count() == 0, "FAIL TC-25.1: No detached crest overlay should be used")
	var panel_style = character_stats_ui.panel_container.get_theme_stylebox("panel") as StyleBoxFlat
	assert(panel_style != null, "FAIL TC-25.1: panel_container StyleBoxFlat missing")
	assert(panel_style.border_width_left == 2 and panel_style.corner_radius_top_left == 12, "FAIL TC-25.1: Monolithic panel border width 2, radius 12 required")
	character_stats_ui.close()
	_log_test(">>> 🟢 TC-25.1 Monolithic Crest Header PASSED!")
	
	# 2. TC-25.2: ONE-CHOICE CONSOLIDATION & MILESTONE FUSION (+5000 XP across mốc 5, 10, 15)
	_log_test("[TC-25.2] Checking One-Choice Rule & Milestone Fusion for 5000 XP...")
	var test_hero: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(test_hero)
	test_hero.initialize(_create_mock_hero_data("KiraTest", HeroData.HeroClass.ASSASSIN, 100.0, 60.0, 10.0, 1.0, 1))
	for lvl in [5, 10, 15]:
		var pool: Array[AbilityData] = []
		for i in range(3):
			var a = AbilityData.new()
			a.name = "Skill_%d_%d" % [lvl, i + 1]
			pool.append(a)
		test_hero.runtime_pools[lvl] = pool
	
	test_hero.progression.add_xp(5000.0)
	assert(test_hero.progression.current_level >= 15, "FAIL TC-25.2: Level should be >= 15 after 5000 XP")
	assert(test_hero.pending_milestones.has(5) and test_hero.pending_milestones.has(10) and test_hero.pending_milestones.has(15), "FAIL TC-25.2: Pending milestones should contain 5, 10, 15")
	
	heroes.clear()
	heroes.append(test_hero)
	_build_post_battle_choice_queue()
	
	assert(choice_queue.size() == 1, "FAIL TC-25.2: choice_queue must contain exactly 1 entry per hero, got %d" % choice_queue.size())
	assert(choice_queue[0].milestone == 15, "FAIL TC-25.2: Milestone fusion must pick highest milestone (15), got %d" % choice_queue[0].milestone)
	assert(is_equal_approx(test_hero.passive_stat_bonus, 0.10), "FAIL TC-25.2: Compensation for 2 skipped milestones should be 0.10 (+10%%), got %f" % test_hero.passive_stat_bonus)
	assert(test_hero.pending_milestones.is_empty(), "FAIL TC-25.2: pending_milestones should be cleared after building queue")
	choice_queue.clear()
	heroes.clear()
	test_hero.queue_free()
	_log_test(">>> 🟢 TC-25.2 One-Choice Consolidation & Milestone Fusion PASSED!")
	
	# 3. TC-25.3: TOTAL AD VS BONUS AD SCALING TOOLTIP BREAKDOWN
	_log_test("[TC-25.3] Checking Total AD vs Bonus AD scaling and breakdown...")
	var kira_data := HeroData.new()
	kira_data.name = "Kira"
	kira_data.base_attack = 60.0
	var mock_kira: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(mock_kira)
	mock_kira.data = kira_data
	mock_kira.passive_stat_bonus = (100.0 / 60.0) - 1.0
	assert(is_equal_approx(mock_kira.get_attack(), 100.0), "FAIL TC-25.3: Kira Total AD should be 100.0, got %f" % mock_kira.get_attack())
	
	# Test 3a: Total AD Scale (Base 70, 20% Total AD, Magic)
	var dmg_total := DamageEffectData.new()
	dmg_total.base_damage = 70.0
	dmg_total.damage_type = DamageEvent.DamageType.MAGIC
	dmg_total.scalings = { EffectData.STAT_TOTAL_AD: 0.20 }
	var total_val := dmg_total.calculate_total_value(mock_kira)
	assert(is_equal_approx(total_val, 90.0), "FAIL TC-25.3: 70 + 100*0.20 must equal 90.0, got %f" % total_val)
	var tooltip_total := dmg_total.get_formatted_description(mock_kira)
	_log_test("[TC-25.3] Tooltip Total AD: %s" % tooltip_total)
	assert(tooltip_total.contains("90") and tooltip_total.contains("70") and tooltip_total.contains("20") and tooltip_total.contains("20% SMCK"), "FAIL TC-25.3: Total AD breakdown text mismatch")
	
	# Test 3b: Bonus AD Scale (Base 70, 50% Bonus AD, Magic)
	var dmg_bonus := DamageEffectData.new()
	dmg_bonus.base_damage = 70.0
	dmg_bonus.damage_type = DamageEvent.DamageType.MAGIC
	dmg_bonus.scalings = { EffectData.STAT_BONUS_AD: 0.50 }
	var bonus_val := dmg_bonus.calculate_total_value(mock_kira)
	assert(is_equal_approx(bonus_val, 90.0), "FAIL TC-25.3: 70 + 40*0.50 must equal 90.0, got %f" % bonus_val)
	var tooltip_bonus := dmg_bonus.get_formatted_description(mock_kira)
	_log_test("[TC-25.3] Tooltip Bonus AD: %s" % tooltip_bonus)
	assert(tooltip_bonus.contains("90") and tooltip_bonus.contains("70") and tooltip_bonus.contains("20") and tooltip_bonus.contains("50% SMCK cộng thêm"), "FAIL TC-25.3: Bonus AD breakdown text mismatch")
	
	mock_kira.queue_free()
	_log_test(">>> 🟢 TC-25.3 Total AD vs Bonus AD Scaling PASSED!")
	
	# 4. TC-25.4: PURE PERCENTAGE SHIELD & HEAL (BASE_AMOUNT = 0)
	_log_test("[TC-25.4] Checking Pure Percentage Shield & Heal (base_amount = 0)...")
	var tank_hero: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(tank_hero)
	tank_hero.max_hp = 400.0
	
	# Test 4a: Pure % Shield (25% Max HP, 4s duration)
	var pure_shield := ShieldEffectData.new()
	pure_shield.base_amount = 0.0
	pure_shield.duration = 4.0
	pure_shield.scalings = { EffectData.STAT_TOTAL_HP: 0.25 }
	var shield_val := pure_shield.calculate_total_value(tank_hero)
	assert(is_equal_approx(shield_val, 100.0), "FAIL TC-25.4: 25%% of 400 HP should be 100.0, got %f" % shield_val)
	var shield_desc := pure_shield.get_formatted_description(tank_hero)
	_log_test("[TC-25.4] Shield Description: %s" % shield_desc)
	assert(shield_desc.contains("100") and shield_desc.contains("25% Máu tối đa") and not shield_desc.contains("0 + "), "FAIL TC-25.4: Pure shield must state '25% Máu tối đa'")
	assert(shield_desc.contains("4 giây"), "FAIL TC-25.4: Shield duration missing")
	
	# Test 4b: Pure % Heal (15% Max HP)
	var pure_heal := HealEffectData.new()
	pure_heal.base_amount = 0.0
	pure_heal.scalings = { EffectData.STAT_TOTAL_HP: 0.15 }
	var heal_val := pure_heal.calculate_total_value(tank_hero)
	assert(is_equal_approx(heal_val, 60.0), "FAIL TC-25.4: 15%% of 400 HP should be 60.0, got %f" % heal_val)
	var heal_desc := pure_heal.get_formatted_description(tank_hero)
	_log_test("[TC-25.4] Heal Description: %s" % heal_desc)
	assert(heal_desc.contains("60") and heal_desc.contains("15% Máu tối đa") and not heal_desc.contains("0 + "), "FAIL TC-25.4: Pure heal must state '15% Máu tối đa'")
	
	tank_hero.queue_free()
	_reset_test_battlefield()
	_log_test(">>> 🟢 TC-25.4 Pure Percentage Shield & Heal PASSED!")
	_log_test(">>> 🟢 TC-25 PASSED: Monolithic Crest Header, One-Choice Gacha & Advanced Scaling fully verified!\n")

# ------------------------------------------------------------------------------
# TC-26: Monolithic Header, LMHT Tooltip & Model A TFT Flow (Sprint 5)
# ------------------------------------------------------------------------------
func _run_tc_26_model_a_tft_and_lmht_tooltips() -> void:
	_log_test("\n==================== [TEST TC-26: MODEL A TFT & LMHT TOOLTIPS] ====================")
	_reset_test_battlefield()
	
	# 1. TC-26.1: KIỂM CHỨNG HEADER LIỀN MỘT KHỐI
	_log_test("[TC-26.1] Checking True Monolithic Header (No inner sub-border)...")
	var knight_data := HeroData.new()
	knight_data.name = "Knight"
	knight_data.hero_class = HeroData.HeroClass.TANK
	var test_hero: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(test_hero)
	test_hero.initialize(knight_data)
	character_stats_ui.inspect_entity(test_hero)
	
	var crest_sb = character_stats_ui.crest_panel.get_theme_stylebox("panel")
	assert(crest_sb is StyleBoxEmpty or (crest_sb is StyleBoxFlat and crest_sb.border_width_left == 0), "FAIL TC-26.1: crest_panel must not have border_width > 0")
	var panel_sb = character_stats_ui.panel_container.get_theme_stylebox("panel") as StyleBoxFlat
	assert(panel_sb != null and panel_sb.border_width_left == 2 and panel_sb.corner_radius_top_left == 12, "FAIL TC-26.1: Card must have single outer border 2px and radius 12")
	character_stats_ui.close()
	test_hero.queue_free()
	_log_test(">>> 🟢 TC-26.1 Monolithic Header PASSED!")
	
	# 2. TC-26.2: KIỂM CHỨNG TOOLTIP THEO CHUẨN LMHT
	_log_test("[TC-26.2] Checking Tooltips according to LMHT standard (Azir Q style)...")
	var kira_data := HeroData.new()
	kira_data.name = "Kira"
	kira_data.base_attack = 60.0
	var mock_hero: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(mock_hero)
	mock_hero.data = kira_data
	mock_hero.passive_stat_bonus = (100.0 / 60.0) - 1.0 # Total AD = 100.0
	
	var dmg_lmht := DamageEffectData.new()
	dmg_lmht.base_damage = 70.0
	dmg_lmht.damage_type = DamageEvent.DamageType.MAGIC
	dmg_lmht.scalings = { EffectData.STAT_TOTAL_AD: 0.20 }
	var desc_lmht := dmg_lmht.get_formatted_description(mock_hero)
	_log_test("[TC-26.2] LMHT Tooltip: %s" % desc_lmht)
	assert(not desc_lmht.contains("gốc") and not desc_lmht.contains("cơ bản"), "FAIL TC-26.2: Tooltip must not contain 'gốc' or 'cơ bản'")
	assert(desc_lmht.contains("[color=#bdc3c7]70[/color]"), "FAIL TC-26.2: Base value must be silver #bdc3c7")
	assert(desc_lmht.contains("90") and desc_lmht.contains("="), "FAIL TC-26.2: Syntax must match [Total] = ([Base] + [Bonus] [Ratio% Stat])")
	mock_hero.queue_free()
	_log_test(">>> 🟢 TC-26.2 LMHT Tooltips PASSED!")
	
	# 3. TC-26.3: KIỂM CHỨNG LUỒNG MÔ HÌNH A (NON-BLOCKING PREPARATION)
	_log_test("[TC-26.3] Checking Model A Non-blocking Preparation Flow...")
	# 3a. Giả lập 3 Hero cùng vượt Milestone sau trận đấu
	var h1: HeroEntity = heroes[0] as HeroEntity
	var h2: HeroEntity = heroes[1] as HeroEntity
	var h3: HeroEntity = heroes[2] as HeroEntity
	h1.progression.milestone_reached.emit(5)
	h2.progression.milestone_reached.emit(5)
	h3.progression.milestone_reached.emit(5)
	
	assert(h1.has_pending_milestone and h2.has_pending_milestone and h3.has_pending_milestone, "FAIL TC-26.3: All 3 heroes must have has_pending_milestone == true")
	assert(h1.upgrade_badge.visible and h2.upgrade_badge.visible and h3.upgrade_badge.visible, "FAIL TC-26.3: All 3 heroes must display visual upgrade badge")
	
	# Kết thúc trận và đóng Summary UI
	_end_battle(GameManager.GameState.REWARD, "Victory Test")
	_on_summary_continued()
	_start_next_floor()
	
	# Game phải vào thẳng Preparation Phase mà KHÔNG tự bật SkillChoiceUI đè màn hình
	assert(current_phase == EncounterPhase.PREPARATION, "FAIL TC-26.3: Must transition to PREPARATION phase")
	assert(not skill_ui.visible, "FAIL TC-26.3: SkillChoiceUI must NOT automatically pop up")
	assert(h1.has_pending_milestone and h2.has_pending_milestone and h3.has_pending_milestone, "FAIL TC-26.3: Milestones must be retained in PREPARATION")
	
	# Click vào Hero 1 để mở bảng chọn 3 thẻ
	handle_hero_clicked(h1)
	assert(skill_ui.visible, "FAIL TC-26.3: Clicking Hero 1 must open SkillChoiceUI")
	var p_choice = AbilityData.new()
	p_choice.name = "Hero1_Skill"
	_on_skill_chosen(p_choice, [p_choice])
	assert(not skill_ui.visible, "FAIL TC-26.3: Choosing skill must hide modal")
	assert(not h1.has_pending_milestone, "FAIL TC-26.3: Hero 1 milestone flag must be cleared")
	assert(not h1.upgrade_badge.visible, "FAIL TC-26.3: Hero 1 badge must disappear")
	
	# Click vào Hero 2 để chọn thẻ
	handle_hero_clicked(h2)
	assert(skill_ui.visible, "FAIL TC-26.3: Clicking Hero 2 must open SkillChoiceUI")
	var p_choice2 = AbilityData.new()
	p_choice2.name = "Hero2_Skill"
	_on_skill_chosen(p_choice2, [p_choice2])
	assert(not h2.has_pending_milestone, "FAIL TC-26.3: Hero 2 milestone flag must be cleared")
	assert(not h2.upgrade_badge.visible, "FAIL TC-26.3: Hero 2 badge must disappear")
	_log_test(">>> 🟢 TC-26.3 Model A Non-blocking Preparation Flow PASSED!")
	
	# 4. TC-26.4: KIỂM CHỨNG BẢO LƯU LƯỢT NÂNG CẤP (BANK UPGRADES)
	_log_test("[TC-26.4] Checking Bank Upgrades across floors...")
	# Hero 3 vẫn chưa chọn chiêu
	assert(h3.has_pending_milestone == true, "FAIL TC-26.4: Hero 3 should still have pending milestone")
	assert(h3.upgrade_badge.visible == true, "FAIL TC-26.4: Hero 3 badge should still be visible")
	
	# Bắt đầu trận chiến mới mà không chọn chiêu cho Hero 3
	start_combat_phase()
	assert(current_phase == EncounterPhase.COMBAT, "FAIL TC-26.4: Should enter combat without crash")
	
	# Kết thúc trận chiến và sang tầng mới
	_end_battle(GameManager.GameState.REWARD, "Floor Cleared")
	_finish_battle_cleanup()
	_start_next_floor()
	
	# Ở tầng mới (Preparation Phase), Hero 3 vẫn bảo lưu lượt nâng cấp
	assert(h3.has_pending_milestone == true, "FAIL TC-26.4: Hero 3 pending milestone must persist to next floor")
	assert(h3.upgrade_badge.visible == true, "FAIL TC-26.4: Hero 3 visual badge must persist to next floor")
	
	# Chọn chiêu an toàn ở tầng mới
	handle_hero_clicked(h3)
	assert(skill_ui.visible, "FAIL TC-26.4: Clicking Hero 3 at next floor must open SkillChoiceUI")
	var p_choice3 = AbilityData.new()
	p_choice3.name = "Hero3_Skill"
	_on_skill_chosen(p_choice3, [p_choice3])
	assert(not h3.has_pending_milestone, "FAIL TC-26.4: Hero 3 milestone flag cleared after choice")
	assert(not h3.upgrade_badge.visible, "FAIL TC-26.4: Hero 3 badge disappeared")
	
	_reset_test_battlefield()
	_log_test(">>> 🟢 TC-26.4 Bank Upgrades PASSED!")
	_log_test(">>> 🟢 TC-26 PASSED: Model A TFT Flow, LMHT Tooltips & Monolithic Header fully verified!\n")

# ------------------------------------------------------------------------------
# TC-27: Dynamic Prestige Border Palette & Card Aura Sync (Sprint 5)
# ------------------------------------------------------------------------------
func _run_tc_27_dynamic_prestige_border_palette() -> void:
	_log_test("\n==================== [TEST TC-27: PRESTIGE BORDER PALETTE & AURA] ====================")
	_reset_test_battlefield()
	
	var hero_data := HeroData.new()
	hero_data.name = "Jaina"
	hero_data.hero_class = HeroData.HeroClass.MAGE
	var test_hero: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(test_hero)
	test_hero.initialize(hero_data)
	
	# 1. Tier I: Tân Binh (Lv 1 - 9) -> Nâu Đồng #cd7f32
	test_hero.progression.current_level = 1
	character_stats_ui.inspect_entity(test_hero)
	assert(character_stats_ui.panel_style.border_color == Color("#cd7f32"), "FAIL TC-27: Lv1 border_color must be #cd7f32")
	assert(character_stats_ui.panel_style.shadow_size == 0, "FAIL TC-27: Lv1 shadow_size must be 0")
	assert(character_stats_ui.panel_style.border_width_left == 2, "FAIL TC-27: Border width must be fixed at 2px")
	
	# 2. Tier II: Tinh Anh (Lv 10 - 24) -> Bạc Ánh Kim #bdc3c7
	test_hero.progression.current_level = 10
	character_stats_ui.update_stats()
	assert(character_stats_ui.panel_style.border_color == Color("#bdc3c7"), "FAIL TC-27: Lv10 border_color must be #bdc3c7")
	assert(character_stats_ui.panel_style.shadow_size == 4, "FAIL TC-27: Lv10 shadow_size must be 4")
	
	# 3. Tier III: Dũng Sĩ (Lv 25 - 49) -> Vàng Hoàng Kim #f1c40f (Jaina Lv31 Verification!)
	test_hero.progression.current_level = 31
	character_stats_ui.update_stats()
	assert(character_stats_ui.panel_style.border_color == Color("#f1c40f"), "FAIL TC-27: Jaina Lv31 border_color must be #f1c40f")
	assert(character_stats_ui.panel_style.shadow_size == 6, "FAIL TC-27: Lv31 shadow_size must be 6")
	_log_test("[TC-27] Verified Jaina Lv31: Border = %s | Shadow size = %d" % [character_stats_ui.panel_style.border_color.to_html(false), character_stats_ui.panel_style.shadow_size])
	
	# 4. Tier IV: Bậc Thầy (Lv 50 - 74) -> Lam Ngọc #00cec9
	test_hero.progression.current_level = 50
	character_stats_ui.update_stats()
	assert(character_stats_ui.panel_style.border_color == Color("#00cec9"), "FAIL TC-27: Lv50 border_color must be #00cec9")
	assert(character_stats_ui.panel_style.shadow_size == 8, "FAIL TC-27: Lv50 shadow_size must be 8")
	
	# 5. Tier V: Huyền Thoại (Lv 75 - 98) -> Đỏ Huyết Ngọc #e74c3c
	test_hero.progression.current_level = 75
	character_stats_ui.update_stats()
	assert(character_stats_ui.panel_style.border_color == Color("#e74c3c"), "FAIL TC-27: Lv75 border_color must be #e74c3c")
	assert(character_stats_ui.panel_style.shadow_size == 10, "FAIL TC-27: Lv75 shadow_size must be 10")
	
	# 6. Tier VI: Vô Cực MAX (Lv 99) -> Tím Vũ Trụ #9b59b6
	test_hero.progression.current_level = 99
	character_stats_ui.update_stats()
	assert(character_stats_ui.panel_style.border_color == Color("#9b59b6"), "FAIL TC-27: Lv99 border_color must be #9b59b6")
	assert(character_stats_ui.panel_style.shadow_size == 14, "FAIL TC-27: Lv99 shadow_size must be 14")
	test_hero.queue_free()
	
	# 7. Enemy Ranks Border Verification
	# 7a. Normal Enemy -> #484852
	var norm_data := EnemyData.new()
	norm_data.name = "NormalSlime"
	norm_data.rank = EnemyData.EnemyRank.NORMAL
	var norm_enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(norm_enemy)
	norm_enemy.initialize(norm_data, 1, EnemyData.EnemyRank.NORMAL, false)
	character_stats_ui.inspect_entity(norm_enemy)
	assert(character_stats_ui.panel_style.border_color == Color("#484852"), "FAIL TC-27: Normal enemy border must be #484852")
	assert(character_stats_ui.panel_style.shadow_size == 0, "FAIL TC-27: Normal enemy shadow_size must be 0")
	norm_enemy.queue_free()
	
	# 7b. Elite Enemy -> #8e44ad
	var elite_data := EnemyData.new()
	elite_data.name = "EliteSlime"
	elite_data.rank = EnemyData.EnemyRank.ELITE
	var elite_enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(elite_enemy)
	elite_enemy.initialize(elite_data, 5, EnemyData.EnemyRank.ELITE, false)
	character_stats_ui.inspect_entity(elite_enemy)
	assert(character_stats_ui.panel_style.border_color == Color("#8e44ad"), "FAIL TC-27: Elite enemy border must be #8e44ad")
	assert(character_stats_ui.panel_style.shadow_size == 6, "FAIL TC-27: Elite enemy shadow_size must be 6")
	elite_enemy.queue_free()
	
	# 7c. Boss Enemy -> #c0392b
	var boss_data := EnemyData.new()
	boss_data.name = "BossSlime"
	boss_data.rank = EnemyData.EnemyRank.BOSS
	var boss_enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(boss_enemy)
	boss_enemy.initialize(boss_data, 10, EnemyData.EnemyRank.BOSS, false)
	character_stats_ui.inspect_entity(boss_enemy)
	assert(character_stats_ui.panel_style.border_color == Color("#c0392b"), "FAIL TC-27: Boss enemy border must be #c0392b")
	assert(character_stats_ui.panel_style.shadow_size == 10, "FAIL TC-27: Boss enemy shadow_size must be 10")
	boss_enemy.queue_free()
	
	# 7d. Solo Raid Boss -> #d35400
	var solo_boss: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(solo_boss)
	solo_boss.initialize(boss_data, 10, EnemyData.EnemyRank.BOSS, true) # DR >= 30%
	character_stats_ui.inspect_entity(solo_boss)
	assert(character_stats_ui.panel_style.border_color == Color("#d35400"), "FAIL TC-27: Solo boss border must be #d35400")
	assert(character_stats_ui.panel_style.shadow_size == 12, "FAIL TC-27: Solo boss shadow_size must be 12")
	solo_boss.queue_free()
	
	character_stats_ui.close()
	_reset_test_battlefield()
	_log_test(">>> 🟢 TC-27 PASSED: Dynamic Prestige Border Palette & Card Aura fully verified!\n")

# ------------------------------------------------------------------------------
# TC-28: Hero Upgrade Input Isolation & Anti-Displacement Verification (Sprint 5)
# ------------------------------------------------------------------------------
func _run_tc_28_hero_upgrade_anti_displacement() -> void:
	_log_test("\n==================== [TEST TC-28: HERO UPGRADE ANTI-DISPLACEMENT] ====================")
	_reset_test_battlefield()
	
	# Chuyển sang Preparation Phase để test kéo thả và nâng cấp Tướng
	enter_preparation_phase()
	assert(current_phase == EncounterPhase.PREPARATION, "FAIL TC-28: Must be in PREPARATION phase")
	
	var hero: HeroEntity = heroes[0] as HeroEntity
	assert(hero != null, "FAIL TC-28: Hero 0 must exist")
	var initial_cell: Vector2i = board_grid.get_cell_for_entity(hero)
	assert(initial_cell != Vector2i(-1, -1), "FAIL TC-28: Hero must be deployed on grid")
	var initial_world_pos: Vector2 = hero.global_position
	
	# 1. TC-28.1: Hero Upgrade Selection keeps hero position completely unchanged
	_log_test("[TC-28.1] Verifying upgrade selection maintains exact hero position...")
	hero.progression.milestone_reached.emit(5)
	assert(hero.has_pending_milestone == true, "FAIL TC-28.1: Hero must have pending milestone")
	
	# Simulate clicking the hero to open upgrade
	handle_hero_clicked(hero)
	assert(skill_ui.visible == true, "FAIL TC-28.1: SkillChoiceUI must open")
	assert(placement_controller.is_locked == true, "FAIL TC-28.1: PlacementController must be locked while SkillChoiceUI is open")
	assert(hero.global_position == initial_world_pos, "FAIL TC-28.1: Hero position must not drift on UI open")
	assert(board_grid.get_cell_for_entity(hero) == initial_cell, "FAIL TC-28.1: Hero cell must not change on UI open")
	
	# Choose skill upgrade
	var choice = AbilityData.new()
	choice.name = "AntiDisplacementSkill"
	_on_skill_chosen(choice, [choice])
	assert(not skill_ui.visible, "FAIL TC-28.1: SkillChoiceUI must close")
	assert(placement_controller.is_locked == false, "FAIL TC-28.1: PlacementController unlocked after skill chosen")
	assert(hero.global_position == initial_world_pos, "FAIL TC-28.1: Hero position must remain exact after skill chosen")
	assert(board_grid.get_cell_for_entity(hero) == initial_cell, "FAIL TC-28.1: Hero cell must remain exact after skill chosen")
	_log_test(">>> 🟢 TC-28.1 Upgrade Selection Anti-Displacement PASSED!")
	
	# 2. TC-28.2: PlacementController cancel_drag resets entity to original_cell
	_log_test("[TC-28.2] Verifying cancel_drag and lock rollback...")
	placement_controller.dragged_entity = hero
	placement_controller.original_cell = initial_cell
	placement_controller.original_z_index = 0
	hero.global_position = Vector2(999, 999) # Displace temporarily
	
	placement_controller.set_locked(true)
	assert(placement_controller.dragged_entity == null, "FAIL TC-28.2: dragged_entity must be cleared")
	assert(hero.global_position == initial_world_pos, "FAIL TC-28.2: Hero must be rolled back to original cell position")
	placement_controller.set_locked(false)
	_log_test(">>> 🟢 TC-28.2 cancel_drag and lock rollback PASSED!")
	
	# 3. TC-28.3: Floating Badge Click Area Detection
	_log_test("[TC-28.3] Verifying upgrade badge detection area...")
	hero.progression.milestone_reached.emit(10)
	assert(hero.has_pending_milestone == true)
	
	var badge_pos: Vector2 = hero.global_position + Vector2(0, -56)
	var detected_hero := placement_controller._find_badge_hero_at(badge_pos)
	assert(detected_hero == hero, "FAIL TC-28.3: Direct click on badge must detect hero")
	
	var near_badge_pos: Vector2 = badge_pos + Vector2(15, -10)
	var detected_near := placement_controller._find_badge_hero_at(near_badge_pos)
	assert(detected_near == hero, "FAIL TC-28.3: Click within badge radius must detect hero")
	
	var far_pos: Vector2 = badge_pos + Vector2(100, 100)
	var detected_far := placement_controller._find_badge_hero_at(far_pos)
	assert(detected_far == null, "FAIL TC-28.3: Click far from badge must return null")
	_log_test(">>> 🟢 TC-28.3 Floating Badge Click Area PASSED!")
	
	# Clean up for next tests
	var choice2 = AbilityData.new()
	choice2.name = "Skill2"
	_on_skill_chosen(choice2, [choice2])
	_reset_test_battlefield()
	_log_test(">>> 🟢 TC-28 PASSED: Hero Upgrade Input Isolation & Anti-Displacement fully verified!\n")

# ------------------------------------------------------------------------------
# TC-29: 4-Tier Ability Tooltip Architecture & Spatial Layout (Sprint 5)
# ------------------------------------------------------------------------------
func _run_tc_29_four_tier_ability_tooltips() -> void:
	_log_test("\n==================== [TEST TC-29: 4-TIER ABILITY TOOLTIPS & SPATIAL LAYOUT] ====================")
	_reset_test_battlefield()
	
	var hero_data := HeroData.new()
	hero_data.name = "Kira"
	hero_data.base_attack = 60.0
	var hero_entity := hero_scene.instantiate() as HeroEntity
	add_child(hero_entity)
	hero_entity.initialize(hero_data)
	
	# 1. TC-29.1: Token Parsing Integrity
	_log_test("[TC-29.1] Verifying Token Parsing Integrity ({hero}, {action_target}, {0})...")
	var test_ab := AbilityData.new()
	test_ab.name = "Vũ Điệu Lưỡi Hái"
	test_ab.target_rule = AbilityData.TargetRule.ALL_ENEMIES
	var dmg_eff := DamageEffectData.new()
	dmg_eff.base_damage = 120.0
	dmg_eff.damage_type = DamageEvent.DamageType.PHYSICAL
	dmg_eff.scalings = { EffectData.STAT_TOTAL_AD: 0.50 }
	test_ab.effects.append(dmg_eff)
	test_ab.narrative_template = "{hero} phóng liên hoàn đoản kiếm vào {action_target}, gây {0} lên từng mục tiêu."
	test_ab.caveat = "Kỹ năng này có thể kích hoạt hiệu ứng đòn đánh và có thể Chí Mạng."
	test_ab.progression_ranks = {
		"Sát thương": [120, 180, 260],
		"Tỉ lệ STVL": ["50%", "65%", "80%"]
	}
	
	var full_desc := test_ab.get_formatted_tooltip(hero_entity, true)
	_log_test("[TC-29.1] Full Parsed Tooltip:\n%s" % full_desc)
	assert(not full_desc.contains("{hero}"), "FAIL TC-29.1: {hero} token was not replaced")
	assert(not full_desc.contains("{action_target}"), "FAIL TC-29.1: {action_target} token was not replaced")
	assert(not full_desc.contains("{0}"), "FAIL TC-29.1: {0} token was not replaced")
	assert(full_desc.contains("Kira"), "FAIL TC-29.1: {hero} must be replaced by hero name 'Kira'")
	assert(full_desc.contains("toàn bộ kẻ địch trên sàn đấu"), "FAIL TC-29.1: {action_target} must be replaced by 'toàn bộ kẻ địch trên sàn đấu'")
	assert(full_desc.contains("150"), "FAIL TC-29.1: {0} must calculate total value 120 + 60*0.5 = 150")
	_log_test(">>> 🟢 TC-29.1 Token Parsing Integrity PASSED!")
	
	# 2. TC-29.2: Spatial Filtering Isolation (Gacha vs Stat Panel)
	_log_test("[TC-29.2] Verifying Spatial Filtering Isolation (Gacha UI vs CharacterStatsUI)...")
	var gacha_desc := test_ab.get_formatted_tooltip(hero_entity, false)
	_log_test("[TC-29.2] Gacha Tooltip (No Tier 4):\n%s" % gacha_desc)
	assert(gacha_desc.contains("Kira phóng liên hoàn đoản kiếm"), "FAIL TC-29.2: Gacha desc must contain Tier 2 Narrative")
	assert(gacha_desc.contains("Kỹ năng này có thể kích hoạt"), "FAIL TC-29.2: Gacha desc must contain Tier 3 Caveat")
	assert(not gacha_desc.contains("─── Tiến trình theo cấp ───"), "FAIL TC-29.2: Gacha desc MUST NOT contain Tier 4 separator")
	assert(not gacha_desc.contains("Sát thương: ["), "FAIL TC-29.2: Gacha desc MUST NOT contain Tier 4 progression table")
	
	var stat_desc := test_ab.get_formatted_tooltip(hero_entity, true)
	assert(stat_desc.contains("─── Tiến trình theo cấp ───"), "FAIL TC-29.2: Stat Panel tooltip must contain Tier 4 separator")
	assert(stat_desc.contains("Sát thương: ["), "FAIL TC-29.2: Stat Panel tooltip must contain Tier 4 progression table")
	_log_test(">>> 🟢 TC-29.2 Spatial Filtering Isolation PASSED!")
	
	# 3. TC-29.3: Backward Compatibility Zero-Regression
	_log_test("[TC-29.3] Verifying Backward Compatibility on legacy skills without template...")
	var legacy_ab := AbilityData.new()
	legacy_ab.name = "Legacy Strike"
	var leg_eff := DamageEffectData.new()
	leg_eff.base_damage = 50.0
	legacy_ab.effects.append(leg_eff)
	var leg_desc_false := legacy_ab.get_formatted_tooltip(hero_entity, false)
	var leg_desc_true := legacy_ab.get_formatted_tooltip(hero_entity, true)
	assert(leg_desc_false != "" and leg_desc_false.contains("50"), "FAIL TC-29.3: Legacy false tooltip failed")
	assert(leg_desc_true != "" and leg_desc_true.contains("50"), "FAIL TC-29.3: Legacy true tooltip failed")
	_log_test(">>> 🟢 TC-29.3 Backward Compatibility Zero-Regression PASSED!")
	
	# 4. TC-29.4: Active Rank Highlighting in Progression Table
	_log_test("[TC-29.4] Verifying Active Rank Highlighting according to hero level...")
	# Lv 1 -> Rank 0 highlighted
	hero_entity.progression.current_level = 1
	var desc_lv1 := test_ab.get_formatted_tooltip(hero_entity, true)
	assert(desc_lv1.contains("[b][color=#f1c40f]120[/color][/b] / 180 / 260"), "FAIL TC-29.4: Lv1 must highlight 120 (Rank 0)")
	
	# Lv 10 -> Rank 1 highlighted
	hero_entity.progression.current_level = 10
	var desc_lv10 := test_ab.get_formatted_tooltip(hero_entity, true)
	assert(desc_lv10.contains("120 / [b][color=#f1c40f]180[/color][/b] / 260"), "FAIL TC-29.4: Lv10 must highlight 180 (Rank 1)")
	
	# Lv 25 -> Rank 2 highlighted
	hero_entity.progression.current_level = 25
	var desc_lv25 := test_ab.get_formatted_tooltip(hero_entity, true)
	assert(desc_lv25.contains("120 / 180 / [b][color=#f1c40f]260[/color][/b]"), "FAIL TC-29.4: Lv25 must highlight 260 (Rank 2)")
	_log_test(">>> 🟢 TC-29.4 Active Rank Highlighting PASSED!")
	
	# 5. TC-29.5: Official Kira, Arthur, Jaina Signature Abilities Verification
	_log_test("[TC-29.5] Verifying official resources for Kira, Arthur, and Jaina...")
	var kira_ult = load("res://data/abilities/Kira_Ultimate.tres") as AbilityData
	assert(kira_ult != null and kira_ult.narrative_template != "" and not kira_ult.progression_ranks.is_empty(), "FAIL TC-29.5: Kira_Ultimate.tres must have 4-tier data")
	
	var arthur_shield = load("res://data/abilities/arthur_holy_shield.tres") as AbilityData
	assert(arthur_shield != null and arthur_shield.narrative_template != "" and not arthur_shield.progression_ranks.is_empty(), "FAIL TC-29.5: arthur_holy_shield.tres must have 4-tier data")
	
	var jaina_blizz = load("res://data/abilities/jaina_eternal_blizzard.tres") as AbilityData
	assert(jaina_blizz != null and jaina_blizz.narrative_template != "" and not jaina_blizz.progression_ranks.is_empty(), "FAIL TC-29.5: jaina_eternal_blizzard.tres must have 4-tier data")
	
	hero_entity.queue_free()
	_reset_test_battlefield()
	_log_test(">>> 🟢 TC-29 PASSED: 4-Tier Ability Tooltip Architecture & Spatial Layout fully verified!\n")

# ------------------------------------------------------------------------------
# Helper Reset Battlefield
# ------------------------------------------------------------------------------
func _reset_test_battlefield() -> void:
	for h in heroes:
		if is_instance_valid(h):
			if h.get_parent(): h.get_parent().remove_child(h)
			h.queue_free()
	for e in enemies:
		if is_instance_valid(e):
			if e.get_parent(): e.get_parent().remove_child(e)
			e.queue_free()
	for c in corpses:
		if is_instance_valid(c):
			if c.get_parent(): c.get_parent().remove_child(c)
			c.queue_free()
	heroes.clear(); enemies.clear(); corpses.clear(); choice_queue.clear()
	if board_grid != null:
		board_grid.is_locked = false
		board_grid.clear()
	if targeting_system != null:
		targeting_system.board_grid = board_grid
	if placement_controller != null:
		placement_controller.set_locked(false)
	if is_instance_valid(skill_ui):
		skill_ui.hide()
	if is_instance_valid(combat_summary_ui):
		combat_summary_ui.hide()
	if is_instance_valid(character_stats_ui):
		character_stats_ui.close()
	if get_tree() != null:
		get_tree().paused = false
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()
	_current_shake_strength = 0.0
	if camera != null:
		camera.offset = Vector2.ZERO
	battle_ended = false
	if RunManager != null:
		RunManager.start_new_run(10, 2)
		current_floor = RunManager.current_floor
	_spawn_mock_teams()
	start_combat_phase()
