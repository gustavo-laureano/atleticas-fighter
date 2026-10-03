extends CanvasLayer

@onready var fill: ColorRect = $ColorRect_fill


func _on_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	fill.scale.x = float(current) / float(maximum)


# Espelha a barra para o canto direito da tela (usado pelo jogador 2).
func move_to_right_side() -> void:
	var screen_width := get_viewport().get_visible_rect().size.x
	offset.x = screen_width - fill.offset_left - fill.offset_right
	# Mantém a barra presa à borda da tela ao perder vida, como a do jogador 1.
	fill.pivot_offset.x = fill.size.x
