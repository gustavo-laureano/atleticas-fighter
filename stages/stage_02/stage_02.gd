extends Node2D

# Cria os dois lutadores escolhidos na tela de seleção: o jogador 1 no
# PlayerSpawn e o jogador 2 no Player2Spawn, e mostra o rosto, o nome e a vida
# de cada um na HUD. Se a fase for aberta direto no editor (F6), usa o
# default_character nos dois.

@export var default_character: CharacterData

@onready var spawns: Array[Marker2D] = [$PlayerSpawn, $Player2Spawn]
@onready var hud: CanvasLayer = $CanvasLayer


func _ready() -> void:
	for i in 2:
		var data: CharacterData = GameState.selected_characters[i]
		if data == null:
			data = default_character
		hud.setup_player(i, data)

		var player: Fighter = data.scene.instantiate()
		player.name = "Player%d" % (i + 1)
		player.player_id = i + 1
		player.position = spawns[i].position
		# Conecta antes do add_child para a HUD receber a vida inicial emitida no _ready do Fighter.
		player.health_changed.connect(hud.set_health.bind(i))
		player.special_changed.connect(hud.set_special.bind(i))
		add_child(player)
		# O jogador 2 começa olhando para o jogador 1.
		player.sprite.flip_h = player.player_id == 2
