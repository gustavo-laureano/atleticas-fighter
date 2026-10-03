extends Node2D

# Cria os dois lutadores escolhidos na tela de seleção: o jogador 1 no
# PlayerSpawn e o jogador 2 no Player2Spawn, cada um com sua barra de vida.
# Se a fase for aberta direto no editor (F6), usa o default_character nos dois.

const HUD_SCENE := preload("res://ui/hud/hud.tscn")

@export var default_character: CharacterData

@onready var spawns: Array[Marker2D] = [$PlayerSpawn, $Player2Spawn]
@onready var hud: CanvasLayer = $CanvasLayer


func _ready() -> void:
	# A HUD da cena fica com o jogador 1; a do jogador 2 é uma cópia espelhada.
	var hud_2 := HUD_SCENE.instantiate()
	add_child(hud_2)
	hud_2.move_to_right_side()
	var huds: Array[CanvasLayer] = [hud, hud_2]

	for i in 2:
		var data: CharacterData = GameState.selected_characters[i]
		if data == null:
			data = default_character

		var player: Fighter = data.scene.instantiate()
		player.name = "Player%d" % (i + 1)
		player.player_id = i + 1
		player.position = spawns[i].position
		# Conecta antes do add_child para a HUD receber a vida inicial emitida no _ready do Fighter.
		player.health_changed.connect(huds[i]._on_health_changed)
		add_child(player)
		# O jogador 2 começa olhando para o jogador 1.
		player.sprite.flip_h = player.player_id == 2
