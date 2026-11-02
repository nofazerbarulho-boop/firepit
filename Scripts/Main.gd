extends Node3D

@onready var fire: FireManager = $FireManager
@onready var second_fire: FireManager = $FireManager2

var fuel_shop: FuelShop
var soot_label: Label
var stats_label: Label
var rate_label: Label
var progress_label: Label
var progress_bar: ProgressBar
var queue_label: Label
var mix_label: Label
var ember_label: Label
var guidance_label: Label
var feedback_label: Label
var prestige_button: Button
var ignite_button: Button
var upgrade_button: Button
var remove_fuel_button: Button
var stoke_button: Button
var permanent_buttons: Dictionary = {}
var skill_tree_overlay: Control
var skill_tree_open_button: Button
var skill_tree_points_label: Label
var advanced_tree_label: Label
var fire_light: OmniLight3D
var fuel_buttons: Dictionary = {}
var purchase_buttons: Dictionary = {}
var hud_layer: CanvasLayer
var second_fire_label: Label
var delivery_label: Label
var delivery_time_left: float = 45.0
var biome_index: int = 0
var biome_label: Label
var second_upgrade_button: Button
var automation_controls: Array[Dictionary] = []
var presentation_label: Label
var tier_button: Button
var skin_button: Button
var accessibility_button: Button
var volume_button: Button
var selected_skin: int = 0
var large_text: bool = false
var high_contrast: bool = false
var fire_volume: float = 0.35
var presentation_config := ConfigFile.new()
var tier_names: Array[String] = ["Convencional", "Fatuo", "Valyrio", "Negro"]
var gain_popups: Array[Label] = []
var hud_refresh_pending: bool = false
var hud_refresh_elapsed: float = 0.0

func _ready() -> void:
	second_fire.has_private_inventory = true
	second_fire.private_stock = second_fire.build_starting_stock()
	second_fire.uses_ember_reserve = false
	_restore_automation_settings()
	fuel_shop = FuelShop.new()
	add_child(fuel_shop)
	_build_world()
	_build_hud()
	_load_presentation_settings()
	GameManager.economy_changed.connect(_request_hud_refresh)
	GameManager.inventory_changed.connect(_request_hud_refresh)
	fire.fire_changed.connect(_request_hud_refresh)
	fire.gain_batch.connect(_show_gain_popup)
	second_fire.fire_changed.connect(_request_hud_refresh)
	second_fire.gain_batch.connect(_show_gain_popup)
	get_tree().root.close_requested.connect(_save_offline_progress)
	var offline_result := GameManager.claim_offline_progress()
	var offline_soot := float(offline_result.get("soot", 0.0))
	if offline_soot > 0.0:
		feedback_label.text = "Progreso automático: %.0f s y +%.1f de hollín." % [int(offline_result.get("seconds", 0)), offline_soot]
	_refresh_hud()

func _process(delta: float) -> void:
	if hud_refresh_pending:
		hud_refresh_elapsed += delta
		if hud_refresh_elapsed >= 0.1:
			hud_refresh_pending = false
			hud_refresh_elapsed = 0.0
			_refresh_hud()
	delivery_time_left -= delta
	if delivery_time_left <= 0.0:
		for fuel_data in FuelCatalog.get_all():
			GameManager.add_fuel_stock(fuel_data.fuel_id, 1)
			second_fire.add_delivery(fuel_data.fuel_id, 1)
		delivery_time_left = 45.0

func _build_world() -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		camera.look_at(Vector3(0.0, 0.6, 0.0))
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(0.0, 1.0, 0.0)
	fire_light.light_color = Color(1.0, 0.3, 0.08)
	fire_light.light_energy = 0.0
	fire_light.omni_range = 6.0
	fire.add_child(fire_light)

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 24.0)
	panel.custom_minimum_size = Vector2(390.0, 660.0)
	hud_layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390.0, 660.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	var title := Label.new()
	title.text = "HOGUERAS"
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)
	soot_label = Label.new()
	layout.add_child(soot_label)
	stats_label = Label.new()
	layout.add_child(stats_label)
	rate_label = Label.new()
	layout.add_child(rate_label)
	progress_label = Label.new()
	layout.add_child(progress_label)
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = GameManager.PRESTIGE_THRESHOLD
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 12.0
	layout.add_child(progress_bar)
	queue_label = Label.new()
	queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(queue_label)
	mix_label = Label.new()
	mix_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(mix_label)
	ember_label = Label.new()
	ember_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(ember_label)
	guidance_label = Label.new()
	guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(guidance_label)
	feedback_label = Label.new()
	feedback_label.text = "Carga combustible y enciende la hoguera."
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(feedback_label)
	for fuel_data in FuelCatalog.get_all():
		_add_fuel_button(layout, "Cargar " + fuel_data.display_name, fuel_data.fuel_id)
	_build_skill_tree_overlay()

	var shop_title := Label.new()
	shop_title.text = "Tienda de combustible · paga con hollín"
	layout.add_child(shop_title)
	for fuel_data in FuelCatalog.get_all():
		_add_purchase_button(layout, "Comprar " + fuel_data.display_name, fuel_data.fuel_id)
	remove_fuel_button = Button.new()
	remove_fuel_button.text = "Retirar último combustible"
	remove_fuel_button.pressed.connect(_on_remove_fuel)
	layout.add_child(remove_fuel_button)
	ignite_button = Button.new()
	ignite_button.text = "Encender hoguera"
	ignite_button.pressed.connect(_on_ignite)
	layout.add_child(ignite_button)
	stoke_button = Button.new()
	stoke_button.pressed.connect(_on_stoke)
	layout.add_child(stoke_button)
	upgrade_button = Button.new()
	upgrade_button.text = "Mejorar producción (25 de hollín, +0,25x)"
	upgrade_button.pressed.connect(_on_upgrade)
	layout.add_child(upgrade_button)
	skill_tree_open_button = Button.new()
	skill_tree_open_button.text = "Abrir arbol de mejoras"
	skill_tree_open_button.pressed.connect(_open_skill_tree)
	layout.add_child(skill_tree_open_button)
	prestige_button = Button.new()
	prestige_button.pressed.connect(_on_prestige)
	layout.add_child(prestige_button)
	var world_title := Label.new()
	world_title.text = "Mundo y entregas"
	layout.add_child(world_title)
	presentation_label = Label.new()
	presentation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(presentation_label)
	tier_button = Button.new()
	tier_button.pressed.connect(_cycle_fire_tier)
	layout.add_child(tier_button)
	skin_button = Button.new()
	skin_button.pressed.connect(_cycle_cosmetic_skin)
	layout.add_child(skin_button)
	accessibility_button = Button.new()
	accessibility_button.pressed.connect(_cycle_accessibility)
	layout.add_child(accessibility_button)
	volume_button = Button.new()
	volume_button.pressed.connect(_cycle_fire_volume)
	layout.add_child(volume_button)
	biome_label = Label.new()
	layout.add_child(biome_label)
	var biome_buttons := HBoxContainer.new()
	layout.add_child(biome_buttons)
	for biome_id in range(2):
		var biome_button := Button.new()
		biome_button.text = "Bosque" if biome_id == 0 else "Turbera (5 brasas)"
		biome_button.pressed.connect(_on_select_biome.bind(biome_id))
		biome_buttons.add_child(biome_button)
	delivery_label = Label.new()
	layout.add_child(delivery_label)
	var second_title := Label.new()
	second_title.text = "Hoguera II · instalación independiente"
	layout.add_child(second_title)
	second_fire_label = Label.new()
	layout.add_child(second_fire_label)
	for fuel_data in FuelCatalog.get_all():
		var station_button := Button.new()
		station_button.text = "Hoguera II: cargar " + fuel_data.display_name
		station_button.pressed.connect(_on_add_second_fuel.bind(fuel_data.fuel_id))
		layout.add_child(station_button)
	var second_ignite := Button.new()
	second_ignite.text = "Encender hoguera II"
	second_ignite.pressed.connect(_on_ignite_second)
	layout.add_child(second_ignite)
	var second_remove := Button.new()
	second_remove.text = "Retirar última carga de hoguera II"
	second_remove.pressed.connect(_on_remove_second_fuel)
	layout.add_child(second_remove)
	second_upgrade_button = Button.new()
	second_upgrade_button.pressed.connect(_on_upgrade_second)
	layout.add_child(second_upgrade_button)
	_add_automation_controls(layout, fire, "Hoguera I", 80.0)
	_add_automation_controls(layout, second_fire, "Hoguera II", 160.0)

func _add_automation_controls(parent: VBoxContainer, target_fire: FireManager, station_name: String, unlock_cost: float) -> void:
	var title := Label.new()
	title.text = "Automatización · " + station_name
	parent.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var toggle := Button.new()
	toggle.custom_minimum_size.x = 180.0
	toggle.pressed.connect(_on_automation_toggle.bind(target_fire, unlock_cost))
	row.add_child(toggle)
	var priority := Button.new()
	priority.text = "Cambiar prioridad"
	priority.pressed.connect(_on_cycle_fuel_priority.bind(target_fire))
	row.add_child(priority)
	automation_controls.append({"fire": target_fire, "cost": unlock_cost, "toggle": toggle, "priority": priority, "name": station_name})

func _on_automation_toggle(target_fire: FireManager, unlock_cost: float) -> void:
	if not target_fire.automation_unlocked:
		if not GameManager.spend_soot(unlock_cost):
			feedback_label.text = "Necesitas %.0f de hollín para automatizar." % unlock_cost
			_refresh_hud()
			return
		target_fire.automation_unlocked = true
		target_fire.automation_active = true
		feedback_label.text = "Automatización desbloqueada y activa."
	else:
		target_fire.automation_active = not target_fire.automation_active
		feedback_label.text = "Automatización %s." % ("activada" if target_fire.automation_active else "pausada")
	target_fire.fire_changed.emit()
	_refresh_hud()

func _on_cycle_fuel_priority(target_fire: FireManager) -> void:
	target_fire.cycle_fuel_priority()
	feedback_label.text = "Prioridad actualizada: %s." % target_fire.get_fuel_priority_text()
	_refresh_hud()

func _save_offline_progress() -> void:
	var first_seconds := fire.get_automation_fuel_seconds()
	var second_seconds := second_fire.get_automation_fuel_seconds()
	var total_seconds := first_seconds + second_seconds
	var weighted_rate := 0.0
	if total_seconds > 0.0:
		weighted_rate = (fire.get_automation_average_rate() * first_seconds + second_fire.get_automation_average_rate() * second_seconds) / total_seconds
	var settings := {
		"fire1": _get_fire_automation_settings(fire),
		"fire2": _get_fire_automation_settings(second_fire)
	}
	GameManager.record_session_exit(total_seconds, weighted_rate, GameManager.get_soot(), settings)

func _get_fire_automation_settings(target_fire: FireManager) -> Dictionary:
	return {
		"unlocked": target_fire.automation_unlocked,
		"active": target_fire.automation_active,
		"priority": target_fire.fuel_priority.duplicate()
	}

func _restore_automation_settings() -> void:
	var settings := GameManager.get_automation_settings()
	_apply_fire_automation_settings(fire, settings.get("fire1", {}))
	_apply_fire_automation_settings(second_fire, settings.get("fire2", {}))

func _apply_fire_automation_settings(target_fire: FireManager, settings: Variant) -> void:
	if not settings is Dictionary:
		return
	target_fire.automation_unlocked = bool(settings.get("unlocked", false))
	target_fire.automation_active = target_fire.automation_unlocked and bool(settings.get("active", false))
	var saved_priority: Variant = settings.get("priority", [])
	if saved_priority is Array:
		target_fire.fuel_priority.clear()
		for fuel_id in saved_priority:
			if FuelCatalog.get_by_id(str(fuel_id)) != null and not target_fire.fuel_priority.has(str(fuel_id)):
				target_fire.fuel_priority.append(str(fuel_id))
	target_fire.ensure_fuel_priority()

func _on_add_second_fuel(fuel_id: String) -> void:
	feedback_label.text = "Carga añadida a la hoguera II." if second_fire.add_fuel(fuel_id) else "No queda ese combustible en inventario."
	_refresh_hud()

func _on_ignite_second() -> void:
	feedback_label.text = "Hoguera II encendida." if second_fire.ignite() else "Prepara combustible para la hoguera II antes de encenderla."
	_refresh_hud()

func _on_remove_second_fuel() -> void:
	feedback_label.text = "Carga retirada de la hoguera II." if second_fire.remove_last_fuel() else "No hay carga retirable en la hoguera II."
	_refresh_hud()

func _on_upgrade_second() -> void:
	var cost := 50.0 * pow(1.7, second_fire.local_upgrade_level)
	if GameManager.spend_soot(cost):
		second_fire.local_upgrade_level += 1
		second_fire.local_production_multiplier += 0.25
		feedback_label.text = "Mejora propia de hoguera II: producción x%.2f." % second_fire.local_production_multiplier
	else:
		feedback_label.text = "Necesitas %.0f de hollín para mejorar la hoguera II." % cost
	_refresh_hud()

func _on_select_biome(selected: int) -> void:
	if selected == 1 and GameManager.get_permanent_points() < 5:
		feedback_label.text = "La turbera se desbloquea al ganar 5 brasas permanentes."
		return
	biome_index = selected
	var multiplier := 1.0 if biome_index == 0 else 1.25
	fire.biome_heat_multiplier = multiplier
	second_fire.biome_heat_multiplier = multiplier
	if is_instance_valid(fire_light):
		fire_light.light_color = Color(1.0, 0.3, 0.08) if biome_index == 0 else Color(0.28, 0.62, 0.42)
	var ground := get_node_or_null("Ground") as MeshInstance3D
	if ground != null:
		var ground_material := ground.get_surface_override_material(0) as StandardMaterial3D
		if ground_material != null:
			ground_material.albedo_color = Color(0.1, 0.12, 0.11) if biome_index == 0 else Color(0.08, 0.16, 0.12)
	biome_label.text = "Bioma: Bosque · calor normal" if biome_index == 0 else "Bioma: Turbera · +25% calor"
	feedback_label.text = "Bioma cambiado."
	_refresh_hud()

func _get_unlocked_fire_tier() -> int:
	var embers := GameManager.get_permanent_points()
	if embers >= 20: return 3
	if embers >= 10: return 2
	if embers >= 5: return 1
	return 0

func _cycle_fire_tier() -> void:
	var max_tier := _get_unlocked_fire_tier()
	var current := fire.visual_tier
	var next_tier := (current + 1) % (max_tier + 1)
	_apply_visual_style(next_tier, selected_skin)
	_save_presentation_settings()
	_refresh_hud()

func _cycle_cosmetic_skin() -> void:
	selected_skin = (selected_skin + 1) % 3
	_apply_visual_style(fire.visual_tier, selected_skin)
	_save_presentation_settings()
	_refresh_hud()

func _cycle_accessibility() -> void:
	if not large_text:
		large_text = true
	elif not high_contrast:
		high_contrast = true
	else:
		large_text = false
		high_contrast = false
	_apply_accessibility()
	_save_presentation_settings()
	accessibility_button.text = "Accesibilidad: %s%s" % ["texto grande" if large_text else "texto normal", " · alto contraste" if high_contrast else ""]

func _cycle_fire_volume() -> void:
	fire_volume = 0.0 if fire_volume > 0.3 else (0.2 if fire_volume <= 0.01 else 0.4)
	fire.set_fire_volume(fire_volume)
	second_fire.set_fire_volume(fire_volume)
	volume_button.text = "Volumen del fuego: %d%%" % int(fire_volume * 100.0)
	_save_presentation_settings()

func _apply_visual_style(tier: int, skin: int) -> void:
	var safe_tier := mini(tier, _get_unlocked_fire_tier())
	fire.set_visual_style(safe_tier, skin)
	second_fire.set_visual_style(safe_tier, skin)

func _load_presentation_settings() -> void:
	presentation_config.load("user://presentation.cfg")
	selected_skin = int(presentation_config.get_value("visual", "skin", 0))
	large_text = bool(presentation_config.get_value("accessibility", "large_text", false))
	high_contrast = bool(presentation_config.get_value("accessibility", "high_contrast", false))
	fire_volume = float(presentation_config.get_value("audio", "volume", 0.35))
	var saved_tier := int(presentation_config.get_value("visual", "tier", 0))
	_apply_visual_style(saved_tier, selected_skin)
	fire.set_fire_volume(fire_volume)
	second_fire.set_fire_volume(fire_volume)
	_apply_accessibility()
	accessibility_button.text = "Accesibilidad: %s%s" % ["texto grande" if large_text else "texto normal", " · alto contraste" if high_contrast else ""]
	volume_button.text = "Volumen del fuego: %d%%" % int(fire_volume * 100.0)

func _save_presentation_settings() -> void:
	presentation_config.set_value("visual", "tier", fire.visual_tier)
	presentation_config.set_value("visual", "skin", selected_skin)
	presentation_config.set_value("accessibility", "large_text", large_text)
	presentation_config.set_value("accessibility", "high_contrast", high_contrast)
	presentation_config.set_value("audio", "volume", fire_volume)
	presentation_config.save("user://presentation.cfg")

func _apply_accessibility() -> void:
	if not is_instance_valid(hud_layer): return
	for control in _walk_controls(hud_layer):
		if control is Label or control is Button:
			control.add_theme_font_size_override("font_size", (18 if large_text else 14) if control != tier_button else 14)
		if control is Label and high_contrast:
			control.add_theme_color_override("font_color", Color(1, 1, 0.82))
		elif control is Label:
			control.remove_theme_color_override("font_color")

func _walk_controls(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in root.get_children():
		if child is Control: result.append(child)
		result.append_array(_walk_controls(child))
	return result

func _add_fuel_button(parent: VBoxContainer, button_text: String, fuel_id: String) -> void:
	var button := Button.new()
	button.text = button_text
	button.tooltip_text = fire.get_fuel_description(fuel_id)
	button.pressed.connect(_on_add_fuel.bind(fuel_id))
	parent.add_child(button)
	fuel_buttons[fuel_id] = button

func _add_purchase_button(parent: VBoxContainer, button_text: String, fuel_id: String) -> void:
	var button := Button.new()
	button.text = button_text
	button.pressed.connect(_on_buy_fuel.bind(fuel_id))
	parent.add_child(button)
	purchase_buttons[fuel_id] = button

func _on_add_fuel(fuel_id: String) -> void:
	if fire.add_fuel(fuel_id):
		feedback_label.text = "Combustible añadido para la siguiente carga." if fire.burning else "Combustible añadido a la pila."
	else:
		feedback_label.text = "No queda más de ese combustible."
	_refresh_hud()

func _on_buy_fuel(fuel_id: String) -> void:
	if fuel_shop.buy_fuel(fuel_id):
		feedback_label.text = "Combustible comprado con hollín."
	else:
		feedback_label.text = "Te falta hollín para esa compra."
	_refresh_hud()

func _on_ignite() -> void:
	if fire.burning:
		feedback_label.text = "La hoguera ya está encendida."
	else:
		feedback_label.text = "La hoguera está encendida." if fire.ignite() else "Añade combustible antes de encender."
	_refresh_hud()

func _on_stoke() -> void:
	if fire.stoke():
		feedback_label.text = "Hoguera avivada: +50% hollín durante 12 segundos."
	elif not fire.burning:
		feedback_label.text = "Enciende la hoguera antes de avivarla."
	elif fire.stoke_time_left > 0.0:
		feedback_label.text = "Espera a que termine el avivado actual."
	elif GameManager.get_soot() < FireManager.STOKE_COST:
		feedback_label.text = "Necesitas 15 de hollín para avivar."
	else:
		feedback_label.text = "No se pudo avivar la hoguera."
	_refresh_hud()

func _on_remove_fuel() -> void:
	if fire.remove_last_fuel():
		feedback_label.text = "Último combustible devuelto al inventario."
	else:
		feedback_label.text = "No hay ninguna carga que puedas retirar."
	_refresh_hud()

func _on_upgrade() -> void:
	if GameManager.buy_upgrade():
		feedback_label.text = "Mejora comprada."
	else:
		feedback_label.text = "Necesitas %.0f de hollín para mejorar." % GameManager.get_upgrade_cost()
	_refresh_hud()

func _on_prestige() -> void:
	var awarded := GameManager.prestige()
	if awarded <= 0:
		return
	fire.clear_for_new_run()
	second_fire.clear_for_new_run()
	delivery_time_left = 45.0
	feedback_label.text = "Run reiniciada: +%d brasas permanentes." % awarded
	_refresh_hud()

func _build_skill_tree_overlay() -> void:
	skill_tree_overlay = Control.new()
	skill_tree_overlay.name = "EmberSkillTree"
	skill_tree_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_tree_overlay.visible = false
	hud_layer.add_child(skill_tree_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.018, 0.014, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	skill_tree_overlay.add_child(backdrop)

	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 28.0
	frame.offset_top = 24.0
	frame.offset_right = -28.0
	frame.offset_bottom = -24.0
	frame.add_theme_stylebox_override("panel", _make_skill_frame_style())
	skill_tree_overlay.add_child(frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	frame.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title_group := VBoxContainer.new()
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_group)
	var title := Label.new()
	title.text = "ARBOL DE MEJORAS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.67, 0.25))
	title_group.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Hollin en brasas  /  Aviva el fuego. Forja tu legado."
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.62, 0.45))
	title_group.add_child(subtitle)
	skill_tree_points_label = Label.new()
	skill_tree_points_label.add_theme_font_size_override("font_size", 18)
	skill_tree_points_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3))
	skill_tree_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(skill_tree_points_label)
	var close_button := Button.new()
	close_button.text = "VOLVER A LA HOGUERA"
	close_button.custom_minimum_size = Vector2(132.0, 42.0)
	close_button.pressed.connect(_close_skill_tree)
	header.add_child(close_button)

	advanced_tree_label = Label.new()
	advanced_tree_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	advanced_tree_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.2))
	content.add_child(advanced_tree_label)

	var branches := HBoxContainer.new()
	branches.size_flags_vertical = Control.SIZE_EXPAND_FILL
	branches.add_theme_constant_override("separation", 16)
	content.add_child(branches)
	_add_skill_branch(branches, "combustion", "RAMA / COMBUSTION", "Llamas mas calientes y combustiones mas largas.", ["thermal_1", "thermal_2", "thermal_advanced"], Color(0.84, 0.31, 0.09))
	_add_skill_branch(branches, "soot", "RAMA / HOLLIN", "Cada fuego produce mas hollin.", ["soot_1", "soot_2", "soot_advanced"], Color(0.37, 0.32, 0.29))
	_refresh_skill_tree()

func _add_skill_branch(parent: HBoxContainer, branch_id: String, title_text: String, subtitle_text: String, node_ids: Array[String], accent: Color) -> void:
	var branch_panel := PanelContainer.new()
	branch_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branch_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	branch_panel.add_theme_stylebox_override("panel", _make_skill_panel_style(accent.darkened(0.77), accent.darkened(0.3)))
	parent.add_child(branch_panel)
	var branch_margin := MarginContainer.new()
	branch_margin.add_theme_constant_override("margin_left", 16)
	branch_margin.add_theme_constant_override("margin_top", 12)
	branch_margin.add_theme_constant_override("margin_right", 16)
	branch_margin.add_theme_constant_override("margin_bottom", 12)
	branch_panel.add_child(branch_margin)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 5)
	branch_margin.add_child(stack)
	var branch_title := Label.new()
	branch_title.text = title_text
	branch_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	branch_title.add_theme_font_size_override("font_size", 17)
	branch_title.add_theme_color_override("font_color", accent.lightened(0.35))
	stack.add_child(branch_title)
	var branch_subtitle := Label.new()
	branch_subtitle.text = subtitle_text
	branch_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	branch_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	branch_subtitle.add_theme_color_override("font_color", Color(0.83, 0.75, 0.66))
	stack.add_child(branch_subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 5.0
	stack.add_child(spacer)
	for index in range(node_ids.size()):
		var node_id: String = node_ids[index]
		var node_data: Dictionary = _get_permanent_node(node_id)
		if node_data.is_empty():
			continue
		var node_button := Button.new()
		node_button.custom_minimum_size = Vector2(300.0, 74.0)
		node_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		node_button.add_theme_font_size_override("font_size", 15)
		node_button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.79))
		node_button.add_theme_color_override("font_disabled_color", Color(0.61, 0.55, 0.48))
		node_button.pressed.connect(_on_purchase_permanent_node.bind(node_id))
		stack.add_child(node_button)
		permanent_buttons[node_id] = node_button
		if index < node_ids.size() - 1:
			var connector := Label.new()
			connector.text = "  ◆  │  ◆  "
			connector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			connector.add_theme_color_override("font_color", accent.lightened(0.1))
			stack.add_child(connector)

func _get_permanent_node(node_id: String) -> Dictionary:
	for node in GameManager.get_permanent_nodes():
		if str(node.id) == node_id:
			return node
	return {}

func _open_skill_tree() -> void:
	_refresh_skill_tree()
	skill_tree_overlay.visible = true

func _close_skill_tree() -> void:
	skill_tree_overlay.visible = false

func _refresh_skill_tree() -> void:
	if not is_instance_valid(skill_tree_overlay):
		return
	skill_tree_points_label.text = "BRASAS DISPONIBLES: %d" % GameManager.get_available_embers()
	advanced_tree_label.text = "RAMA AVANZADA DESBLOQUEADA" if GameManager.has_advanced_tree() else "RAMA AVANZADA BLOQUEADA  /  %s" % GameManager.get_advanced_tree_progress()
	for node_id in permanent_buttons:
		var node_data: Dictionary = _get_permanent_node(str(node_id))
		var node_button: Button = permanent_buttons[node_id]
		var is_owned := GameManager.owns_permanent_node(str(node_id))
		var can_buy := GameManager.can_purchase_permanent_node(node_data)
		var state := _get_skill_node_state(node_data, is_owned, can_buy)
		node_button.text = "%s   |   %d brasas\n%s\n%s" % [str(node_data.name).to_upper(), int(node_data.cost), str(node_data.effect), state]
		node_button.disabled = is_owned or not can_buy
		node_button.tooltip_text = "%s. Coste: %d brasas. %s" % [str(node_data.effect), int(node_data.cost), state]
		var node_color := Color(0.35, 0.2, 0.11) if is_owned else (Color(0.49, 0.25, 0.1) if can_buy else Color(0.16, 0.13, 0.11))
		node_button.add_theme_stylebox_override("normal", _make_skill_panel_style(node_color, Color(1.0, 0.55, 0.18) if can_buy else Color(0.35, 0.28, 0.22)))
		node_button.add_theme_stylebox_override("hover", _make_skill_panel_style(node_color.lightened(0.12), Color(1.0, 0.72, 0.32)))
		node_button.add_theme_stylebox_override("pressed", _make_skill_panel_style(node_color.darkened(0.15), Color(1.0, 0.48, 0.12)))
		node_button.add_theme_stylebox_override("disabled", _make_skill_panel_style(node_color.darkened(0.1), Color(0.32, 0.27, 0.22)))

func _get_skill_node_state(node: Dictionary, is_owned: bool, can_buy: bool) -> String:
	if is_owned:
		return "APRENDIDO  /  brasa sellada"
	if bool(node.advanced) and not GameManager.has_advanced_tree():
		return "BLOQUEADO  /  gana 5 brasas"
	var requirement := str(node.requires)
	if not requirement.is_empty() and not GameManager.owns_permanent_node(requirement):
		return "BLOQUEADO  /  aprende %s" % str(_get_permanent_node(requirement).name)
	if not can_buy:
		return "FALTAN %d BRASAS" % maxi(0, int(node.cost) - GameManager.get_available_embers())
	return "LISTO PARA ENCENDER"

func _make_skill_frame_style() -> StyleBoxFlat:
	return _make_skill_panel_style(Color(0.09, 0.065, 0.047, 0.98), Color(0.66, 0.29, 0.11))

func _make_skill_panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style

func _on_purchase_permanent_node(node_id: String) -> void:
	if GameManager.purchase_permanent_node(node_id):
		feedback_label.text = "Nodo permanente desbloqueado: %s." % _get_node_name(node_id)
	else:
		feedback_label.text = "No cumples el coste, prerequisito o desbloqueo de ese nodo."
	_refresh_hud()
	_refresh_skill_tree()

func _get_node_name(node_id: String) -> String:
	var node := _get_permanent_node(node_id)
	return str(node.get("name", node_id))

func _refresh_hud() -> void:
	if not is_instance_valid(soot_label) or not is_instance_valid(fire):
		return
	hud_refresh_pending = false
	hud_refresh_elapsed = 0.0
	var unlocked_tier := _get_unlocked_fire_tier()
	presentation_label.text = "Tier %s | desbloqueado hasta %s (%d brasas)\nLas tiers cambian el aspecto. Skin: %s (sin bonus)." % [tier_names[fire.visual_tier], tier_names[unlocked_tier], GameManager.get_permanent_points(), ["Natural", "Ambar", "Azul palido"][selected_skin]]
	tier_button.text = "Cambiar tier: %s" % tier_names[fire.visual_tier]
	tier_button.disabled = unlocked_tier == 0
	skin_button.text = "Cambiar skin (%s)" % ["Natural", "Ambar", "Azul palido"][selected_skin]
	accessibility_button.text = "Accesibilidad: %s%s" % ["texto grande" if large_text else "texto normal", " | alto contraste" if high_contrast else ""]
	volume_button.text = "Volumen del fuego: %d%%" % int(fire_volume * 100.0)
	soot_label.text = "Hollin: %.1f | Generado en esta run: %.1f" % [GameManager.get_soot(), GameManager.get_run_soot_earned()]
	stats_label.text = "Calor: %.1f (x%.2f) | Multiplicador: %.2fx\nBrasas ganadas: %d | Disponibles: %d" % [fire.current_heat, GameManager.get_thermal_multiplier(), GameManager.get_global_multiplier(), GameManager.get_permanent_points(), GameManager.get_available_embers()]
	var second_stock_parts := PackedStringArray()
	for fuel_data in FuelCatalog.get_all():
		second_stock_parts.append("%s %d" % [fuel_data.display_name, second_fire.private_stock.get(fuel_data.fuel_id, 0)])
	second_fire_label.text = "Stock propio: %s | Calor: %.1f | %s" % [" | ".join(second_stock_parts), second_fire.current_heat, second_fire.get_current_phase()]
	var second_upgrade_cost := 50.0 * pow(1.7, second_fire.local_upgrade_level)
	second_upgrade_button.text = "Mejora Hoguera II: +0,25x (%.0f hollin) | x%.2f" % [second_upgrade_cost, second_fire.local_production_multiplier]
	second_upgrade_button.disabled = GameManager.get_soot() < second_upgrade_cost
	for control in automation_controls:
		var target_fire: FireManager = control.fire
		var toggle: Button = control.toggle
		var priority: Button = control.priority
		var unlock_cost := float(control.cost)
		if target_fire.automation_unlocked:
			toggle.text = "%s: %s" % [str(control.name), "Activa" if target_fire.automation_active else "Pausada"]
		else:
			toggle.text = "Desbloquear %s (%.0f hollin)" % [str(control.name), unlock_cost]
		toggle.disabled = not target_fire.automation_unlocked and GameManager.get_soot() < unlock_cost
		priority.text = "Prioridad: " + target_fire.get_fuel_priority_text()
		priority.disabled = not target_fire.automation_unlocked
	delivery_label.text = "Siguiente entrega en %.0f s | +1 de cada combustible por hoguera" % delivery_time_left
	biome_label.text = "Bioma: Bosque | calor normal" if biome_index == 0 else "Bioma: Turbera | +25% calor"
	var live_rate := GameManager.get_soot_rate(fire.current_heat)
	if fire.stoke_time_left > 0.0:
		live_rate *= FireManager.STOKE_MULTIPLIER
	rate_label.text = "Produccion actual: %.1f hollin/s" % live_rate
	var progress := GameManager.get_prestige_progress()
	progress_label.text = "Proxima brasa: %.0f / %.0f de hollin" % [progress, GameManager.PRESTIGE_THRESHOLD]
	progress_bar.value = progress
	var stock := GameManager.get_fuel_stock()
	var stock_parts := PackedStringArray()
	for fuel_data in FuelCatalog.get_all():
		stock_parts.append("%s %d" % [fuel_data.display_name, stock.get(fuel_data.fuel_id, 0)])
	var queue_names := PackedStringArray()
	for fuel in fire.fuel_queue:
		queue_names.append(fuel.display_name)
	var state_text := "%s | %.1f s de esta carga" % [fire.get_current_phase(), fire.remaining_burn] if fire.burning else fire.get_current_phase()
	queue_label.text = "Combustible: %s\nEstado: %s\nPila: %s" % [" | ".join(stock_parts), state_text, " -> ".join(queue_names) if not queue_names.is_empty() else "vacia"]
	var quality := fire.active_quality if fire.burning else fire.get_queue_quality()
	mix_label.text = "Calidad de mezcla: %.0f%% | +12%% por secuencia, +4%% por variedad, -2%% por repeticion." % (quality * 100.0)
	ember_label.text = "Calor recuperado: +%.1f" % fire.recovered_ember_heat if fire.burning and fire.recovered_ember_heat > 0.0 else "Reserva: %.1f / %.1f | Siguiente run: %.1f" % [GameManager.get_run_ember_reserve(), GameManager.EMBER_RESERVE_CAP, GameManager.get_next_run_ember_reserve()]
	for fuel_id in fuel_buttons:
		var fuel_button: Button = fuel_buttons[fuel_id]
		var available := GameManager.get_fuel_count(fuel_id)
		fuel_button.disabled = available <= 0
		fuel_button.text = "Anadir %s (%d)" % [fuel_id, available]
	for fuel_id in purchase_buttons:
		var purchase_button: Button = purchase_buttons[fuel_id]
		var price := fuel_shop.get_price(fuel_id)
		purchase_button.text = "Comprar %s (%.0f hollin)" % [fuel_shop.get_display_name(fuel_id), price]
		purchase_button.disabled = GameManager.get_soot() < price
	ignite_button.disabled = fire.burning or fire.fuel_queue.is_empty()
	stoke_button.text = "Avivar (+50% durante 12 s | 15 hollin)" if fire.stoke_time_left <= 0.0 else "Avivando (%.1f s)" % fire.stoke_time_left
	stoke_button.disabled = not fire.burning or fire.stoke_time_left > 0.0 or GameManager.get_soot() < FireManager.STOKE_COST
	remove_fuel_button.disabled = fire.fuel_queue.size() <= (1 if fire.burning else 0)
	upgrade_button.text = "Mejorar produccion (%.0f hollin, +0,25x | nivel %d)" % [GameManager.get_upgrade_cost(), GameManager.get_temporary_upgrades() + 1]
	upgrade_button.disabled = GameManager.get_soot() < GameManager.get_upgrade_cost()
	var points_available := int(floor(GameManager.get_run_soot_earned() / GameManager.PRESTIGE_THRESHOLD))
	prestige_button.text = "Reiniciar run (+%d brasas; 100 hollin por brasa)" % points_available
	prestige_button.disabled = points_available < 1
	_update_guidance_and_tooltips(stock)
	if is_instance_valid(fire_light):
		var light_base := 0.3 + minf(fire.current_heat / 35.0, 1.0) * 2.2
		var flicker := 1.0 + sin(float(Time.get_ticks_msec()) / 83.0) * 0.07
		fire_light.light_energy = 0.0 if fire.current_heat <= 0.1 else light_base * flicker
	if skill_tree_overlay.visible:
		_refresh_skill_tree()
func _request_hud_refresh() -> void:
	hud_refresh_pending = true

func _update_guidance_and_tooltips(stock: Dictionary) -> void:
	if fire.burning:
		guidance_label.text = "La hoguera está activa. Puedes preparar más combustible para cuando termine la pila."
	elif not fire.fuel_queue.is_empty():
		guidance_label.text = "Pila preparada: pulsa Encender para comenzar la combustión."
	elif int(stock.get("hojarasca", 0)) + int(stock.get("leña", 0)) + int(stock.get("tronco", 0)) > 0:
		guidance_label.text = "Pila vacía: añade combustible. La secuencia afecta a su calidad."
	elif GameManager.get_soot() >= fuel_shop.get_price("hojarasca"):
		guidance_label.text = "Sin existencias: compra combustible en la tienda para continuar."
	else:
		guidance_label.text = "Sin combustible ni hollín para comprarlo. Espera a una brasa recuperable o reinicia cuando puedas."

	for fuel_id in fuel_buttons:
		var fuel_button: Button = fuel_buttons[fuel_id]
		if GameManager.get_fuel_count(fuel_id) <= 0:
			fuel_button.tooltip_text = "Sin existencias. Compra %s por %.0f de hollín." % [fuel_shop.get_display_name(fuel_id), fuel_shop.get_price(fuel_id)]
		elif fire.burning:
			fuel_button.tooltip_text = "Se añadirá al final de la pila y arderá cuando acabe la carga activa."
		else:
			fuel_button.tooltip_text = fire.get_fuel_description(fuel_id) + " Se añadirá al final de la pila."
	for fuel_id in purchase_buttons:
		var purchase_button: Button = purchase_buttons[fuel_id]
		var price := fuel_shop.get_price(fuel_id)
		purchase_button.tooltip_text = "Cuesta %.0f de hollín; tienes %.1f." % [price, GameManager.get_soot()] if GameManager.get_soot() < price else "Añade una unidad de %s al inventario." % fuel_shop.get_display_name(fuel_id)
	ignite_button.tooltip_text = "La hoguera ya está encendida." if fire.burning else ("Añade combustible a la pila antes de encender." if fire.fuel_queue.is_empty() else "Inicia la pila en el orden mostrado.")
	remove_fuel_button.tooltip_text = "No hay cargas retirables mientras arde la primera." if fire.burning and fire.fuel_queue.size() <= 1 else ("Añade combustible antes de poder retirar una carga." if fire.fuel_queue.is_empty() else "Devuelve a inventario la última carga añadida.")
	if not fire.burning:
		stoke_button.tooltip_text = "Solo se puede avivar una hoguera encendida."
	elif fire.stoke_time_left > 0.0:
		stoke_button.tooltip_text = "El avivado activo termina en %.1f s." % fire.stoke_time_left
	elif GameManager.get_soot() < FireManager.STOKE_COST:
		stoke_button.tooltip_text = "Necesitas 15 de hollín; tienes %.1f." % GameManager.get_soot()
	else:
		stoke_button.tooltip_text = "Gasta 15 de hollín para producir 50%% más durante 12 s."
	upgrade_button.tooltip_text = "Necesitas %.0f de hollín; tienes %.1f." % [GameManager.get_upgrade_cost(), GameManager.get_soot()] if GameManager.get_soot() < GameManager.get_upgrade_cost() else "Aumenta el multiplicador de producción en 0,25."
	var points_to_next := GameManager.PRESTIGE_THRESHOLD - GameManager.get_prestige_progress()
	prestige_button.tooltip_text = "Genera %.0f más de hollín para recibir otra brasa." % points_to_next if GameManager.get_run_soot_earned() < GameManager.PRESTIGE_THRESHOLD else "Reinicia la run y recibe las brasas acumuladas."

func _show_gain_popup(amount: float) -> void:
	if not is_instance_valid(hud_layer) or amount < 0.1:
		return
	for index in range(gain_popups.size() - 1, -1, -1):
		if not is_instance_valid(gain_popups[index]):
			gain_popups.remove_at(index)
	if gain_popups.size() >= 4:
		gain_popups.pop_front().queue_free()
	var popup := Label.new()
	popup.text = "+%.1f hollín" % amount
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", Color(1.0, 0.72, 0.24))
	popup.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.025, 0.95))
	popup.add_theme_constant_override("outline_size", 4)
	var viewport_size := get_viewport().get_visible_rect().size
	var start_position := Vector2(viewport_size.x * 0.55, viewport_size.y * 0.52)
	start_position.x += randf_range(-24.0, 24.0)
	popup.position = start_position
	hud_layer.add_child(popup)
	gain_popups.append(popup)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position", start_position + Vector2(0.0, -56.0), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tween.set_parallel(false)
	tween.tween_callback(popup.queue_free)
