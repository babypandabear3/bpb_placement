tool
class_name BPBP_Main
signal ghost_made
signal ghost_removed

extends Control

const DATAPATH = "res://addons/bpb_placement/data.sav"
const TAB_PAGE = preload("res://addons/bpb_placement/bpbp_tab.tscn")
const DIALOG_TAB_TITLE = preload("res://addons/bpb_placement/dialog_tab_title.tscn")

var plugin_node
var resource_preview

var saved_data = {}
var data
var current_tab_idx = -1

var tab_selected_timer = 0

onready var tab : TabContainer = $Panel/VBoxContainer/TabContainer
onready var button_paint = $Panel/VBoxContainer/HBoxContainer/btn_paint
onready var dialog_tab_title : WindowDialog
onready var context_menu : PopupMenu = $PopupMenu
onready var dialog_confirm_deletion = $ConfirmationDialog
onready var dialog_warning := $AcceptDialog
onready var le_grid_level := $Panel/VBoxContainer/HBoxContainer/le_grid_level

# Called when the node enters the scene tree for the first time.
func _ready():
	
	var file = File.new()
	if file.file_exists(DATAPATH):
		file.open(DATAPATH, File.READ)
		var content = file.get_as_text()
		saved_data = file.get_var()
		#WAIT UNTIL ENTERING READY STATE BEFORE REMAKING TAB PAGES
		yield(get_tree(), "idle_frame")
		restore_panel_data(saved_data)
		remake_tab_pages(saved_data)
		file.close()
		
	dialog_tab_title = DIALOG_TAB_TITLE.instance()
	dialog_tab_title.connect("confirmed", self, "update_tab_title")
	add_child(dialog_tab_title)
	
	init_context_menu()
	
func _enabled_disabled_paint_button():
	if tab.get_tab_count() == 0:
		button_paint.disabled = true
	else:
		button_paint.disabled = false
		
func _input(event):
	_enabled_disabled_paint_button()
	
func init_context_menu():
	context_menu.connect("index_pressed", self, "_on_context_menu_index_pressed")
	context_menu.clear()
	context_menu.add_item("Rename Tab")
	context_menu.add_item("Delete Tab")
	
	tab.set_popup(context_menu)
	
func _on_context_menu_index_pressed(index):
	var chosen = context_menu.get_item_text(index)
	match chosen:
		"Rename Tab" : 
			if dialog_tab_title:
				dialog_tab_title.set_tab_idx(tab.current_tab)
				dialog_tab_title.clear_input()
				dialog_tab_title.popup_centered()
				dialog_tab_title.do_focus()
		"Delete Tab" :
			dialog_confirm_deletion.popup_centered()
	
func _on_btn_add_button_up():
	button_paint.grab_focus()
	var page = TAB_PAGE.instance()
	tab.add_child(page)
	page.set_resource_preview(resource_preview) # SETTING UP THUMBNAIL MAKER
	page.connect("ghost_made", plugin_node, "make_ghost") # SETTING UP GHOST NODE MAKER

	if dialog_tab_title:
		dialog_tab_title.set_tab_idx(tab.get_tab_count()-1)
		dialog_tab_title.clear_input()
		dialog_tab_title.popup_centered()
		dialog_tab_title.do_focus()

func update_tab_title():
	var data = dialog_tab_title.get_data()
	tab.set_tab_title(data.tab_idx, data.text)
	tab.current_tab = data.tab_idx
	
func set_plugin_node(par):
	plugin_node = par
	resource_preview = plugin_node.resource_preview
	connect("ghost_made", plugin_node, "make_ghost")
	connect("ghost_removed", plugin_node, "make_ghost")

func is_painting():
	return button_paint.pressed
	
func get_selected_obj():
	var ret = tab.get_current_tab_control().get_selected_item_list()
	if ret == null:
		dialog_warning.popup_centered()
	return ret

func save_data():
	data = {}
	for i in tab.get_tab_count():
		var tmp = {}
		tmp["title"] = tab.get_tab_title(i)
		tmp["tabdata"] = tab.get_tab_control(i).get_data()
		data[i] = tmp
	
	var data_to_save = {}
	data_to_save.panel_data = get_panel_data()
	data_to_save.tab_data = data
	
	var file = File.new()
	file.open(DATAPATH, File.WRITE)
	file.store_var(data_to_save, true)
	file.close()
	
func get_panel_data():
	var panel_data = {}
	panel_data.grid_level = _float_or_zero($Panel/VBoxContainer/HBoxContainer/le_grid_level.text)
	panel_data.rotation_snap = _float_or_zero($Panel/VBoxContainer/HBoxContainer/le_rotation_snap.text)
	panel_data.z_up = $Panel/VBoxContainer/HBoxContainer/chk_z_up.pressed
	panel_data.gsr = $Panel/VBoxContainer/HBoxContainer/chk_gsr.pressed
	return panel_data
	
func _float_or_zero(par):
	if par.rstrip(" ") == "":
		par = "0"
	return float(par)
	
func get_current_tab_data():
	var tmp = {}
	if tab.get_tab_count() > 0:
		tmp["title"] = tab.get_tab_title(tab.current_tab)
		tmp["tabdata"] = tab.get_tab_control(tab.current_tab).get_data()
		tmp["paneldata"] = get_panel_data()
	return tmp

func _exit_tree():
	save_data()

func restore_panel_data(saved_data):
	var panel_data = saved_data.panel_data
	$Panel/VBoxContainer/HBoxContainer/le_grid_level.text = str(panel_data.grid_level)
	$Panel/VBoxContainer/HBoxContainer/le_rotation_snap.text = str(panel_data.rotation_snap)
	$Panel/VBoxContainer/HBoxContainer/chk_z_up.pressed = panel_data.z_up
	$Panel/VBoxContainer/HBoxContainer/chk_gsr.pressed = panel_data.gsr

func remake_tab_pages(saved_data):
	var tab_data = saved_data.tab_data
	for i in tab_data.keys().size():
		_on_btn_add_button_up()
		tab.set_tab_title(i, tab_data[i]["title"])
		tab.get_tab_control(i).set_resource_preview(resource_preview)
		tab.get_tab_control(i).set_data(tab_data[i]["tabdata"])

func _on_ConfirmationDialog_confirmed():
	var current_tab = tab.get_current_tab_control()
	tab.remove_child(current_tab)
	current_tab.queue_free()
	_enabled_disabled_paint_button()
	plugin_node.kill_ghost()
	
func toggle_paint():
	button_paint.pressed = not button_paint.pressed
	_on_btn_paint_toggled(button_paint.pressed)


func grid_level_raised():
	le_grid_level.text = str(_float_or_zero(le_grid_level.text) + 1)
	
func grid_level_lowered():
	le_grid_level.text = str(_float_or_zero(le_grid_level.text) - 1)


func _on_btn_paint_toggled(button_pressed):
	if button_pressed:
		plugin_node.start_painting()
	else:
		plugin_node.stop_painting()
