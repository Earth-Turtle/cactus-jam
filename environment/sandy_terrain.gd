@tool
class_name SandyTerrain
extends StaticBody2D

@export var terrain_boundary: Path2D:
	set(new_boundary):
		terrain_boundary = new_boundary
		update_configuration_warnings()
		
		if terrain_boundary != null:
			terrain_boundary.property_list_changed.connect(_on_path_updated)
			if terrain_boundary.curve != null:
				terrain_boundary.curve.changed.connect(_on_curve_updated)
				_update_polygons()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings = []
	
	if terrain_boundary == null:
		warnings.append("Terrain needs a Path2D to define its area.")
	
	return warnings

func _ready() -> void:
	if terrain_boundary == null:
		push_error("Terrain has no Path2D to define its area")
		return
	
	_update_polygons()
	
func _update_polygons() -> void:
	var baked_points = terrain_boundary.curve.get_baked_points()
	$Polygon2D.polygon = baked_points
	$CollisionPolygon2D.polygon = baked_points
	
func _on_curve_updated():
	_update_polygons()

func _on_path_updated():
	if terrain_boundary.curve != null:
		terrain_boundary.curve.changed.connect(_on_curve_updated)
	update_configuration_warnings()
