@tool
extends Control

# Tela de seleção de personagem. Os cards são montados a partir da lista
# `characters`: para adicionar um lutador novo, crie o .tres dele
# (CharacterData) e arraste para essa lista no Inspetor.
#
# O @tool faz este script rodar também dentro do editor, para os cards
# aparecerem na Grid enquanto você monta a tela. O visual de cada card
# fica em character_slot.tscn.

const STAGE_SCENE := "res://stages/stage_01/stage_01.tscn"
const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const SLOT_SCENE := preload("res://ui/character_selection/character_slot.tscn")

@export var characters: Array[CharacterData] = []:
	set(value):
		characters = value
		# Atualiza a Grid no editor sempre que a lista muda no Inspetor.
		if is_node_ready():
			_build_slots()

@onready var grid: GridContainer = %Grid
@onready var preview_portrait: TextureRect = %PreviewPortrait
@onready var preview_name: Label = %PreviewName


func _ready() -> void:
	_build_slots()
	if Engine.is_editor_hint():
		return
	if grid.get_child_count() > 0:
		grid.get_child(0).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _build_slots() -> void:
	# Só apaga os cards gerados (sem owner), nunca nós que você colocou na Grid pelo editor.
	for child in grid.get_children():
		if child.owner == null:
			grid.remove_child(child)
			child.queue_free()

	for data in characters:
		if data == null:
			continue
		var slot: CharacterSlot = SLOT_SCENE.instantiate()
		slot.setup(data)
		slot.focus_entered.connect(_show_preview.bind(data))
		slot.pressed.connect(_confirm.bind(data))
		grid.add_child(slot)


func _show_preview(data: CharacterData) -> void:
	preview_portrait.texture = data.portrait
	preview_name.text = data.display_name.to_upper()
	# "Pulinho" no retrato grande para dar feedback de troca.
	preview_portrait.pivot_offset = preview_portrait.size / 2
	preview_portrait.scale = Vector2(1.1, 1.1)
	create_tween().tween_property(preview_portrait, "scale", Vector2.ONE, 0.15)


func _confirm(data: CharacterData) -> void:
	GameState.selected_character = data
	get_tree().change_scene_to_file(STAGE_SCENE)
