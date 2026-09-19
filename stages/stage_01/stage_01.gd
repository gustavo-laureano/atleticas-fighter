extends Node2D

# Cria o lutador escolhido na tela de seleção no ponto PlayerSpawn.
# Se a fase for aberta direto no editor (F6), usa o default_character.

@export var default_character: CharacterData

@onready var spawn: Marker2D = $PlayerSpawn
@onready var hud: CanvasLayer = $CanvasLayer


func _ready() -> void:
	var data: CharacterData = GameState.selected_character
	if data == null:
		data = default_character

	var player: Fighter = data.scene.instantiate()
	player.name = "Player"
	player.position = spawn.position
	# Conecta antes do add_child para a HUD receber a vida inicial emitida no _ready do Fighter.
	player.health_changed.connect(hud._on_health_changed)
	add_child(player)
