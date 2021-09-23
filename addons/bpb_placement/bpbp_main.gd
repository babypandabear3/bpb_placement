tool
extends Control

class_name BPBP_Main

const TAB_PAGE = preload("res://addons/bpb_placement/bpbp_tab.tscn")

onready var tab = $Panel/VBoxContainer/TabContainer

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
