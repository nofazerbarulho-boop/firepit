extends Node
class_name InventoryManager

signal changed

const STARTING_STOCK := {"hojarasca": 4, "leña": 4, "tronco": 3, "turba": 2}
const MAX_STOCK_PER_FUEL := 99

var _stock: Dictionary = {}
var capacity: int = 20

func _ready() -> void:
	reset_to_starting_stock()

func get_stock() -> Dictionary:
	return _stock.duplicate(true)

func get_count(fuel_id: String) -> int:
	return int(_stock.get(fuel_id, 0))

func load_stock(saved_stock: Dictionary) -> void:
	if saved_stock.is_empty():
		return
	for fuel_data in FuelCatalog.get_all():
		_stock[fuel_data.fuel_id] = clampi(int(saved_stock.get(fuel_data.fuel_id, fuel_data.starting_stock)), 0, MAX_STOCK_PER_FUEL)
	_trim_to_capacity()
	changed.emit()

func set_count(fuel_id: String, amount: int) -> void:
	if FuelCatalog.get_by_id(fuel_id) == null:
		return
	_stock[fuel_id] = clampi(amount, 0, MAX_STOCK_PER_FUEL)
	changed.emit()

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
	var room := maxi(0, capacity - _total_stock())
	var new_count := mini(MAX_STOCK_PER_FUEL, get_count(fuel_id) + mini(amount, room))
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

func set_capacity(value: int) -> void:
	capacity = maxi(1, value)
	_trim_to_capacity()
	changed.emit()

func _total_stock() -> int:
	var total := 0
	for amount in _stock.values(): total += int(amount)
	return total

func can_add_fuel(amount: int = 1) -> bool:
	return amount > 0 and _total_stock() + amount <= capacity

func _trim_to_capacity() -> void:
	var excess := maxi(0, _total_stock() - capacity)
	var fuels := FuelCatalog.get_all()
	fuels.reverse()
	for fuel_data in fuels:
		var take := mini(excess, get_count(fuel_data.fuel_id))
		_stock[fuel_data.fuel_id] = get_count(fuel_data.fuel_id) - take
		excess -= take
		if excess <= 0: break
