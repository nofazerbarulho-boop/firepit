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
	_log_line("RUN", "Sprint 1 regression")
	_backup_saved_progress()
	GameManager.begin_new_run()
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
	var guidance := main.get("guidance_label") as Label
	var ignite_button := main.get("ignite_button") as Button
	_check(guidance.text.contains("Pila vacía"), "El HUD debe explicar cómo avanzar desde la pila vacía.")
	_check(ignite_button.disabled and ignite_button.tooltip_text.contains("Añade combustible"), "El botón de encendido debe explicar por qué está deshabilitado.")
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
	_check(expected_award >= 2, "La preparación de la prueba debe alcanzar varias brasas.")
	var awarded := GameManager.prestige()
	_check(awarded == expected_award, "El prestigio debe conceder una brasa por cada 100 de hollín generado.")
	_check(GameManager.get_permanent_points() == starting_points + expected_award, "El progreso permanente debe acumular las brasas recibidas.")
	_check(GameManager.get_soot() == 0.0 and GameManager.get_temporary_upgrades() == 0, "El prestigio debe limpiar el estado económico temporal.")
	_check(GameManager.get_fuel_count("hojarasca") == 4 and GameManager.get_fuel_count("tronco") == 3, "El prestigio debe reponer el inventario inicial.")
	_check(GameManager.get_next_run_ember_reserve() <= GameManager.EMBER_RESERVE_CAP, "La reserva térmica debe respetar su límite.")
	if save_write_available:
		GameManager._load_progress()
		_check(GameManager.get_permanent_points() == starting_points + expected_award, "Las brasas deben cargarse desde el guardado.")
	else:
		checks_skipped += 1
		_log_line("SKIP", "Persistencia no validada: escritura de user:// bloqueada.")

	_restore_saved_progress()
	GameManager._load_progress()
	GameManager.begin_new_run()
	main.queue_free()
	shop.queue_free()
	var status := "PASS" if checks_failed == 0 else "FAIL"
	_log_line("SUMMARY", "%s — %d comprobaciones, %d fallidas" % [status, checks_run, checks_failed])
	print("Sprint 1 regression %s: %d comprobaciones, %d fallidas. Log: %s" % [status, checks_run, checks_failed, ProjectSettings.globalize_path(test_log_path)])
	test_log.close()
	get_tree().quit(0 if checks_failed == 0 else 1)

func _open_test_log() -> void:
	var directory := "res://Tests/Logs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	test_log_path = "%s/sprint1_regression_%s.log" % [directory, timestamp]
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

