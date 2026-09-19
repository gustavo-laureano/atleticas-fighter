extends Control

# Tela de seleção de personagem. Os cards são montados a partir da lista
# `characters`: para adicionar um lutador novo, crie o .tres dele
# (CharacterData) e arraste para essa lista no Inspetor.

const STAGE_SCENE := "res://stages/stage_01/stage_01.tscn"
const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const SLOT_SIZE := Vector2(128, 128)

@export var characters: Array[CharacterData] = []

@onready var grid: GridContainer = %Grid
@onready var preview_portrait: TextureRect = %PreviewPortrait
@onready var preview_name: Label = %PreviewName

var _slot_style := _make_slot_style()
var _slot_focus_style := _make_slot_focus_style()


func _ready() -> void:
	for data in characters:
		grid.add_child(_create_slot(data))
	if grid.get_child_count() > 0:
		grid.get_child(0).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _create_slot(data: CharacterData) -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.icon = data.portrait
	slot.expand_icon = true
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.tooltip_text = data.display_name
	for state in ["normal", "hover", "pressed"]:
		slot.add_theme_stylebox_override(state, _slot_style)
	slot.add_theme_stylebox_override("focus", _slot_focus_style)
	# Mouse e teclado/controle dividem o mesmo "cursor": passar o mouse dá foco.
	slot.mouse_entered.connect(slot.grab_focus)
	slot.focus_entered.connect(_show_preview.bind(data))
	slot.pressed.connect(_confirm.bind(data))
	return slot


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


func _make_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.border_color = Color(0.3, 0.3, 0.38)
	style.set_border_width_all(3)
	style.set_content_margin_all(8)
	return style


func _make_slot_focus_style() -> StyleBoxFlat:
	# Só a borda (draw_center = false): é desenhada por cima do slot normal.
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Color(1.0, 0.8, 0.1)
	style.set_border_width_all(5)
	return style
