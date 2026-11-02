extends Resource
class_name FuelData

@export var fuel_id: String = "fuel"
@export var display_name: String = "Combustible"
@export_range(0.1, 100.0, 0.1) var heat_value: float = 5.0
@export_range(0.1, 120.0, 0.1) var burn_duration: float = 5.0
@export_range(0.0, 100000.0, 1.0) var soot_price: float = 10.0
@export_range(0, 100, 1) var starting_stock: int = 0
@export_range(1, 100, 1) var unlock_day: int = 1
