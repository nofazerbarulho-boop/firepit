extends Node
class_name RunProgressManager

signal changed

const PRESTIGE_THRESHOLD := 100.0
const EMBER_RESERVE_CAP := 12.0
const SAVE_PATH := "user://hogueras_save.cfg"
const SAVE_VERSION := 6
const WORKDAY_DURATION_SECONDS := 240.0
const REST_UNLOCK_SECONDS := 120.0
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
var day_number: int = 1
var day_elapsed: float = 0.0
var daily_ash: float = 0.0
var daily_fire_state: Dictionary = {}
var claimed_temperature_milestones: Dictionary = {}
var saved_fuel_stock: Dictionary = {}
var saved_temporary_upgrades: int = 0
var silo_ash: float = 0.0
var uncollected_ash: float = 0.0
var facility_levels: Dictionary = {"warehouse": 0, "silo": 0, "workshop": 0, "garage": 0}
var truck_seconds_left: float = 0.0
var truck_pending: bool = false
var truck_cargo: Dictionary = {}
var experimental_unlocked: Dictionary = {}
var persistence_enabled: bool = true

func load_progress() -> void:
	_reset_campaign_state()
	var save_file := ConfigFile.new()
	var load_error := save_file.load(SAVE_PATH)
	if load_error != OK:
		# Missing or corrupt saves start cleanly; never leave a partial state behind.
		if FileAccess.file_exists(SAVE_PATH):
			_backup_legacy_save()
		save_progress()
		changed.emit()
		return
	var saved_version := maxi(1, _safe_int(save_file.get_value("progress", "version", 1)))
	if saved_version < SAVE_VERSION:
		_backup_legacy_save()
		_reset_campaign_state()
		save_progress()
		changed.emit()
		return
	var saved_automation: Variant = save_file.get_value("run", "automation", {})
	automation_settings = saved_automation.duplicate(true) if saved_automation is Dictionary else {}
	day_number = maxi(1, _safe_int(save_file.get_value("daily", "day_number", 1)))
	day_elapsed = clampf(_safe_float(save_file.get_value("daily", "elapsed", 0.0)), 0.0, WORKDAY_DURATION_SECONDS)
	daily_ash = maxf(0.0, _safe_float(save_file.get_value("daily", "ash", 0.0)))
	var saved_fire_state: Variant = save_file.get_value("daily", "fire_state", {})
	daily_fire_state = saved_fire_state.duplicate(true) if saved_fire_state is Dictionary else {}
	var saved_milestones: Variant = save_file.get_value("daily", "milestones", {})
	claimed_temperature_milestones = saved_milestones.duplicate(true) if saved_milestones is Dictionary else {}
	var stock_value: Variant = save_file.get_value("daily", "fuel_stock", {})
	saved_fuel_stock = stock_value.duplicate(true) if stock_value is Dictionary else {}
	saved_temporary_upgrades = maxi(0, _safe_int(save_file.get_value("daily", "temporary_upgrades", 0)))
	silo_ash = maxf(0.0, _safe_float(save_file.get_value("facilities", "silo_ash", 0.0)))
	uncollected_ash = maxf(0.0, _safe_float(save_file.get_value("facilities", "uncollected_ash", 0.0)))
	var levels: Variant = save_file.get_value("facilities", "levels", facility_levels)
	if levels is Dictionary:
		for key in facility_levels: facility_levels[key] = clampi(_safe_int(levels.get(key, 0)), 0, 3)
	truck_pending = bool(save_file.get_value("logistics", "truck_pending", false))
	truck_seconds_left = clampf(_safe_float(save_file.get_value("logistics", "truck_seconds_left", 0.0)), 0.0, 60.0)
	var cargo: Variant = save_file.get_value("logistics", "truck_cargo", {})
	truck_cargo = cargo.duplicate(true) if cargo is Dictionary else {}
	var tech: Variant = save_file.get_value("technology", "unlocked", {})
	experimental_unlocked = tech.duplicate(true) if tech is Dictionary else {}
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

func _reset_campaign_state() -> void:
	soot_earned = 0.0
	current_soot = 0.0
	permanent_points = 0
	ember_reserve = 0.0
	next_run_ember_reserve = 0.0
	available_embers = 0
	purchased_nodes.clear()
	offline_saved_at = 0
	offline_fuel_seconds = 0.0
	offline_soot_per_second = 0.0
	automation_settings.clear()
	day_number = 1
	day_elapsed = 0.0
	daily_ash = 0.0
	daily_fire_state.clear()
	claimed_temperature_milestones.clear()
	saved_fuel_stock.clear()
	saved_temporary_upgrades = 0
	silo_ash = 0.0
	uncollected_ash = 0.0
	facility_levels = {"warehouse": 0, "silo": 0, "workshop": 0, "garage": 0}
	truck_seconds_left = 0.0
	truck_pending = false
	truck_cargo.clear()
	experimental_unlocked.clear()

func _backup_legacy_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var source := ProjectSettings.globalize_path(SAVE_PATH)
	var backup := ProjectSettings.globalize_path(SAVE_PATH + ".legacy.bak")
	if FileAccess.file_exists(SAVE_PATH + ".legacy.bak"):
		return
	var error := DirAccess.copy_absolute(source, backup)
	if error != OK:
		push_warning("No se pudo respaldar el guardado del prototipo (código %d)." % error)

func save_progress() -> void:
	if not persistence_enabled:
		return
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
	save_file.set_value("daily", "day_number", day_number)
	save_file.set_value("daily", "elapsed", day_elapsed)
	save_file.set_value("daily", "ash", daily_ash)
	save_file.set_value("daily", "fire_state", daily_fire_state.duplicate(true))
	save_file.set_value("daily", "milestones", claimed_temperature_milestones.duplicate(true))
	save_file.set_value("daily", "fuel_stock", saved_fuel_stock.duplicate(true))
	save_file.set_value("daily", "temporary_upgrades", saved_temporary_upgrades)
	save_file.set_value("facilities", "silo_ash", silo_ash)
	save_file.set_value("facilities", "uncollected_ash", uncollected_ash)
	save_file.set_value("facilities", "levels", facility_levels.duplicate(true))
	save_file.set_value("logistics", "truck_pending", truck_pending)
	save_file.set_value("logistics", "truck_seconds_left", truck_seconds_left)
	save_file.set_value("logistics", "truck_cargo", truck_cargo.duplicate(true))
	save_file.set_value("technology", "unlocked", experimental_unlocked.duplicate(true))
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
	daily_ash += amount
	uncollected_ash += amount
	changed.emit()

func close_workday(manual: bool = false) -> float:
	if manual and day_elapsed < REST_UNLOCK_SECONDS:
		return -1.0
	if not manual and day_elapsed < WORKDAY_DURATION_SECONDS:
		return -1.0
	var soot_sale := daily_ash
	silo_ash = 0.0
	uncollected_ash = 0.0
	daily_ash = 0.0
	current_soot += soot_sale
	day_number += 1
	day_elapsed = 0.0
	save_progress()
	changed.emit()
	return soot_sale

func get_facility_capacity(kind: String) -> int:
	var level := int(facility_levels.get(kind, 0))
	return 20 + level * 5 if kind == "warehouse" else (300 + level * 150 if kind == "silo" else level)

func advance_workday(seconds: float) -> bool:
	if seconds <= 0.0:
		return false
	day_elapsed = minf(WORKDAY_DURATION_SECONDS, day_elapsed + seconds)
	return day_elapsed >= WORKDAY_DURATION_SECONDS

func claim_temperature_milestone(temperature: float) -> int:
	var awarded := 0
	for threshold in [100, 500, 1000]:
		var key := str(threshold)
		if temperature >= float(threshold) and not bool(claimed_temperature_milestones.get(key, false)):
			claimed_temperature_milestones[key] = true
			permanent_points += 1
			available_embers += 1
			awarded += 1
	if awarded > 0:
		save_progress()
		changed.emit()
	return awarded

func get_next_temperature_milestone() -> int:
	for threshold in [100, 500, 1000]:
		if not bool(claimed_temperature_milestones.get(str(threshold), false)):
			return threshold
	return 0

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
	return 0.0

func get_soot_bonus() -> float:
	return 0.0

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
