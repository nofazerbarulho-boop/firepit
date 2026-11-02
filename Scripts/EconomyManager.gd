extends Node
class_name EconomyManager

signal changed

const UPGRADE_COST := 25.0
const UPGRADE_COST_GROWTH := 1.6
const UPGRADE_BOOST := 0.25
const SOOT_OUTPUT_SCALE := 0.015

var soot: float = 0.0
var temporary_upgrades: int = 0

func add_soot(amount: float) -> void:
	if amount <= 0.0:
		return
	soot += amount
	changed.emit()

func spend_soot(amount: float) -> bool:
	if amount < 0.0 or soot < amount:
		return false
	soot -= amount
	changed.emit()
	return true

func buy_upgrade() -> bool:
	if not spend_soot(get_upgrade_cost()):
		return false
	temporary_upgrades += 1
	changed.emit()
	return true

func get_upgrade_cost() -> float:
	return UPGRADE_COST * pow(UPGRADE_COST_GROWTH, temporary_upgrades)

func get_multiplier(permanent_points: int) -> float:
	return 1.0 + float(permanent_points) * 0.1 + float(temporary_upgrades) * UPGRADE_BOOST

func get_soot_rate(heat: float, multiplier: float) -> float:
	return maxf(heat, 0.0) * multiplier * SOOT_OUTPUT_SCALE

func reset_for_new_run() -> void:
	soot = 0.0
	temporary_upgrades = 0
	changed.emit()
