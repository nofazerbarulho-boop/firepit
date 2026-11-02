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
var rest_button: Button
var permanent_buttons: Dictionary = {}
var skill_tree_overlay: Control
var skill_tree_open_button: Button
var skill_tree_points_label: Label
var advanced_tree_label: Label
var fire_light: OmniLight3D
var second_fire_light: OmniLight3D
var fuel_buttons: Dictionary = {}
var purchase_buttons: Dictionary = {}
var hud_layer: CanvasLayer
var second_fire_label: Label
var delivery_label: Label
var daily_save_elapsed: float = 0.0
var biome_index: int = 0
var second_upgrade_button: Button
var automation_controls: Array[Dictionary] = []
var presentation_label: Label
var tier_button: Button
var accessibility_button: Button
var volume_button: Button
var selected_skin: int = 0
var large_text: bool = false
var high_contrast: bool = false
var fire_volume: float = 0.35
var presentation_config := ConfigFile.new()
var tier_names: Array[String] = ["Convencional", "Fatuo", "Valyrio", "Negro"]
var gain_popups: Array[Label] = []
var resource_bar: HBoxContainer
var control_tabs: TabContainer
var map_hint_label: Label
var fire_intensity: ProgressBar
var fire_intensity_label: Label
var button_tweens: Dictionary = {}
var hud_refresh_pending: bool = false
var hud_refresh_elapsed: float = 0.0
var facility_buttons: Dictionary = {}
var wagon_button: Button
var truck_button: Button
var experimental_buttons: Dictionary = {}
var menu_panel: PanelContainer
var menu_toggle: Button
var main_menu_layer: CanvasLayer
var main_menu_root: Control
var main_menu_panel: PanelContainer
var main_menu_layout: VBoxContainer
var options_volume_value: Label
var pregame_selection_label: Label
var options_button: Button
var game_started: bool = false
var return_to_game_after_options: bool = false
var camera_dragging: bool = false
var camera_last_mouse := Vector2.ZERO
var camera_node: Camera3D
var player_body: CharacterBody3D
var player_position := Vector3(0.0, 0.9, 6.0)
var camera_yaw: float = 0.0
var camera_pitch: float = -0.08
var mouse_sensitivity: float = 0.0025

class ResourceBadge extends Control:
	var ember: bool = false
	func _draw() -> void:
		var center := size * 0.5
		if ember:
			draw_circle(center, 15.0, Color("7c4d20"))
			draw_arc(center, 11.0, 0.0, TAU, 32, Color("f3c65c"), 2.0, true)
			var spark := PackedVector2Array([center + Vector2(0, -9), center + Vector2(3, -2), center + Vector2(8, 0), center + Vector2(2, 3), center + Vector2(0, 9), center + Vector2(-3, 3), center + Vector2(-8, 0), center + Vector2(-2, -3)])
			draw_colored_polygon(spark, Color("ffe78c"))
		else:
			draw_circle(center, 15.0, Color("423e38"))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-10, 5), center + Vector2(-7, -2), center + Vector2(-1, -8), center + Vector2(4, -5), center + Vector2(10, 2), center + Vector2(8, 7)]), Color("aaa69d"))
			draw_circle(center + Vector2(-3, 1), 2.0, Color("d2ccc0"))

class SkillTreeConnections extends Control:
	var points: Array[Vector2] = []
	var links: Array[Vector2i] = []
	func _draw() -> void:
		for link in links:
			if link.x >= points.size() or link.y >= points.size():
				continue
			var a := Vector2(points[link.x].x * size.x, points[link.x].y * size.y)
			var b := Vector2(points[link.y].x * size.x, points[link.y].y * size.y)
			var bend := Vector2((a.x + b.x) * 0.5, minf(a.y, b.y) - 22.0 if absf(a.y - b.y) > 30.0 else a.y - 12.0)
			draw_line(a, bend, Color("171819"), 11.0, true)
			draw_line(bend, b, Color("171819"), 11.0, true)
			draw_line(a + Vector2(0, -1), bend + Vector2(0, -1), Color("827b6e"), 3.0, true)
			draw_line(bend + Vector2(0, -1), b + Vector2(0, -1), Color("827b6e"), 3.0, true)
			draw_circle(bend, 3.0, Color("d08a43"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_TAB:
			_toggle_menu()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var look_motion: InputEventMouseMotion = event as InputEventMouseMotion
		camera_yaw -= look_motion.relative.x * mouse_sensitivity
		camera_pitch = clampf(camera_pitch - look_motion.relative.y * mouse_sensitivity, -1.15, 1.05)
		_update_camera_position()

func _update_camera_position() -> void:
	if is_instance_valid(camera_node):
		if is_instance_valid(player_body):
			player_body.rotation.y = camera_yaw
			camera_node.rotation = Vector3(camera_pitch, 0.0, 0.0)
		else:
			camera_node.position = player_position
			camera_node.rotation = Vector3(camera_pitch, camera_yaw, 0.0)

func _toggle_menu() -> void:
	if is_instance_valid(menu_panel):
		menu_panel.visible = not menu_panel.visible
		menu_toggle.text = "×" if menu_panel.visible else "☰"

func _prepare_main_menu_screen(title_text: String) -> void:
	if not is_instance_valid(main_menu_layer):
		main_menu_layer = CanvasLayer.new()
		main_menu_layer.layer = 20
		add_child(main_menu_layer)
		main_menu_root = Control.new()
		main_menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		main_menu_layer.add_child(main_menu_root)
	main_menu_layer.visible = true
	for child in main_menu_root.get_children():
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.012, 0.01, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu_root.add_child(center)
	main_menu_panel = PanelContainer.new()
	main_menu_panel.custom_minimum_size = Vector2(440.0, 0.0)
	main_menu_panel.add_theme_stylebox_override("panel", _make_skill_panel_style(Color(0.07, 0.055, 0.045, 0.97), Color(0.68, 0.39, 0.16, 1.0)))
	center.add_child(main_menu_panel)
	main_menu_layout = VBoxContainer.new()
	main_menu_layout.add_theme_constant_override("separation", 14)
	main_menu_layout.add_theme_constant_override("margin_left", 24)
	main_menu_layout.add_theme_constant_override("margin_right", 24)
	main_menu_layout.add_theme_constant_override("margin_top", 24)
	main_menu_layout.add_theme_constant_override("margin_bottom", 24)
	main_menu_panel.add_child(main_menu_layout)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	main_menu_layout.add_child(title)

func _add_main_menu_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size.y = 48.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	main_menu_layout.add_child(button)
	return button

func _show_main_menu() -> void:
	_prepare_main_menu_screen("HOGUERAS")
	_add_main_menu_button("Iniciar juego", _on_start_pressed)
	_add_main_menu_button("Configuración", _open_options_from_menu)
	_add_main_menu_button("Salir", _quit_game)

func _has_player_progress() -> bool:
	return GameManager.get_run_soot_earned() > 0.0 or GameManager.get_soot() > 0.0 or GameManager.get_permanent_points() > 0 or GameManager.get_day_number() > 1

func _on_start_pressed() -> void:
	if _has_player_progress():
		_show_pregame_selection()
	else:
		_begin_game()

func _show_pregame_selection() -> void:
	_prepare_main_menu_screen("Preparar partida")
	var progress_note := Label.new()
	progress_note.text = "Elige el entorno y la apariencia de tu hoguera."
	progress_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_menu_layout.add_child(progress_note)
	pregame_selection_label = Label.new()
	pregame_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_menu_layout.add_child(pregame_selection_label)
	var biomes := HBoxContainer.new()
	main_menu_layout.add_child(biomes)
	var forest := Button.new()
	forest.text = "Bosque"
	forest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forest.pressed.connect(_on_select_biome.bind(0))
	biomes.add_child(forest)
	var bog := Button.new()
	bog.text = "Turbera (5 brasas)"
	bog.disabled = GameManager.get_permanent_points() < 5
	bog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bog.pressed.connect(_on_select_biome.bind(1))
	biomes.add_child(bog)
	_add_main_menu_button("Cambiar apariencia del fuego", _cycle_cosmetic_skin)
	_add_main_menu_button("Empezar", _begin_game)
	_add_main_menu_button("Volver", _show_main_menu)
	_update_pregame_selection_label()

func _update_pregame_selection_label() -> void:
	if is_instance_valid(pregame_selection_label):
		var biome_name := "Bosque" if biome_index == 0 else "Turbera"
		var skin_name: Array[String] = ["Natural", "Ámbar", "Azul pálido"]
		pregame_selection_label.text = "Bioma: %s  ·  Fuego: %s" % [biome_name, skin_name[selected_skin]]

func _begin_game() -> void:
	game_started = true
	main_menu_layer.visible = false
	hud_layer.visible = true
	menu_panel.visible = false
	menu_toggle.text = "☰"
	fire.set_process(true)
	second_fire.set_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_hud()

func _open_options_from_menu() -> void:
	return_to_game_after_options = false
	_show_options_screen()

func _open_options_from_game() -> void:
	return_to_game_after_options = true
	_show_options_screen()

func _show_options_screen() -> void:
	_prepare_main_menu_screen("Configuración")
	var sound_label := Label.new()
	sound_label.text = "Volumen de sonidos del juego"
	main_menu_layout.add_child(sound_label)
	var sound_row := HBoxContainer.new()
	main_menu_layout.add_child(sound_row)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = fire_volume
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(_set_fire_volume)
	sound_row.add_child(volume_slider)
	options_volume_value = Label.new()
	options_volume_value.custom_minimum_size.x = 52.0
	options_volume_value.text = "%d%%" % int(fire_volume * 100.0)
	sound_row.add_child(options_volume_value)
	var sensitivity_label := Label.new()
	sensitivity_label.text = "Sensibilidad del ratón"
	main_menu_layout.add_child(sensitivity_label)
	var sensitivity_slider := HSlider.new()
	sensitivity_slider.min_value = 0.001
	sensitivity_slider.max_value = 0.006
	sensitivity_slider.step = 0.00025
	sensitivity_slider.value = mouse_sensitivity
	sensitivity_slider.value_changed.connect(_set_mouse_sensitivity)
	main_menu_layout.add_child(sensitivity_slider)
	_add_main_menu_button("Accesibilidad: cambiar texto/contraste", _cycle_accessibility)
	_add_main_menu_button("Alternar pantalla completa", _toggle_fullscreen)
	_add_main_menu_button("Volver", _close_options_screen)

func _set_fire_volume(value: float) -> void:
	fire_volume = clampf(value, 0.0, 1.0)
	fire.set_fire_volume(fire_volume)
	second_fire.set_fire_volume(fire_volume)
	if is_instance_valid(options_volume_value):
		options_volume_value.text = "%d%%" % int(fire_volume * 100.0)
	if is_instance_valid(volume_button):
		volume_button.text = "Volumen del fuego: %d%%" % int(fire_volume * 100.0)
	_save_presentation_settings()

func _set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.001, 0.006)
	_save_presentation_settings()

func _toggle_fullscreen() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _close_options_screen() -> void:
	if return_to_game_after_options:
		main_menu_layer.visible = false
		return_to_game_after_options = false
	else:
		_show_main_menu()

func _quit_game() -> void:
	_save_offline_progress()
	get_tree().quit()

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
	_show_main_menu()
	hud_layer.visible = false
	menu_panel.visible = false
	fire.set_process(false)
	second_fire.set_process(false)
	GameManager.economy_changed.connect(_request_hud_refresh)
	GameManager.inventory_changed.connect(_request_hud_refresh)
	fire.fire_changed.connect(_request_hud_refresh)
	fire.gain_batch.connect(_show_gain_popup)
	fire.critical_explosion.connect(_on_critical_explosion)
	second_fire.fire_changed.connect(_request_hud_refresh)
	second_fire.gain_batch.connect(_show_gain_popup)
	get_tree().root.close_requested.connect(_save_offline_progress)
	_refresh_hud()

func _process(delta: float) -> void:
	if not game_started:
		return
	if is_instance_valid(fire_intensity):
		fire_intensity.value = lerpf(fire_intensity.value, clampf(fire.current_heat, 0.0, fire_intensity.max_value), 1.0 - exp(-8.0 * delta))
	if hud_refresh_pending:
		hud_refresh_elapsed += delta
		if hud_refresh_elapsed >= 0.1:
			hud_refresh_pending = false
			hud_refresh_elapsed = 0.0
			_refresh_hud()
	if GameManager.advance_workday(delta):
		var sold_ash := GameManager.close_workday()
		feedback_label.text = "Jornada cerrada: ceniza vendida por %.1f de hollín. Día %d." % [sold_ash, GameManager.get_day_number()]
		daily_save_elapsed = 0.0
		_refresh_hud()
	GameManager.advance_logistics(delta)
	daily_save_elapsed += delta
	if daily_save_elapsed >= 10.0:
		daily_save_elapsed = 0.0
		GameManager.save_daily_state()
	var milestone_reward := GameManager.claim_temperature_milestones(fire.current_heat)
	if milestone_reward > 0:
		feedback_label.text = "¡Hito de temperatura! +%d brasa(s) permanente(s)." % milestone_reward
		_show_resource_popup("+%d brasa%s" % [milestone_reward, "" if milestone_reward == 1 else "s"], Color("FFC56A"))

func _physics_process(delta: float) -> void:
	if not game_started:
		return
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1.0
	var forward := -camera_node.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera_node.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var direction := (right * move.x + forward * -move.y).normalized() if move.length_squared() > 0.0 else Vector3.ZERO
	var speed := 5.2 if Input.is_key_pressed(KEY_SHIFT) else 3.2
	if is_instance_valid(player_body):
		player_body.velocity = direction * speed
		player_body.move_and_slide()
		player_position = player_body.global_position
	else:
		player_position += direction * speed * delta
		player_position.x = clampf(player_position.x, -11.0, 11.0)
		player_position.z = clampf(player_position.z, -11.0, 11.0)
	_update_camera_position()

func _build_world() -> void:
	camera_node = get_node_or_null("Camera3D") as Camera3D
	if camera_node != null:
		camera_node.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera_node.fov = 78.0
		player_position = Vector3(0.0, 0.9, 6.0)
		player_body = CharacterBody3D.new()
		player_body.name = "Player"
		player_body.position = player_position
		var player_shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.32
		capsule.height = 1.8
		player_shape.shape = capsule
		player_body.add_child(player_shape)
		add_child(player_body)
		remove_child(camera_node)
		player_body.add_child(camera_node)
		camera_node.position = Vector3(0.0, 0.75, 0.0)
		_update_camera_position()
	var atmosphere := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.048, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.43, 0.32)
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.12, 0.105, 0.085)
	environment.fog_density = 0.008
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	environment.glow_strength = 0.65
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.96
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.84
	atmosphere.environment = environment
	add_child(atmosphere)
	_build_warehouse()
	var floor_body := StaticBody3D.new()
	floor_body.name = "WalkableFloor"
	var floor_shape_node := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(24.0, 0.1, 24.0)
	floor_shape_node.shape = floor_shape
	floor_shape_node.position.y = -0.05
	floor_body.add_child(floor_shape_node)
	add_child(floor_body)
	var floor_node := get_node_or_null("Ground") as MeshInstance3D
	if floor_node != null:
		var floor_material := StandardMaterial3D.new()
		floor_material.albedo_texture = load("res://Resources/warehouse_floor.svg") as Texture2D
		floor_material.roughness = 0.92
		floor_node.material_override = floor_material
		floor_node.scale = Vector3(1.5, 1.0, 1.5)
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(0.0, 1.0, 0.0)
	fire_light.light_color = Color(1.0, 0.3, 0.08)
	fire_light.light_energy = 0.0
	fire_light.omni_range = 6.0
	fire.add_child(fire_light)
	second_fire_light = OmniLight3D.new()
	second_fire_light.name = "HearthGlow"
	second_fire_light.position = Vector3(0.0, 1.0, 0.0)
	second_fire_light.light_color = Color(1.0, 0.3, 0.08)
	second_fire_light.light_energy = 0.0
	second_fire_light.omni_range = 5.0
	second_fire.add_child(second_fire_light)
	_build_hearth_surroundings()

func _build_hearth_surroundings() -> void:
	var soot_stain := _make_surface(Color(0.075, 0.067, 0.057), 1.0)
	var firebrick := _make_surface(Color(0.20, 0.18, 0.15), 0.92)
	var ash := _make_surface(Color(0.18, 0.17, 0.15), 1.0)
	for center_x in [0.0, 2.5]:
		var stain := _add_cylinder("HearthScorch", Vector3(center_x, -0.038, 0.0), 1.08, 0.025, soot_stain)
		stain.name = "HearthScorch_%.1f" % center_x
		for stone_index in range(12):
			var angle := TAU * float(stone_index) / 12.0
			var radius := 0.78 + 0.04 * sin(float(stone_index) * 2.3)
			var stone_at := Vector3(center_x + cos(angle) * radius, 0.075, sin(angle) * radius)
			var stone := _add_cylinder("FireRingStone", stone_at, 0.19, 0.25, firebrick, Vector3(randf_range(-0.08, 0.08), angle, randf_range(-0.08, 0.08)))
			stone.scale = Vector3(randf_range(0.8, 1.15), 1.0, randf_range(0.8, 1.15))
		for ash_index in range(8):
			var angle := TAU * float(ash_index) / 8.0 + 0.2
			var ash_at := Vector3(center_x + cos(angle) * randf_range(0.38, 0.62), -0.04, sin(angle) * randf_range(0.38, 0.62))
			var fleck := _add_sphere("AshFleck", ash_at, Vector3(0.10, 0.018, 0.07), ash)
			fleck.rotation.y = angle

func _make_surface(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _add_box(name: String, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.name = name + "Body"
	body.position = at
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = dimensions
	collision.shape = box_shape
	body.add_child(collision)
	var node := MeshInstance3D.new()
	node.name = name
	var box := BoxMesh.new()
	box.size = dimensions
	box.material = material
	node.mesh = box
	body.add_child(node)
	add_child(body)
	return node

func _add_cylinder(name: String, at: Vector3, radius: float, height: float, material: Material, tilt: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.9
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.material = material
	node.mesh = cylinder
	node.position = at
	node.rotation = tilt
	add_child(node)
	return node

func _add_sphere(name: String, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.material = material
	node.mesh = sphere
	node.material_override = material
	node.position = at
	node.scale = dimensions
	add_child(node)
	return node

func _build_warehouse() -> void:
	var brick := _make_surface(Color(0.24, 0.22, 0.20))
	var steel := _make_surface(Color(0.12, 0.14, 0.15), 0.48, 0.55)
	var beam := _make_surface(Color(0.20, 0.17, 0.14), 0.68, 0.15)
	var glass := _make_surface(Color(0.36, 0.48, 0.52, 0.72), 0.24, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add_box("RearWall", Vector3(0, 4.0, -12.2), Vector3(24.4, 8.0, 0.4), brick)
	_add_box("LeftWall", Vector3(-12.2, 4.0, 0), Vector3(0.4, 8.0, 24.4), brick)
	_add_box("RightWall", Vector3(12.2, 4.0, 0), Vector3(0.4, 8.0, 24.4), brick)
	for x in [-9.0, -5.4, -1.8, 1.8, 5.4, 9.0]:
		_add_box("RearWindow", Vector3(x, 6.25, -11.96), Vector3(2.45, 1.5, 0.08), glass)
		_add_box("RearWindowSill", Vector3(x, 5.45, -11.9), Vector3(2.7, 0.12, 0.18), steel)
	for side in [-1.0, 1.0]:
		for z in [-8.0, -3.0, 2.0, 7.0]:
			_add_box("SideWindow", Vector3(side * 11.96, 6.1, z), Vector3(0.08, 1.65, 2.8), glass)
			_add_box("SideWindowSill", Vector3(side * 11.9, 5.2, z), Vector3(0.18, 0.12, 3.0), steel)
	for x in [-11.6, -7.0, -2.35, 2.35, 7.0, 11.6]:
		_add_box("RoofTruss", Vector3(x, 7.55, 0), Vector3(0.22, 0.22, 23.0), beam)
		_add_box("CrossBeam", Vector3(x, 7.45, 0), Vector3(24.0, 0.2, 0.22), beam)
		_add_box("ColumnL", Vector3(x, 3.9, -11.8), Vector3(0.38, 7.8, 0.38), steel)
		_add_box("ColumnR", Vector3(x, 3.9, 11.8), Vector3(0.38, 7.8, 0.38), steel)
	for z in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_add_box("Catwalk", Vector3(0, 5.05, z), Vector3(23.2, 0.12, 0.16), steel)
		_add_box("CatwalkRail", Vector3(0, 5.52, z), Vector3(23.2, 0.08, 0.08), beam)
	for x in [-1.1, 1.1]:
		_add_box("MineRail", Vector3(x, 0.035, -1.5), Vector3(0.11, 0.07, 20.0), steel)
	for z in range(-11, 10, 2):
		_add_box("RailSleeper", Vector3(0, 0.025, float(z)), Vector3(2.9, 0.05, 0.22), beam)
	for side in [-1.0, 1.0]:
		for z in [-5.0, 1.0, 7.0]:
			_add_box("BenchSeat", Vector3(side * 8.6, 0.62, z), Vector3(2.2, 0.16, 0.72), beam)
			for leg_x in [-0.8, 0.8]:
				_add_box("BenchLeg", Vector3(side * 8.6 + leg_x, 0.3, z), Vector3(0.12, 0.6, 0.58), steel)
	for x in [-7.0, 0.0, 7.0]:
		_add_box("HangingCable", Vector3(x, 6.95, 0.0), Vector3(0.035, 1.0, 0.035), steel)
		_add_cylinder("LampHousing", Vector3(x, 5.83, 0.0), 0.27, 0.16, steel)
		var bulb := _add_sphere("LampBulb", Vector3(x, 5.68, 0.0), Vector3(0.24, 0.13, 0.24), _make_surface(Color(1.0, 0.63, 0.30), 0.3))
		var bulb_material := bulb.material_override as StandardMaterial3D
		if bulb_material != null:
			bulb_material.emission_enabled = true
			bulb_material.emission = Color(1.0, 0.42, 0.12)
			bulb_material.emission_energy_multiplier = 1.4
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 6.3, 0.0)
		lamp.light_color = Color(1.0, 0.67, 0.35)
		lamp.light_energy = 0.7
		lamp.omni_range = 5.0
		add_child(lamp)
	# Objetos de trabajo, carbón y vegetación para que el recinto se sienta habitado.
	var crate_wood := _make_surface(Color(0.29, 0.19, 0.11), 0.9)
	var pot_material := _make_surface(Color(0.35, 0.20, 0.12), 0.82)
	var leaf_material := _make_surface(Color(0.12, 0.22, 0.12), 0.95)
	var coal_material := _make_surface(Color(0.055, 0.052, 0.05), 0.96)
	var brass := _make_surface(Color(0.48, 0.31, 0.12), 0.35, 0.62)
	for crate_data in [Vector3(-9.2, 0.42, -8.8), Vector3(-8.5, 0.42, -8.15), Vector3(9.2, 0.42, -9.0)]:
		_add_box("SupplyCrate", crate_data, Vector3(0.85, 0.84, 0.85), crate_wood)
		_add_box("CrateBand", crate_data + Vector3(0.0, 0.0, 0.44), Vector3(0.9, 0.08, 0.035), brass)
	for plant_at in [Vector3(-10.0, 0.0, -3.5), Vector3(10.0, 0.0, -2.0), Vector3(-9.5, 0.0, 5.0), Vector3(9.8, 0.0, 6.0)]:
		_add_cylinder("TerracottaPot", plant_at + Vector3(0.0, 0.28, 0.0), 0.38, 0.56, pot_material)
		_add_cylinder("PlantStem", plant_at + Vector3(0.0, 1.1, 0.0), 0.055, 1.4, leaf_material)
		for leaf_index in range(5):
			var angle := float(leaf_index) * TAU / 5.0
			var leaf_offset := Vector3(cos(angle) * 0.3, 0.85 + 0.15 * sin(angle * 2.0), sin(angle) * 0.3)
			var leaf := _add_sphere("PlantLeaf", plant_at + leaf_offset + Vector3(0.0, 0.7, 0.0), Vector3(0.18, 0.72, 0.2), leaf_material)
			leaf.rotation.z = cos(angle) * 0.45
	# Vagoneta cargada, como la referencia visual, junto al lateral de la nave.
	var cart_at := Vector3(7.0, 0.0, -7.0)
	var cart_metal := _make_surface(Color(0.22, 0.23, 0.23), 0.42, 0.66)
	_add_box("CoalCartFloor", cart_at + Vector3(0.0, 0.62, 0.0), Vector3(2.0, 0.14, 2.35), cart_metal)
	_add_box("CoalCartFront", cart_at + Vector3(0.0, 1.0, -1.08), Vector3(2.0, 0.72, 0.14), cart_metal)
	_add_box("CoalCartBack", cart_at + Vector3(0.0, 1.0, 1.08), Vector3(2.0, 0.72, 0.14), cart_metal)
	_add_box("CoalCartLeft", cart_at + Vector3(-0.93, 1.0, 0.0), Vector3(0.14, 0.72, 2.0), cart_metal)
	_add_box("CoalCartRight", cart_at + Vector3(0.93, 1.0, 0.0), Vector3(0.14, 0.72, 2.0), cart_metal)
	for wheel_x in [-0.82, 0.82]:
		for wheel_z in [-0.78, 0.78]:
			_add_cylinder("CartWheel", cart_at + Vector3(wheel_x, 0.3, wheel_z), 0.36, 0.16, steel, Vector3(0.0, 0.0, PI / 2.0))
	for coal_index in range(24):
		var coal_at := cart_at + Vector3(randf_range(-0.8, 0.8), randf_range(1.12, 1.48), randf_range(-0.9, 0.9))
		_add_sphere("CoalLump", coal_at, Vector3(randf_range(0.24, 0.42), randf_range(0.18, 0.32), randf_range(0.22, 0.4)), coal_material)
	# Carteles metálicos en los muros, visibles al recorrer el taller.
	for sign_at in [Vector3(-7.0, 3.2, -11.94), Vector3(3.8, 3.2, -11.94)]:
		_add_box("WorkshopSignFrame", sign_at, Vector3(1.8, 1.25, 0.16), brass)
		_add_box("WorkshopSign", sign_at + Vector3(0.0, 0.0, 0.1), Vector3(1.58, 1.03, 0.08), crate_wood)
	var barrel_material := _make_surface(Color(0.18, 0.22, 0.21), 0.55, 0.5)
	for barrel_at in [Vector3(-9.0, 0.0, 1.0), Vector3(9.0, 0.0, 2.0)]:
		_add_cylinder("WorkshopBarrel", barrel_at + Vector3(0.0, 0.72, 0.0), 0.42, 1.35, barrel_material)
		_add_cylinder("BarrelRim", barrel_at + Vector3(0.0, 0.42, 0.0), 0.44, 0.08, brass)
		_add_cylinder("BarrelRim", barrel_at + Vector3(0.0, 1.02, 0.0), 0.44, 0.08, brass)
	var log_material := _make_surface(Color(0.26, 0.15, 0.075), 0.95)
	for log_index in range(5):
		var log := _add_cylinder("SpareFirewood", Vector3(-8.8 + float(log_index % 3) * 0.45, 0.22 + float(log_index / 3) * 0.3, -5.8), 0.16, 1.2, log_material, Vector3(0.0, 0.0, PI / 2.0))
		log.rotation.y = float(log_index % 2) * 0.12

func _create_facility_visual(kind: String, at: Vector3, base_scale: Vector3, tint: Color, cylinder: bool = false) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Facility_" + kind
	var shape: PrimitiveMesh = CylinderMesh.new() if cylinder else BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	shape.material = material
	mesh_node.mesh = shape
	mesh_node.position = at
	mesh_node.scale = base_scale
	add_child(mesh_node)

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var hud_theme := _make_hud_theme()
	menu_toggle = Button.new()
	menu_toggle.theme = hud_theme
	menu_toggle.text = "☰"
	menu_toggle.position = Vector2(16, 16)
	menu_toggle.custom_minimum_size = Vector2(48, 44)
	menu_toggle.size = Vector2(48, 44)
	menu_toggle.pressed.connect(_toggle_menu)
	hud_layer.add_child(menu_toggle)
	resource_bar = HBoxContainer.new()
	resource_bar.theme = hud_theme
	resource_bar.position = Vector2(76, 16)
	resource_bar.size = Vector2(310, 40)
	resource_bar.add_theme_constant_override("separation", 8)
	hud_layer.add_child(resource_bar)
	for badge_ember in [false, true]:
		var badge := ResourceBadge.new()
		badge.ember = badge_ember
		badge.custom_minimum_size = Vector2(34, 34)
		resource_bar.add_child(badge)
		var resource_value := Label.new()
		resource_value.name = "EmberCount" if badge_ember else "SootCount"
		resource_value.custom_minimum_size = Vector2(110, 34)
		resource_value.add_theme_font_size_override("font_size", 18)
		resource_value.add_theme_color_override("font_color", Color("E4DED2"))
		resource_bar.add_child(resource_value)
	map_hint_label = Label.new()
	map_hint_label.text = "WASD: mover  ·  Shift: correr  ·  Ratón: mirar  ·  Esc: liberar cursor  ·  Tab: menú"
	map_hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_hint_label.custom_minimum_size = Vector2(470.0, 28.0)
	map_hint_label.size = Vector2(470.0, 28.0)
	map_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_hint_label.add_theme_color_override("font_color", Color(0.9, 0.79, 0.61))
	map_hint_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))
	map_hint_label.add_theme_constant_override("outline_size", 3)
	hud_layer.add_child(map_hint_label)
	menu_panel = PanelContainer.new()
	menu_panel.theme = hud_theme
	menu_panel.position = Vector2(16.0, 70.0)
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(clampf(viewport_size.x * 0.28, 290.0, 390.0), maxf(220.0, viewport_size.x - 32.0))
	menu_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu_panel.size = Vector2(panel_width, maxf(180.0, viewport_size.y - 86.0))
	get_viewport().size_changed.connect(_resize_hud_panel)
	hud_layer.add_child(menu_panel)
	apply_industrial_panel(menu_panel)
	control_tabs = TabContainer.new()
	control_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_panel.add_child(control_tabs)
	var fire_layout := _add_control_tab("Hoguera", panel_width)
	var fuel_layout := _add_control_tab("Combustible", panel_width)
	var upgrades_layout := _add_control_tab("Mejoras", panel_width)
	var layout: VBoxContainer = fire_layout
	var title := Label.new()
	title.text = "HOGUERA"
	title.add_theme_font_size_override("font_size", 20)
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
	fire_intensity_label = Label.new()
	fire_intensity_label.text = "Intensidad del fuego"
	layout.add_child(fire_intensity_label)
	fire_intensity = ProgressBar.new()
	fire_intensity.min_value = 0.0
	fire_intensity.max_value = 1000.0
	fire_intensity.show_percentage = false
	fire_intensity.custom_minimum_size.y = 14.0
	fire_intensity.tooltip_text = "Escala visual hasta 1.000 °C; la temperatura exacta aparece arriba."
	var intensity_track := StyleBoxFlat.new()
	intensity_track.bg_color = Color("242525")
	intensity_track.set_corner_radius_all(4)
	var intensity_fill := StyleBoxFlat.new()
	intensity_fill.bg_color = Color("D88A36")
	intensity_fill.set_corner_radius_all(4)
	fire_intensity.add_theme_stylebox_override("background", intensity_track)
	fire_intensity.add_theme_stylebox_override("fill", intensity_fill)
	layout.add_child(fire_intensity)
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
		layout = fuel_layout
		_add_fuel_button(layout, "Cargar " + fuel_data.display_name, fuel_data.fuel_id)
	layout = fuel_layout
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
	layout = fire_layout
	ignite_button = Button.new()
	ignite_button.text = "Encender hoguera"
	ignite_button.pressed.connect(_on_ignite)
	layout.add_child(ignite_button)
	stoke_button = Button.new()
	stoke_button.pressed.connect(_on_stoke)
	layout.add_child(stoke_button)
	rest_button = Button.new()
	rest_button.text = "Descansar y cerrar la jornada"
	rest_button.pressed.connect(_on_rest)
	layout.add_child(rest_button)
	layout = upgrades_layout
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
	prestige_button.visible = false
	var facilities_title := Label.new()
	facilities_title.text = "Instalaciones y logística"
	layout.add_child(facilities_title)
	for facility in ["warehouse", "silo", "workshop", "garage"]:
		var facility_button := Button.new()
		facility_button.pressed.connect(_on_upgrade_facility.bind(facility))
		layout.add_child(facility_button)
		facility_buttons[facility] = facility_button
	wagon_button = Button.new()
	wagon_button.text = "Enviar vagoneta (10 s, hasta 50 cenizas)"
	wagon_button.pressed.connect(_on_dispatch_wagon)
	layout.add_child(wagon_button)
	truck_button = Button.new()
	truck_button.pressed.connect(_on_request_truck)
	layout.add_child(truck_button)
	for tech in ["gas", "tritium", "laser"]:
		var tech_button := Button.new()
		tech_button.pressed.connect(_on_experimental.bind(tech))
		layout.add_child(tech_button)
		experimental_buttons[tech] = tech_button
	var world_title := Label.new()
	world_title.text = "Combustibles y suministro diario"
	layout.add_child(world_title)
	presentation_label = Label.new()
	presentation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(presentation_label)
	tier_button = Button.new()
	tier_button.pressed.connect(_cycle_fire_tier)
	layout.add_child(tier_button)
	accessibility_button = Button.new()
	accessibility_button.pressed.connect(_cycle_accessibility)
	layout.add_child(accessibility_button)
	volume_button = Button.new()
	volume_button.pressed.connect(_cycle_fire_volume)
	layout.add_child(volume_button)
	options_button = Button.new()
	options_button.text = "Configuración"
	options_button.pressed.connect(_open_options_from_game)
	layout.add_child(options_button)
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
	_apply_accessibility()
	_update_resource_cards()
	_resize_hud_panel()
	_install_button_feedback()

func apply_industrial_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17191A", 0.96)
	style.border_color = Color("75634E", 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

func _add_control_tab(tab_name: String, panel_width: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.custom_minimum_size = Vector2(panel_width - 28.0, 0.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	control_tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content

func _make_hud_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("242525")
	normal.border_color = Color("75634E")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	theme.set_stylebox("normal", "Button", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("34302A")
	hover.border_color = Color("D88A36")
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(5)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color("49351F")
	pressed.border_color = Color("FFC56A")
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(5)
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color("202121")
	disabled.border_color = Color("504E48")
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(5)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color("242525")
	focus.border_color = Color("FFC56A")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Label", Color("E4DED2"))
	theme.set_color("font_color", "Button", Color("E4DED2"))
	theme.set_color("font_disabled_color", "Button", Color("AAA69D"))
	return theme

func _update_resource_cards() -> void:
	if not is_instance_valid(resource_bar):
		return
	var soot_count := hud_layer.find_child("SootCount", true, false) as Label
	var ember_count := hud_layer.find_child("EmberCount", true, false) as Label
	if is_instance_valid(soot_count): soot_count.text = "HOLLÍN\n%s" % _format_resource_count(GameManager.get_soot())
	if is_instance_valid(ember_count): ember_count.text = "BRASAS\n%d" % GameManager.get_permanent_points()

func _install_button_feedback() -> void:
	for control in _walk_controls(hud_layer):
		if control is Button:
			var button := control as Button
			button.pivot_offset = button.size * 0.5
			button.mouse_entered.connect(_on_button_hover.bind(button, true))
			button.mouse_exited.connect(_on_button_hover.bind(button, false))
			button.pressed.connect(_pulse_button.bind(button))

func _on_button_hover(button: Button, is_hovered: bool) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	_tween_button_scale(button, Vector2.ONE * (1.025 if is_hovered else 1.0), 0.1)

func _pulse_button(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var tween := _start_button_tween(button)
	tween.tween_property(button, "scale", Vector2(0.97, 0.97), 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _tween_button_scale(button: Button, target: Vector2, duration: float) -> void:
	var tween := _start_button_tween(button)
	tween.tween_property(button, "scale", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _start_button_tween(button: Button) -> Tween:
	var previous: Variant = button_tweens.get(button)
	if is_instance_valid(previous):
		(previous as Tween).kill()
	var tween := button.create_tween()
	button_tweens[button] = tween
	return tween

func _set_action_feedback(message: String, success: bool, popup_message: String = "") -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", Color("FFC56A") if success else Color("E98B75"))
	if success and not popup_message.is_empty():
		_show_resource_popup(popup_message, Color("FFC56A"))

func _resize_hud_panel() -> void:
	if not is_instance_valid(menu_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(clampf(viewport_size.x * 0.28, 290.0, 390.0), maxf(220.0, viewport_size.x - 32.0))
	var compact := viewport_size.x < 800.0
	var narrow := viewport_size.x < 500.0
	var panel_top := 108.0 if compact else 70.0
	menu_panel.position.x = 16.0
	menu_panel.custom_minimum_size.x = panel_width
	menu_panel.position.y = panel_top
	menu_panel.size = Vector2(panel_width, maxf(150.0, viewport_size.y - panel_top - 16.0))
	if compact:
		map_hint_label.text = "WASD mover · Shift correr · Ratón mirar · Esc cursor · Tab menú"
		map_hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		map_hint_label.position = Vector2(16.0, 58.0)
		map_hint_label.custom_minimum_size = Vector2(viewport_size.x - 32.0, 40.0)
		map_hint_label.size = Vector2(viewport_size.x - 32.0, 40.0)
		map_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if narrow:
			map_hint_label.text = "WASD mover · Shift correr · Ratón mirar\nEsc cursor · Tab menú"
	else:
		map_hint_label.text = "WASD: mover  ·  Shift: correr  ·  Ratón: mirar  ·  Esc: liberar cursor  ·  Tab: menú"
		map_hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		map_hint_label.position = Vector2(-490.0, 20.0)
		map_hint_label.custom_minimum_size = Vector2(470.0, 28.0)
		map_hint_label.size = Vector2(470.0, 28.0)
		map_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	resource_bar.size.x = 230.0 if narrow else 310.0
	for badge in resource_bar.get_children():
		if badge is ResourceBadge:
			badge.custom_minimum_size = Vector2(28.0, 28.0) if narrow else Vector2(34.0, 34.0)
		elif badge is Label:
			badge.custom_minimum_size.x = 76.0 if narrow else 110.0
	if is_instance_valid(control_tabs):
		for page in control_tabs.get_children():
			if page is ScrollContainer:
				page.custom_minimum_size.x = panel_width - 28.0

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
	GameManager.save_daily_state()

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
	if is_instance_valid(second_fire_light):
		second_fire_light.light_color = Color(1.0, 0.3, 0.08) if biome_index == 0 else Color(0.28, 0.62, 0.42)
	var ground := get_node_or_null("Ground") as MeshInstance3D
	if ground != null:
		var ground_material := ground.material_override as StandardMaterial3D
		if ground_material != null:
			ground_material.albedo_color = Color(0.1, 0.12, 0.11) if biome_index == 0 else Color(0.08, 0.16, 0.12)
	feedback_label.text = "Bioma cambiado."
	presentation_config.set_value("visual", "biome", biome_index)
	presentation_config.save("user://presentation.cfg")
	_update_pregame_selection_label()
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
	_update_pregame_selection_label()
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
	_set_fire_volume(0.0 if fire_volume > 0.3 else (0.2 if fire_volume <= 0.01 else 0.4))

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
	biome_index = clampi(int(presentation_config.get_value("visual", "biome", 0)), 0, 1)
	mouse_sensitivity = clampf(float(presentation_config.get_value("controls", "mouse_sensitivity", 0.0025)), 0.001, 0.006)
	var saved_tier := int(presentation_config.get_value("visual", "tier", 0))
	_apply_visual_style(saved_tier, selected_skin)
	fire.set_fire_volume(fire_volume)
	second_fire.set_fire_volume(fire_volume)
	if biome_index == 1 and GameManager.get_permanent_points() < 5:
		biome_index = 0
	fire.biome_heat_multiplier = 1.0 if biome_index == 0 else 1.25
	second_fire.biome_heat_multiplier = fire.biome_heat_multiplier
	if is_instance_valid(fire_light):
		fire_light.light_color = Color(1.0, 0.3, 0.08) if biome_index == 0 else Color(0.28, 0.62, 0.42)
	if is_instance_valid(second_fire_light):
		second_fire_light.light_color = Color(1.0, 0.3, 0.08) if biome_index == 0 else Color(0.28, 0.62, 0.42)
	var ground := get_node_or_null("Ground") as MeshInstance3D
	if is_instance_valid(ground):
		var ground_material := ground.material_override as StandardMaterial3D
		if ground_material != null:
			ground_material.albedo_color = Color(0.1, 0.12, 0.11) if biome_index == 0 else Color(0.08, 0.16, 0.12)
	_apply_accessibility()
	accessibility_button.text = "Accesibilidad: %s%s" % ["texto grande" if large_text else "texto normal", " · alto contraste" if high_contrast else ""]
	volume_button.text = "Volumen del fuego: %d%%" % int(fire_volume * 100.0)

func _save_presentation_settings() -> void:
	presentation_config.set_value("visual", "tier", fire.visual_tier)
	presentation_config.set_value("visual", "skin", selected_skin)
	presentation_config.set_value("accessibility", "large_text", large_text)
	presentation_config.set_value("accessibility", "high_contrast", high_contrast)
	presentation_config.set_value("audio", "volume", fire_volume)
	presentation_config.set_value("visual", "biome", biome_index)
	presentation_config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	presentation_config.save("user://presentation.cfg")

func _apply_accessibility() -> void:
	var roots: Array[Node] = []
	if is_instance_valid(hud_layer): roots.append(hud_layer)
	if is_instance_valid(main_menu_root): roots.append(main_menu_root)
	for root in roots:
		for control in _walk_controls(root):
			if control is Label or control is Button:
				var readable_size := 18 if large_text else 14
				if control.name == "SootCount" or control.name == "EmberCount":
					readable_size = 22 if large_text else 18
				control.add_theme_font_size_override("font_size", readable_size if control != tier_button else 14)
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
	var fuel_name := fuel_shop.get_display_name(fuel_id)
	if fire.add_fuel(fuel_id):
		_set_action_feedback("Combustible añadido para la siguiente carga." if fire.burning else "Combustible añadido a la pila.", true, "+1 %s en la pila" % fuel_name)
	else:
		_set_action_feedback("No queda más de ese combustible en el inventario.", false)
	_refresh_hud()

func _on_buy_fuel(fuel_id: String) -> void:
	if fuel_shop.buy_fuel(fuel_id):
		_set_action_feedback("Combustible comprado con hollín.", true, "%s comprado" % fuel_shop.get_display_name(fuel_id))
	elif not GameManager.is_fuel_unlocked(fuel_id):
		_set_action_feedback("Este combustible se desbloquea el día %d." % FuelCatalog.get_by_id(fuel_id).unlock_day, false)
	elif not GameManager.can_store_fuel():
		_set_action_feedback("Almacén lleno. Mejora su capacidad antes de comprar más.", false)
	elif GameManager.get_soot() < fuel_shop.get_price(fuel_id):
		_set_action_feedback("Necesitas %.0f de hollín para comprar %s." % [fuel_shop.get_price(fuel_id), fuel_shop.get_display_name(fuel_id)], false)
	else:
		_set_action_feedback("No se pudo completar la compra.", false)
	_refresh_hud()

func _on_ignite() -> void:
	if fire.burning:
		_set_action_feedback("La hoguera ya está encendida.", false)
	else:
		if fire.ignite():
			_set_action_feedback("La hoguera está encendida.", true, "¡Hoguera encendida!")
		else:
			_set_action_feedback("Añade combustible a la pila antes de encender.", false)
	_refresh_hud()

func _on_stoke() -> void:
	if fire.stoke():
		_set_action_feedback("Hoguera avivada: +50% hollín durante 12 segundos.", true, "Avivada · +50% / 12 s")
	elif not fire.burning:
		_set_action_feedback("Enciende la hoguera antes de avivarla.", false)
	elif fire.stoke_time_left > 0.0:
		_set_action_feedback("Espera a que termine el avivado actual.", false)
	elif GameManager.get_soot() < FireManager.STOKE_COST:
		_set_action_feedback("Necesitas 15 de hollín para avivar.", false)
	else:
		_set_action_feedback("No se pudo avivar la hoguera.", false)
	_refresh_hud()

func _on_rest() -> void:
	if GameManager.get_day_elapsed() < 120.0:
		feedback_label.text = "Podrás descansar después de 2 minutos de jornada."
		return
	var sold_ash := GameManager.close_workday()
	feedback_label.text = "Jornada cerrada: ceniza vendida por %.1f de hollín. Día %d." % [sold_ash, GameManager.get_day_number()]
	daily_save_elapsed = 0.0
	_refresh_hud()

func _on_upgrade_facility(kind: String) -> void:
	if GameManager.purchase_facility(kind): feedback_label.text = "Instalación mejorada: %s." % kind
	else: feedback_label.text = "Mejora no disponible: revisa hollín o nivel máximo."
	_refresh_hud()

func _on_dispatch_wagon() -> void:
	feedback_label.text = "Vagoneta despachada." if GameManager.dispatch_wagon() else "No hay ceniza disponible o la ruta está ocupada."
	_refresh_hud()

func _on_request_truck() -> void:
	if GameManager.request_fuel_truck():
		feedback_label.text = "Camión pedido; entrega en %.0f s." % GameManager.get_truck_seconds_left()
	else:
		feedback_label.text = "No se pudo pedir el camión (25 hollines y una ruta libre)."
	_refresh_hud()

func _on_experimental(id: String) -> void:
	if GameManager.get_tech_unlocked(id):
		feedback_label.text = "Tecnología activada: %s." % id if fire.activate_experimental(id) else "La tecnología requiere una combustión activa y hollín suficiente."
	elif GameManager.unlock_experimental(id):
		feedback_label.text = "Tecnología experimental desbloqueada: %s." % id
	else:
		feedback_label.text = "Requiere alcanzar el hito correspondiente y gastar una brasa."
	_refresh_hud()

func _on_critical_explosion() -> void:
	feedback_label.text = "¡Combustión crítica! +100 °C. La jornada termina; la ceniza no recogida se pierde."
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
	title.text = "ÁRBOL DE BRASAS"
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

	var map := Control.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size = Vector2(620, 400)
	content.add_child(map)
	var connections := SkillTreeConnections.new()
	connections.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	connections.points = [Vector2(0.5, 0.5), Vector2(0.5, 0.17), Vector2(0.25, 0.36), Vector2(0.75, 0.36), Vector2(0.3, 0.75), Vector2(0.7, 0.75)]
	connections.links = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(2, 4), Vector2i(3, 5)]
	connections.mouse_filter = Control.MOUSE_FILTER_IGNORE
	connections.resized.connect(connections.queue_redraw)
	map.add_child(connections)
	var node_ids: Array[String] = ["thermal_1", "thermal_2", "thermal_advanced", "soot_1", "soot_2", "soot_advanced"]
	for index in range(node_ids.size()):
		var node_id := node_ids[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 82)
		button.anchor_left = connections.points[index].x
		button.anchor_right = connections.points[index].x
		button.anchor_top = connections.points[index].y
		button.anchor_bottom = connections.points[index].y
		button.offset_left = -75
		button.offset_right = 75
		button.offset_top = -41
		button.offset_bottom = 41
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color("e7dfd0"))
		button.pressed.connect(_on_purchase_permanent_node.bind(node_id))
		map.add_child(button)
		permanent_buttons[node_id] = button
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
	advanced_tree_label.text = "NODOS PLACEHOLDER · LOS EFECTOS SE DEFINIRÁN MÁS ADELANTE"
	for node_id in permanent_buttons:
		var node_data: Dictionary = _get_permanent_node(str(node_id))
		var node_button: Button = permanent_buttons[node_id]
		var is_owned := GameManager.owns_permanent_node(str(node_id))
		var can_buy := GameManager.can_purchase_permanent_node(node_data)
		var state := _get_skill_node_state(node_data, is_owned, can_buy)
		node_button.text = "✧\n%s\n%d brasas · %s" % [str(node_data.name).to_upper(), int(node_data.cost), state]
		node_button.disabled = is_owned or not can_buy
		node_button.tooltip_text = "%s. Coste: %d brasas. %s" % [str(node_data.effect), int(node_data.cost), state]
		var node_color := Color("625b4e") if is_owned else (Color("514b41") if can_buy else Color("343638"))
		node_button.add_theme_stylebox_override("normal", _make_skill_panel_style(node_color, Color("d49a4b") if can_buy else Color("888276")))
		node_button.add_theme_stylebox_override("hover", _make_skill_panel_style(node_color.lightened(0.12), Color("f1c36e")))
		node_button.add_theme_stylebox_override("pressed", _make_skill_panel_style(node_color.darkened(0.15), Color("d88939")))
		node_button.add_theme_stylebox_override("disabled", _make_skill_panel_style(node_color.darkened(0.1), Color("716c62")))

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
	return _make_skill_panel_style(Color("292b2c"), Color("7e786c"))

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
	accessibility_button.text = "Accesibilidad: %s%s" % ["texto grande" if large_text else "texto normal", " | alto contraste" if high_contrast else ""]
	volume_button.text = "Volumen del fuego: %d%%" % int(fire_volume * 100.0)
	soot_label.text = "Hollín disponible: %.1f | Ceniza de la jornada: %.1f" % [GameManager.get_soot(), GameManager.get_daily_ash()]
	_update_resource_cards()
	stats_label.text = "Temperatura: %.1f °C (x%.2f) | Multiplicador: %.2fx\nBrasas ganadas: %d | Disponibles: %d" % [fire.current_heat, GameManager.get_thermal_multiplier(), GameManager.get_global_multiplier(), GameManager.get_permanent_points(), GameManager.get_available_embers()]
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
		toggle.add_theme_color_override("font_color", Color("FFC56A") if target_fire.automation_active else Color("E4DED2"))
		priority.text = "Prioridad: " + target_fire.get_fuel_priority_text()
		priority.disabled = not target_fire.automation_unlocked
	var remaining_day := maxf(0.0, 720.0 - GameManager.get_day_elapsed())
	delivery_label.text = "Día %d · %02d:%02d · ceniza suelta %.1f / silo %.1f/%d · próxima entrega al comenzar el día" % [GameManager.get_day_number(), int(remaining_day / 60.0), int(remaining_day) % 60, GameManager.get_uncollected_ash(), GameManager.get_silo_ash(), GameManager.get_silo_capacity()]
	for kind in facility_buttons:
		var level := GameManager.get_facility_level(str(kind))
		var capacity := "20→%d unidades" % GameManager.get_warehouse_capacity() if kind == "warehouse" else ("300→%d cenizas" % GameManager.get_silo_capacity() if kind == "silo" else ("vagoneta automática" if kind == "workshop" else "cargas %d | espera %.0f s" % [level + 1, maxf(30.0, 60.0 - 15.0 * level)]))
		var cost := 50.0 * pow(1.5, level)
		var button: Button = facility_buttons[kind]
		button.text = "%s nivel %d/3 · %s · mejorar (%.0f hollín)" % [str(kind).capitalize(), level, capacity, cost]
		button.disabled = level >= 3 or GameManager.get_soot() < cost
		var visual := get_node_or_null("Facility_" + str(kind)) as MeshInstance3D
		if visual != null:
			visual.scale.y = (1.0 + 0.2 * float(level)) * (1.4 if kind == "silo" else 0.9 if kind == "warehouse" else 0.7)
	wagon_button.text = "Vagoneta en ruta: %.1f s" % GameManager.get_truck_seconds_left() if GameManager.is_truck_pending() else "Enviar vagoneta (10 s, hasta 50 cenizas)"
	wagon_button.disabled = GameManager.is_truck_pending() or GameManager.get_uncollected_ash() <= 0.0 or GameManager.get_silo_ash() >= GameManager.get_silo_capacity()
	truck_button.text = "Camión en ruta: %.1f s" % GameManager.get_truck_seconds_left() if GameManager.is_truck_pending() else "Pedir camión (25 hollín)"
	truck_button.disabled = GameManager.is_truck_pending() or GameManager.get_soot() < 25.0
	for id in experimental_buttons:
		var threshold: int = int({"gas": 100, "tritium": 500, "laser": 1000}[str(id)])
		var button: Button = experimental_buttons[id]
		var effect_text := "activo x%.1f · %.1f s" % [fire.experimental_heat_multiplier, fire.experimental_time_left] if fire.experimental_time_left > 0.0 else ("activar (25 hollín)" if id in ["gas", "tritium"] else "activar (50 hollín)")
		button.text = "%s · %s" % [str(id).capitalize(), effect_text] if GameManager.get_tech_unlocked(id) else "%s · desbloquear (hito %d °C, 1 brasa)" % [str(id).capitalize(), threshold]
		var previous_tech := "gas" if id == "tritium" else "tritium" if id == "laser" else ""
		button.disabled = (not GameManager.get_tech_unlocked(id) and (not bool(GameManager.run_progress.claimed_temperature_milestones.get(str(threshold), false)) or GameManager.get_available_embers() < 1 or (not previous_tech.is_empty() and not GameManager.get_tech_unlocked(previous_tech)))) or (GameManager.get_tech_unlocked(id) and (not fire.burning or GameManager.get_soot() < (50.0 if id == "laser" else 25.0)))
	rest_button.disabled = GameManager.get_day_elapsed() < 120.0
	var live_rate := 0.0
	var stations: Array[FireManager] = [fire, second_fire]
	for station in stations:
		if not station.burning:
			continue
		var station_rate: float = GameManager.get_soot_rate(station.current_heat) * station.local_production_multiplier
		if station.stoke_time_left > 0.0:
			station_rate *= FireManager.STOKE_MULTIPLIER
		live_rate += station_rate
	rate_label.text = "Produccion actual: %.1f hollin/s" % live_rate
	var next_milestone := GameManager.get_next_temperature_milestone()
	progress_label.text = "Siguiente hito: %.0f °C" % next_milestone if next_milestone > 0 else "Todos los hitos de temperatura alcanzados"
	progress_bar.max_value = float(next_milestone) if next_milestone > 0 else 1.0
	progress_bar.value = minf(fire.current_heat, float(next_milestone)) if next_milestone > 0 else 1.0
	fire_intensity_label.text = "INTENSIDAD · %.1f °C (escala visual hasta 1.000 °C)" % fire.current_heat
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
		var unlocked := GameManager.is_fuel_unlocked(fuel_id)
		fuel_button.disabled = available <= 0 or not unlocked
		fuel_button.text = "Anadir %s (%d)" % [fuel_id, available] if unlocked else "%s · disponible el día %d" % [fuel_id, FuelCatalog.get_by_id(fuel_id).unlock_day]
	for fuel_id in purchase_buttons:
		var purchase_button: Button = purchase_buttons[fuel_id]
		var price := fuel_shop.get_price(fuel_id)
		var unlocked := GameManager.is_fuel_unlocked(fuel_id)
		purchase_button.disabled = not unlocked or GameManager.get_soot() < price
		purchase_button.text = "Comprar %s (%.0f hollin)" % [fuel_shop.get_display_name(fuel_id), price] if unlocked else "%s · se desbloquea el día %d" % [fuel_shop.get_display_name(fuel_id), FuelCatalog.get_by_id(fuel_id).unlock_day]
	ignite_button.disabled = fire.burning or fire.fuel_queue.is_empty()
	stoke_button.text = "Avivar (+50% durante 12 s | 15 hollin)" if fire.stoke_time_left <= 0.0 else "Avivando (%.1f s)" % fire.stoke_time_left
	stoke_button.disabled = not fire.burning or fire.stoke_time_left > 0.0 or GameManager.get_soot() < FireManager.STOKE_COST
	stoke_button.add_theme_color_override("font_color", Color("FFC56A") if fire.stoke_time_left > 0.0 else Color("E4DED2"))
	if fire.stoke_time_left > 0.0:
		stoke_button.add_theme_color_override("font_disabled_color", Color("FFC56A"))
	else:
		stoke_button.remove_theme_color_override("font_disabled_color")
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
	if is_instance_valid(second_fire_light):
		var second_light_base := 0.25 + minf(second_fire.current_heat / 35.0, 1.0) * 1.8
		var second_flicker := 1.0 + sin(float(Time.get_ticks_msec()) / 97.0 + 1.3) * 0.08
		second_fire_light.light_energy = 0.0 if second_fire.current_heat <= 0.1 else second_light_base * second_flicker
	if skill_tree_overlay.visible:
		_refresh_skill_tree()
func _request_hud_refresh() -> void:
	hud_refresh_pending = true

func _format_resource_count(value: float) -> String:
	return "%.0f" % value if value >= 100.0 else "%.1f" % value

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
	if fire.burning and fire.current_heat >= 100.0 and GameManager.is_fuel_unlocked("combustible_liquido"):
		for queued_fuel in fire.fuel_queue:
			if queued_fuel.fuel_id == "carbon":
				guidance_label.text += " Señales de inestabilidad: mezcla crítica posible."
				break

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
	if amount < 0.1:
		return
	_show_resource_popup("+%.1f hollín" % amount, Color("FFC56A"))

func _show_resource_popup(message: String, tint: Color) -> void:
	if not is_instance_valid(hud_layer):
		return
	for index in range(gain_popups.size() - 1, -1, -1):
		if not is_instance_valid(gain_popups[index]):
			gain_popups.remove_at(index)
	if gain_popups.size() >= 4:
		gain_popups.pop_front().queue_free()
	var popup := Label.new()
	popup.text = message
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", tint)
	popup.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.025, 0.95))
	popup.add_theme_constant_override("outline_size", 4)
	var viewport_size := get_viewport().get_visible_rect().size
	var start_position := Vector2(viewport_size.x * 0.55, viewport_size.y * 0.52 - gain_popups.size() * 28.0)
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
