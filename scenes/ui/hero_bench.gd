class_name HeroBench
extends Control

# ==========================================
# HERO BENCH - TFT-STYLE 8-SLOT RESERVE BENCH
# Quản lý hàng chờ tướng dự bị 8 ô (Dải ngang Y = 475..540)
# ==========================================

signal bench_slot_clicked(slot_idx: int)
signal hero_placed_on_bench(hero: HeroEntity, slot_idx: int)
signal hero_removed_from_bench(slot_idx: int)

const MAX_BENCH_SLOTS: int = 8
const SLOT_SIZE: Vector2 = Vector2(54, 54)
const SLOT_SPACING: float = 8.0

var bench_slots: Array[HeroEntity] = []
var slot_buttons: Array[PanelContainer] = []
var slots_container: HBoxContainer = null
var _slot_styles: Array[StyleBoxFlat] = []

func _init() -> void:
	bench_slots.resize(MAX_BENCH_SLOTS)
	for i in range(MAX_BENCH_SLOTS):
		bench_slots[i] = null
	custom_minimum_size = Vector2(488, 60)
	size = Vector2(488, 60)
	position = Vector2(332, 478)
	_build_ui()

func _ready() -> void:
	if slots_container == null:
		_build_ui()

func _build_ui() -> void:
	if slots_container != null:
		return
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	slots_container = HBoxContainer.new()
	slots_container.name = "SlotsContainer"
	slots_container.add_theme_constant_override("separation", int(SLOT_SPACING))
	slots_container.position = Vector2(0, 3)
	slots_container.size = Vector2(488, 54)
	slots_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(slots_container)
	
	for i in range(MAX_BENCH_SLOTS):
		var panel := PanelContainer.new()
		panel.name = "BenchSlot_%d" % i
		panel.custom_minimum_size = SLOT_SIZE
		panel.size = SLOT_SIZE
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
		_slot_styles.append(style)
		
		var lbl := Label.new()
		lbl.name = "IndexLabel"
		lbl.text = str(i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color("#475569"))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)
		
		var slot_idx := i
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				bench_slot_clicked.emit(slot_idx)
		)
		
		slots_container.add_child(panel)
		slot_buttons.append(panel)

func highlight_slot(slot_idx: int, highlight: bool) -> void:
	if slot_idx < 0 or slot_idx >= _slot_styles.size():
		return
	var style := _slot_styles[slot_idx]
	if highlight:
		style.border_color = Color("#38bdf8")
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	else:
		style.border_color = Color("#334155")
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2

func has_empty_slot() -> bool:
	for hero in bench_slots:
		if hero == null:
			return true
	return false

func get_first_empty_slot() -> int:
	for i in range(bench_slots.size()):
		if bench_slots[i] == null:
			return i
	return -1

func get_slot_center(slot_idx: int) -> Vector2:
	if slot_idx < 0 or slot_idx >= MAX_BENCH_SLOTS:
		return Vector2.ZERO
	var origin: Vector2 = global_position
	if origin == Vector2.ZERO and position != Vector2.ZERO:
		origin = position
	if slot_idx < slot_buttons.size() and is_instance_valid(slot_buttons[slot_idx]):
		var btn = slot_buttons[slot_idx]
		var btn_pos: Vector2 = btn.global_position
		if btn_pos != Vector2.ZERO:
			return btn_pos + btn.size * 0.5
	var x: float = origin.x + slot_idx * (SLOT_SIZE.x + SLOT_SPACING) + SLOT_SIZE.x * 0.5
	var y: float = origin.y + 3.0 + SLOT_SIZE.y * 0.5
	return Vector2(x, y)

func get_slot_at_position(world_pos: Vector2) -> int:
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		if is_instance_valid(btn):
			var rect: Rect2 = btn.get_global_rect()
			if rect.size != Vector2.ZERO and rect.has_point(world_pos):
				return i
		if world_pos.distance_to(get_slot_center(i)) <= (SLOT_SIZE.x * 0.5 + 4.0):
			return i
	return -1

func get_hero_at_position(world_pos: Vector2) -> HeroEntity:
	var slot := get_slot_at_position(world_pos)
	if slot != -1 and slot < bench_slots.size() and bench_slots[slot] != null and is_instance_valid(bench_slots[slot]):
		return bench_slots[slot]
	for hero in bench_slots:
		if hero != null and is_instance_valid(hero):
			if hero.global_position.distance_to(world_pos) <= 40.0:
				return hero
	return null

func add_hero(hero: HeroEntity, preferred_slot: int = -1) -> int:
	if hero == null or not is_instance_valid(hero):
		return -1
	var target_slot: int = -1
	if preferred_slot >= 0 and preferred_slot < MAX_BENCH_SLOTS and bench_slots[preferred_slot] == null:
		target_slot = preferred_slot
	else:
		target_slot = get_first_empty_slot()
		
	if target_slot == -1:
		return -1
		
	bench_slots[target_slot] = hero
	hero.is_on_bench = true
	hero.set_combat_active(false)
	if hero.status_bar != null:
		hero.status_bar.visible = false
	var center_pos := get_slot_center(target_slot)
	hero.global_position = center_pos
	snap_to_slot(hero, target_slot)
	hero_placed_on_bench.emit(hero, target_slot)
	return target_slot

func remove_hero(slot_idx: int) -> HeroEntity:
	if slot_idx < 0 or slot_idx >= MAX_BENCH_SLOTS:
		return null
	var hero := bench_slots[slot_idx]
	if hero != null:
		bench_slots[slot_idx] = null
		hero.is_on_bench = false
		if hero.status_bar != null:
			hero.status_bar.visible = true
		hero_removed_from_bench.emit(slot_idx)
	return hero

func swap_slots(idx_a: int, idx_b: int) -> void:
	if idx_a < 0 or idx_a >= MAX_BENCH_SLOTS or idx_b < 0 or idx_b >= MAX_BENCH_SLOTS or idx_a == idx_b:
		return
	var temp := bench_slots[idx_a]
	bench_slots[idx_a] = bench_slots[idx_b]
	bench_slots[idx_b] = temp
	
	if bench_slots[idx_a] != null:
		bench_slots[idx_a].global_position = get_slot_center(idx_a)
		snap_to_slot(bench_slots[idx_a], idx_a)
	if bench_slots[idx_b] != null:
		bench_slots[idx_b].global_position = get_slot_center(idx_b)
		snap_to_slot(bench_slots[idx_b], idx_b)

func snap_to_slot(hero: HeroEntity, slot_idx: int) -> void:
	if not is_instance_valid(hero) or slot_idx < 0 or slot_idx >= MAX_BENCH_SLOTS:
		return
	var target_pos := get_slot_center(slot_idx)
	var from_pos := hero.global_position
	hero.global_position = target_pos
	var tween: Tween = create_tween()
	if tween != null:
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(hero, "global_position", target_pos, 0.15).from(from_pos)
