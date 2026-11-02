extends Node

var save_existed := false
var saved_progress := ""
var test_log: FileAccess
var checks_run := 0
var checks_failed := 0
var checks_skipped := 0
var test_log_path := ""
var save_write_available := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_open_test_log()
	_log_line("RUN", "Sprint 0-5 regression")
	_backup_saved_progress()
	GameManager.begin_new_run()
	GameManager.run_progress.offline_saved_at = 0
	GameManager.run_progress.offline_fuel_seconds = 0.0
	GameManager.run_progress.offline_soot_per_second = 0.0
	GameManager.run_progress.ember_reserve = 0.0
	GameManager.run_progress.next_run_ember_reserve = 0.0
	GameManager.run_progress.automation_settings.clear()
	var starting_points := GameManager.get_permanent_points()
	_check(GameManager.prestige() == 0, "Una run sin hollín suficiente no debe conceder brasas.")
	_check(not GameManager.buy_upgrade(), "La mejora debe fallar si no hay hollín suficiente.")

	var main_scene := load("res://Scenes/main.tscn") as PackedScene
	_check(main_scene != null, "La escena principal debe cargar.")
	var main := main_scene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	var fire := main.get_node("FireManager") as FireManager
	_check(fire != null, "La escena debe contener FireManager.")
	fire.clear_for_new_run()
	GameManager.reset_inventory()
	var main_second_fire := main.get_node("FireManager2") as FireManager
	main_second_fire.clear_for_new_run()
	var strategy_fire := FireManager.new()
	strategy_fire.name = "Sprint2ValidationFire"
	strategy_fire.has_private_inventory = true
	strategy_fire.uses_ember_reserve = false
	strategy_fire.set_process(false)
	get_tree().root.add_child(strategy_fire)
	await get_tree().process_frame
	_check(is_instance_valid(strategy_fire), "Debe poder crearse una hoguera aislada para validar Sprint 2.")
	_check(_check_mix_quality(strategy_fire, [FireManager.FUEL_HOJARASCA, FireManager.FUEL_LENA], 1.16), "Hojarasca seguida de leña suma 12% de secuencia y 4% de variedad.")
	_check(_check_mix_quality(strategy_fire, [FireManager.FUEL_LENA, FireManager.FUEL_TRONCO], 1.16), "Leña seguida de tronco suma 12% de secuencia y 4% de variedad.")
	_check(_check_mix_quality(strategy_fire, [FireManager.FUEL_HOJARASCA, FireManager.FUEL_LENA, FireManager.FUEL_TRONCO], 1.32), "La receta completa suma 12% por cada transición y 4% por cada tipo adicional.")
	_check(_check_mix_quality(strategy_fire, [FireManager.FUEL_LENA, FireManager.FUEL_LENA, FireManager.FUEL_LENA], 0.96), "Cada repetición consecutiva resta 2% de calidad.")
	strategy_fire.fuel_queue.clear()
	strategy_fire.fuel_queue.append_array([FireManager.FUEL_HOJARASCA, FireManager.FUEL_LENA, FireManager.FUEL_TRONCO])
	_check(strategy_fire.ignite(), "La pila de estrategia debe encenderse.")
	_check(strategy_fire.get_current_phase().contains("Encendido"), "La hojarasca muestra la fase de encendido.")
	var expected_ignition_heat := FireManager.FUEL_HOJARASCA.heat_value * 1.2 * 1.32 * GameManager.get_thermal_multiplier() * 0.5
	strategy_fire._process(0.5)
	_check(is_equal_approx(strategy_fire.current_heat, expected_ignition_heat), "La hojarasca aporta 20% más calor durante el encendido.")
	strategy_fire._process(2.5)
	_check(strategy_fire.get_current_phase().contains("Mantenimiento"), "La leña muestra la fase de mantenimiento.")
	strategy_fire._process(FireManager.FUEL_LENA.burn_duration)
	_check(strategy_fire.get_current_phase().contains("Combustión larga"), "El tronco muestra combustión larga según su fase de datos.")
	strategy_fire._process(FireManager.FUEL_TRONCO.burn_duration)
	_check(not strategy_fire.burning, "La secuencia de Sprint 2 termina al agotarse sus duraciones de combustible.")
	var reserve_probe := RunProgressManager.new()
	reserve_probe.add_ember_reserve(20.0)
	_check(is_equal_approx(reserve_probe.ember_reserve, 4.0), "La reserva convierte 20% del calor acumulado en brasas recuperables.")
	reserve_probe.add_ember_reserve(1000.0)
	_check(is_equal_approx(reserve_probe.ember_reserve, GameManager.EMBER_RESERVE_CAP), "La reserva térmica nunca supera el límite de 12.")
	reserve_probe.free()
	GameManager.run_progress.ember_reserve = 0.0
	strategy_fire.clear_for_new_run()
	strategy_fire.fuel_queue.append(FireManager.FUEL_HOJARASCA)
	_check(strategy_fire.ignite(), "Una pila corta también puede encenderse para medir su reserva sin alcanzar el límite.")
	strategy_fire._process(FireManager.FUEL_HOJARASCA.burn_duration)
	var expected_reserve := minf(GameManager.EMBER_RESERVE_CAP, FireManager.FUEL_HOJARASCA.heat_value * 1.2 * FireManager.FUEL_HOJARASCA.burn_duration * GameManager.get_thermal_multiplier() * 0.2)
	_check(is_equal_approx(GameManager.get_run_ember_reserve(), expected_reserve), "Al terminar una pila se reserva exactamente 20% del calor, por debajo del límite.")
	var guidance := main.get("guidance_label") as Label
	var ignite_button := main.get("ignite_button") as Button
	var mix_quality_label := main.get("mix_label") as Label
	var stoke_button := main.get("stoke_button") as Button
	_check(guidance.text.contains("Pila vacía"), "El HUD debe explicar cómo avanzar desde la pila vacía.")
	_check(ignite_button.disabled and ignite_button.tooltip_text.contains("Añade combustible"), "El botón de encendido debe explicar por qué está deshabilitado.")
	_check(stoke_button.text.contains("12 s") and stoke_button.tooltip_text.contains("encendida"), "El HUD de Avivar muestra duración y requisito de fuego activo.")
	var shop := FuelShop.new()
	get_tree().root.add_child(shop)
	_check(not shop.buy_fuel("tronco"), "La tienda debe rechazar compras sin hollín.")
	_check(GameManager.get_fuel_count("tronco") == 3, "Una compra fallida no debe cambiar el inventario.")

	for _index in range(4):
		_check(fire.add_fuel("hojarasca"), "Debe poder cargar la hojarasca inicial.")
	for _index in range(4):
		_check(fire.add_fuel("leña"), "Debe poder cargar la leña inicial.")
	for _index in range(3):
		_check(fire.add_fuel("tronco"), "Debe poder cargar los troncos iniciales.")
	_check(fire.fuel_queue[0].fuel_id == "hojarasca", "La pila debe conservar el orden añadido.")
	_check(fire.get_queue_quality() > 1.0, "La receta encadenada debe mejorar la calidad.")
	_check(fire.remove_last_fuel(), "Debe poder retirar la última carga antes de encender.")
	_check(GameManager.get_fuel_count("tronco") == 1, "Retirar una carga debe devolverla al inventario.")
	_check(fire.add_fuel("tronco"), "Debe poder volver a cargar el tronco retirado.")
	await get_tree().create_timer(0.11).timeout
	_check(guidance.text.contains("Pila preparada"), "El HUD debe indicar que la mezcla ya está lista para encender.")
	_check(mix_quality_label.text.contains("116%"), "El HUD muestra el porcentaje de calidad de la mezcla preparada.")

	fire.set_process(false)
	_check(fire.ignite(), "Debe encenderse con combustible cargado.")
	fire._process(12.0)
	_check(fire.fuel_queue[0].fuel_id == "leña", "La hojarasca debe consumirse antes que la leña.")
	fire._process(24.0)
	_check(fire.fuel_queue[0].fuel_id == "tronco", "La leña debe consumirse antes que los troncos.")
	fire._process(24.0)
	_check(not fire.burning and fire.fuel_queue.is_empty(), "La pila inicial debe agotarse en 60 segundos simulados.")
	_check(GameManager.get_run_soot_earned() > 119.88, "La mezcla ordenada y el encendido deben superar la producción base histórica.")
	_check(not fire.add_fuel("tronco"), "No debe poder cargarse combustible agotado.")

	var heat_before_cooling := fire.current_heat
	fire._process(0.5)
	_check(fire.current_heat < heat_before_cooling, "El calor debe decaer al apagarse.")
	fire._process(1000.0)
	_check(is_zero_approx(fire.current_heat), "La hoguera debe enfriarse hasta cero.")
	strategy_fire.clear_for_new_run()
	_check(not strategy_fire.stoke(), "Avivar debe fallar si no hay fuego activo.")
	strategy_fire.fuel_queue.append(FireManager.FUEL_HOJARASCA)
	for _index in range(5):
		strategy_fire.fuel_queue.append(FireManager.FUEL_HOJARASCA)
	GameManager.spend_soot(GameManager.get_soot())
	_check(strategy_fire.ignite(), "La hoguera de prueba puede encenderse antes de avivar.")
	_check(not strategy_fire.stoke(), "Avivar debe fallar sin los 15 de hollín requeridos.")
	GameManager.add_soot(20.0)
	var soot_before_stoke := GameManager.get_soot()
	_check(strategy_fire.stoke(), "Avivar funciona con fuego activo y saldo suficiente.")
	_check(is_equal_approx(GameManager.get_soot(), soot_before_stoke - FireManager.STOKE_COST), "Avivar descuenta exactamente 15 de hollín.")
	_check(is_equal_approx(strategy_fire.stoke_time_left, FireManager.STOKE_DURATION), "Avivar activa una duración de 12 segundos.")
	var soot_earned_before_stoke_tick := GameManager.get_run_soot_earned()
	var stoked_heat_rate := FireManager.FUEL_HOJARASCA.heat_value * 1.2 * strategy_fire.active_quality * GameManager.get_thermal_multiplier()
	var expected_stoked_soot := GameManager.get_soot_rate(stoked_heat_rate * 0.5) * FireManager.STOKE_MULTIPLIER
	strategy_fire._process(1.0)
	_check(is_equal_approx(GameManager.get_run_soot_earned() - soot_earned_before_stoke_tick, expected_stoked_soot), "Avivar multiplica por 1,5 la producción mientras está activo.")
	strategy_fire._process(FireManager.STOKE_DURATION - 1.0)
	_check(is_zero_approx(strategy_fire.stoke_time_left), "Avivar termina al alcanzar los 12 segundos.")

	var upgrade_cost := GameManager.get_upgrade_cost()
	_check(is_equal_approx(upgrade_cost, 25.0), "La mejora inicial debe costar 25.")
	_check(GameManager.buy_upgrade(), "Debe poder comprarse la mejora inicial.")
	_check(is_equal_approx(GameManager.get_global_multiplier(), 1.0 + float(starting_points) * 0.1 + 0.25), "La mejora debe sumar 0,25 al multiplicador.")
	_check(is_equal_approx(GameManager.get_upgrade_cost(), 40.0), "El siguiente coste debe crecer a 40.")
	_check(GameManager.buy_upgrade(), "El segundo nivel debe poder comprarse con el saldo generado.")
	_check(is_equal_approx(GameManager.get_upgrade_cost(), 64.0), "El tercer coste debe crecer a 64.")
	_check(is_equal_approx(shop.get_price("tronco"), 14.0), "El precio de la tienda debe venir del recurso.")
	var soot_before_purchase := GameManager.get_soot()
	_check(shop.buy_fuel("tronco"), "Debe poder comprarse combustible con hollín.")
	_check(is_equal_approx(GameManager.get_soot(), soot_before_purchase - 14.0), "La tienda debe descontar el precio exacto.")

	GameManager.add_soot(220.0)
	var expected_award := int(floor(GameManager.get_run_soot_earned() / GameManager.PRESTIGE_THRESHOLD))
	var expected_next_run_reserve := GameManager.get_run_ember_reserve()
	_check(expected_next_run_reserve > 0.0, "La combustión ha acumulado calor recuperable antes del prestigio.")
	_check(expected_award >= 2, "La preparación de la prueba debe alcanzar varias brasas.")
	var awarded := GameManager.prestige()
	_check(awarded == expected_award, "El prestigio debe conceder una brasa por cada 100 de hollín generado.")
	_check(GameManager.get_permanent_points() == starting_points + expected_award, "El progreso permanente debe acumular las brasas recibidas.")
	_check(GameManager.get_soot() == 0.0 and GameManager.get_temporary_upgrades() == 0, "El prestigio debe limpiar el estado económico temporal.")
	_check(GameManager.get_fuel_count("hojarasca") == 4 and GameManager.get_fuel_count("tronco") == 3, "El prestigio debe reponer el inventario inicial.")
	_check(GameManager.get_next_run_ember_reserve() <= GameManager.EMBER_RESERVE_CAP, "La reserva térmica debe respetar su límite.")
	_check(is_equal_approx(GameManager.get_next_run_ember_reserve(), expected_next_run_reserve), "El prestigio conserva la reserva térmica para la siguiente run.")
	if save_write_available:
		GameManager._load_progress()
		_check(GameManager.get_permanent_points() == starting_points + expected_award, "Las brasas deben cargarse desde el guardado.")
		_check(is_equal_approx(GameManager.get_next_run_ember_reserve(), expected_next_run_reserve), "La reserva térmica se conserva en el guardado.")
		strategy_fire.clear_for_new_run()
		strategy_fire.uses_ember_reserve = true
		strategy_fire.fuel_queue.append(FireManager.FUEL_HOJARASCA)
		_check(strategy_fire.get_current_phase().contains("recuperable"), "El HUD de fase comunica la brasa recuperable al inicio de la nueva run.")
		_check(strategy_fire.ignite(), "El primer encendido de la nueva run acepta la pila preparada.")
		_check(is_equal_approx(strategy_fire.recovered_ember_heat, expected_next_run_reserve), "El primer encendido consume la reserva guardada como calor.")
		_check(is_zero_approx(GameManager.get_next_run_ember_reserve()), "La reserva se consume una sola vez.")
	else:
		checks_skipped += 1
		_log_line("SKIP", "Persistencia no validada: escritura de user:// bloqueada.")

	_validate_sprints_3_to_5(main, fire, strategy_fire)
	_restore_saved_progress()
	GameManager._load_progress()
	GameManager.begin_new_run()
	main.queue_free()
	shop.queue_free()
	strategy_fire.queue_free()
	var status := "PASS" if checks_failed == 0 else "FAIL"
	_log_line("SUMMARY", "%s — %d comprobaciones, %d fallidas" % [status, checks_run, checks_failed])
	print("Sprint 0-5 regression %s: %d comprobaciones, %d fallidas. Log: %s" % [status, checks_run, checks_failed, ProjectSettings.globalize_path(test_log_path)])
	test_log.close()
	get_tree().quit(0 if checks_failed == 0 else 1)

func _check_mix_quality(fire: FireManager, fuels: Array[FuelData], expected_quality: float) -> bool:
	fire.fuel_queue.clear()
	fire.fuel_queue.append_array(fuels)
	return is_equal_approx(fire.get_queue_quality(), expected_quality)

func _validate_sprints_3_to_5(main: Node, primary_fire: FireManager, automation_fire: FireManager) -> void:
	# Sprint 3: permanent nodes, prerequisites, effects, wallet and save migration.
	var progress: RunProgressManager = GameManager.run_progress
	progress.permanent_points = 5
	progress.available_embers = 30
	progress.purchased_nodes.clear()
	progress.changed.emit()
	main.call("_open_skill_tree")
	_check(GameManager.has_advanced_tree(), "Cinco brasas ganadas desbloquean los nodos avanzados.")
	var hud := main.get("skill_tree_overlay") as Control
	var advanced_label := main.get("advanced_tree_label") as Label
	var permanent_buttons: Dictionary = main.get("permanent_buttons")
	_check(hud != null and hud.visible and hud.get_child_count() > 0, "El menú permanente presenta los nodos y sus estados antes de comprar.")
	_check(advanced_label != null and advanced_label.text.contains("DESBLOQUEADA"), "El HUD comunica el progreso y desbloqueo de la rama avanzada.")
	_check(str(permanent_buttons["thermal_1"].text).contains("+10% de calor") and str(permanent_buttons["thermal_1"].text).contains("2 brasas"), "Cada nodo visible muestra su efecto y coste antes de comprar.")
	_check(str(permanent_buttons["thermal_2"].tooltip_text).contains("BLOQUEADO"), "El HUD muestra el prerequisito del nodo siguiente.")
	var nodes := GameManager.get_permanent_nodes()
	var thermal_1: Dictionary = nodes[0]
	var thermal_2: Dictionary = nodes[1]
	var thermal_advanced: Dictionary = nodes[2]
	_check(GameManager.can_purchase_permanent_node(thermal_1), "El primer nodo térmico muestra coste y permite compra asequible.")
	_check(not GameManager.can_purchase_permanent_node(thermal_2), "El segundo nodo térmico exige su prerequisito.")
	_check(GameManager.purchase_permanent_node("thermal_1"), "Se puede comprar el primer nodo persistente.")
	_check(GameManager.can_purchase_permanent_node(thermal_2) and GameManager.purchase_permanent_node("thermal_2"), "El segundo nodo se habilita al comprar su prerequisito.")
	_check(GameManager.can_purchase_permanent_node(thermal_advanced) and GameManager.purchase_permanent_node("thermal_advanced"), "El nodo avanzado queda disponible con cinco brasas y su cadena completa.")
	_check(is_equal_approx(GameManager.get_thermal_multiplier(), 1.5), "Los nodos térmicos aplican sus efectos permanentes de calor.")
	_check(GameManager.purchase_permanent_node("soot_1"), "La rama de hollín acepta la compra de su nodo inicial.")
	_check(GameManager.purchase_permanent_node("soot_2") and GameManager.purchase_permanent_node("soot_advanced"), "La rama económica ofrece tres nodos persistentes con prerequisitos.")
	_check(is_equal_approx(progress.get_soot_bonus(), 0.5), "Los tres nodos económicos aplican sus bonificaciones de hollín.")
	if save_write_available:
		GameManager._load_progress()
		_check(GameManager.owns_permanent_node("thermal_advanced") and GameManager.owns_permanent_node("soot_1"), "La compra de nodos se conserva al recargar el guardado.")
		_check(GameManager.get_available_embers() == 6, "El guardado conserva el saldo de brasas disponibles tras las compras.")
		var migration_file := ConfigFile.new()
		migration_file.set_value("progress", "version", 1)
		migration_file.set_value("progress", "embers", 7)
		migration_file.save("user://hogueras_save.cfg")
		GameManager._load_progress()
		_check(GameManager.get_permanent_points() == 0 and GameManager.get_available_embers() == 0, "La migración a la campaña alineada inicia progreso nuevo.")
		_check(FileAccess.file_exists(RunProgressManager.SAVE_PATH + ".legacy.bak"), "La migración conserva una copia de seguridad del guardado anterior.")
		var migrated_nodes_empty := true
		for node in GameManager.get_permanent_nodes():
			migrated_nodes_empty = migrated_nodes_empty and not GameManager.owns_permanent_node(str(node.id))
		_check(migrated_nodes_empty, "La migración versión 1 inicializa el árbol sin compras inexistentes.")
	else:
		checks_skipped += 1
		_log_line("SKIP", "Persistencia y migración del Sprint 3 no validadas: escritura de user:// bloqueada.")

	# Sprint 4: isolated station, data-driven fuel, biome rules and deliveries.
	var second_fire := main.get_node("FireManager2") as FireManager
	second_fire.set_process(false)
	primary_fire.set_process(false)
	GameManager.begin_new_run()
	GameManager.run_progress.day_number = 3
	second_fire.private_stock = second_fire.build_starting_stock()
	var global_wood := GameManager.get_fuel_count("leña")
	_check(second_fire.add_fuel("hojarasca"), "La segunda hoguera carga combustible desde su almacén propio.")
	_check(second_fire.get_station_fuel_count("hojarasca") == 3 and GameManager.get_fuel_count("leña") == global_wood, "Cargar la segunda hoguera no mezcla ni consume el inventario global.")
	_check(second_fire.ignite(), "La segunda hoguera puede encenderse de forma independiente.")
	var soot_before_second_fire := GameManager.get_run_soot_earned()
	second_fire._process(1.0)
	_check(GameManager.get_run_soot_earned() > soot_before_second_fire and not primary_fire.burning, "La segunda hoguera produce hollín sin encender la primera.")
	_check(primary_fire.add_fuel("hojarasca") and primary_fire.ignite(), "La primera hoguera mantiene un ciclo independiente mientras arde la segunda.")
	second_fire._process(1.0)
	primary_fire._process(1.0)
	main.call("_refresh_hud")
	var rate_label := main.get("rate_label") as Label
	var primary_rate := GameManager.get_soot_rate(primary_fire.current_heat) * primary_fire.local_production_multiplier
	var shown_total_rate := rate_label.text.get_slice(": ", 1).get_slice(" ", 0).to_float()
	_check(is_equal_approx(shown_total_rate, snappedf(primary_rate, 0.1)), "El HUD muestra solo la tasa de ceniza de la hoguera activa.")
	GameManager.add_soot(60.0)
	main.call("_on_upgrade_second")
	_check(second_fire.local_upgrade_level == 1 and is_equal_approx(second_fire.local_production_multiplier, 1.25), "La mejora de producción de la segunda hoguera se compra y aplica localmente.")
	_check(FuelCatalog.get_by_id("turba") != null and second_fire.add_fuel("turba"), "Un combustible añadido por recurso aparece en el catálogo y el inventario de estación.")
	var purchase_buttons: Dictionary = main.get("purchase_buttons")
	var fuel_buttons: Dictionary = main.get("fuel_buttons")
	_check(purchase_buttons.has("turba") and fuel_buttons.has("turba"), "La tienda y el HUD reconocen el combustible añadido por datos.")
	second_fire.add_delivery("turba", 1)
	_check(second_fire.get_station_fuel_count("turba") > 0, "La entrega repone el almacén independiente de la segunda hoguera.")
	second_fire.private_stock["turba"] = InventoryManager.MAX_STOCK_PER_FUEL
	second_fire.add_delivery("turba", 1)
	_check(second_fire.get_station_fuel_count("turba") == InventoryManager.MAX_STOCK_PER_FUEL, "Las entregas respetan la capacidad máxima del almacén.")
	main.call("_on_select_biome", 1)
	_check(is_equal_approx(primary_fire.biome_heat_multiplier, 1.0) and is_equal_approx(second_fire.biome_heat_multiplier, 1.0), "La primera entrega conserva un único entorno térmico.")
	var delivery_label := main.get("delivery_label") as Label
	_check(delivery_label != null and delivery_label.text.to_lower().contains("jornada"), "El HUD informa del temporizador de la jornada.")

	# Sprint 5: per-station automation, priority, offline cap and one-time claims.
	automation_fire.clear_for_new_run()
	automation_fire.private_stock = {"hojarasca": 1, "leña": 1, "tronco": 0, "turba": 0}
	automation_fire.private_stock["turba"] = 1
	_check(automation_fire.add_fuel("turba") and automation_fire.ignite(), "El combustible añadido por recurso puede entrar en la pila de combustión.")
	automation_fire._process(FuelCatalog.get_by_id("turba").burn_duration)
	_check(not automation_fire.burning and automation_fire.fuel_queue.is_empty(), "La hoguera consume y termina el combustible nuevo usando sus datos.")
	automation_fire.clear_for_new_run()
	automation_fire.private_stock = {"hojarasca": 1, "leña": 1, "tronco": 0, "turba": 0}
	automation_fire.automation_unlocked = true
	automation_fire.automation_active = true
	automation_fire.fuel_priority = ["leña", "hojarasca", "tronco", "turba"]
	automation_fire._run_automation()
	_check(automation_fire.burning and automation_fire.fuel_queue[0].fuel_id == "leña", "La automatización carga y enciende usando la prioridad configurada.")
	_check(automation_fire.get_station_fuel_count("leña") == 0, "La automatización consume solo stock existente de la estación.")
	automation_fire.automation_active = false
	automation_fire.clear_for_new_run()
	_check(not automation_fire.burning and automation_fire.fuel_queue.is_empty(), "Pausar automatización detiene nuevas cargas individuales.")
	automation_fire.fuel_priority = ["hojarasca", "leña", "tronco", "turba"]
	automation_fire.cycle_fuel_priority()
	_check(automation_fire.fuel_priority[0] == "leña", "La política de combustible rota su prioridad por hoguera.")
	automation_fire.private_stock = {"hojarasca": 0, "leña": 0, "tronco": 0, "turba": 0}
	automation_fire.automation_active = true
	automation_fire._run_automation()
	_check(not automation_fire.burning and automation_fire.fuel_queue.is_empty(), "La automatización no consume combustible inexistente.")
	GameManager.add_soot(200.0)
	main.call("_on_automation_toggle", automation_fire, 80.0)
	_check(automation_fire.automation_unlocked and automation_fire.automation_active, "La automatización se desbloquea por hoguera con el coste indicado.")
	main.call("_on_automation_toggle", automation_fire, 80.0)
	_check(not automation_fire.automation_active, "La automatización puede pausarse individualmente.")
	var automation_settings: Dictionary = main.call("_get_fire_automation_settings", automation_fire)
	var restored_automation := FireManager.new()
	main.call("_apply_fire_automation_settings", restored_automation, automation_settings)
	_check(not restored_automation.automation_unlocked and not restored_automation.automation_active, "La automatización empieza deshabilitada en la campaña de Early Access.")
	restored_automation.free()
	GameManager.add_soot(40.0)
	main.call("_on_automation_toggle", second_fire, 160.0)
	_check(second_fire.automation_unlocked and second_fire.automation_active and not automation_fire.automation_active, "La segunda instalación se desbloquea por separado con su coste de 160.")
	main.call("_on_automation_toggle", second_fire, 160.0)
	second_fire.cycle_fuel_priority()
	main.call("_save_session_progress")
	second_fire.automation_unlocked = false
	second_fire.automation_active = false
	second_fire.fuel_priority = ["hojarasca", "leña", "tronco", "turba"]
	GameManager.run_progress.load_progress()
	main.call("_restore_automation_settings")
	_check(not second_fire.automation_unlocked and not second_fire.automation_active, "La automatización queda deshabilitada tras cargar una sesión.")
	var progress_probe := RunProgressManager.new()
	progress_probe.offline_saved_at = int(Time.get_unix_time_from_system()) - int(RunProgressManager.OFFLINE_CAP_SECONDS + 3600.0)
	progress_probe.offline_fuel_seconds = RunProgressManager.OFFLINE_CAP_SECONDS + 3600.0
	progress_probe.offline_soot_per_second = 1.0
	progress_probe.current_soot = 3.0
	var offline_result: Dictionary = progress_probe.claim_offline_progress()
	_check(offline_result.seconds == int(RunProgressManager.OFFLINE_CAP_SECONDS) and is_equal_approx(float(offline_result.soot), RunProgressManager.OFFLINE_CAP_SECONDS), "El progreso sin sesión se limita a ocho horas y al combustible disponible.")
	_check(is_equal_approx(progress_probe.current_soot, 3.0 + RunProgressManager.OFFLINE_CAP_SECONDS), "El progreso offline se suma al hollín de la run.")
	var second_claim: Dictionary = progress_probe.claim_offline_progress()
	_check(float(second_claim.soot) == 0.0, "El premio offline ya reclamado no se vuelve a conceder.")
	progress_probe.offline_saved_at = int(Time.get_unix_time_from_system()) - 120
	progress_probe.offline_fuel_seconds = 45.0
	var fuel_limited_result: Dictionary = progress_probe.claim_offline_progress()
	_check(fuel_limited_result.seconds == 45, "El progreso offline también se limita a la duración de combustible disponible.")
	var progress_reload_probe := RunProgressManager.new()
	progress_reload_probe.load_progress()
	_check(is_equal_approx(progress_reload_probe.current_soot, progress_probe.current_soot), "El hollín de run calculado offline persiste al recargar.")
	progress_reload_probe.free()
	progress_probe.free()

func _open_test_log() -> void:
	var directory := "res://Tests/Logs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	test_log_path = "%s/sprint0-5_regression_%s.log" % [directory, timestamp]
	test_log = FileAccess.open(test_log_path, FileAccess.WRITE)
	if test_log == null:
		push_error("No se pudo crear el log de pruebas: %s" % test_log_path)
		return
	print("Log de pruebas: %s" % ProjectSettings.globalize_path(test_log_path))

func _check(condition: bool, description: String) -> void:
	checks_run += 1
	if not condition:
		checks_failed += 1
	_log_line("PASS" if condition else "FAIL", description)

func _log_line(status: String, message: String) -> void:
	if test_log == null:
		return
	test_log.store_line("%s | %s | %s" % [Time.get_datetime_string_from_system(), status, message])
	test_log.flush()

func _backup_saved_progress() -> void:
	var probe := FileAccess.open("user://hogueras_test_write_probe.tmp", FileAccess.WRITE)
	if probe != null:
		probe.close()
		save_write_available = true
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://hogueras_test_write_probe.tmp"))
	save_existed = FileAccess.file_exists("user://hogueras_save.cfg")
	if save_existed:
		var file := FileAccess.open("user://hogueras_save.cfg", FileAccess.READ)
		saved_progress = file.get_as_text()

func _restore_saved_progress() -> void:
	if not save_write_available:
		return
	if save_existed:
		var file := FileAccess.open("user://hogueras_save.cfg", FileAccess.WRITE)
		if file == null:
			_log_line("WARN", "No se pudo restaurar el guardado: el entorno bloqueó la escritura.")
			return
		file.store_string(saved_progress)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://hogueras_save.cfg"))

