extends Node
class_name FuelShop

func get_price(fuel_id: String) -> float:
	var data: FuelData = FuelCatalog.get_by_id(fuel_id)
	if data == null:
		return INF
	return data.soot_price

func get_display_name(fuel_id: String) -> String:
	var data: FuelData = FuelCatalog.get_by_id(fuel_id)
	if data == null:
		return "combustible"
	return data.display_name

func buy_fuel(fuel_id: String) -> bool:
	if not GameManager.is_fuel_unlocked(fuel_id):
		return false
	var data: FuelData = FuelCatalog.get_by_id(fuel_id)
	if data == null:
		return false
	if not GameManager.can_store_fuel_type(fuel_id):
		return false
	var price := get_price(fuel_id)
	if not GameManager.spend_soot(price):
		return false
	return GameManager.add_fuel_stock(fuel_id)
