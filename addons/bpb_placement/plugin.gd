tool
extends EditorPlugin

const SIDE_PANEL = preload("res://addons/bpb_placement/bpbp_main.tscn")
var panel = SIDE_PANEL.instance()

var button_active : CheckButton

func _enter_tree():
	button_active = CheckButton.new()
	button_active.text = "BPB Placement"
	button_active.connect("button_up", self, "toggle_panel")
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, button_active)
	
func _exit_tree():
	hide_panel()
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, button_active)

func show_panel():
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT , panel)
	
func hide_panel():
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT , panel)
	
func toggle_panel():
	if button_active.pressed:
		show_panel()
	else:
		hide_panel()
