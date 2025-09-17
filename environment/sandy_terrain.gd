@tool
class_name SandyTerrain
extends StaticBody2D

@export var terrain_boundary: Path2D:
	set(new_boundary):
		if terrain_boundary != null:
			terrain_boundary.property_list_changed.disconnect(_on_path_updated)
			if terrain_boundary.curve != null:
				terrain_boundary.curve.changed.disconnect(_on_curve_updated)
			
		terrain_boundary = new_boundary
		
		if terrain_boundary != null:
			terrain_boundary.property_list_changed.connect(_on_path_updated)
			if terrain_boundary.curve != null:
				terrain_boundary.curve.changed.connect(_on_curve_updated)
				_update_polygons()
			
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = []
	
	if terrain_boundary == null:
		warnings.append("Terrain needs a Path2D to define its area.")
	elif terrain_boundary.curve == null:
		warnings.append("Path2D needs a curve defined")
	
	return warnings

func _ready() -> void:
	if terrain_boundary == null:
		push_error("Terrain has no Path2D to define its area")
		return
	elif terrain_boundary.curve == null:
		push_error("Terrain's Path2D needs a curve defined")
		return
	
	_update_polygons()
	
func _update_polygons() -> void:
	var baked_points = terrain_boundary.curve.get_baked_points()
	$Polygon2D.polygon = baked_points
	$CollisionPolygon2D.polygon = baked_points
	
func _on_curve_updated():
	# don't need to update warnings because we already have a curve if this is getting called
	_update_polygons()
	
func _on_path_updated():
	if terrain_boundary.curve != null:
		terrain_boundary.curve.changed.connect(_on_curve_updated)
		_update_polygons()
	update_configuration_warnings()
	
