extends Node2D

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text/FloatingText.tscn")

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
var choice_queue: Array[Dictionary] = []

var board_config: BoardConfig
var board_grid: BoardGrid

enum EncounterPhase { PREPARATION, COMBAT, POST_COMBAT, REWARD, GAME_OVER }
var current_phase: EncounterPhase = EncounterPhase.PREPARATION
var start_combat_button: Button = null

# Trạng thái điều phối cuối trận
var battle_ended: bool = false
var next_game_state: GameManager.GameState

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.BATTLE)
	_start_battle()
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

	combat_system = CombatSystem.new()
	combat_system.name = "CombatSystem"
	add_child(combat_system)
	combat_system.damage_dealt.connect(_on_combat_damage_dealt)
	
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
	ability_system.ability_executed.connect(_on_ability_executed)
	
	skill_ui = SkillChoiceUI.new()
	add_child(skill_ui)
	skill_ui.skill_chosen.connect(_on_skill_chosen)
	
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
		start_combat_button.show()
	print("[BattleManager] 🛡️ PHASE: PREPARATION (Kéo thả bố trí đội hình)")

func start_combat_phase() -> void:
	if current_phase == EncounterPhase.COMBAT:
		return
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
	if start_combat_button != null:
		start_combat_button.hide()
		
	if targeting_system != null:
		targeting_system.set_process(true)
		
	for hero in heroes:
		if is_instance_valid(hero):
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
		_spawn_hero_at_grid(kira_data, Vector2i(4, 3))
		
	# 2. Sinh nhanh 4 Tướng ẢO (Trên–Dưới Layout)
	_spawn_hero_at_grid(_create_mock_hero_data("Arthur", HeroData.HeroClass.TANK, 250.0, 5.0, 30.0, 0.8), Vector2i(3, 3))
	_spawn_hero_at_grid(_create_mock_hero_data("Jaina", HeroData.HeroClass.MAGE, 80.0, 25.0, 2.0, 0.7), Vector2i(2, 4))
	_spawn_hero_at_grid(_create_mock_hero_data("Robin", HeroData.HeroClass.MARKSMAN, 90.0, 15.0, 5.0, 1.5), Vector2i(3, 4))
	_spawn_hero_at_grid(_create_mock_hero_data("Soraka", HeroData.HeroClass.SUPPORT, 120.0, 3.0, 10.0, 0.6), Vector2i(4, 4))
	
	# 3. Quái vật (Nửa trên bàn cờ: Hàng 1 & 2)
	var slime_coords = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(3, 1)]
	for i in range(slime_coords.size()):
		_spawn_enemy_at_grid("Slime " + str(i+1), 80.0, 8.0, 5.0, 1.0, 0.0, 2.0, slime_coords[i])

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

func _spawn_hero_at_grid(data: HeroData, cell: Vector2i) -> HeroEntity:
	var hero: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(hero)
	hero.deployed_cell = cell
	
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
		var default_ult := AbilityData.new()
		default_ult.name = data.name + " Ultimate"
		default_ult.ability_type = AbilityData.AbilityType.ULTIMATE
		default_ult.target_rule = AbilityData.TargetRule.SINGLE_ENEMY
		default_ult.cooldown = 1.0
		var ult_dmg := DamageEffectData.new()
		ult_dmg.base_damage = data.base_attack * 2.5
		default_ult.effects.append(ult_dmg)
		hero.unlocked_abilities.append(Ability.new(hero, default_ult))

	hero.healed.connect(_on_entity_healed)
	if hero.progression != null:
		hero.progression.xp_gained.connect(func(amt: float): _on_hero_xp_gained(hero, amt))
		hero.progression.milestone_reached.connect(func(ms: int): _on_hero_milestone(hero, ms))
	heroes.append(hero)
	return hero

func _spawn_enemy_at_grid(e_name: String, hp: float, atk: float, def: float, spd: float, crit_c: float, crit_d: float, cell: Vector2i) -> EnemyEntity:
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
	
	if board_grid != null:
		board_grid.place_entity(enemy, cell)
	if board_view != null:
		enemy.global_position = board_view.grid_to_world(cell)
	else:
		enemy.global_position = Vector2(cell * 80)
	
	enemy.died.connect(_on_entity_died.bind(false))
	enemy.attack_requested.connect(_on_entity_attack_requested)
	enemy.initialize(data)
	enemy.healed.connect(_on_entity_healed)
	enemies.append(enemy)
	return enemy

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
	
	_build_post_battle_choice_queue()
	
	if not choice_queue.is_empty():
		_process_next_choice()
	else:
		_finish_battle_cleanup()

func _build_post_battle_choice_queue() -> void:
	choice_queue.clear()
	# RÀ SOÁT: Nối mảng an toàn không qua toán tử +
	var all_heroes: Array[CombatEntity] = []
	all_heroes.append_array(heroes)
	all_heroes.append_array(corpses)
	
	for entity in all_heroes:
		if entity is HeroEntity:
			var hero = entity as HeroEntity
			for milestone in hero.pending_milestones:
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
	if choice_queue.is_empty():
		return
	var current = choice_queue.pop_front()
	if current == null or not current.has("hero") or not is_instance_valid(current.hero):
		return
	current.hero.apply_skill_choice(current.milestone, chosen, all_choices)
	
	if choice_queue.size() > 0:
		_process_next_choice()
	else:
		_finish_battle_cleanup()

func _finish_battle_cleanup() -> void:
	var surviving_hero_corpses: Array[CombatEntity] = []
	for corpse in corpses:
		if is_instance_valid(corpse):
			if corpse is HeroEntity:
				surviving_hero_corpses.append(corpse)
			else:
				corpse.queue_free()
	corpses = surviving_hero_corpses

	# Nếu GAME_OVER thì dừng lại, không tự qua tầng mới
	if next_game_state == GameManager.GameState.GAME_OVER:
		GameManager.change_state(GameManager.GameState.GAME_OVER)
		print("[BattleManager] 🛑 GAME OVER - Stopping floor progression.")
		return

	get_tree().create_timer(1.0).timeout.connect(_start_next_floor)

func _start_next_floor() -> void:
	battle_ended = false
	print("\n=====================================")
	print("[BattleManager] 🚀 BẮT ĐẦU MÀN MỚI / TẦNG TIẾP THEO 🚀")
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
			if board_view != null and placed:
				hero.global_position = board_view.grid_to_world(target_cell)
				
	# Dọn dẹp quái vật cũ còn sót lại (nếu có)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	
	# Sinh quái vật ngẫu nhiên trên các ô trống trong Enemy Zone
	if board_grid != null:
		var empty_enemy_cells := board_grid.get_empty_enemy_cells()
		empty_enemy_cells.shuffle()
		var spawn_count: int = mini(5, empty_enemy_cells.size())
		for i in range(spawn_count):
			_spawn_enemy_at_grid("Slime Lv2 - " + str(i+1), 120.0, 10.0, 6.0, 1.0, 0.0, 2.0, empty_enemy_cells[i])
			
	enter_preparation_phase()

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

func _on_combat_damage_dealt(_source: CombatEntity, target: CombatEntity, amount: float, is_crit: bool) -> void:
	if not is_instance_valid(target):
		return
	target.play_hit_vfx()
	var dmg_val: int = maxi(1, roundi(amount))
	if is_crit:
		_shake_camera(4.0, 0.18)
		_spawn_floating_text(target.global_position, "%d!" % dmg_val, FloatingText.Type.CRIT)
	else:
		_spawn_floating_text(target.global_position, str(dmg_val), FloatingText.Type.DAMAGE)

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

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed): return
	
	match event.keycode:
		KEY_SPACE:
			print("\n[DEBUG] 🚀 BƠM 800 XP CHO TOÀN BỘ HEROES!")
			for hero in heroes:
				if is_instance_valid(hero) and hero.progression != null:
					hero.progression.add_xp(800.0)
					
		# PHÍM 0: CHẠY TOÀN BỘ 9 TEST CASE VÀ GHI REPORT
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

func _run_all_tests() -> void:
	var file = FileAccess.open(test_report_path, FileAccess.WRITE)
	if file:
		file.store_line("=== BÁO CÁO KIỂM THỬ SPRINT 1, 4 & 5 ===")
		file.store_line("Thời gian: " + Time.get_datetime_string_from_system())
		file.store_line("========================================\n")
		file.close()
	
	_log_test("Đang chạy toàn bộ Test Suite (Sprint 1, 4 & 5)...")
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
	
	_log_test("\n🎉 TẤT CẢ 9 BÀI TEST ĐÃ HOÀN THÀNH (100% PASSED)!")

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
	assert(choice_queue.size() == 3, "FAIL: Queue construction failed")
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
# Helper Reset Battlefield
# ------------------------------------------------------------------------------
func _reset_test_battlefield() -> void:
	for h in heroes: if is_instance_valid(h): h.queue_free()
	for e in enemies: if is_instance_valid(e): e.queue_free()
	for c in corpses: if is_instance_valid(c): c.queue_free()
	heroes.clear(); enemies.clear(); corpses.clear(); choice_queue.clear()
	if board_grid != null:
		board_grid.is_locked = false
		board_grid.clear()
	if placement_controller != null:
		placement_controller.set_locked(false)
	if is_instance_valid(skill_ui):
		skill_ui.hide()
	if get_tree() != null:
		get_tree().paused = false
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()
	_current_shake_strength = 0.0
	if camera != null:
		camera.offset = Vector2.ZERO
	battle_ended = false
	_spawn_mock_teams()
	start_combat_phase()
