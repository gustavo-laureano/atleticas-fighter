@tool
class_name CharacterSlot
extends Button

# Card de um personagem na tela de seleção. O visual (tamanho, bordas, cores)
# é editado direto em character_slot.tscn; aqui só entram os dados.


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Mouse e teclado/controle dividem o mesmo "cursor": passar o mouse dá foco.
	mouse_entered.connect(grab_focus)


func setup(data: CharacterData) -> void:
	icon = data.portrait
	tooltip_text = data.display_name
