tool
extends Control

class_name BPBP_Main

const TAB_PAGE = preload("res://addons/bpb_placement/bpbp_tab.tscn")

onready var tab : TabContainer = $Panel/VBoxContainer/TabContainer
onready var button_paint = $Panel/VBoxContainer/HBoxContainer/CheckButton
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_btn_add_button_up():
	var page = TAB_PAGE.instance()
	tab.add_child(page)
	
	pass # Replace with function body.


func _on_CheckButton_button_up():
	pass # Replace with function body.

func is_painting():
	return button_paint.pressed
	
func get_selected_obj():
	return tab.get_current_tab_control().get_selected_item_list()
