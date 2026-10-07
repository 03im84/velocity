extends RefCounted
class_name QuadraticAxisDragModel


## QuadraticAxisDragModel
##
## Snapshot tratado como inmutable que calcula drag escalar por eje:
## -0.5 * density * coefficient * area * speed * abs(speed).
##
## No conoce Vector3, body, orientación o Godot Physics.
## ADR-017 / Vehicle Environment and Realism Addendum.


var _drag_coefficient: float
var _reference_area_square_meters: float
var _max_abs_drag_force_newtons: float


func _init(
	drag_coefficient: float,
	reference_area_square_meters: float,
	max_abs_drag_force_newtons: float
) -> void:

	_drag_coefficient = drag_coefficient
	_reference_area_square_meters = reference_area_square_meters
	_max_abs_drag_force_newtons = max_abs_drag_force_newtons


func get_drag_coefficient() -> float:

	return _drag_coefficient


func get_reference_area_square_meters() -> float:

	return _reference_area_square_meters


func get_max_abs_drag_force_newtons() -> float:

	return _max_abs_drag_force_newtons


func calculate_drag_force_newtons(
	axis_speed_meters_per_second: float,
	atmospheric_density_kg_per_cubic_meter: float
) -> float:

	if not is_valid():
		return 0.0

	if (
		not is_finite(axis_speed_meters_per_second)
		or not is_finite(
			atmospheric_density_kg_per_cubic_meter
		)
		or atmospheric_density_kg_per_cubic_meter < 0.0
	):
		return 0.0

	var raw_drag := (
		-0.5
		* atmospheric_density_kg_per_cubic_meter
		* _drag_coefficient
		* _reference_area_square_meters
		* axis_speed_meters_per_second
		* absf(axis_speed_meters_per_second)
	)

	if not is_finite(raw_drag):
		return 0.0

	return clampf(
		raw_drag,
		-_max_abs_drag_force_newtons,
		_max_abs_drag_force_newtons
	)


func is_force_within_limits(
	force_newtons: float
) -> bool:

	return (
		is_valid()
		and is_finite(force_newtons)
		and force_newtons
		>= -_max_abs_drag_force_newtons
		and force_newtons
		<= _max_abs_drag_force_newtons
	)


func is_valid() -> bool:

	return (
		is_finite(_drag_coefficient)
		and is_finite(_reference_area_square_meters)
		and is_finite(_max_abs_drag_force_newtons)
		and _drag_coefficient >= 0.0
		and _reference_area_square_meters >= 0.0
		and _max_abs_drag_force_newtons >= 0.0
	)
