extends Node
class_name InventoryManager

signal changed

const STARTING_STOCK := {"hojarasca": 4, "leña": 4, "tronco": 3, "turba": 2}
const MAX_STOCK_PER_FUEL := 99

var _stock: Dictionary = {}

func _ready() -> void:
	reset_to_starting_stock()

func get_stock() -> Dictionary:
	return _stock.duplicate(true)

func get_count(fuel_id: String) -> int:
	return int(_stock.get(fuel_id, 0))

func take_fuel(fuel_id: String) -> bool:
	if get_count(fuel_id) <= 0:
		return false
	_stock[fuel_id] = get_count(fuel_id) - 1
	changed.emit()
	return true

func return_fuel(fuel_id: String) -> void:
	add_fuel_stock(fuel_id)

func add_fuel_stock(fuel_id: String, amount: int = 1) -> bool:
	if amount <= 0 or FuelCatalog.get_by_id(fuel_id) == null:
		return false
	var new_count := mini(MAX_STOCK_PER_FUEL, get_count(fuel_id) + amount)
	if new_count == get_count(fuel_id):
		return false
	_stock[fuel_id] = new_count
	changed.emit()
	return true

func reset_to_starting_stock() -> void:
	_stock.clear()
	for fuel_data in FuelCatalog.get_all():
		_stock[fuel_data.fuel_id] = fuel_data.starting_stock
	changed.emit()
