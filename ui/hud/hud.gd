extends CanvasLayer

# HUD da luta: as duas barras de vida ficam em LifeBars (ver life_bars.gd).
# A fase chama setup_player() com o personagem de cada jogador e liga o sinal
# health_changed de cada lutador em set_health().

@onready var life_bars: Control = $LifeBars


func setup_player(index: int, data: CharacterData) -> void:
	life_bars.setup_player(index, data)


# Ligue com bind: player.health_changed.connect(hud.set_health.bind(index)).
func set_health(current: int, maximum: int, index: int) -> void:
	life_bars.set_health(current, maximum, index)
