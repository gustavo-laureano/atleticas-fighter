extends CanvasLayer

# HUD da luta: as barras de vida e de especial ficam em LifeBars (ver
# life_bars.gd). A fase chama setup_player() com o personagem de cada jogador
# e liga os sinais health_changed e special_changed de cada lutador em
# set_health() e set_special().

@onready var life_bars: Control = $LifeBars


func setup_player(index: int, data: CharacterData) -> void:
	life_bars.setup_player(index, data)


# Ligue com bind: player.health_changed.connect(hud.set_health.bind(index)).
func set_health(current: int, maximum: int, index: int) -> void:
	life_bars.set_health(current, maximum, index)


# Ligue com bind: player.special_changed.connect(hud.set_special.bind(index)).
func set_special(current: int, maximum: int, index: int) -> void:
	life_bars.set_special(current, maximum, index)
