tool
extends Panel

var files = []

onready var item_list : ItemList = $VBoxContainer/ItemList

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
	update_item_list()
	
func update_item_list():
	for path in files:
		item_list.add_item(path)
