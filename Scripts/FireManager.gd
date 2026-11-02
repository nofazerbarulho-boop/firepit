extends Node3D
class_name FireManager

signal fire_changed
signal gain_batch(amount: float)

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
var fire_audio: AudioStreamPlayer
var audio_volume: float = 0.35
var hud_signal_timer: float = 0.0

func _ready() -> void:
	if has_private_inventory:
		private_stock = build_starting_stock()
	_build_fire_visuals()
	_update_visuals()

func add_fuel(fuel_id: String) -> bool:
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
	if not burning:
		active_quality = get_queue_quality()
	fire_changed.emit()
	return true

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
		var heat_per_second := fuel.heat_value * phase_heat_multiplier * active_quality * GameManager.get_thermal_multiplier() * biome_heat_multiplier
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
	fire_audio = AudioStreamPlayer.new()
	fire_audio.name = "FireAudio"
	fire_audio.stream = _make_fire_loop()
	fire_audio.volume_db = -22.0
	add_child(fire_audio)
	fire_audio.play()

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
	if fire_particles != null:
		fire_particles.emitting = current_heat > 0.1
		fire_particles.amount = 8 + int(clampf(current_heat, 0.0, 60.0))
	if fire_audio != null:
		fire_audio.volume_db = -80.0 if current_heat <= 0.1 or audio_volume <= 0.001 else linear_to_db(audio_volume) - 10.0 + minf(current_heat / 10.0, 1.0) * 8.0
	var intensity := clampf(current_heat / 45.0, 0.15, 1.0)
	var time := float(Time.get_ticks_msec()) / 1000.0
	var flicker := 1.0 + sin(time * 13.0) * 0.06 + sin(time * 21.7) * 0.035
	flame.scale = Vector3(0.6 * flicker, intensity * flicker, 0.6 * flicker)
	var tier_colors: Array[Color] = [Color(1.0, 0.23, 0.025), Color(0.25, 0.92, 0.72), Color(0.45, 0.62, 1.0), Color(0.42, 0.16, 0.68)]
	var skin_colors: Array[Color] = [Color.WHITE, Color(1.0, 0.65, 0.28), Color(0.72, 0.9, 1.0)]
	var base_color: Color = tier_colors[visual_tier] * skin_colors[cosmetic_skin]
	flame_material.emission = base_color * flicker
	if fire_particles != null and fire_particles.process_material is ParticleProcessMaterial:
		(fire_particles.process_material as ParticleProcessMaterial).color = base_color



