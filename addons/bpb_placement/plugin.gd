tool
extends EditorPlugin

const SIDE_PANEL = preload("res://addons/bpb_placement/bpbp_main.tscn")
var panel = SIDE_PANEL.instance()

var focused_object setget set_focused_object
var editor_selection

func _enter_tree():
	editor_selection = get_editor_interface().get_selection()
	editor_selection.connect("selection_changed", self, "_on_EditorSelection_selection_changed")
	add_custom_type("BPB_Placement", "Spatial", preload("bpbp_spatial.gd"), preload("icon.png"))
	
func _exit_tree():
	remove_custom_type("BPB_Placement")

func _on_EditorSelection_selection_changed():
	var selected_nodes = editor_selection.get_selected_nodes()
	if selected_nodes.size() == 1:
		var selected_node = selected_nodes[0]
		if selected_node is BPB_Placement_Spatial:
			set_focused_object(selected_node)
			return
		else:
			#if editor:
			#	editor.graphnode_updated()
			pass
	set_focused_object(null)
	
func set_focused_object(obj):
	if focused_object != obj:
		focused_object = obj
		_on_focused_object_changed(obj)

func _on_focused_object_changed(new_obj):
	if new_obj:
		if focused_object is BPB_Placement_Spatial:
			show_panel()
		else:
			hide_panel()
	else:
		hide_panel()
		
func show_panel():
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT , panel)
	
func hide_panel():
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT , panel)
	
