tool
extends HBoxContainer
signal ghost_made

var files = []
var resource_preview

onready var item_list : ItemList = $ItemList

onready var node_chk_rapid = $VBoxContainer/HBoxContainer3/chk_rapid
onready var node_chk_grid = $VBoxContainer/HBoxContainer/chk_grid
onready var node_opt_grid = $VBoxContainer/HBoxContainer/opt_grid
onready var node_le_gridsize = $VBoxContainer/HBoxContainer/le_gridsize
onready var node_chk_rot_x = $VBoxContainer/HBoxContainer2/HBoxContainer/chk_rot_x
onready var node_chk_rot_y = $VBoxContainer/HBoxContainer2/HBoxContainer/chk_rot_y
onready var node_chk_rot_z = $VBoxContainer/HBoxContainer2/HBoxContainer/chk_rot_z
onready var node_chk_y_normal = $VBoxContainer/HBoxContainer2/HBoxContainer/chk_y_normal

onready var node_chk_scale_x = $VBoxContainer/VBoxContainer3/HBoxContainer/chk_scale_x
onready var node_le_scale_x_min = $VBoxContainer/VBoxContainer3/HBoxContainer/le_scale_x_min
onready var node_le_scale_x_max = $VBoxContainer/VBoxContainer3/HBoxContainer/le_scale_x_max

onready var node_chk_scale_y = $VBoxContainer/VBoxContainer3/HBoxContainer2/chk_scale_y
onready var node_le_scale_y_min = $VBoxContainer/VBoxContainer3/HBoxContainer2/le_scale_y_min
onready var node_le_scale_y_max = $VBoxContainer/VBoxContainer3/HBoxContainer2/le_scale_y_max

onready var node_chk_scale_z = $VBoxContainer/VBoxContainer3/HBoxContainer3/chk_scale_z
onready var node_le_scale_z_min = $VBoxContainer/VBoxContainer3/HBoxContainer3/le_scale_z_min
onready var node_le_scale_z_max = $VBoxContainer/VBoxContainer3/HBoxContainer3/le_scale_z_max

onready var context_menu = $PopupMenu

func _ready():
	item_list.max_columns = int(item_list.rect_size.x / 64)
	context_menu.connect("index_pressed", self, "_on_context_menu_index_pressed")
	
func _on_btn_add_button_up():
	var dialog = EditorFileDialog.new()
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.mode = EditorFileDialog.MODE_OPEN_FILES
	dialog.display_mode = EditorFileDialog.DISPLAY_LIST
	dialog.add_filter("*.tscn, *.scn; Scenes")
	add_child(dialog)
	dialog.show_modal(true)
	dialog.invalidate()
	
	dialog.connect("file_selected", self, "update_file")
	dialog.connect("files_selected", self, "update_files")
	files.clear()
	
	
func update_file(path):
	files.clear()
	files.append(path)
	update_item_list()
	
	
func update_files(paths):
	files.clear()
	for p in paths:
		files.append(p)
	update_item_list()
	
	
func update_item_list():
	var arr_tmp = []
	for i in item_list.get_item_count():
		arr_tmp.append(item_list.get_item_tooltip(i))
	for path in files:
		if not arr_tmp.has(path):
			item_list.add_item(path)
			var i = item_list.get_item_count()-1
			item_list.set_item_tooltip(i, path)
	
	#WAIT UNTIL ENTERING READY STATE ALLOWING resource_preview VALUE TO BE VALID BEFORE REQUESTING THUMBNAIL IMAGE
	yield(get_tree(), "idle_frame")
	for path in files:
		get_preview(path)
		
func get_selected_item_list():
	if item_list.get_selected_items().size() > 0:
		return item_list.get_item_tooltip(item_list.get_selected_items()[0])
	else:
		return null


func set_resource_preview(par):
	resource_preview = par


func get_preview(path):
	resource_preview.queue_resource_preview(path, self, "_on_resource_preview", null)
		
func _on_resource_preview(path, texture, user_data):
	for i in item_list.get_item_count():
		if item_list.get_item_text(i) == path:
			item_list.set_item_icon(i, texture)
			item_list.set_item_text(i, "")

func _float_or_zero(par):
	if str(par).is_valid_float():
		return float(par)
	else:
		return 0.0
		
func get_data():
	var data = {}
	var itemlist_data = []
	for i in item_list.get_item_count():
		itemlist_data.append(item_list.get_item_tooltip(i))
	data["itemlist_data"] = itemlist_data
	
	data.chk_rapid = node_chk_rapid.pressed
	data.chk_grid = node_chk_grid.pressed
	data.opt_grid = node_opt_grid.selected
	data.le_gridsize = _float_or_zero(node_le_gridsize.text)
	data.chk_rot_x = node_chk_rot_x.pressed
	data.chk_rot_y = node_chk_rot_y.pressed
	data.chk_rot_z = node_chk_rot_z.pressed
	
	data.y_normal = node_chk_y_normal.pressed
	
	data.chk_scale_x = node_chk_scale_x.pressed
	data.le_scale_x_min = _float_or_zero(node_le_scale_x_min.text)
	data.le_scale_x_max = _float_or_zero(node_le_scale_x_max.text)
	
	data.chk_scale_y = node_chk_scale_y.pressed
	data.le_scale_y_min = _float_or_zero(node_le_scale_y_min.text)
	data.le_scale_y_max = _float_or_zero(node_le_scale_y_max.text)
	
	data.chk_scale_z = node_chk_scale_z.pressed
	data.le_scale_z_min = _float_or_zero(node_le_scale_z_min.text)
	data.le_scale_z_max = _float_or_zero(node_le_scale_z_max.text)

	return data
	
func set_data(data):
	node_chk_rapid.pressed = data.chk_rapid
	node_chk_grid.pressed = data.chk_grid
	node_opt_grid.selected = data.opt_grid 
	node_le_gridsize.text = str(data.le_gridsize)
	node_chk_rot_x.pressed = data.chk_rot_x 
	node_chk_rot_y.pressed = data.chk_rot_y 
	node_chk_rot_z.pressed = data.chk_rot_z 
	
	node_chk_y_normal.pressed = data.y_normal 
	
	node_chk_scale_x.pressed = data.chk_scale_x 
	node_le_scale_x_min.text = str(data.le_scale_x_min)
	node_le_scale_x_max.text = str(data.le_scale_x_max)
	
	node_chk_scale_y.pressed = data.chk_scale_y 
	node_le_scale_y_min.text = str(data.le_scale_y_min)
	node_le_scale_y_max.text = str(data.le_scale_y_max)
	
	node_chk_scale_z.pressed = data.chk_scale_z 
	node_le_scale_z_min.text = str(data.le_scale_z_min)
	node_le_scale_z_max.text = str(data.le_scale_z_max)
	
	files = data.itemlist_data
	update_item_list()

func _on_ItemList_item_selected(index):
	emit_signal("ghost_made")

func _on_ItemList_item_rmb_selected(index, at_position):
	var pos = get_viewport().get_mouse_position()
	context_menu.rect_position = pos
	context_menu.popup()

func _on_context_menu_index_pressed(index):
	if index == 0: #remove
		item_list.remove_item(item_list.get_selected_items()[0])
	elif index == 1: #clear
		item_list.clear()
