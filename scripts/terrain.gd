extends StaticBody2D


func _ready() -> void:
	var curve: Curve2D = $Path2D.curve
	var polygon: PackedVector2Array = curve.get_baked_points()
	
	$Polygon2D.polygon = polygon
	$Line2D.points = polygon
	$CollisionPolygon2D.polygon = polygon
