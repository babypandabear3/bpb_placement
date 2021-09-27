tool
extends EditorPlugin


const PANEL_DEFAULT = preload("res://addons/bpb_placement/bpbp_main.tscn")

var panel 

var button_active : CheckButton
var resource_preview 
var left_mouse_hold = false
var last_placement = Vector3(10000, 10000, 10000)
var allow_paint = true
	
func _enter_tree():
	resource_preview = get_editor_interface().get_resource_previewer()
	panel = PANEL_DEFAULT.instance()
	
	add_control_to_bottom_panel(panel, "BPB Placement")
	make_bottom_panel_item_visible(panel)
	set_input_event_forwarding_always_enabled()
	
func _exit_tree():
	#save_data()
	hide_bottom_panel()
	remove_control_from_bottom_panel(panel)
	#hide_panel()
	panel.queue_free()

func _ready():
	panel.set_plugin_node(self)
	
func show_panel():
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM , panel)
	
func hide_panel():
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM , panel)
	
func _intersect_with_colliders(camera, screen_point):
	var from = camera.project_ray_origin(screen_point)
	var dir = camera.project_ray_normal(screen_point)
	var space_state = get_tree().get_edited_scene_root().get_world().direct_space_state
	var result = space_state.intersect_ray(from, from + dir * 4096)
	if result:
		var res = {}
		res.position = result.position
		res.normal = result.normal
		return res
	return null

func forward_spatial_gui_input(camera, event):
	if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT):
		if event.is_pressed():
			if panel.is_painting():
				var tab_data = panel.get_current_tab_data()["tabdata"]
				var ray_result = _intersect_with_colliders(camera, event.position)
				if ray_result == null:
					return false
				init_paint_job(ray_result, tab_data)
				return true
				
	if event is InputEventMouseMotion:
		if event.button_mask == 1 and panel.is_painting():
			var tab_data = panel.get_current_tab_data()["tabdata"]
			if tab_data.chk_rapid:
				var ray_result = _intersect_with_colliders(camera, event.position)
				if ray_result == null:
					return false
				else:
					if last_placement.distance_to(ray_result.position) < 0.5:
						return false
					else:
						init_paint_job(ray_result, tab_data)
						return true
			
	return false

func init_paint_job(ray_result, tab_data):
	var path = panel.get_selected_obj()
	if path == null:
		return
		
	var obj = load(path).instance()
				
	var new_rot = Vector3(0,0,0)
	if tab_data.chk_rot_x:
		new_rot.x = deg2rad(rand_range(0, 360))
	if tab_data.chk_rot_y:
		new_rot.y = deg2rad(rand_range(0, 360))
	if tab_data.chk_rot_z:
		new_rot.z = deg2rad(rand_range(0, 360))
					
	var align_y = tab_data.y_normal
			
	var new_scale = Vector3(1,1,1)
	if tab_data.chk_scale_x:
		new_scale.x = rand_range(float(tab_data.le_scale_x_min), float(tab_data.le_scale_x_max))
	if tab_data.chk_scale_y:
		new_scale.y = rand_range(float(tab_data.le_scale_y_min), float(tab_data.le_scale_y_max))
	if tab_data.chk_scale_z:
		new_scale.z = rand_range(float(tab_data.le_scale_z_min), float(tab_data.le_scale_z_max))
			
	var undo_redo := get_undo_redo()
	undo_redo.create_action("paint_scene")
	undo_redo.add_do_method(self, "do_placement", obj, ray_result, new_rot, align_y, new_scale)
	undo_redo.add_undo_method(self, "undo_placement", obj)
	undo_redo.add_do_reference(obj)
	undo_redo.commit_action()
	last_placement = ray_result.position
	
	
func do_placement(obj, ray_result, new_rot, align_y, new_scale):
	get_tree().get_edited_scene_root().add_child(obj)
	obj.global_transform.origin = ray_result.position
	obj.rotation = new_rot
	if align_y:
		var new_basis = obj.global_transform.basis
		new_basis.y = ray_result.normal
		new_basis.x = ((new_basis.x).slide(ray_result.normal)).normalized()
		new_basis.z = new_basis.x.cross(new_basis.y).normalized()
		obj.global_transform.basis = new_basis.orthonormalized()
	obj.scale = new_scale
	obj.set_owner(get_tree().get_edited_scene_root())
	
	
func undo_placement(obj):
	obj.queue_free()

func get_undo_redo_stack():
	return get_undo_redo()
