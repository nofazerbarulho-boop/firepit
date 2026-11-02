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
	economy.temporary_upgrades = run_progress.saved_temporary_upgrades
	inventory.load_stock(run_progress.saved_fuel_stock)
	inventory.set_capacity(run_progress.get_facility_capacity("warehouse"))
	var has_saved_daily_stock: bool = not run_progress.saved_fuel_stock.is_empty()
	for fuel_data in FuelCatalog.get_all():
		if not has_saved_daily_stock and not is_fuel_unlocked(fuel_data.fuel_id):
			inventory.set_count(fuel_data.fuel_id, 0)
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
		{"id": "thermal_1", "branch": "combustion", "name": "Habilidad I", "cost": 1, "effect": "Efecto por definir", "requires": "", "advanced": false},
		{"id": "thermal_2", "branch": "combustion", "name": "Habilidad II", "cost": 2, "effect": "Efecto por definir", "requires": "thermal_1", "advanced": false},
		{"id": "thermal_advanced", "branch": "combustion", "name": "Habilidad III", "cost": 3, "effect": "Efecto por definir", "requires": "thermal_1", "advanced": false},
		{"id": "soot_1", "branch": "soot", "name": "Habilidad IV", "cost": 4, "effect": "Efecto por definir", "requires": "thermal_1", "advanced": false},
		{"id": "soot_2", "branch": "soot", "name": "Habilidad V", "cost": 5, "effect": "Efecto por definir", "requires": "thermal_advanced", "advanced": false},
		{"id": "soot_advanced", "branch": "soot", "name": "Habilidad VI", "cost": 6, "effect": "Efecto por definir", "requires": "soot_1", "advanced": false}
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

func is_fuel_unlocked(fuel_id: String) -> bool:
	var fuel_data := FuelCatalog.get_by_id(fuel_id)
	return fuel_data != null and run_progress.day_number >= fuel_data.unlock_day

func get_run_ember_reserve() -> float:
	return run_progress.ember_reserve

func get_next_run_ember_reserve() -> float:
	return run_progress.next_run_ember_reserve

func get_prestige_progress() -> float:
	return run_progress.get_progress_to_next_prestige()

func add_soot(amount: float) -> void:
	run_progress.record_soot(amount)

func advance_workday(seconds: float) -> bool:
	return run_progress.advance_workday(seconds)

func close_workday() -> float:
	var sold_ash: float = run_progress.close_workday()
	economy.soot = run_progress.current_soot
	for fuel_data in FuelCatalog.get_all():
		if is_fuel_unlocked(fuel_data.fuel_id):
			inventory.add_fuel_stock(fuel_data.fuel_id, fuel_data.starting_stock)
	_save_daily_state()
	return sold_ash

func save_daily_state() -> void:
	_save_daily_state()

func get_day_number() -> int:
	return run_progress.day_number

func get_day_elapsed() -> float:
	return run_progress.day_elapsed

func get_daily_ash() -> float:
	return run_progress.daily_ash

func get_silo_ash() -> float: return run_progress.silo_ash
func get_uncollected_ash() -> float: return run_progress.uncollected_ash
func get_silo_capacity() -> int: return run_progress.get_facility_capacity("silo")
func get_warehouse_capacity() -> int: return run_progress.get_facility_capacity("warehouse")
func get_facility_level(kind: String) -> int: return int(run_progress.facility_levels.get(kind, 0))

func purchase_facility(kind: String) -> bool:
	if not kind in ["warehouse", "silo", "workshop", "garage"]: return false
	var level := get_facility_level(kind)
	if level >= 3: return false
	var cost := 50.0 * pow(1.5, level)
	if not spend_soot(cost): return false
	run_progress.facility_levels[kind] = level + 1
	if kind == "warehouse": inventory.set_capacity(get_warehouse_capacity())
	_save_daily_state()
	return true

func transfer_ash_to_silo() -> float:
	var room := maxf(0.0, float(get_silo_capacity()) - run_progress.silo_ash)
	var moved := minf(50.0, minf(room, run_progress.uncollected_ash))
	run_progress.uncollected_ash -= moved
	run_progress.silo_ash += moved
	_save_daily_state()
	return moved

func dispatch_wagon() -> bool:
	if run_progress.truck_pending: return false
	if run_progress.uncollected_ash <= 0.0 or run_progress.silo_ash >= get_silo_capacity(): return false
	run_progress.truck_pending = true
	run_progress.truck_seconds_left = 10.0
	_save_daily_state()
	return true

func advance_logistics(delta: float) -> void:
	var completed_delivery := false
	if run_progress.truck_pending:
		run_progress.truck_seconds_left = maxf(0.0, run_progress.truck_seconds_left - delta)
		if run_progress.truck_seconds_left <= 0.0:
			if run_progress.truck_cargo.has("fuel"):
				for id in run_progress.truck_cargo.fuel: add_fuel_stock(str(id), int(run_progress.truck_cargo.fuel[id]))
				run_progress.truck_cargo.clear()
			else:
				transfer_ash_to_silo()
			run_progress.truck_pending = false
			completed_delivery = true
	if get_facility_level("workshop") > 0 and not run_progress.truck_pending and run_progress.uncollected_ash > 0.0 and run_progress.silo_ash < get_silo_capacity():
		dispatch_wagon()
	if completed_delivery: _save_daily_state()

func request_fuel_truck() -> bool:
	if run_progress.truck_pending or not spend_soot(25.0): return false
	var level := get_facility_level("garage")
	var cargo := {}
	for fuel in FuelCatalog.get_all():
		if is_fuel_unlocked(fuel.fuel_id): cargo[fuel.fuel_id] = level + 1
	run_progress.truck_pending = true
	run_progress.truck_seconds_left = maxf(30.0, 60.0 - 15.0 * level)
	run_progress.truck_cargo = {"fuel": cargo}
	_save_daily_state()
	return true

func get_truck_seconds_left() -> float: return run_progress.truck_seconds_left
func is_truck_pending() -> bool: return run_progress.truck_pending
func get_tech_unlocked(id: String) -> bool: return bool(run_progress.experimental_unlocked.get(id, false))

func unlock_experimental(id: String) -> bool:
	var thresholds := {"gas": 100, "tritium": 500, "laser": 1000}
	if not thresholds.has(id) or get_tech_unlocked(id) or not bool(run_progress.claimed_temperature_milestones.get(str(thresholds[id]), false)): return false
	if id == "tritium" and not get_tech_unlocked("gas"): return false
	if id == "laser" and not get_tech_unlocked("tritium"): return false
	if not run_progress.spend_embers(1): return false
	run_progress.experimental_unlocked[id] = true
	_save_daily_state()
	return true

func activate_experimental(id: String) -> bool:
	if not get_tech_unlocked(id): return false
	var price := 25.0 if id in ["gas", "tritium"] else 50.0
	if not spend_soot(price): return false
	return true

func get_next_temperature_milestone() -> int:
	return run_progress.get_next_temperature_milestone()

func claim_temperature_milestones(temperature: float) -> int:
	return run_progress.claim_temperature_milestone(temperature)

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

func can_store_fuel(amount: int = 1) -> bool:
	return inventory.can_add_fuel(amount)

func reset_inventory() -> void:
	inventory.reset_to_starting_stock()

func begin_new_run() -> void:
	economy.reset_for_new_run()
	inventory.reset_to_starting_stock()
	run_progress.reset_run_progress()

func buy_upgrade() -> bool:
	var cost: float = economy.get_upgrade_cost()
	if not economy.buy_upgrade():
		return false
	run_progress.record_spend_soot(cost)
	return true

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
	if run_progress != null and economy != null:
		run_progress.saved_temporary_upgrades = economy.temporary_upgrades
	economy_changed.emit()

func _on_inventory_changed() -> void:
	if run_progress != null and inventory != null:
		run_progress.saved_fuel_stock = inventory.get_stock()
	inventory_changed.emit()

func _save_daily_state() -> void:
	run_progress.saved_fuel_stock = inventory.get_stock()
	run_progress.saved_temporary_upgrades = economy.temporary_upgrades
	run_progress.current_soot = economy.soot
	run_progress.save_progress()
