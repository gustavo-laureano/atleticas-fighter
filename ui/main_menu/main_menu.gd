extends Control

const CHARACTER_SELECTION_SCENE := "res://ui/character_selection/character_selection.tscn"
const COLOR_IDLE := Color(1, 1, 1, 1)
const COLOR_FOCUS := Color(1, 0.8, 0.1, 1)
const CURSOR := "▶ "
const FOCUS_SCALE := Vector2(1.08, 1.08)

@onready var button_play: Button = %ButtonPlay
@onready var button_quit: Button = %ButtonQuit

var _labels: Dictionary = {}


func _ready() -> void:
	for button in [button_play, button_quit]:
		_labels[button] = button.text
		button.focus_entered.connect(_on_button_focus_changed.bind(button, true))
		button.focus_exited.connect(_on_button_focus_changed.bind(button, false))
	_link_focus()
	# O container só calcula o tamanho dos botões depois do _ready.
	call_deferred("_focus_initial")


func _focus_initial() -> void:
	button_play.grab_focus()


func _link_focus() -> void:
	button_play.focus_neighbor_top = button_play.get_path_to(button_quit)
	button_play.focus_neighbor_bottom = button_play.get_path_to(button_quit)
	button_quit.focus_neighbor_top = button_quit.get_path_to(button_play)
	button_quit.focus_neighbor_bottom = button_quit.get_path_to(button_play)


func _on_button_focus_changed(button: Button, focused: bool) -> void:
	_apply_state(button, focused)


func _apply_state(button: Button, focused: bool) -> void:
	var label: String = _labels[button]
	button.text = (CURSOR + label) if focused else label
	var color := COLOR_FOCUS if focused else COLOR_IDLE
	for key in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, color)
	var bounds := button.size
	if bounds == Vector2.ZERO:
		bounds = button.custom_minimum_size
	button.pivot_offset = bounds / 2.0
	if button.has_meta("focus_tween"):
		var previous: Tween = button.get_meta("focus_tween")
		if is_instance_valid(previous):
			previous.kill()
	var tween := create_tween()
	button.set_meta("focus_tween", tween)
	tween.tween_property(button, "scale", FOCUS_SCALE if focused else Vector2.ONE, 0.12)


func _on_button_play_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECTION_SCENE)


func _on_button_quit_pressed() -> void:
	get_tree().quit()
