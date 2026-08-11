extends Node

# ==========================================
# EVENT BUS - GLOBAL SIGNAL ROUTER
# Chú ý (Rule 15): Không dùng EventBus cho logic Combat (deal_damage, add_xp, v.v.)
# Chỉ dùng cho các thay đổi State ở cấp độ toàn hệ thống hoặc UI cập nhật.
# ==========================================

# Phát ra khi GameManager thay đổi State
signal game_state_changed(new_state: int, old_state: int)

# (Các signal toàn cục khác như cập nhật Vàng, UI sẽ được thêm vào các Sprint sau)
