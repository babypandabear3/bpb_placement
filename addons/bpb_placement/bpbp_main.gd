tool
class_name BPBP_Main
extends Control

const DATAPATH = "res://addons/bpb_placement/data.sav"
const TAB_PAGE = preload("res://addons/bpb_placement/bpbp_tab.tscn")

var plugin_node
var resource_preview

var saved_data = {}
var data

onready var tab : TabContainer = $Panel/VBoxContainer/TabContainer
onready var button_paint = $Panel/VBoxContainer/HBoxContainer/CheckButton

# Called when the node enters the scene tree for the first time.
func _ready():
	var file = File.new()
	if file.file_exists(DATAPATH):
		file.open(DATAPATH, File.READ)
		var content = file.get_as_text()
		saved_data = file.get_var()
		#WAIT UNTIL ENTERING READY STATE BEFORE REMAKING TAB PAGES
		yield(get_tree(), "idle_frame")
		remake_tab_pages(saved_data)
		file.close()
	
func _on_btn_add_button_up():
	var page = TAB_PAGE.instance()
	tab.add_child(page)
	page.set_resource_preview(resource_preview)

func set_plugin_node(par):
	plugin_node = par
	resource_preview = plugin_node.resource_preview

func _on_CheckButton_button_up():
	pass # Replace with function body.

func is_painting():
	return button_paint.pressed
	
func get_selected_obj():
	return tab.get_current_tab_control().get_selected_item_list()

func save_data():
	data = {}
	for i in tab.get_tab_count():
		var tmp = {}
		tmp["title"] = tab.get_tab_title(i)
		tmp["tabdata"] = tab.get_tab_control(i).get_data()
		data[i] = tmp
	
	var file = File.new()
	file.open(DATAPATH, File.WRITE)
	file.store_var(data, true)
	file.close()

func _exit_tree():
	save_data()

func remake_tab_pages(saved_data):
	for i in saved_data.keys().size():
		_on_btn_add_button_up()
		tab.set_tab_title(i, saved_data[i]["title"])
		tab.get_tab_control(i).set_resource_preview(resource_preview)
		tab.get_tab_control(i).set_data(saved_data[i]["tabdata"])
