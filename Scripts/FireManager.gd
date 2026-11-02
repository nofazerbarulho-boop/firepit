extends Node3D
class_name FireManager

signal fire_changed
signal gain_batch(amount: float)
signal critical_explosion

const FUEL_HOJARASCA: FuelData = preload("res://Resources/Hojarasca.tres")
const FUEL_LENA: FuelData = preload("res://Resources/Leña.tres")
const FUEL_TRONCO: FuelData = preload("res://Resources/Tronco.tres")
const FUEL_TURBA: FuelData = preload("res://Resources/Turba.tres")
const FUEL_TYPES := {"hojarasca": FUEL_HOJARASCA, "leña": FUEL_LENA, "tronco": FUEL_TRONCO, "turba": FUEL_TURBA}
const MIX_STEP_BONUS := 0.12
const VARIETY_BONUS := 0.04
const REPEAT_PENALTY := 0.02
const IGNITION_HEAT_BONUS := 1.2
const STOKE_COST := 15.0
const STOKE_DURATION := 12.0
const STOKE_MULTIPLIER := 1.5

var fuel_queue: Array[FuelData] = []
var current_heat: float = 0.0
var burning: bool = false
var remaining_burn: float = 0.0
var flame: MeshInstance3D
var flame_material: StandardMaterial3D
var pending_gain: float = 0.0
var popup_interval: float = 0.4
var popup_timer: float = 0.0
var active_quality: float = 1.0
var stoke_time_left: float = 0.0
var recovered_ember_heat: float = 0.0
var biome_heat_multiplier: float = 1.0
var has_private_inventory: bool = false
var uses_ember_reserve: bool = true
var local_production_multiplier: float = 1.0
var local_upgrade_level: int = 0
var private_stock: Dictionary = {}
var automation_unlocked: bool = false
var automation_active: bool = false
var fuel_priority: Array[String] = ["hojarasca", "leña", "tronco", "turba"]
var visual_tier: int = 0
var cosmetic_skin: int = 0
var fire_particles: GPUParticles3D
var spark_particles: GPUParticles3D
var inner_flame: MeshInstance3D
var flame_tongues: Array[MeshInstance3D] = []
var fire_audio: AudioStreamPlayer
var audio_volume: float = 0.35
var hud_signal_timer: float = 0.0
var experimental_time_left: float = 0.0
var experimental_heat_multiplier: float = 1.0
var fuel_visuals: Array[RigidBody3D] = []
var fuel_visual_materials: Array[Material] = []
var fuel_visual_ids: Array[String] = []
var fuel_bed: StaticBody3D
var smoke_particles: GPUParticles3D
var ember_core: MeshInstance3D
var leaf_burn_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	if has_private_inventory:
		private_stock = build_starting_stock()
	_build_fire_visuals()
	_update_visuals()

func add_fuel(fuel_id: String) -> bool:
	if not GameManager.is_fuel_unlocked(fuel_id):
		return false
	var data: FuelData = FUEL_TYPES.get(fuel_id, FuelCatalog.get_by_id(fuel_id))
	if data == null:
		return false
	if has_private_inventory:
		if int(private_stock.get(fuel_id, 0)) <= 0:
			return false
		private_stock[fuel_id] = int(private_stock[fuel_id]) - 1
	elif not GameManager.take_fuel(fuel_id):
		return false
	fuel_queue.append(data)
	_spawn_fuel_visual(fuel_id)
	if fuel_id == "combustible_liquido" and burning and current_heat >= 100.0 and _queue_contains("carbon"):
		fire_changed.emit()
		if randf() < 0.05:
			current_heat += 100.0
			burning = false
			fuel_queue.clear()
			_clear_fuel_visuals()
			remaining_burn = 0.0
			GameManager.close_workday()
			critical_explosion.emit()
			_update_visuals()
			fire_changed.emit()
			return true
	if not burning:
		active_quality = get_queue_quality()
	fire_changed.emit()
	return true

func _queue_contains(fuel_id: String) -> bool:
	for queued in fuel_queue:
		if queued.fuel_id == fuel_id: return true
	return false

func get_queue_quality() -> float:
	if fuel_queue.size() <= 1:
		return 1.0
	var unique_fuels: Dictionary = {}
	var score := 1.0
	for index in range(fuel_queue.size()):
		var fuel_id := fuel_queue[index].fuel_id
		unique_fuels[fuel_id] = true
		if index == 0:
			continue
		var previous_id := fuel_queue[index - 1].fuel_id
		if previous_id == "hojarasca" and fuel_id == "leña":
			score += MIX_STEP_BONUS
		elif previous_id == "leña" and fuel_id == "tronco":
			score += MIX_STEP_BONUS
		elif previous_id == fuel_id:
			score -= REPEAT_PENALTY
	score += maxf(0.0, float(unique_fuels.size() - 1)) * VARIETY_BONUS
	return clampf(score, 0.75, 1.5)

func get_current_phase() -> String:
	if burning and not fuel_queue.is_empty():
		match fuel_queue[0].fuel_id:
			"hojarasca": return "Encendido · +20% calor"
			"leña": return "Mantenimiento · leña"
			"tronco": return "Combustión larga · tronco"
	if GameManager.get_next_run_ember_reserve() > 0.0:
		return "Brasa recuperable para la próxima run"
	if current_heat > 0.1:
		return "Enfriamiento"
	return "Apagada"

func stoke() -> bool:
	if not burning or stoke_time_left > 0.0 or not GameManager.spend_soot(STOKE_COST):
		return false
	stoke_time_left = STOKE_DURATION
	fire_changed.emit()
	return true

func activate_experimental(id: String) -> bool:
	if not burning or not GameManager.activate_experimental(id): return false
	experimental_time_left = 12.0 if id == "tritium" else 10.0
	experimental_heat_multiplier = 2.0 if id == "tritium" else 1.5
	fire_changed.emit()
	return true

func get_fuel_description(fuel_id: String) -> String:
	var data: FuelData = FUEL_TYPES.get(fuel_id, FuelCatalog.get_by_id(fuel_id))
	if data == null:
		return "Combustible desconocido."
	return "%s: %.1f calor/s durante %.1f s." % [data.display_name, data.heat_value, data.burn_duration]

func remove_last_fuel() -> bool:
	var first_removable_index := 1 if burning else 0
	if fuel_queue.size() <= first_removable_index:
		return false
	var removed_fuel: FuelData = fuel_queue.pop_back()
	_remove_fuel_visual_at(fuel_visuals.size() - 1, false)
	if has_private_inventory:
		private_stock[removed_fuel.fuel_id] = int(private_stock.get(removed_fuel.fuel_id, 0)) + 1
	else:
		GameManager.return_fuel(removed_fuel.fuel_id)
	if not burning:
		active_quality = get_queue_quality()
	fire_changed.emit()
	return true

func ignite() -> bool:
	if burning or fuel_queue.is_empty():
		return false
	burning = true
	active_quality = get_queue_quality()
	recovered_ember_heat = GameManager.consume_next_run_ember_reserve() if uses_ember_reserve else 0.0
	current_heat += recovered_ember_heat
	remaining_burn = fuel_queue[0].burn_duration
	fire_changed.emit()
	return true

func clear_for_new_run() -> void:
	fuel_queue.clear()
	burning = false
	remaining_burn = 0.0
	current_heat = 0.0
	active_quality = 1.0
	stoke_time_left = 0.0
	recovered_ember_heat = 0.0
	pending_gain = 0.0
	popup_timer = 0.0
	if has_private_inventory:
		private_stock = build_starting_stock()
		local_production_multiplier = 1.0
		local_upgrade_level = 0
	automation_unlocked = false
	automation_active = false
	_update_visuals()
	fire_changed.emit()

func get_save_state() -> Dictionary:
	var queued_fuels: Array[String] = []
	for fuel in fuel_queue:
		queued_fuels.append(fuel.fuel_id)
	return {
		"fuel_queue": queued_fuels,
		"burning": burning,
		"remaining_burn": remaining_burn,
		"current_heat": current_heat,
		"active_quality": active_quality,
		"stoke_time_left": stoke_time_left,
	}

func restore_save_state(state: Dictionary) -> void:
	fuel_queue.clear()
	_clear_fuel_visuals()
	var saved_queue: Variant = state.get("fuel_queue", [])
	if saved_queue is Array:
		for raw_id in saved_queue:
			var fuel_id := str(raw_id)
			if not GameManager.is_fuel_unlocked(fuel_id):
				continue
			var fuel_data := FuelCatalog.get_by_id(fuel_id)
			if fuel_data == null:
				continue
			fuel_queue.append(fuel_data)
			_spawn_fuel_visual(fuel_id)
	current_heat = maxf(0.0, float(state.get("current_heat", 0.0)))
	active_quality = clampf(float(state.get("active_quality", 1.0)), 0.75, 1.5)
	stoke_time_left = maxf(0.0, float(state.get("stoke_time_left", 0.0)))
	burning = bool(state.get("burning", false)) and not fuel_queue.is_empty()
	remaining_burn = clampf(float(state.get("remaining_burn", 0.0)), 0.0, fuel_queue[0].burn_duration) if burning else 0.0
	if burning and remaining_burn <= 0.0:
		remaining_burn = fuel_queue[0].burn_duration
	automation_unlocked = false
	automation_active = false
	_update_visuals()
	fire_changed.emit()

func build_starting_stock() -> Dictionary:
	var stock: Dictionary = {}
	for fuel_data in FuelCatalog.get_all():
		stock[fuel_data.fuel_id] = fuel_data.starting_stock
	return stock

func get_station_stock() -> Dictionary:
	return private_stock.duplicate(true) if has_private_inventory else GameManager.get_fuel_stock()

func add_delivery(fuel_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	if has_private_inventory:
		private_stock[fuel_id] = mini(InventoryManager.MAX_STOCK_PER_FUEL, int(private_stock.get(fuel_id, 0)) + amount)
	else:
		GameManager.add_fuel_stock(fuel_id, amount)
	fire_changed.emit()

func _process(delta: float) -> void:
	hud_signal_timer += delta
	_run_automation()
	stoke_time_left = maxf(0.0, stoke_time_left - delta)
	if experimental_time_left > 0.0:
		experimental_time_left = maxf(0.0, experimental_time_left - delta)
		if experimental_time_left <= 0.0: experimental_heat_multiplier = 1.0
	var time_left := delta
	var pile_finished := false
	while burning and time_left > 0.0:
		if fuel_queue.is_empty():
			burning = false
			break
		var fuel: FuelData = fuel_queue[0]
		var step := minf(time_left, remaining_burn)
		var starting_heat := current_heat
		var phase_heat_multiplier := IGNITION_HEAT_BONUS if fuel.fuel_id == "hojarasca" else 1.0
		var heat_per_second := fuel.heat_value * phase_heat_multiplier * active_quality * GameManager.get_thermal_multiplier() * biome_heat_multiplier * experimental_heat_multiplier
		current_heat += heat_per_second * step
		var average_heat := starting_heat + heat_per_second * step * 0.5
		var production_multiplier := STOKE_MULTIPLIER if stoke_time_left > 0.0 else 1.0
		var produced := GameManager.get_soot_rate(average_heat) * production_multiplier * local_production_multiplier * step
		GameManager.add_soot(produced)
		pending_gain += produced
		remaining_burn -= step
		time_left -= step
		if remaining_burn <= 0.0001:
			fuel_queue.pop_front()
			_remove_fuel_visual_at(0, true)
			if fuel_queue.is_empty():
				burning = false
				pile_finished = true
			else:
				active_quality = get_queue_quality()
				remaining_burn = fuel_queue[0].burn_duration
	if pile_finished:
		GameManager.add_run_ember_reserve(current_heat)
	if automation_active and fuel_queue.is_empty():
		_run_automation()
	if not burning:
		current_heat = maxf(0.0, current_heat - 2.0 * delta)
	_update_fuel_visual_state()
	popup_timer += delta
	if popup_timer >= popup_interval:
		if pending_gain > 0.0:
			gain_batch.emit(pending_gain)
			pending_gain = 0.0
		popup_timer = fposmod(popup_timer, popup_interval)
	_update_visuals()
	if hud_signal_timer >= 0.25:
		hud_signal_timer = fposmod(hud_signal_timer, 0.25)
		fire_changed.emit()

func _run_automation() -> void:
	if not automation_unlocked or not automation_active:
		return
	ensure_fuel_priority()
	if not burning and fuel_queue.is_empty():
		for fuel_id in fuel_priority:
			if get_station_fuel_count(fuel_id) > 0 and add_fuel(fuel_id):
				break
	if not burning and not fuel_queue.is_empty():
		ignite()

func get_station_fuel_count(fuel_id: String) -> int:
	return int(private_stock.get(fuel_id, 0)) if has_private_inventory else GameManager.get_fuel_count(fuel_id)

func cycle_fuel_priority() -> void:
	ensure_fuel_priority()
	if fuel_priority.size() > 1:
		fuel_priority.append(fuel_priority.pop_front())
	fire_changed.emit()

func ensure_fuel_priority() -> void:
	for fuel_data in FuelCatalog.get_all():
		if not fuel_priority.has(fuel_data.fuel_id):
			fuel_priority.append(fuel_data.fuel_id)
	for fuel_id in fuel_priority.duplicate():
		if FuelCatalog.get_by_id(fuel_id) == null:
			fuel_priority.erase(fuel_id)

func get_fuel_priority_text() -> String:
	ensure_fuel_priority()
	var names := PackedStringArray()
	for fuel_id in fuel_priority:
		var fuel_data := FuelCatalog.get_by_id(fuel_id)
		if fuel_data != null:
			names.append(fuel_data.display_name)
	return " > ".join(names)

func get_automation_fuel_seconds() -> float:
	ensure_fuel_priority()
	if not automation_unlocked or not automation_active:
		return 0.0
	var available := get_station_stock()
	for fuel in fuel_queue:
		available[fuel.fuel_id] = int(available.get(fuel.fuel_id, 0)) + 1
	var total := 0.0
	for fuel_data in FuelCatalog.get_all():
		total += float(available.get(fuel_data.fuel_id, 0)) * fuel_data.burn_duration
	return total

func get_automation_average_rate() -> float:
	ensure_fuel_priority()
	var duration := get_automation_fuel_seconds()
	if duration <= 0.0:
		return 0.0
	var available := get_station_stock()
	for fuel in fuel_queue:
		available[fuel.fuel_id] = int(available.get(fuel.fuel_id, 0)) + 1
	var heat := current_heat
	var total_soot := 0.0
	var fuel_count := 0
	for fuel_id in fuel_priority:
		var fuel_data := FuelCatalog.get_by_id(fuel_id)
		if fuel_data == null:
			continue
		for index in range(int(available.get(fuel_id, 0))):
			var quality := 1.0
			var heat_rate := fuel_data.heat_value * (1.2 if fuel_id == "hojarasca" else 1.0) * GameManager.get_thermal_multiplier() * biome_heat_multiplier
			var end_heat := heat + heat_rate * fuel_data.burn_duration
			total_soot += GameManager.get_soot_rate((heat + end_heat) * 0.5) * local_production_multiplier * quality * fuel_data.burn_duration
			heat = end_heat
			fuel_count += 1
	return total_soot / duration if fuel_count > 0 else 0.0

func _build_fire_visuals() -> void:
	_build_fuel_bed()
	_build_ember_core()
	flame = get_node_or_null("Flame") as MeshInstance3D
	if flame == null:
		flame = MeshInstance3D.new()
		flame.name = "Flame"
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.45
		flame_mesh.height = 1.3
		flame.mesh = flame_mesh
		flame.position.y = 0.85
		add_child(flame)
	flame_material = flame.material_override as StandardMaterial3D
	if flame_material == null:
		flame_material = StandardMaterial3D.new()
		flame.material_override = flame_material
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.22, 0.025)
	flame_material.emission_energy_multiplier = 2.2
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_material.albedo_color = Color(1.0, 0.3, 0.025, 0.82)
	flame_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	inner_flame = MeshInstance3D.new()
	inner_flame.name = "FlameCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.25
	core_mesh.height = 0.85
	inner_flame.mesh = core_mesh
	inner_flame.position = Vector3(0.0, 0.04, -0.04)
	var core_material := StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.emission_enabled = true
	core_material.emission = Color(1.0, 0.78, 0.24)
	core_material.emission_energy_multiplier = 3.0
	core_material.albedo_color = Color(1.0, 0.78, 0.24, 0.9)
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	inner_flame.material_override = core_material
	flame.add_child(inner_flame)
	# A trio of tapered tongues gives the fire a readable silhouette beyond the soft outer glow.
	var tongue_colors: Array[Color] = [Color(1.0, 0.30, 0.035), Color(1.0, 0.48, 0.055), Color(1.0, 0.22, 0.025)]
	for index in range(3):
		var tongue := MeshInstance3D.new()
		tongue.name = "FlameTongue%d" % index
		var tongue_mesh := CylinderMesh.new()
		tongue_mesh.top_radius = 0.015
		tongue_mesh.bottom_radius = 0.14 if index == 0 else 0.105
		tongue_mesh.height = 0.72 if index == 0 else 0.55
		tongue.mesh = tongue_mesh
		tongue.position = Vector3((index - 1) * 0.13, 0.12, 0.04 if index != 1 else -0.10)
		tongue.rotation.z = deg_to_rad((index - 1) * 12.0)
		var tongue_material := StandardMaterial3D.new()
		tongue_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tongue_material.emission_enabled = true
		tongue_material.emission = tongue_colors[index]
		tongue_material.emission_energy_multiplier = 2.0
		tongue_material.albedo_color = Color(tongue_colors[index].r, tongue_colors[index].g, tongue_colors[index].b, 0.88)
		tongue_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tongue_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		tongue.material_override = tongue_material
		flame.add_child(tongue)
		flame_tongues.append(tongue)
	fire_particles = GPUParticles3D.new()
	fire_particles.name = "FireParticles"
	fire_particles.amount = 24
	fire_particles.lifetime = 0.8
	fire_particles.position.y = 0.35
	var particle_process := ParticleProcessMaterial.new()
	particle_process.direction = Vector3(0, 1, 0)
	particle_process.spread = 28.0
	particle_process.initial_velocity_min = 0.25
	particle_process.initial_velocity_max = 0.8
	particle_process.gravity = Vector3(0, 0.7, 0)
	particle_process.scale_min = 0.025
	particle_process.scale_max = 0.07
	particle_process.color = Color(1.0, 0.35, 0.06, 0.8)
	fire_particles.process_material = particle_process
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.035
	particle_mesh.height = 0.07
	fire_particles.draw_pass_1 = particle_mesh
	add_child(fire_particles)
	spark_particles = GPUParticles3D.new()
	spark_particles.name = "EmberSparks"
	spark_particles.amount = 18
	spark_particles.lifetime = 1.15
	spark_particles.position.y = 0.35
	var spark_process := ParticleProcessMaterial.new()
	spark_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spark_process.emission_sphere_radius = 0.22
	spark_process.direction = Vector3(0.0, 1.0, 0.0)
	spark_process.spread = 48.0
	spark_process.initial_velocity_min = 0.45
	spark_process.initial_velocity_max = 1.4
	spark_process.gravity = Vector3(0.0, 0.35, 0.0)
	spark_process.scale_min = 0.018
	spark_process.scale_max = 0.045
	spark_process.color = Color(1.0, 0.72, 0.2, 0.95)
	spark_particles.process_material = spark_process
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.025
	spark_mesh.height = 0.05
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.48, 0.08)
	spark_material.emission_energy_multiplier = 2.0
	spark_mesh.material = spark_material
	spark_particles.draw_pass_1 = spark_mesh
	add_child(spark_particles)
	smoke_particles = GPUParticles3D.new()
	smoke_particles.name = "SootSmoke"
	smoke_particles.amount = 16
	smoke_particles.lifetime = 1.6
	smoke_particles.position.y = 0.45
	var smoke_process := ParticleProcessMaterial.new()
	smoke_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_process.emission_sphere_radius = 0.16
	smoke_process.direction = Vector3(0.0, 1.0, 0.0)
	smoke_process.spread = 18.0
	smoke_process.initial_velocity_min = 0.12
	smoke_process.initial_velocity_max = 0.32
	smoke_process.gravity = Vector3(0.0, -0.08, 0.0)
	smoke_process.scale_min = 0.035
	smoke_process.scale_max = 0.09
	smoke_process.color = Color(0.10, 0.09, 0.08, 0.34)
	smoke_particles.process_material = smoke_process
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.08
	smoke_mesh.height = 0.16
	var smoke_material := StandardMaterial3D.new()
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.albedo_color = Color(0.10, 0.09, 0.08, 0.30)
	smoke_mesh.material = smoke_material
	smoke_particles.draw_pass_1 = smoke_mesh
	add_child(smoke_particles)
	fire_audio = AudioStreamPlayer.new()
	fire_audio.name = "FireAudio"
	fire_audio.stream = _make_fire_loop()
	fire_audio.volume_db = -22.0
	add_child(fire_audio)
	fire_audio.play()

func _build_ember_core() -> void:
	ember_core = MeshInstance3D.new()
	ember_core.name = "EmberCore"
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.075
	ember_mesh.height = 0.15
	ember_core.mesh = ember_mesh
	ember_core.position = Vector3(0.0, 0.30, 0.0)
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.20, 0.015)
	ember_material.emission_energy_multiplier = 4.0
	ember_material.albedo_color = Color(1.0, 0.28, 0.025, 0.9)
	ember_core.material_override = ember_material
	add_child(ember_core)

func _build_fuel_bed() -> void:
	if get_node_or_null("FuelBed") != null:
		return
	fuel_bed = StaticBody3D.new()
	fuel_bed.name = "FuelBed"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, 0.16, 1.15)
	collision.shape = shape
	collision.position.y = 0.20
	fuel_bed.add_child(collision)
	add_child(fuel_bed)

func _spawn_fuel_visual(fuel_id: String) -> void:
	var body := RigidBody3D.new()
	body.name = "Fuel_%s" % fuel_id
	body.mass = 0.8
	body.freeze = false
	body.linear_damp = 1.8
	body.angular_damp = 2.5
	body.position = Vector3(randf_range(-0.18, 0.18), 1.05 + fuel_visuals.size() * 0.18, randf_range(-0.18, 0.18))
	body.rotation = Vector3(randf_range(-0.3, 0.3), randf_range(0.0, TAU), randf_range(-0.3, 0.3))
	var mesh_instance := MeshInstance3D.new()
	var shape: Shape3D
	var material := StandardMaterial3D.new()
	material.roughness = 0.92
	material.albedo_color = _fuel_color(fuel_id)
	var leaf_shader_material: ShaderMaterial
	match fuel_id:
		"hojarasca":
			var leaf := SphereMesh.new()
			leaf.radius = 0.22
			leaf.height = 0.07
			mesh_instance.mesh = leaf
			mesh_instance.scale = Vector3(1.2, 0.45, 0.8)
			leaf_shader_material = _make_leaf_burn_material()
			shape = SphereShape3D.new()
			(shape as SphereShape3D).radius = 0.16
			var vein := MeshInstance3D.new()
			var vein_mesh := CylinderMesh.new()
			vein_mesh.top_radius = 0.006
			vein_mesh.bottom_radius = 0.009
			vein_mesh.height = 0.29
			vein.mesh = vein_mesh
			vein.rotation_degrees.z = 90.0
			var vein_material := StandardMaterial3D.new()
			vein_material.albedo_color = Color(0.68, 0.43, 0.12)
			vein_material.roughness = 1.0
			vein.material_override = vein_material
			mesh_instance.add_child(vein)
		"turba":
			var block := BoxMesh.new()
			block.size = Vector3(0.38, 0.18, 0.28)
			mesh_instance.mesh = block
			shape = BoxShape3D.new()
			(shape as BoxShape3D).size = block.size
		"carbon":
			var coal := SphereMesh.new()
			coal.radius = 0.19
			coal.height = 0.25
			mesh_instance.mesh = coal
			shape = SphereShape3D.new()
			(shape as SphereShape3D).radius = 0.17
		_:
			var log := CylinderMesh.new()
			log.top_radius = 0.105
			log.bottom_radius = 0.13
			log.height = 0.72 if fuel_id == "tronco" else 0.48
			mesh_instance.mesh = log
			mesh_instance.rotation_degrees.z = 90.0
			# Pale cut ends make the timber read as logs instead of plain cylinders.
			var end_material := StandardMaterial3D.new()
			end_material.albedo_color = Color(0.62, 0.39, 0.19) if fuel_id == "leña" else Color(0.48, 0.30, 0.16)
			end_material.roughness = 1.0
			for end_sign in [-1.0, 1.0]:
				var end_cap := MeshInstance3D.new()
				var cap_mesh := CylinderMesh.new()
				cap_mesh.top_radius = 0.105
				cap_mesh.bottom_radius = 0.13
				cap_mesh.height = 0.018
				end_cap.mesh = cap_mesh
				end_cap.position.y = end_sign * log.height * 0.48
				end_cap.material_override = end_material
				mesh_instance.add_child(end_cap)
			shape = CylinderShape3D.new()
			(shape as CylinderShape3D).radius = 0.12
			(shape as CylinderShape3D).height = log.height
	mesh_instance.material_override = leaf_shader_material if leaf_shader_material != null else material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	if fuel_id in ["leña", "tronco"]:
		collision.rotation_degrees.z = 90.0
	body.add_child(collision)
	add_child(body)
	fuel_visuals.append(body)
	fuel_visual_materials.append(leaf_shader_material if leaf_shader_material != null else material)
	leaf_burn_materials.append(leaf_shader_material)
	fuel_visual_ids.append(fuel_id)
	var toss := Vector3(randf_range(-0.55, 0.55), -0.15, randf_range(-0.4, 0.4))
	body.apply_impulse(toss)
	body.apply_torque_impulse(Vector3(randf_range(-0.35, 0.35), randf_range(-0.6, 0.6), randf_range(-0.35, 0.35)))

func _fuel_color(fuel_id: String) -> Color:
	match fuel_id:
		"hojarasca": return Color(0.43, 0.27, 0.08)
		"turba": return Color(0.25, 0.13, 0.08)
		"carbon": return Color(0.09, 0.08, 0.07)
		"tronco": return Color(0.31, 0.16, 0.075)
		_: return Color(0.42, 0.23, 0.10)

func _make_leaf_burn_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform float burn_progress = 0.0;
uniform float dissolve = 0.0;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.5);
	float radial = length(p * vec2(1.0, 1.25));
	float local_burn = clamp(burn_progress - radial * 0.85 + 0.08, 0.0, 1.0);
	vec3 yellow = vec3(0.92, 0.62, 0.12);
	vec3 charred = vec3(0.075, 0.045, 0.025);
	vec3 red = vec3(1.0, 0.12, 0.012);
	vec3 ash = vec3(0.43, 0.44, 0.42);
	vec3 color = mix(yellow, charred, smoothstep(0.02, 0.27, local_burn));
	color = mix(color, red, smoothstep(0.30, 0.57, local_burn));
	color = mix(color, ash, smoothstep(0.63, 0.94, local_burn));
	float vein = 1.0 - smoothstep(0.008, 0.024, abs(p.y) + abs(p.x) * 0.42);
	color = mix(color, color * 1.22, vein * (1.0 - smoothstep(0.15, 0.85, local_burn)));
	ALBEDO = color;
	ROUGHNESS = 0.96;
	EMISSION = red * smoothstep(0.31, 0.56, local_burn) * (1.0 - smoothstep(0.58, 0.86, local_burn)) * 0.85;
	ALPHA = 1.0 - dissolve;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("burn_progress", 0.0)
	material.set_shader_parameter("dissolve", 0.0)
	return material

func _remove_fuel_visual_at(index: int, burnt: bool) -> void:
	if index < 0 or index >= fuel_visuals.size():
		return
	var body := fuel_visuals[index]
	var material := fuel_visual_materials[index]
	if is_instance_valid(body):
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		if burnt:
			# A quick lift and flash sells the moment the last flame eats the fuel.
			body.position.y += 0.12
			var tween := create_tween()
			if material is ShaderMaterial:
				(material as ShaderMaterial).set_shader_parameter("burn_progress", 1.0)
				tween.tween_property(body, "scale", Vector3(0.06, 0.06, 0.06), 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tween.parallel().tween_method(func(value: float) -> void: (material as ShaderMaterial).set_shader_parameter("dissolve", value), 0.0, 1.0, 0.85)
			else:
				var standard_material := material as StandardMaterial3D
				standard_material.emission_enabled = true
				standard_material.emission = Color(1.0, 0.34, 0.045)
				standard_material.emission_energy_multiplier = 2.8
				standard_material.albedo_color = Color(0.055, 0.045, 0.035)
				tween.tween_property(body, "scale", Vector3(0.06, 0.06, 0.06), 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tween.parallel().tween_property(standard_material, "albedo_color", Color(0.06, 0.05, 0.045, 0.0), 0.85)
				tween.parallel().tween_property(standard_material, "emission_energy_multiplier", 0.0, 0.55)
			tween.tween_callback(body.queue_free)
		else:
			body.queue_free()
	fuel_visuals.remove_at(index)
	fuel_visual_materials.remove_at(index)
	leaf_burn_materials.remove_at(index)
	fuel_visual_ids.remove_at(index)

func _clear_fuel_visuals() -> void:
	for body in fuel_visuals:
		if is_instance_valid(body): body.queue_free()
	fuel_visuals.clear()
	fuel_visual_materials.clear()
	leaf_burn_materials.clear()
	fuel_visual_ids.clear()

func set_visual_style(tier: int, skin: int) -> void:
	visual_tier = clampi(tier, 0, 3)
	cosmetic_skin = clampi(skin, 0, 2)
	_update_visuals()

func set_fire_volume(volume: float) -> void:
	audio_volume = clampf(volume, 0.0, 1.0)
	if fire_audio != null:
		fire_audio.volume_db = -80.0 if audio_volume <= 0.001 else linear_to_db(audio_volume)

func _make_fire_loop() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 8000
	var samples := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 76231
	for index in range(8000):
		var sample := 128.0 + rng.randf_range(-8.0, 8.0) + sin(float(index) * 0.0369) * 3.0
		samples.append(clampi(int(sample), 0, 255))
	wav.data = samples
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = samples.size()
	return wav

func _update_visuals() -> void:
	if flame == null:
		return
	flame.visible = current_heat > 0.1
	if is_instance_valid(ember_core):
		ember_core.visible = current_heat > 0.1
		var ember_pulse := 0.88 + 0.12 * sin(float(Time.get_ticks_msec()) / 73.0)
		ember_core.scale = Vector3.ONE * ember_pulse * clampf(0.45 + current_heat / 80.0, 0.45, 1.0)
	if fire_particles != null:
		fire_particles.emitting = current_heat > 0.1
		fire_particles.amount = 8 + int(clampf(current_heat, 0.0, 60.0))
	if spark_particles != null:
		spark_particles.emitting = current_heat > 0.1
		spark_particles.amount = 4 + int(clampf(current_heat * 0.45, 0.0, 24.0))
	if smoke_particles != null:
		smoke_particles.emitting = burning and not fuel_queue.is_empty()
		smoke_particles.amount = 6 + int(clampf(current_heat * 0.18, 0.0, 14.0))
	if fire_audio != null:
		fire_audio.volume_db = -80.0 if current_heat <= 0.1 or audio_volume <= 0.001 else linear_to_db(audio_volume) - 10.0 + minf(current_heat / 10.0, 1.0) * 8.0
	var intensity := clampf(current_heat / 45.0, 0.15, 1.0)
	var time := float(Time.get_ticks_msec()) / 1000.0
	var flicker := 1.0 + sin(time * 13.0) * 0.06 + sin(time * 21.7) * 0.035
	flame.scale = Vector3(0.6 * flicker, intensity * flicker, 0.6 * flicker)
	if is_instance_valid(inner_flame):
		inner_flame.scale = Vector3(0.68, 0.78 + sin(time * 17.0) * 0.08, 0.68)
	for index in range(flame_tongues.size()):
		var tongue := flame_tongues[index]
		if is_instance_valid(tongue):
			var pulse := 0.78 + 0.20 * sin(time * (11.0 + index * 2.7) + index * 2.1)
			tongue.scale = Vector3(pulse, pulse * (0.90 + 0.16 * sin(time * 15.0 + index)), pulse)
			tongue.position.y = 0.12 + 0.035 * sin(time * (13.0 + index) + index)
	var tier_colors: Array[Color] = [Color(1.0, 0.23, 0.025), Color(0.25, 0.92, 0.72), Color(0.45, 0.62, 1.0), Color(0.42, 0.16, 0.68)]
	var skin_colors: Array[Color] = [Color.WHITE, Color(1.0, 0.65, 0.28), Color(0.72, 0.9, 1.0)]
	var base_color: Color = tier_colors[visual_tier] * skin_colors[cosmetic_skin]
	flame_material.emission = base_color * flicker
	if fire_particles != null and fire_particles.process_material is ParticleProcessMaterial:
		(fire_particles.process_material as ParticleProcessMaterial).color = base_color

func _update_fuel_visual_state() -> void:
	if not burning or fuel_queue.is_empty() or fuel_visual_materials.is_empty():
		return
	var fuel := fuel_queue[0]
	var index := 0
	if index >= fuel_visual_materials.size():
		return
	var progress := clampf(1.0 - remaining_burn / maxf(fuel.burn_duration, 0.01), 0.0, 1.0)
	var material := fuel_visual_materials[index]
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("burn_progress", progress)
		return
	if not material is StandardMaterial3D:
		return
	var standard_material := material as StandardMaterial3D
	var char_color := standard_material.albedo_color.lerp(Color(0.055, 0.045, 0.035), progress * 0.82)
	standard_material.albedo_color = char_color
	standard_material.emission_enabled = progress > 0.35
	standard_material.emission = Color(1.0, 0.16, 0.015) * clampf((progress - 0.35) * 0.9, 0.0, 0.55)
	standard_material.emission_energy_multiplier = 1.1



