class_name CharacterData
extends Resource

# Ficha de um personagem jogável. Cada personagem tem um arquivo .tres
# (ex.: characters/crocks/crocks_data.tres) e a tela de seleção monta
# os cards a partir desses arquivos.

@export var display_name: String = ""
@export var portrait: Texture2D
@export var scene: PackedScene
# Rosto que aparece na barra de vida, olhando para a direita. Opcional: se
# ficar vazio, a HUD recorta a cabeça automaticamente do topo do `portrait`.
@export var face: Texture2D
