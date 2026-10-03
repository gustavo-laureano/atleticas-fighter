extends Node

# Autoload (Projeto > Configurações > Globais) com o nome "GameState".
# Guarda o que precisa sobreviver à troca de cena, como os personagens escolhidos.

# Índice 0 = jogador 1, índice 1 = jogador 2.
var selected_characters: Array[CharacterData] = [null, null]
