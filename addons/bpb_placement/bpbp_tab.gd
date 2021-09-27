tool
extends HBoxContainer

var files = []
var resource_preview

onready var item_list : ItemList = $ItemList

func _ready():
	item_list.max_columns = int(item_list.rect_size.x / 64)

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
	for path in files:
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

func get_data():
	var data = {}
	var itemlist_data = []
	for i in item_list.get_item_count():
		itemlist_data.append(item_list.get_item_tooltip(i))
	data["itemlist_data"] = itemlist_data
	
	data.chk_rapid = $VBoxContainer/HBoxContainer3/chk_rapid.pressed
	data.chk_grid = $VBoxContainer/HBoxContainer/chk_grid.pressed
	data.le_gridsize = $VBoxContainer/HBoxContainer/le_gridsize.text
	data.chk_rot_x = $VBoxContainer/HBoxContainer2/HBoxContainer/chk_rot_x.pressed
	data.chk_rot_y = $VBoxContainer/HBoxContainer2/HBoxContainer/chk_rot_y.pressed
	data.chk_rot_z = $VBoxContainer/HBoxContainer2/HBoxContainer/chk_rot_z.pressed
	
	data.y_normal = $VBoxContainer/HBoxContainer4/chk_y_normal.pressed
	
	data.chk_scale_x = $VBoxContainer/VBoxContainer3/HBoxContainer/chk_scale_x.pressed
	data.le_scale_x_min = $VBoxContainer/VBoxContainer3/HBoxContainer/le_scale_x_min.text
	data.le_scale_x_max = $VBoxContainer/VBoxContainer3/HBoxContainer/le_scale_x_max.text

	data.chk_scale_y = $VBoxContainer/VBoxContainer3/HBoxContainer2/chk_scale_y.pressed
	data.le_scale_y_min = $VBoxContainer/VBoxContainer3/HBoxContainer2/le_scale_y_min.text
	data.le_scale_y_max = $VBoxContainer/VBoxContainer3/HBoxContainer2/le_scale_y_max.text

	data.chk_scale_z = $VBoxContainer/VBoxContainer3/HBoxContainer3/chk_scale_z.pressed
	data.le_scale_z_min = $VBoxContainer/VBoxContainer3/HBoxContainer3/le_scale_z_min.text
	data.le_scale_z_max = $VBoxContainer/VBoxContainer3/HBoxContainer3/le_scale_z_max.text
	
	return data
	
func set_data(data):
	$VBoxContainer/HBoxContainer3/chk_rapid.pressed = data.chk_rapid
	$VBoxContainer/HBoxContainer/chk_grid.pressed = data.chk_grid
	$VBoxContainer/HBoxContainer/le_gridsize.text = data.le_gridsize 
	$VBoxContainer/HBoxContainer2/HBoxContainer/chk_rot_x.pressed = data.chk_rot_x 
	$VBoxContainer/HBoxContainer2/HBoxContainer/chk_rot_y.pressed = data.chk_rot_y 
	$VBoxContainer/HBoxContainer2/HBoxContainer/chk_rot_z.pressed = data.chk_rot_z 
	$VBoxContainer/HBoxContainer4/chk_y_normal.pressed = data.y_normal
	
	$VBoxContainer/VBoxContainer3/HBoxContainer/chk_scale_x.pressed = data.chk_scale_x 
	$VBoxContainer/VBoxContainer3/HBoxContainer/le_scale_x_min.text = data.le_scale_x_min 
	$VBoxContainer/VBoxContainer3/HBoxContainer/le_scale_x_max.text = data.le_scale_x_max 

	$VBoxContainer/VBoxContainer3/HBoxContainer2/chk_scale_y.pressed = data.chk_scale_y 
	$VBoxContainer/VBoxContainer3/HBoxContainer2/le_scale_y_min.text = data.le_scale_y_min 
	$VBoxContainer/VBoxContainer3/HBoxContainer2/le_scale_y_max.text = data.le_scale_y_max 

	$VBoxContainer/VBoxContainer3/HBoxContainer3/chk_scale_z.pressed = data.chk_scale_z 
	$VBoxContainer/VBoxContainer3/HBoxContainer3/le_scale_z_min.text = data.le_scale_z_min 
	$VBoxContainer/VBoxContainer3/HBoxContainer3/le_scale_z_max.text = data.le_scale_z_max 
	
	files = data.itemlist_data
	update_item_list()
