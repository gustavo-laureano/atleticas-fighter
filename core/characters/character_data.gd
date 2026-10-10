class_name CharacterData
extends Resource

# Ficha de um personagem jogável. Cada personagem tem um arquivo .tres
# (ex.: characters/crocks/crocks_data.tres) e a tela de seleção monta
# os cards a partir desses arquivos.

@export var display_name: String = ""
@export var portrait: Texture2D
@export var scene: PackedScene
# Foto de perfil (pasta main/ do personagem), olhando para a direita e com
# fundo transparente. Aparece na barra de vida e no card da seleção.
# Opcional: se ficar vazia, a HUD recorta a cabeça do topo do `portrait` e o
# card usa o `portrait`.
@export var face: Texture2D
