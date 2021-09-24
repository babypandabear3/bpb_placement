tool
extends HBoxContainer

signal saving_requested

var files = []
var resource_preview

onready var item_list : ItemList = $ItemList

func _ready():
	pass # Replace with function body.

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
		get_preview(p, self)
	update_item_list()
	
	
func update_item_list():
	for path in files:
		item_list.add_item(path)
		var i = item_list.get_item_count()-1
		item_list.set_item_tooltip(i, path)
		get_preview(path, self)
	emit_signal("saving_requested")
	

func get_selected_item_list():
	return item_list.get_item_tooltip(item_list.get_selected_items()[0])


func set_resource_preview(par):
	resource_preview = par


func get_preview(path, sender):
	resource_preview.queue_resource_preview(path, sender, "_on_resource_preview", null)
		
		
func _on_resource_preview(path, texture, user_data):
	for i in item_list.get_item_count():
		if item_list.get_item_text(i) == path:
			item_list.set_item_icon(i, texture)
			item_list.set_item_tooltip(i, path)
			item_list.set_item_text(i, "")
	emit_signal("saving_requested")
	

func set_owner_recursive(pobj, powner):
	for o in pobj.get_children():
		set_owner_recursive(o, powner)
		o.owner = powner
	pobj.owner = powner
