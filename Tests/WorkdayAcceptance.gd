extends Node

var checks_run := 0
var checks_failed := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_workday_rules()
	_test_milestones()
	_test_daily_supply_and_failed_purchase()
	_test_fire_resume()
	print("Workday acceptance: %d checks, %d failures" % [checks_run, checks_failed])
	get_tree().quit(1 if checks_failed > 0 else 0)

func _test_workday_rules() -> void:
	var progress := RunProgressManager.new()
	progress.persistence_enabled = false
	progress.day_elapsed = 119.99
	progress.daily_ash = 12.5
	_check(progress.close_workday(true) < 0.0, "Rest is unavailable before 120 active seconds.")
	_check(progress.day_number == 1 and is_equal_approx(progress.daily_ash, 12.5), "A rejected rest leaves the day and ash untouched.")
	_check(not progress.advance_workday(119.99), "Automatic closure does not happen before 240 active seconds.")
	progress.day_elapsed = 239.5
	_check(progress.advance_workday(0.5), "The day reaches its automatic close at 240 active seconds.")
	var sold_ash := progress.close_workday()
	_check(is_equal_approx(sold_ash, 12.5), "Automatic closure sells all ash earned that day.")
	_check(progress.day_number == 2 and is_zero_approx(progress.day_elapsed), "Closure starts the next day and resets its timer.")
	_check(progress.close_workday() < 0.0 and progress.day_number == 2, "A repeated close cannot sell ash or advance the day twice.")
	progress.day_elapsed = 120.0
	progress.daily_ash = 3.0
	_check(is_equal_approx(progress.close_workday(true), 3.0), "Manual rest is available at exactly 120 active seconds.")
	_check(progress.day_number == 3, "Manual rest advances exactly one day.")
	_check(not GameManager.is_fuel_unlocked("carbon") and not GameManager.is_fuel_unlocked("combustible_liquido"), "Late fuels stay unavailable in the first release.")
	var day_one_burn_seconds := 0.0
	for fuel in FuelCatalog.get_all():
		if fuel.unlock_day == 1:
			day_one_burn_seconds += float(fuel.starting_stock) * fuel.burn_duration
	_check(day_one_burn_seconds >= RunProgressManager.REST_UNLOCK_SECONDS, "Day-one fuel supply lasts until rest becomes available.")
	progress.free()

func _test_milestones() -> void:
	var progress := RunProgressManager.new()
	progress.persistence_enabled = false
	_check(progress.claim_temperature_milestone(100.0) == 1, "The 100 degree milestone grants one ember.")
	_check(progress.claim_temperature_milestone(100.0) == 0, "A claimed milestone cannot grant another ember.")
	_check(progress.claim_temperature_milestone(1000.0) == 2, "Crossing multiple remaining thresholds grants each once.")
	_check(progress.permanent_points == 3 and progress.available_embers == 3, "Milestone rewards update earned and spendable ember totals.")
	progress.free()

func _test_daily_supply_and_failed_purchase() -> void:
	var progress: RunProgressManager = GameManager.run_progress
	var previous_persistence := progress.persistence_enabled
	var previous_day := progress.day_number
	var previous_elapsed := progress.day_elapsed
	var previous_ash := progress.daily_ash
	var previous_silo_ash := progress.silo_ash
	var previous_uncollected_ash := progress.uncollected_ash
	var previous_current_soot := progress.current_soot
	var previous_soot := GameManager.get_soot()
	var previous_stock := GameManager.get_fuel_stock()
	var previous_saved_stock := progress.saved_fuel_stock.duplicate(true)
	progress.persistence_enabled = false
	GameManager.economy.soot = 0.0
	progress.current_soot = 0.0
	var shop := FuelShop.new()
	add_child(shop)
	_check(not shop.buy_fuel("hojarasca"), "A fuel purchase fails cleanly when the player has no soot.")
	GameManager.economy.soot = 50.0
	GameManager.inventory.set_count("hojarasca", InventoryManager.MAX_STOCK_PER_FUEL)
	_check(not shop.buy_fuel("hojarasca") and is_equal_approx(GameManager.get_soot(), 50.0), "A purchase at the fuel stock cap does not consume soot.")
	shop.free()
	for fuel in FuelCatalog.get_all():
		GameManager.inventory.set_count(fuel.fuel_id, 0)
	progress.day_number = 1
	progress.day_elapsed = 120.0
	progress.daily_ash = 3.0
	var sold := GameManager.close_workday(true)
	_check(is_equal_approx(sold, 3.0) and GameManager.get_day_number() == 2, "Closing a day sells its ash and advances once.")
	_check(GameManager.get_fuel_count("tronco") > 0 and GameManager.get_fuel_count("turba") == 0, "The next day supplies unlocked fuels only.")
	_check(GameManager.close_workday(true) < 0.0 and GameManager.get_fuel_count("tronco") > 0, "A duplicate close cannot duplicate the daily delivery.")
	progress.day_number = previous_day
	progress.day_elapsed = previous_elapsed
	progress.daily_ash = previous_ash
	progress.silo_ash = previous_silo_ash
	progress.uncollected_ash = previous_uncollected_ash
	progress.current_soot = previous_current_soot
	progress.saved_fuel_stock = previous_saved_stock
	GameManager.economy.soot = previous_soot
	GameManager.inventory.load_stock(previous_stock)
	progress.persistence_enabled = previous_persistence

func _test_fire_resume() -> void:
	var fire := FireManager.new()
	add_child(fire)
	fire.set_process(false)
	fire.fuel_queue.append(FireManager.FUEL_HOJARASCA)
	fire.fuel_queue.append(FireManager.FUEL_LENA)
	fire.burning = true
	fire.remaining_burn = 1.75
	fire.current_heat = 42.0
	fire.active_quality = 1.16
	fire.stoke_time_left = 4.0
	var saved_state := fire.get_save_state()
	var resumed_fire := FireManager.new()
	add_child(resumed_fire)
	resumed_fire.set_process(false)
	resumed_fire.restore_save_state(saved_state)
	_check(resumed_fire.burning and resumed_fire.fuel_queue.size() == 2, "A closed session restores the active fire and its remaining queue.")
	_check(is_equal_approx(resumed_fire.remaining_burn, 1.75), "Restoring a session preserves the active fuel timer.")
	_check(is_equal_approx(resumed_fire.current_heat, 42.0) and is_equal_approx(resumed_fire.stoke_time_left, 4.0), "Restoring a session preserves heat and remaining active effects.")
	fire.queue_free()
	resumed_fire.queue_free()

func _check(condition: bool, description: String) -> void:
	checks_run += 1
	if not condition:
		checks_failed += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)
