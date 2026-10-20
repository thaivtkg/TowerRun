class_name InventoryPanel
extends Control

# ==========================================
# INVENTORY BENCH PANEL (SPRINT 6 - TASK S6.2)
# Quản lý 10 ô chứa đồ và thao tác ghép đồ
# ==========================================

signal slot_clicked(slot_idx: int)
signal item_crafted_ui(item: ItemData, slot_idx: int)

@export var max_slots: int = 10
var selected_slot: int = -1

func _ready() -> void:
	if ItemManager != null:
		ItemManager.item_crafted.connect(_on_item_crafted)

func select_slot(idx: int) -> void:
	if idx < 0 or idx >= max_slots:
		return
	if selected_slot == -1:
		selected_slot = idx
		slot_clicked.emit(idx)
	else:
		# Thử ghép từ selected_slot sang idx
		if ItemManager != null and ItemManager.craft_on_bench(selected_slot, idx):
			selected_slot = -1
		else:
			selected_slot = idx
			slot_clicked.emit(idx)

func get_item_at(idx: int) -> ItemData:
	if ItemManager != null and idx >= 0 and idx < ItemManager.bench_slots.size():
		return ItemManager.bench_slots[idx]
	return null

func _on_item_crafted(item: ItemData, slot_idx: int) -> void:
	item_crafted_ui.emit(item, slot_idx)
