class_name HeroShop
extends Control

# ==========================================
# HERO SHOP - TFT-STYLE 5-CARD SHOP & RECRUITMENT
# Quản lý Cửa Hàng Tướng 5 ô, Reroll, Khóa Shop & Thức Tỉnh (Task S7.2)
# ==========================================

signal hero_bought(hero_data: HeroData, slot_idx: int)
signal shop_rerolled()
signal shop_locked_toggled(is_locked: bool)
signal start_combat_requested()

const SHOP_SIZE: int = 5
const REROLL_COST: int = 2
const CARD_SIZE: Vector2 = Vector2(96, 76)

var shop_slots: Array[HeroData] = []
var is_shop_locked: bool = false
var active_pool: Array[HeroData] = []

# UI Nodes
var card_buttons: Array[Button] = []
var card_panels: Array[PanelContainer] = []
var reroll_button: Button = null
var lock_button: Button = null
var start_combat_button: Button = null

# System references
var battle_manager = null
var hero_bench: HeroBench = null
var inventory_panel: InventoryPanel = null

func _init() -> void:
	shop_slots.resize(SHOP_SIZE)
	for i in range(SHOP_SIZE):
		shop_slots[i] = null
	custom_minimum_size = Vector2(1152, 88)
	size = Vector2(1152, 88)
	position = Vector2(0, 550)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	setup_default_pool()
	roll_shop(true)

func _ready() -> void:
	if card_buttons.is_empty():
		_build_ui()
		setup_default_pool()
		roll_shop(true)

func setup_default_pool() -> void:
	active_pool.clear()
	var kira = load("res://data/heroes/kira_data.tres") as HeroData
	if kira != null:
		active_pool.append(kira)
	else:
		var mock_kira := HeroData.new()
		mock_kira.name = "Kira"
		mock_kira.id = "hero_kira"
		mock_kira.hero_class = HeroData.HeroClass.ASSASSIN
		mock_kira.cost = 2
		active_pool.append(mock_kira)
		
	var arthur := HeroData.new()
	arthur.name = "Arthur"
	arthur.id = "hero_arthur"
	arthur.hero_class = HeroData.HeroClass.TANK
	arthur.base_hp = 250.0
	arthur.base_attack = 5.0
	arthur.base_defense = 30.0
	arthur.attack_speed = 0.8
	arthur.cost = 2
	active_pool.append(arthur)
	
	var jaina := HeroData.new()
	jaina.name = "Jaina"
	jaina.id = "hero_jaina"
	jaina.hero_class = HeroData.HeroClass.MAGE
	jaina.base_hp = 80.0
	jaina.base_attack = 25.0
	jaina.base_spell_power = 20.0
	jaina.attack_speed = 0.7
	jaina.cost = 2
	active_pool.append(jaina)
	
	var robin := HeroData.new()
	robin.name = "Robin"
	robin.id = "hero_robin"
	robin.hero_class = HeroData.HeroClass.MARKSMAN
	robin.base_hp = 90.0
	robin.base_attack = 15.0
	robin.attack_speed = 1.5
	robin.cost = 2
	active_pool.append(robin)
	
	var soraka := HeroData.new()
	soraka.name = "Soraka"
	soraka.id = "hero_soraka"
	soraka.hero_class = HeroData.HeroClass.SUPPORT
	soraka.base_hp = 120.0
	soraka.base_attack = 3.0
	soraka.base_spell_power = 10.0
	soraka.attack_speed = 0.6
	soraka.cost = 2
	active_pool.append(soraka)

func _build_ui() -> void:
	if not card_buttons.is_empty():
		return
		
	# 1. Nút Reroll (Đổi tướng - 2 Vàng)
	reroll_button = Button.new()
	reroll_button.name = "RerollButton"
	reroll_button.text = "🎲 Đổi (2 Vàng)"
	reroll_button.custom_minimum_size = Vector2(96, 36)
	reroll_button.size = Vector2(96, 36)
	reroll_button.position = Vector2(140, 6)
	reroll_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var style_reroll := StyleBoxFlat.new()
	style_reroll.bg_color = Color("#0f172a")
	style_reroll.set_corner_radius_all(6)
	style_reroll.border_width_left = 2
	style_reroll.border_width_top = 2
	style_reroll.border_width_right = 2
	style_reroll.border_width_bottom = 2
	style_reroll.border_color = Color("#f59e0b")
	reroll_button.add_theme_stylebox_override("normal", style_reroll)
	reroll_button.add_theme_font_size_override("font_size", 11)
	reroll_button.add_theme_color_override("font_color", Color("#fbbf24"))
	reroll_button.pressed.connect(func(): reroll())
	add_child(reroll_button)
	
	# 2. Nút Khóa Shop
	lock_button = Button.new()
	lock_button.name = "LockButton"
	lock_button.text = "🔓 Khóa Shop"
	lock_button.custom_minimum_size = Vector2(96, 32)
	lock_button.size = Vector2(96, 32)
	lock_button.position = Vector2(140, 46)
	lock_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var style_lock := StyleBoxFlat.new()
	style_lock.bg_color = Color("#0f172a")
	style_lock.set_corner_radius_all(6)
	style_lock.border_width_left = 1
	style_lock.border_width_top = 1
	style_lock.border_width_right = 1
	style_lock.border_width_bottom = 1
	style_lock.border_color = Color("#475569")
	lock_button.add_theme_stylebox_override("normal", style_lock)
	lock_button.add_theme_font_size_override("font_size", 11)
	lock_button.add_theme_color_override("font_color", Color("#94a3b8"))
	lock_button.pressed.connect(func(): toggle_lock())
	add_child(lock_button)
	
	# 3. 5 Thẻ Tướng
	card_buttons.clear()
	card_panels.clear()
	var start_x: float = 246.0
	var spacing: float = 6.0
	
	for i in range(SHOP_SIZE):
		var panel := PanelContainer.new()
		panel.name = "ShopCard_%d" % i
		panel.custom_minimum_size = CARD_SIZE
		panel.size = CARD_SIZE
		panel.position = Vector2(start_x + i * (CARD_SIZE.x + spacing), 6)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#0f172a")
		style.set_corner_radius_all(8)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color("#334155")
		panel.add_theme_stylebox_override("panel", style)
		
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var name_lbl := Label.new()
		name_lbl.name = "HeroName"
		name_lbl.text = "Hero"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)
		
		var class_lbl := Label.new()
		class_lbl.name = "HeroClass"
		class_lbl.text = "Class"
		class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		class_lbl.add_theme_font_size_override("font_size", 10)
		class_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
		class_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(class_lbl)
		
		var cost_lbl := Label.new()
		cost_lbl.name = "HeroCost"
		cost_lbl.text = "💰 2 Vàng"
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(cost_lbl)
		
		panel.add_child(vbox)
		
		var btn := Button.new()
		btn.name = "BuyButton"
		btn.flat = true
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var slot_idx := i
		btn.pressed.connect(func(): buy_hero(slot_idx))
		panel.add_child(btn)
		
		add_child(panel)
		card_panels.append(panel)
		card_buttons.append(btn)
		
	# 4. Nút Bắt Đầu Chiến Đấu tại góc phải X = 765, Y = 0 (Global Y = 550)
	start_combat_button = Button.new()
	start_combat_button.name = "StartCombatButton"
	start_combat_button.text = "⚔️ BẮT ĐẦU CHIẾN ĐẤU"
	start_combat_button.custom_minimum_size = Vector2(230, 52)
	start_combat_button.size = Vector2(230, 52)
	start_combat_button.position = Vector2(765, 0)
	start_combat_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start_combat_button.pressed.connect(func(): start_combat_requested.emit())
	
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
	start_combat_button.add_theme_font_size_override("font_size", 16)
	add_child(start_combat_button)

func toggle_lock() -> void:
	is_shop_locked = !is_shop_locked
	_update_lock_button_display()
	shop_locked_toggled.emit(is_shop_locked)

func _update_lock_button_display() -> void:
	if lock_button == null:
		return
	if is_shop_locked:
		lock_button.text = "🔒 Đã Khóa"
		lock_button.add_theme_color_override("font_color", Color("#fbbf24"))
	else:
		lock_button.text = "🔓 Khóa Shop"
		lock_button.add_theme_color_override("font_color", Color("#94a3b8"))

func remove_hero_from_pool(hero_id: String) -> void:
	for i in range(active_pool.size() - 1, -1, -1):
		var h = active_pool[i]
		if h != null and (h.name == hero_id or h.id == hero_id):
			active_pool.remove_at(i)

func roll_shop(force: bool = false) -> void:
	if is_shop_locked and not force:
		return
	_generate_cards()

func reroll(force: bool = false) -> bool:
	if is_shop_locked and not force:
		return false
	if RunManager != null:
		if RunManager.current_gold < REROLL_COST:
			return false
		RunManager.add_gold(-REROLL_COST)
	_generate_cards()
	shop_rerolled.emit()
	return true

func _generate_cards() -> void:
	if active_pool.is_empty():
		setup_default_pool()
		
	for i in range(SHOP_SIZE):
		if not active_pool.is_empty():
			var picked: HeroData = active_pool[randi() % active_pool.size()]
			shop_slots[i] = picked
		else:
			shop_slots[i] = null
		_update_slot_display(i)

func _update_slot_display(idx: int) -> void:
	if idx < 0 or idx >= card_panels.size():
		return
	var panel := card_panels[idx]
	var btn := card_buttons[idx]
	var data := shop_slots[idx]
	
	var vbox := panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox == null:
		return
	var name_lbl := vbox.get_node_or_null("HeroName") as Label
	var class_lbl := vbox.get_node_or_null("HeroClass") as Label
	var cost_lbl := vbox.get_node_or_null("HeroCost") as Label
	
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = Color("#0f172a")
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)
		
	if data == null:
		btn.disabled = true
		if name_lbl: name_lbl.text = "[ĐÃ MUA]"
		if class_lbl: class_lbl.text = ""
		if cost_lbl: cost_lbl.text = ""
		style.border_color = Color("#1e293b")
		style.bg_color = Color(0.06, 0.09, 0.16, 0.5)
	else:
		btn.disabled = false
		if name_lbl: name_lbl.text = data.name
		if class_lbl:
			class_lbl.text = _get_class_text(data.hero_class)
			class_lbl.add_theme_color_override("font_color", _get_class_color(data.hero_class))
		if cost_lbl:
			var cost: int = data.cost if ("cost" in data and data.cost > 0) else 2
			cost_lbl.text = "💰 %d Vàng" % cost
		style.border_color = _get_class_color(data.hero_class)
		style.bg_color = Color("#0f172a")

func _get_class_text(c: HeroData.HeroClass) -> String:
	match c:
		HeroData.HeroClass.TANK: return "🛡️ Tank"
		HeroData.HeroClass.FIGHTER: return "⚔️ Fighter"
		HeroData.HeroClass.ASSASSIN: return "🗡️ Assassin"
		HeroData.HeroClass.MAGE: return "🔮 Mage"
		HeroData.HeroClass.MARKSMAN: return "🏹 Marksman"
		HeroData.HeroClass.SUPPORT: return "💚 Support"
		_: return "Hero"

func _get_class_color(c: HeroData.HeroClass) -> Color:
	match c:
		HeroData.HeroClass.TANK: return Color("#38bdf8")
		HeroData.HeroClass.FIGHTER: return Color("#f97316")
		HeroData.HeroClass.ASSASSIN: return Color("#f43f5e")
		HeroData.HeroClass.MAGE: return Color("#c084fc")
		HeroData.HeroClass.MARKSMAN: return Color("#eab308")
		HeroData.HeroClass.SUPPORT: return Color("#34d399")
		_: return Color("#94a3b8")

func buy_hero(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= shop_slots.size():
		return {"success": false, "reason": "invalid_slot"}
	var offer_data: HeroData = shop_slots[slot_idx]
	if offer_data == null:
		return {"success": false, "reason": "empty_slot"}
		
	var cost: int = offer_data.cost if ("cost" in offer_data and offer_data.cost > 0) else 2
	if RunManager != null and RunManager.current_gold < cost:
		return {"success": false, "reason": "not_enough_gold"}
		
	# Tìm xem người chơi đã sở hữu tướng này chưa (trên Sàn Đấu hoặc trên Hàng Chờ)
	var existing_hero: HeroEntity = null
	if battle_manager != null and "heroes" in battle_manager:
		for h in battle_manager.heroes:
			if is_instance_valid(h) and h is HeroEntity and h.data != null:
				if h.data.name == offer_data.name or (offer_data.id != "" and h.data.id == offer_data.id):
					existing_hero = h
					break
	if existing_hero == null and hero_bench != null:
		for h in hero_bench.bench_slots:
			if is_instance_valid(h) and h.data != null:
				if h.data.name == offer_data.name or (offer_data.id != "" and h.data.id == offer_data.id):
					existing_hero = h
					break
					
	if existing_hero != null:
		# TRƯỜNG HỢP 1: ĐÃ SỞ HỮU -> TIẾN HÓA BẢN SAO THEO HỆ (CLASS AWAKENING)
		if RunManager != null:
			RunManager.add_gold(-cost)
			
		var res: Dictionary = existing_hero.apply_class_awakening(offer_data)
		if res.get("refund", false):
			# Anti-Exploit Bench Guard: Ở Bench và đã Max 5/5 -> Hoàn trả 100% vàng, thẻ shop vẫn giữ nguyên
			if RunManager != null:
				RunManager.add_gold(cost)
			return {
				"success": false,
				"refund": true,
				"reason": "bench_guard",
				"hero": existing_hero
			}
		elif res.get("transmuted", false):
			# Transcendent Shard: Ở Board và đã Max 5/5 -> Chuyển hóa 1 Mảnh Cổ Vật vào Inventory, xóa vĩnh viễn khỏi Shop Pool
			var shard_id: String = res.get("shard_id", "")
			if shard_id != "":
				var shard_item: ItemData = null
				if ItemManager != null:
					shard_item = ItemManager.get_item_by_id(shard_id)
				if shard_item == null:
					shard_item = load("res://data/items/" + shard_id + ".tres") as ItemData
				if shard_item != null:
					if ItemManager != null:
						ItemManager.add_item_to_bench(shard_item)
					if inventory_panel != null:
						inventory_panel.refresh_all_slots()
						
			remove_hero_from_pool(offer_data.name)
			if offer_data.id != "":
				remove_hero_from_pool(offer_data.id)
			shop_slots[slot_idx] = null
			_update_slot_display(slot_idx)
			hero_bought.emit(offer_data, slot_idx)
			return {
				"success": true,
				"type": "transmuted",
				"shard_id": shard_id,
				"hero": existing_hero
			}
		else:
			# Tăng tầng thức tỉnh thông thường (< 5)
			shop_slots[slot_idx] = null
			_update_slot_display(slot_idx)
			hero_bought.emit(offer_data, slot_idx)
			return {
				"success": true,
				"type": "awakened",
				"awakening_count": existing_hero.awakening_count,
				"hero": existing_hero
			}
	else:
		# TRƯỜNG HỢP 2: CHƯA SỞ HỮU -> CHIÊU MỘ TƯỚNG MỚI VÀO HÀNG CHỜ DỰ BỊ
		if hero_bench == null or not hero_bench.has_empty_slot():
			return {"success": false, "reason": "bench_full"}
			
		if RunManager != null:
			RunManager.add_gold(-cost)
			
		var new_hero: HeroEntity = null
		if battle_manager != null and battle_manager.has_method("spawn_hero_for_bench"):
			new_hero = battle_manager.spawn_hero_for_bench(offer_data)
		else:
			new_hero = HeroEntity.new()
			new_hero.initialize(offer_data)
			
		var placed_slot := hero_bench.add_hero(new_hero)
		shop_slots[slot_idx] = null
		_update_slot_display(slot_idx)
		hero_bought.emit(offer_data, slot_idx)
		return {
			"success": true,
			"type": "recruited",
			"hero": new_hero,
			"bench_slot": placed_slot
		}
