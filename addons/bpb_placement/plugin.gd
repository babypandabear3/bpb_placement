tool
extends EditorPlugin

signal ghost_made
signal ghost_removed

const PANEL_DEFAULT = preload("res://addons/bpb_placement/bpbp_main.tscn")
var Interop = preload("res://addons/bpb_placement/interop.gd")

enum EDIT_MODES {
	NORMAL,
	ROTATE,
	SCALE
}

enum SCALE_MODES {
	XYZ,
	X,
	Y,
	Z,
	XY,
	XZ,
	YZ
}

enum ROTATE_MODES {
	X,
	Y,
	Z,
}

var interop_ignore_input := false

var panel 

var button_active : CheckButton
var resource_preview 
var left_mouse_hold = false
var last_placement = Vector3(10000, 10000, 10000)
var allow_paint = true

var ghost = null
var ghost_grid = null
var grid_plane
var grid_placement = []
var plane_xz = Plane(Plane.PLANE_XZ)
var plane_xy = Plane(Plane.PLANE_XY)
var plane_yz = Plane(Plane.PLANE_YZ)

var edit_mode = EDIT_MODES.NORMAL
var scale_mode = SCALE_MODES.XYZ
var rotate_mode = ROTATE_MODES.Y

var use_ghost_last_pos = false
var ghost_last_pos = Vector3()
var mouse_last_ghost_pos = Vector2()
var mouse_last_pos = Vector2()
var viewport_center = Vector2()
var ghost_init_scale = Vector3()

var ghost_init_basis
var ghost_init_rotation


var first_draw = false
var circle_center = Vector2()

var timer = Timer.new()
var timer_click = Timer.new()
var allow_rapid_paint = true

onready var transform_menu = get_editor_interface().get_editor_viewport().get_child(1).get_child(0) #.get_child(18)
#Popupmenu has a set_item_disabled. So get the popupmenu child of the menu button and use that on the first item.

func _enter_tree():
	Interop.register(self, "BPB_Placement")
	resource_preview = get_editor_interface().get_resource_previewer()
	panel = PANEL_DEFAULT.instance()
	
	add_control_to_bottom_panel(panel, "BPB Placement")
	make_bottom_panel_item_visible(panel)
	set_input_event_forwarding_always_enabled()
	#set_force_draw_over_forwarding_enabled()
	grid_plane = plane_xz
	add_child(timer)
	timer.one_shot = true
	timer.connect("timeout", self, "_on_timer_timeout")
	
	add_child(timer_click)
	timer_click.one_shot = true
	timer_click.connect("timeout", self, "_on_timer_click_timeout")
	
func _exit_tree():
	Interop.deregister(self) 
	hide_bottom_panel()
	remove_control_from_bottom_panel(panel)
	if ghost:
		ghost.queue_free()
	panel.queue_free()

func _ready():
	panel.set_plugin_node(self)
	
func _interop_notification(caller_plugin_id: String, code: int, id: String, args):
	match code:
		Interop.NOTIFY_CODE_REQUEST_IGNORE_INPUT:
			interop_ignore_input = true
		Interop.NOTIFY_CODE_ALLOW_INPUT:
			interop_ignore_input = false
			
func _on_timer_timeout():
	allow_rapid_paint = true
	
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

func _intersect_with_plane(camera, screen_point, snap_val, grid_level, grid_type):
	match grid_type:
		0:
			grid_plane = plane_xz
		1:
			grid_plane = plane_xy
		2:
			grid_plane = plane_yz
	var from = camera.project_ray_origin(screen_point)
	var dir = camera.project_ray_normal(screen_point)
	grid_plane.d = snap_val * grid_level
	var result = grid_plane.intersects_ray(from, dir)
	if result:
		var res = {}
		res.position = result.snapped(Vector3(snap_val, snap_val, snap_val))
		res.normal = Vector3.UP
		return res
	return null
	
func _start_edit_mode_scale(event, fresh=true):
	edit_mode = EDIT_MODES.SCALE
	scale_mode = SCALE_MODES.XYZ
	
	var tmp_center = Vector2()
	if not fresh:
		tmp_center = mouse_last_pos
	mouse_last_pos = get_viewport().get_mouse_position()
	viewport_center = get_viewport().size / 2
	
	if not fresh:
		mouse_last_pos = tmp_center
		
	var mouse_edit_pos = mouse_last_pos
	if mouse_last_pos.x < get_viewport().size.x / 2:
		mouse_edit_pos.x += 100
	else:
		mouse_edit_pos.x -= 100
	
	get_viewport().warp_mouse(mouse_edit_pos)
	ghost_init_scale = ghost.scale
	
	first_draw = true
	
func _start_edit_mode_rotate(event, fresh=true):
	edit_mode = EDIT_MODES.ROTATE
	rotate_mode = ROTATE_MODES.Y
	
	var tmp_center = Vector2()
	if not fresh:
		tmp_center = mouse_last_pos
	mouse_last_pos = get_viewport().get_mouse_position()
	if not fresh:
		mouse_last_pos = tmp_center
	ghost_init_basis = ghost.global_transform.basis
	ghost_init_rotation = ghost.rotation
	get_viewport().warp_mouse(mouse_last_pos)
	first_draw = true

# FUNCTION handles IS NEEDED TO ALLOW OVERLAY DRAWING
func handles(object):
	if object != null:
		if object is Spatial:
			return true
	return object == null

func forward_spatial_gui_input(camera, event):
	if interop_ignore_input:
		return false
		
	update_overlays()
	# SHOW / HIDE GHOST
	if ghost != null:
		if panel.is_painting() :
			ghost.show()
		else:
			ghost.hide()
			
	if event is InputEventMouseMotion:
		# GHOST LOGIC
		if panel.is_painting() and ghost != null:
			match edit_mode:
				EDIT_MODES.NORMAL:
					var panel_data = panel.get_current_tab_data()
					var tab_data = panel_data["tabdata"]
					var ray_result = null
					if tab_data.chk_grid:
						ray_result = _intersect_with_plane(camera, event.position, float(tab_data.le_gridsize), panel_data["paneldata"].grid_level, tab_data.opt_grid)
					else:
						ray_result = _intersect_with_colliders(camera, event.position)
					if ray_result == null:
						return false
					else:
						if tab_data.y_normal:
							var scale_prev = ghost.scale
							var new_basis = ghost.global_transform.basis
							new_basis.y = ray_result.normal
							new_basis.x = ((new_basis.x).slide(ray_result.normal)).normalized()
							new_basis.z = new_basis.x.cross(new_basis.y).normalized()
							new_basis = new_basis.orthonormalized()
							new_basis.x *= scale_prev.x
							new_basis.y *= scale_prev.y
							new_basis.z *= scale_prev.z
							ghost.global_transform.basis = new_basis
						ghost.global_transform.origin = ray_result.position
				
				EDIT_MODES.SCALE:
					var cur_mouse = get_viewport().get_mouse_position()
					var dist = mouse_last_pos.distance_to(cur_mouse) / 100
					var new_scale = ghost_init_scale
					match scale_mode :
						SCALE_MODES.XYZ:
							new_scale *= dist
						SCALE_MODES.X:
							new_scale.x = ghost_init_scale.x * dist
						SCALE_MODES.Y:
							new_scale.y = ghost_init_scale.y * dist
						SCALE_MODES.Z:
							new_scale.z = ghost_init_scale.z * dist
						SCALE_MODES.XY:
							new_scale.x = ghost_init_scale.x * dist
							new_scale.y = ghost_init_scale.y * dist
						SCALE_MODES.XZ:
							new_scale.x = ghost_init_scale.x * dist
							new_scale.z = ghost_init_scale.z * dist
						SCALE_MODES.YZ:
							new_scale.y = ghost_init_scale.y * dist
							new_scale.z = ghost_init_scale.z * dist
					ghost.scale = new_scale
				EDIT_MODES.ROTATE:
					var cur_mouse = get_viewport().get_mouse_position()
					var dist = (cur_mouse.x - mouse_last_pos.x) / 100 #viewport_center.distance_to(cur_mouse) / 100
					var new_x = ghost_init_basis.x
					var new_y = ghost_init_basis.y
					var new_z = ghost_init_basis.z
					if rotate_mode == ROTATE_MODES.X:
						new_y = (ghost_init_basis.y).rotated(ghost_init_basis.x.normalized(), dist)
						new_z = (ghost_init_basis.z).rotated(ghost_init_basis.x.normalized(), dist)
					if rotate_mode == ROTATE_MODES.Y:
						new_x = (ghost_init_basis.x).rotated(ghost_init_basis.y.normalized(), dist)
						new_z = (ghost_init_basis.z).rotated(ghost_init_basis.y.normalized(), dist)
					if rotate_mode == ROTATE_MODES.Z:
						new_x = (ghost_init_basis.x).rotated(ghost_init_basis.z.normalized(), dist)
						new_y = (ghost_init_basis.y).rotated(ghost_init_basis.z.normalized(), dist)
					ghost.global_transform.basis = Basis(new_x, new_y, new_z)
				
		# RAPID PLACEMENT LOGIC
		if event.button_mask == 1 and panel.is_painting() and edit_mode == EDIT_MODES.NORMAL:
			var panel_data = panel.get_current_tab_data()
			var tab_data = panel_data["tabdata"]
			if tab_data.chk_rapid:
				var ray_result = null
				if tab_data.chk_grid:
					ray_result = _intersect_with_plane(camera, event.position, float(tab_data.le_gridsize), panel_data["paneldata"].grid_level, tab_data.opt_grid)
				else:
					ray_result = _intersect_with_colliders(camera, event.position)
				if ray_result == null:
					return false
				else:
					if tab_data.chk_grid:
						#GRID RAPID PLACEMENT
						if not grid_placement.has(ray_result.position):
							if allow_rapid_paint:
								init_paint_job(ray_result, tab_data, ghost)
								grid_placement.append(ray_result.position)
							return true
						else:
							return false
					else:
						#NORMAL RAPID PLACEMENT
						if last_placement.distance_to(ray_result.position) < 0.5:
							return false
						else:
							if allow_rapid_paint:
								init_paint_job(ray_result, tab_data, ghost)
							return true
							
	#KEYBOARD SHORTCUT
	if event is InputEventKey :
		if event.is_pressed():
			if event.scancode == KEY_SPACE and event.control :
				panel.toggle_paint()
				
			if panel.is_painting():
				var panel_data = panel.get_current_tab_data()
				var tab_data = panel_data["tabdata"]
				var rotation_snap = float(panel_data["paneldata"].rotation_snap)
				var z_up = panel_data["paneldata"].z_up
				
				match edit_mode :
					EDIT_MODES.NORMAL:
						
						if event.scancode == KEY_PERIOD:
							panel.grid_level_raised()
							
						if event.scancode == KEY_COMMA:
							panel.grid_level_lowered()
							
						if event.scancode == KEY_S:
							if event.alt:
								ghost.scale = Vector3(1,1,1)
								ghost_init_scale = Vector3(1,1,1)
							else:
								_start_edit_mode_scale(event)
						
						if event.scancode == KEY_R:
							if event.alt:
								ghost.rotation = Vector3()
								ghost_init_rotation = Vector3()
							else:
								_start_edit_mode_rotate(event)
								
						if event.scancode == KEY_X:
							if event.shift:
								rotate_ghost("X", -rotation_snap)
							else:
								rotate_ghost("X", rotation_snap)
						if event.scancode == KEY_Y:
							if not z_up:
								if event.shift:
									rotate_ghost("Y", -rotation_snap)
								else:
									rotate_ghost("Y", rotation_snap)
							else:
								if event.shift:
									rotate_ghost("Z", -rotation_snap)
								else:
									rotate_ghost("Z", rotation_snap)
						if event.scancode == KEY_Z:
							if not z_up:
								if event.shift:
									rotate_ghost("Z", -rotation_snap)
								else:
									rotate_ghost("Z", rotation_snap)
							else:
								if event.shift:
									rotate_ghost("Y", -rotation_snap)
								else:
									rotate_ghost("Y", rotation_snap)
							
					EDIT_MODES.SCALE:
						if event.scancode == KEY_R:
							if event.alt:
								ghost.rotation = Vector3()
								ghost_init_rotation = Vector3()
							else:
								_start_edit_mode_rotate(event, false)
								
						if event.scancode == KEY_X:
							if event.shift:
								scale_mode = SCALE_MODES.YZ
							else:
								scale_mode = SCALE_MODES.X
						elif event.scancode == KEY_Y:
							if not z_up:
								if event.shift:
									scale_mode = SCALE_MODES.XZ
								else:
									scale_mode = SCALE_MODES.Y
							else:
								if event.shift:
									scale_mode = SCALE_MODES.XY
								else:
									scale_mode = SCALE_MODES.Z
						elif event.scancode == KEY_Z:
							if not z_up:
								if event.shift:
									scale_mode = SCALE_MODES.XY
								else:
									scale_mode = SCALE_MODES.Z
							else:
								if event.shift:
									scale_mode = SCALE_MODES.XZ
								else:
									scale_mode = SCALE_MODES.Y
						elif event.scancode == KEY_S:
							if event.alt:
								ghost.scale = Vector3(1,1,1)
								ghost_init_scale = Vector3(1,1,1)
							elif event.shift:
								ghost.scale = ghost_init_scale
							else:
								scale_mode = SCALE_MODES.XYZ
					EDIT_MODES.ROTATE:
						if event.scancode == KEY_S:
							if event.alt:
								ghost.scale = Vector3(1,1,1)
								ghost_init_scale = Vector3(1,1,1)
							else:
								_start_edit_mode_scale(event, false)
								
						if event.scancode == KEY_X:
							rotate_mode = ROTATE_MODES.X
						elif event.scancode == KEY_Y:
							if not z_up:
								rotate_mode = ROTATE_MODES.Y
							else:
								rotate_mode = ROTATE_MODES.Z
						elif event.scancode == KEY_Z:
							if not z_up:
								rotate_mode = ROTATE_MODES.Z
							else:
								rotate_mode = ROTATE_MODES.Y
						elif event.scancode == KEY_R:
							if event.alt:
								ghost.rotation = Vector3()
								ghost_init_rotation = Vector3()
							elif event.shift:
								ghost.global_transform.basis = ghost_init_basis
	
	## MOUSE BUTTON, LEFT TO PLACE / CONFIRM SCALE AND ROTATE, RIGHT TO CANCEL
	if event is InputEventMouseButton :
		if event.button_index == BUTTON_LEFT:
			# NORMAL PLACEMENT LOGIC
			if event.is_pressed() and panel.is_painting():
				match edit_mode:
					EDIT_MODES.NORMAL:
						var panel_data = panel.get_current_tab_data()
						var tab_data = panel_data["tabdata"]
						var ray_result = null
						if tab_data.chk_grid:
							ray_result = _intersect_with_plane(camera, event.position, float(tab_data.le_gridsize), panel_data["paneldata"].grid_level, tab_data.opt_grid)
						else:
							ray_result = _intersect_with_colliders(camera, event.position)
						
						if ray_result == null:
							return false
						init_paint_job(ray_result, tab_data, ghost)
						if tab_data.chk_grid:
							grid_placement.clear()
							grid_placement.append(ray_result.position)
						return true
					EDIT_MODES.SCALE:
						edit_mode = EDIT_MODES.NORMAL
						get_viewport().warp_mouse(mouse_last_pos)
						allow_rapid_paint = false
						timer.start(0.1)
						update_overlays()
						return true
					EDIT_MODES.ROTATE:
						edit_mode = EDIT_MODES.NORMAL
						get_viewport().warp_mouse(mouse_last_pos)
						allow_rapid_paint = false
						timer.start(0.1)
						update_overlays()
						return true
						
		if event.button_index == BUTTON_RIGHT:
			if event.is_pressed() and panel.is_painting():
				match edit_mode:
					EDIT_MODES.SCALE:
						ghost.scale = ghost_init_scale
						edit_mode = EDIT_MODES.NORMAL
						get_viewport().warp_mouse(mouse_last_pos)
						update_overlays()
						return true
					EDIT_MODES.ROTATE:
						ghost.global_transform.basis = ghost_init_basis
						edit_mode = EDIT_MODES.NORMAL
						get_viewport().warp_mouse(mouse_last_pos)
						update_overlays()
						return true

	return false

func init_paint_job(ray_result, tab_data, ghost_data):
	Interop.start_work(self, "bpb_placement")
	var path = panel.get_selected_obj()
	if path == null:
		return
		
	var obj = load(path).instance()
	
	#ROTATION
	var new_basis = ghost.global_transform.basis
	var use_basis = true
	var new_rot = Vector3(0,0,0)
	if tab_data.chk_rot_x:
		new_rot.x = deg2rad(rand_range(0, 360))
		use_basis = false
	if tab_data.chk_rot_y:
		new_rot.y = deg2rad(rand_range(0, 360))
		use_basis = false
	if tab_data.chk_rot_z:
		new_rot.z = deg2rad(rand_range(0, 360))
		use_basis = false
	
	var rot_val = {}
	rot_val.use_basis = use_basis
	rot_val.basis = new_basis
	rot_val.rot = new_rot
	
	#SCALE
	var new_scale = ghost.scale
	if tab_data.chk_scale_x:
		new_scale.x = rand_range(float(tab_data.le_scale_x_min), float(tab_data.le_scale_x_max))
	if tab_data.chk_scale_y:
		new_scale.y = rand_range(float(tab_data.le_scale_y_min), float(tab_data.le_scale_y_max))
	if tab_data.chk_scale_z:
		new_scale.z = rand_range(float(tab_data.le_scale_z_min), float(tab_data.le_scale_z_max))
			
	var undo_redo := get_undo_redo()
	undo_redo.create_action("paint_scene")
	undo_redo.add_do_method(self, "do_placement", obj, ray_result, rot_val, new_scale)
	undo_redo.add_undo_method(self, "undo_placement", obj)
	undo_redo.add_do_reference(obj)
	undo_redo.commit_action()
	last_placement = ray_result.position
	
	timer_click.start(0.1)
	first_draw = true
	
	Interop.end_work(self, "bpb_placement")
	
func do_placement(obj, ray_result, new_rot, new_scale):
	get_tree().get_edited_scene_root().add_child(obj)
	#POSITION
	obj.global_transform.origin = ray_result.position
	#ROTATION
	if new_rot.use_basis:
		obj.global_transform.basis = new_rot.basis
	else:
		obj.rotation = new_rot.rotation
	#SCALE
	obj.scale = new_scale
	#ADD TO SCENE TREE
	obj.set_owner(get_tree().get_edited_scene_root())
	
	
func undo_placement(obj):
	obj.get_parent().remove_child(obj)
	#obj.queue_free()

func get_undo_redo_stack():
	return get_undo_redo()

func make_ghost():
	var path = panel.get_selected_obj()
	if path == null:
		return
	if ghost:
		ghost.queue_free()
	ghost = load(path).instance()
	get_tree().get_edited_scene_root().add_child(ghost)
	edit_mode = EDIT_MODES.NORMAL

func remove_ghost():
	if ghost:
		ghost.hide()
		ghost.queue_free()

func rotate_ghost(axis, val):
	var degree = deg2rad(val)
	var ghost_basis = ghost.global_transform.basis
	var vector_axis = Vector3.UP
	if axis == "X":
		vector_axis = Vector3.RIGHT
	if axis == "Y":
		vector_axis = Vector3.UP
	if axis == "Z":
		vector_axis = Vector3.BACK
	var new_x = (ghost_basis.x).rotated(vector_axis, degree)
	var new_y = (ghost_basis.y).rotated(vector_axis, degree)
	var new_z = (ghost_basis.z).rotated(vector_axis, degree)
	ghost.global_transform.basis = Basis(new_x, new_y, new_z)
	

func _on_timer_click_timeout():
	update_overlays()
	pass
	
func forward_spatial_draw_over_viewport(overlay):
	if edit_mode == EDIT_MODES.SCALE or edit_mode == EDIT_MODES.ROTATE:
		var color0 = Color(0.0, 0.0, 0.0, 0.1)
		if first_draw:
			circle_center = overlay.get_local_mouse_position()
			var mouse_pos = overlay.get_global_mouse_position()
			var diff = mouse_pos - circle_center
			circle_center = mouse_last_pos - diff
			first_draw = false
		overlay.draw_circle(circle_center, 100, color0)
		
		var color1 = Color(0.0, 1.0, 1.0, 0.1)
		if edit_mode == EDIT_MODES.SCALE:
			color1 = Color(0.0, 0.0, 1.0, 0.1)
		
		var radius = circle_center.distance_to(overlay.get_local_mouse_position())
		overlay.draw_circle(circle_center, radius, color1)
	if timer_click.time_left > 0:
		if first_draw:
			circle_center = overlay.get_local_mouse_position()
			first_draw = false
		var color0 = Color(0.0, 1.0, 0.0, 0.8)
		overlay.draw_circle(circle_center, 10, color0)
	
func start_painting():
	Interop.grab_full_input(self)
	
func stop_painting():
	Interop.release_full_input(self)
	ghost.hide()
	update_overlays()
	
