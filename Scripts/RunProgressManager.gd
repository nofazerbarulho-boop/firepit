extends Node
class_name RunProgressManager

signal changed

const PRESTIGE_THRESHOLD := 100.0
const EMBER_RESERVE_CAP := 12.0
const SAVE_PATH := "user://hogueras_save.cfg"
const SAVE_VERSION := 3
const ADVANCED_TREE_THRESHOLD := 5
const OFFLINE_CAP_SECONDS := 8.0 * 60.0 * 60.0

var soot_earned: float = 0.0
var current_soot: float = 0.0
var permanent_points: int = 0
var ember_reserve: float = 0.0
var next_run_ember_reserve: float = 0.0
var available_embers: int = 0
var purchased_nodes: Dictionary = {}
var offline_saved_at: int = 0
var offline_fuel_seconds: float = 0.0
var offline_soot_per_second: float = 0.0
var automation_settings: Dictionary = {}

func load_progress() -> void:
	var save_file := ConfigFile.new()
	var load_error := save_file.load(SAVE_PATH)
	if load_error != OK:
		# Missing or corrupt saves start cleanly; never leave a partial state behind.
		permanent_points = 0
		soot_earned = 0.0
		current_soot = 0.0
		available_embers = 0
		next_run_ember_reserve = 0.0
		purchased_nodes.clear()
		offline_saved_at = 0
		offline_fuel_seconds = 0.0
		offline_soot_per_second = 0.0
		automation_settings.clear()
		changed.emit()
		return
	var saved_version := maxi(1, _safe_int(save_file.get_value("progress", "version", 1)))
	var saved_automation: Variant = save_file.get_value("run", "automation", {})
	automation_settings = saved_automation.duplicate(true) if saved_automation is Dictionary else {}
	offline_saved_at = maxi(0, _safe_int(save_file.get_value("offline", "saved_at", 0)))
	offline_fuel_seconds = clampf(_safe_float(save_file.get_value("offline", "fuel_seconds", 0.0)), 0.0, OFFLINE_CAP_SECONDS)
	offline_soot_per_second = maxf(0.0, _safe_float(save_file.get_value("offline", "soot_per_second", 0.0)))
	permanent_points = maxi(0, _safe_int(save_file.get_value("progress", "embers", 0)))
	soot_earned = maxf(0.0, _safe_float(save_file.get_value("run", "soot_earned", 0.0)))
	current_soot = maxf(0.0, _safe_float(save_file.get_value("run", "current_soot", 0.0)))
	# Version 1 had no separate wallet or tree. Treat all earned embers as available.
	available_embers = maxi(0, _safe_int(save_file.get_value("progress", "available_embers", permanent_points)))
	available_embers = mini(available_embers, permanent_points)
	next_run_ember_reserve = clampf(_safe_float(save_file.get_value("progress", "ember_reserve", 0.0)), 0.0, EMBER_RESERVE_CAP)
	purchased_nodes.clear()
	var saved_nodes: Variant = save_file.get_value("progress", "permanent_nodes", {}) if saved_version >= 2 else {}
	if saved_nodes is Dictionary:
		for node_id in ["thermal_1", "thermal_2", "thermal_advanced", "soot_1", "soot_2", "soot_advanced"]:
			if bool(saved_nodes.get(node_id, false)) and _is_valid_node_id(node_id) and _has_saved_node_prerequisite(node_id):
				purchased_nodes[node_id] = true
	changed.emit()

func save_progress() -> void:
	var save_file := ConfigFile.new()
	save_file.set_value("progress", "embers", permanent_points)
	save_file.set_value("progress", "available_embers", available_embers)
	save_file.set_value("progress", "ember_reserve", next_run_ember_reserve)
	save_file.set_value("progress", "version", SAVE_VERSION)
	save_file.set_value("progress", "permanent_nodes", purchased_nodes.duplicate())
	save_file.set_value("run", "soot_earned", soot_earned)
	save_file.set_value("run", "current_soot", current_soot)
	save_file.set_value("run", "automation", automation_settings.duplicate(true))
	save_file.set_value("offline", "saved_at", offline_saved_at)
	save_file.set_value("offline", "fuel_seconds", offline_fuel_seconds)
	save_file.set_value("offline", "soot_per_second", offline_soot_per_second)
	var save_error := save_file.save(SAVE_PATH)
	if save_error != OK:
		push_warning("No se pudo guardar el progreso permanente (código %d)." % save_error)

func record_session_exit(fuel_seconds: float, soot_per_second: float, current_run_soot: float, saved_automation: Dictionary) -> void:
	offline_fuel_seconds = clampf(fuel_seconds, 0.0, OFFLINE_CAP_SECONDS)
	offline_soot_per_second = maxf(0.0, soot_per_second)
	current_soot = maxf(0.0, current_run_soot)
	automation_settings = saved_automation.duplicate(true)
	offline_saved_at = int(Time.get_unix_time_from_system())
	save_progress()

func claim_offline_progress() -> Dictionary:
	if offline_saved_at <= 0 or offline_fuel_seconds <= 0.0 or offline_soot_per_second <= 0.0:
		return {"seconds": 0, "soot": 0.0}
	var now := int(Time.get_unix_time_from_system())
	var elapsed := clampf(float(maxi(0, now - offline_saved_at)), 0.0, OFFLINE_CAP_SECONDS)
	var active_seconds := minf(elapsed, offline_fuel_seconds)
	var soot_reward := active_seconds * offline_soot_per_second
	offline_fuel_seconds = maxf(0.0, offline_fuel_seconds - active_seconds)
	offline_saved_at = now
	current_soot += soot_reward
	soot_earned += soot_reward
	save_progress()
	return {"seconds": int(floor(active_seconds)), "soot": soot_reward}

func get_automation_settings() -> Dictionary:
	return automation_settings.duplicate(true)

func record_soot(amount: float) -> void:
	if amount <= 0.0:
		return
	soot_earned += amount
	current_soot += amount
	changed.emit()

func record_spend_soot(amount: float) -> void:
	if amount > 0.0:
		current_soot = maxf(0.0, current_soot - amount)

func add_ember_reserve(heat: float) -> void:
	if heat <= 0.0:
		return
	ember_reserve = minf(EMBER_RESERVE_CAP, ember_reserve + heat * 0.2)
	changed.emit()

func consume_next_run_ember_reserve() -> float:
	var reserve := next_run_ember_reserve
	if reserve <= 0.0:
		return 0.0
	next_run_ember_reserve = 0.0
	save_progress()
	changed.emit()
	return reserve

func award_prestige() -> int:
	var points := int(floor(soot_earned / PRESTIGE_THRESHOLD))
	if points < 1:
		return 0
	permanent_points += points
	available_embers += points
	next_run_ember_reserve = minf(EMBER_RESERVE_CAP, ember_reserve)
	automation_settings.clear()
	reset_run_progress()
	save_progress()
	changed.emit()
	return points

func reset_run_progress() -> void:
	soot_earned = 0.0
	current_soot = 0.0
	ember_reserve = 0.0
	changed.emit()

func get_progress_to_next_prestige() -> float:
	return fposmod(soot_earned, PRESTIGE_THRESHOLD)

func can_afford_embers(cost: int) -> bool:
	return cost >= 0 and available_embers >= cost

func spend_embers(cost: int) -> bool:
	if not can_afford_embers(cost):
		return false
	available_embers -= cost
	changed.emit()
	return true

func owns_node(node_id: String) -> bool:
	return bool(purchased_nodes.get(node_id, false))

func purchase_node(node_id: String, cost: int) -> bool:
	if owns_node(node_id) or not spend_embers(cost):
		return false
	purchased_nodes[node_id] = true
	save_progress()
	changed.emit()
	return true

func has_advanced_tree() -> bool:
	return permanent_points >= ADVANCED_TREE_THRESHOLD

func get_thermal_bonus() -> float:
	var bonus := 0.0
	if owns_node("thermal_1"):
		bonus += 0.10
	if owns_node("thermal_2"):
		bonus += 0.15
	if owns_node("thermal_advanced"):
		bonus += 0.25
	return bonus

func get_soot_bonus() -> float:
	var bonus := 0.0
	if owns_node("soot_1"):
		bonus += 0.10
	if owns_node("soot_2"):
		bonus += 0.15
	if owns_node("soot_advanced"):
		bonus += 0.25
	return bonus

func _safe_float(value: Variant) -> float:
	if value is float or value is int:
		var number := float(value)
		return number if is_finite(number) else 0.0
	return 0.0

func _safe_int(value: Variant) -> int:
	if value is int or value is float:
		var number := float(value)
		if is_finite(number):
			return int(number)
	return 0

func _has_saved_node_prerequisite(node_id: String) -> bool:
	if node_id.ends_with("_advanced"):
		return permanent_points >= ADVANCED_TREE_THRESHOLD and owns_node(node_id.replace("_advanced", "_2"))
	if node_id.ends_with("_2"):
		return owns_node(node_id.replace("_2", "_1"))
	return true

func _is_valid_node_id(node_id: String) -> bool:
	return node_id in ["thermal_1", "thermal_2", "thermal_advanced", "soot_1", "soot_2", "soot_advanced"]
