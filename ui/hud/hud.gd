extends CanvasLayer

@onready var fill: ColorRect = $ColorRect_fill


func _on_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	fill.scale.x = float(current) / float(maximum)
