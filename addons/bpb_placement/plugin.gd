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
	set_input_event_forwarding_always_enabled()
	
func _exit_tree():
	if button_active.pressed:
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
		
func _intersect_with_colliders(camera, screen_point):
	var from = camera.project_ray_origin(screen_point)
	var dir = camera.project_ray_normal(screen_point)
	var space_state = get_tree().get_root().get_world().direct_space_state
	var result = space_state.intersect_ray(from, from + dir * 4096)
	if result:
		return result.position
	return null

func forward_spatial_gui_input(camera, event):
	if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT):
		if event.is_pressed():
			if button_active.pressed and panel.is_painting():
				var pos = _intersect_with_colliders(camera, event.position)
				var path = panel.get_selected_obj()
				var obj = load(path).instance()
				get_tree().get_edited_scene_root().add_child(obj)
				obj.global_transform.origin = pos
				obj.set_owner(get_tree().get_edited_scene_root())
				
	return false


