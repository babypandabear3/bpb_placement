tool
class_name BPBP_Main
extends Control

signal saving_requested

const TAB_PAGE = preload("res://addons/bpb_placement/bpbp_tab.tscn")

var plugin_node
var resource_preview
var data

onready var tab : TabContainer = $Panel/VBoxContainer/TabContainer
onready var button_paint = $Panel/VBoxContainer/HBoxContainer/CheckButton


# Called when the node enters the scene tree for the first time.
func _ready():
	set_owner_recursive(self, self)
	connect("saving_requested", plugin_node, "save_data")
	
func _on_btn_add_button_up():
	var page = TAB_PAGE.instance()
	tab.add_child(page)
	page.set_resource_preview(resource_preview)
	page.set_owner_recursive(page, self)
	page.owner = self
	page.connect("saving_requested", plugin_node, "save_data")

func set_plugin_node(par):
	plugin_node = par
	resource_preview = plugin_node.resource_preview

func _on_CheckButton_button_up():
	pass # Replace with function body.

func is_painting():
	return button_paint.pressed
	
func get_selected_obj():
	return tab.get_current_tab_control().get_selected_item_list()

func set_owner_recursive(pobj, powner):
	for o in pobj.get_children():
		set_owner_recursive(o, powner)
		o.owner = powner
	#pobj.owner = powner
