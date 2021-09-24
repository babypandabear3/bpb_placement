tool
extends EditorPlugin

const DATAPATH = "res://addons/bpb_placement/data.tscn"
const PANEL_DEFAULT = preload("res://addons/bpb_placement/bpbp_main.tscn")

var panel 

var button_active : CheckButton
var resource_preview 
	
func _enter_tree():
	var file2Check = File.new()
	if file2Check.file_exists(DATAPATH):
		panel = load(DATAPATH).instance()
	else:
		panel = PANEL_DEFAULT.instance()
		
	button_active = CheckButton.new()
	button_active.text = "BPB Placement"
	button_active.connect("button_up", self, "toggle_panel")
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, button_active)
	set_input_event_forwarding_always_enabled()
	resource_preview = get_editor_interface().get_resource_previewer()
	panel.set_plugin_node(self)
	save_data()
	
func _exit_tree():
	save_data()
	if button_active.pressed:
		hide_panel()
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, button_active)
	panel.queue_free()

func show_panel():
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM , panel)
	
func hide_panel():
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM , panel)
	
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

func save_data():
	var packed_scene = PackedScene.new()
	packed_scene.pack(panel)
	ResourceSaver.save(DATAPATH, packed_scene)
