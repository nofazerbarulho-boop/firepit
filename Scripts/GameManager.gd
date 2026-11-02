extends Node

signal economy_changed
signal inventory_changed

const EconomyModule = preload("res://Scripts/EconomyManager.gd")
const InventoryModule = preload("res://Scripts/InventoryManager.gd")
const RunProgressModule = preload("res://Scripts/RunProgressManager.gd")
const PRESTIGE_THRESHOLD := 100.0
const SOOT_OUTPUT_SCALE := 0.015
const EMBER_RESERVE_CAP := 12.0

var economy: Variant
var inventory: Variant
var run_progress: Variant

# Read-only compatibility properties. Game systems should use the getters below.
var soot: float:
	get: return economy.soot
var run_soot_earned: float:
	get: return run_progress.soot_earned
var permanent_points: int:
	get: return run_progress.permanent_points
var temporary_upgrades: int:
	get: return economy.temporary_upgrades
var fuel_stock: Dictionary:
	get: return inventory.get_stock()
var run_ember_reserve: float:
	get: return run_progress.ember_reserve
var next_run_ember_reserve: float:
	get: return run_progress.next_run_ember_reserve
var global_multiplier: float:
	get: return get_global_multiplier()

func _ready() -> void:
	economy = EconomyModule.new()
	economy.name = "Economy"
	add_child(economy)
	economy.changed.connect(_on_economy_changed)

	inventory = InventoryModule.new()
	inventory.name = "Inventory"
	add_child(inventory)
	inventory.changed.connect(_on_inventory_changed)

	run_progress = RunProgressModule.new()
	run_progress.name = "RunProgress"
	add_child(run_progress)
	run_progress.load_progress()
	economy.soot = run_progress.current_soot
	run_progress.changed.connect(_on_economy_changed)

func get_soot() -> float:
	return economy.soot

func get_run_soot_earned() -> float:
	return run_progress.soot_earned

func get_permanent_points() -> int:
	return run_progress.permanent_points

func get_temporary_upgrades() -> int:
	return economy.temporary_upgrades

func get_global_multiplier() -> float:
	return economy.get_multiplier(run_progress.permanent_points) * (1.0 + run_progress.get_soot_bonus())

func get_thermal_multiplier() -> float:
	return 1.0 + run_progress.get_thermal_bonus()

func get_available_embers() -> int:
	return run_progress.available_embers

func has_advanced_tree() -> bool:
	return run_progress.has_advanced_tree()

func get_advanced_tree_progress() -> String:
	return "%d / %d brasas ganadas" % [mini(run_progress.permanent_points, RunProgressModule.ADVANCED_TREE_THRESHOLD), RunProgressModule.ADVANCED_TREE_THRESHOLD]

func get_permanent_nodes() -> Array[Dictionary]:
	return [
		{"id": "thermal_1", "branch": "combustion", "name": "Lecho caliente", "cost": 2, "effect": "+10% de calor", "requires": "", "advanced": false},
		{"id": "thermal_2", "branch": "combustion", "name": "Tiro constante", "cost": 4, "effect": "+15% de calor", "requires": "thermal_1", "advanced": false},
		{"id": "thermal_advanced", "branch": "combustion", "name": "Corazón de brasa", "cost": 6, "effect": "+25% de calor", "requires": "thermal_2", "advanced": true},
		{"id": "soot_1", "branch": "soot", "name": "Carbonilla fina", "cost": 2, "effect": "+10% de hollín", "requires": "", "advanced": false},
		{"id": "soot_2", "branch": "soot", "name": "Condensador", "cost": 4, "effect": "+15% de hollín", "requires": "soot_1", "advanced": false},
		{"id": "soot_advanced", "branch": "soot", "name": "Veta negra", "cost": 6, "effect": "+25% de hollín", "requires": "soot_2", "advanced": true}
	]

func owns_permanent_node(node_id: String) -> bool:
	return run_progress.owns_node(node_id)

func can_purchase_permanent_node(node: Dictionary) -> bool:
	if owns_permanent_node(str(node.id)):
		return false
	if bool(node.advanced) and not has_advanced_tree():
		return false
	var requirement := str(node.requires)
	if not requirement.is_empty() and not owns_permanent_node(requirement):
		return false
	return run_progress.can_afford_embers(int(node.cost))

func purchase_permanent_node(node_id: String) -> bool:
	for node in get_permanent_nodes():
		if str(node.id) == node_id and can_purchase_permanent_node(node):
			return run_progress.purchase_node(node_id, int(node.cost))
	return false

func get_soot_rate(heat: float) -> float:
	return economy.get_soot_rate(heat, get_global_multiplier())

func get_upgrade_cost() -> float:
	return economy.get_upgrade_cost()

func get_fuel_stock() -> Dictionary:
	return inventory.get_stock()

func get_fuel_count(fuel_id: String) -> int:
	return inventory.get_count(fuel_id)

func get_run_ember_reserve() -> float:
	return run_progress.ember_reserve

func get_next_run_ember_reserve() -> float:
	return run_progress.next_run_ember_reserve

func get_prestige_progress() -> float:
	return run_progress.get_progress_to_next_prestige()

func add_soot(amount: float) -> void:
	economy.add_soot(amount)
	run_progress.record_soot(amount)

func record_session_exit(fuel_seconds: float, soot_per_second: float, current_run_soot: float, automation_settings: Dictionary) -> void:
	run_progress.record_session_exit(fuel_seconds, soot_per_second, current_run_soot, automation_settings)

func get_automation_settings() -> Dictionary:
	return run_progress.get_automation_settings()

func claim_offline_progress() -> Dictionary:
	var offline_result: Dictionary = run_progress.claim_offline_progress()
	economy.soot = run_progress.current_soot
	return offline_result

func spend_soot(amount: float) -> bool:
	if not economy.spend_soot(amount):
		return false
	run_progress.record_spend_soot(amount)
	return true

func take_fuel(fuel_id: String) -> bool:
	return inventory.take_fuel(fuel_id)

func return_fuel(fuel_id: String) -> void:
	inventory.return_fuel(fuel_id)

func add_fuel_stock(fuel_id: String, amount: int = 1) -> bool:
	return inventory.add_fuel_stock(fuel_id, amount)

func reset_inventory() -> void:
	inventory.reset_to_starting_stock()

func begin_new_run() -> void:
	economy.reset_for_new_run()
	inventory.reset_to_starting_stock()
	run_progress.reset_run_progress()

func buy_upgrade() -> bool:
	return economy.buy_upgrade()

func add_run_ember_reserve(heat: float) -> void:
	run_progress.add_ember_reserve(heat)

func consume_next_run_ember_reserve() -> float:
	return run_progress.consume_next_run_ember_reserve()

func prestige() -> int:
	var awarded: int = run_progress.award_prestige()
	if awarded <= 0:
		return 0
	economy.reset_for_new_run()
	inventory.reset_to_starting_stock()
	economy_changed.emit()
	return awarded

func _load_progress() -> void:
	run_progress.load_progress()

func _save_progress() -> void:
	run_progress.save_progress()

func _on_economy_changed() -> void:
	economy_changed.emit()

func _on_inventory_changed() -> void:
	inventory_changed.emit()
