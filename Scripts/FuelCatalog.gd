extends RefCounted
class_name FuelCatalog

const FUELS: Array[FuelData] = [
	preload("res://Resources/Hojarasca.tres"),
	preload("res://Resources/Leña.tres"),
	preload("res://Resources/Tronco.tres"),
	preload("res://Resources/Turba.tres"),
]

static func get_all() -> Array[FuelData]:
	return FUELS.duplicate()

static func get_by_id(fuel_id: String) -> FuelData:
	for fuel in FUELS:
		if fuel.fuel_id == fuel_id:
			return fuel
	return null
