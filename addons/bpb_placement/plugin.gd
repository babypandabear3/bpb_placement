tool
extends EditorPlugin

signal ghost_made
signal ghost_removed

const GRID_OVERLAY_TSCN = preload("res://addons/bpb_placement/grid_overlay.tscn")
const PANEL_DEFAULT = preload("res://addons/bpb_placement/bpbp_main.tscn")
var Interop = preload("res://addons/bpb_placement/interop.gd")

enum EDIT_MODES {
	NONE,
	NORMAL,
	ROTATE,
	SCALE,
	GSR
}


enum AXIS_ENUM {
	XYZ,
	X,
	Y,
	Z,
	XY,
	XZ,
	YZ,
}

var interop_ignore_input := false
var gsr_plugin 

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

var edit_mode = EDIT_MODES.NONE
var axis = AXIS_ENUM.XYZ
var axis_local = true

var use_ghost_last_pos = false
var ghost_prepared_pos = Vector3()
var ghost_last_pos = Vector3()
var mouse_last_ghost_pos = Vector2()
var mouse_last_pos = Vector2()
var viewport_center = Vector2()
var ghost_init_scale = Vector3()

var ghost_init_viewport_pos = Vector2()
var ghost_init_basis
var ghost_init_rotation

var grid_overlay

var first_draw = false
var circle_center = Vector2()

var timer = Timer.new()
var timer_click = Timer.new()
var allow_rapid_paint = true

var camera_last
var overlay_pos_top_left = Vector2()

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
	edit_mode = EDIT_MODES.NONE
	
	grid_overlay = GRID_OVERLAY_TSCN.instance()
	add_child(grid_overlay)
	grid_overlay.hide()
	
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
	
func gsr_manipulation_result(what, accept, t):
	print(accept)
	if t:
		ghost.transform = t[0]
	else:
		ghost.global_transform.basis = ghost_init_basis
		
	edit_mode = EDIT_MODES.NORMAL
	get_viewport().warp_mouse(mouse_last_pos)
	allow_rapid_paint = false
	timer.start(0.1)
	
func _start_edit_mode_scale(event, camera, fresh=true):
	axis = AXIS_ENUM.XYZ
	axis_local = true
	
	viewport_center = get_viewport().size / 2
	mouse_last_pos = get_viewport().get_mouse_position()
	if not fresh:
		mouse_last_pos = ghost_init_viewport_pos
		
	var mouse_edit_pos = mouse_last_pos
	if mouse_last_pos.x < get_viewport().size.x / 2:
		mouse_edit_pos.x += 100
	else:
		mouse_edit_pos.x -= 100
	
	get_viewport().warp_mouse(mouse_edit_pos)
	ghost_init_viewport_pos = mouse_last_pos
	ghost_init_scale = ghost.scale
	ghost_init_basis = ghost.global_transform.basis
	first_draw = true
	
	# GSR Integration
	var panel_gsr = panel.get_panel_data().gsr
	gsr_plugin = Interop.get_plugin_or_null(self, "gsr")
	if gsr_plugin and panel_gsr:
		edit_mode = EDIT_MODES.GSR
		yield(get_tree().create_timer(0.1), "timeout")
		gsr_plugin.external_request_manipulation(camera, "sr", [ghost], self, "gsr_manipulation_result")
		return
		
	edit_mode = EDIT_MODES.SCALE
	
	
	
func _start_edit_mode_rotate(event, camera, fresh=true):
	axis = AXIS_ENUM.Y
	axis_local = false
	
	mouse_last_pos = get_viewport().get_mouse_position()
	if not fresh:
		mouse_last_pos = ghost_init_viewport_pos
		
	ghost_init_viewport_pos = mouse_last_pos
	ghost_init_basis = ghost.global_transform.basis
	ghost_init_rotation = ghost.rotation
	var mouse_first_rotate_pos = mouse_last_pos
	mouse_first_rotate_pos.x += 50
	get_viewport().warp_mouse(mouse_first_rotate_pos)
	first_draw = true
	
	# GSR Integration
	var panel_gsr = panel.get_panel_data().gsr
	gsr_plugin = Interop.get_plugin_or_null(self, "gsr")
	if gsr_plugin and panel_gsr:
		edit_mode = EDIT_MODES.GSR
		yield(get_tree().create_timer(0.1), "timeout")
		gsr_plugin.external_request_manipulation(camera, "rs", [ghost], self, "gsr_manipulation_result")
		return
		
	edit_mode = EDIT_MODES.ROTATE

# FUNCTION handles IS NEEDED TO ALLOW OVERLAY DRAWING
func handles(object):
	if edit_mode != EDIT_MODES.NONE:
		return true
		
	if object != null:
		if object is Spatial:
			return true

	return object == null

func forward_spatial_gui_input(camera, event):
	camera_last = camera
	if interop_ignore_input:
		return false
		
	if edit_mode == EDIT_MODES.GSR:
		return false
		
	update_overlays()
	# SHOW / HIDE GHOST
	if ghost != null:
		if edit_mode == EDIT_MODES.NONE:
			ghost.hide()
			grid_overlay.hide()
		else:
			#WORKAROUND JUST IN CASE GHOST IS DELETED SOMEWHERE ELSE, SET IT TO NULL
			var wr = weakref(ghost)
			if (!wr.get_ref()):
				ghost = null
				grid_overlay.hide()
			else:
				ghost.show()
			
	if event is InputEventMouseMotion:
		# GHOST LOGIC
		if ghost != null:
			match edit_mode:
				EDIT_MODES.NONE:
					ghost.hide()
					set_init_ghost_pos()
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
						if tab_data.chk_grid:
							update_grid_overlay(ray_result.position, tab_data)
						else:
							grid_overlay.hide()
				EDIT_MODES.SCALE:
					var cur_mouse = get_viewport().get_mouse_position()
					var dist = mouse_last_pos.distance_to(cur_mouse) / 100
					scale_ghost(dist)
				EDIT_MODES.ROTATE:
					var cur_mouse = get_viewport().get_mouse_position()
					var angle = Vector2.RIGHT.angle_to(cur_mouse-ghost_init_viewport_pos)
					rotate_ghost(axis, axis_local, angle, true)
					
		# RAPID PLACEMENT LOGIC
		if event.button_mask == 1 and edit_mode == EDIT_MODES.NORMAL:
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
							_start_edit_mode_scale(event, camera)
						
					if event.scancode == KEY_R:
						if event.alt:
							ghost.rotation = Vector3()
							ghost_init_rotation = Vector3()
						else:
							_start_edit_mode_rotate(event, camera)
							
					if event.scancode == KEY_X:
						if event.control:
							pass
						elif event.alt:
							pass
						else:
							axis_local = false
							axis = AXIS_ENUM.X
							if event.shift:
								rotate_ghost(axis, axis_local, -rotation_snap)
							else:
								rotate_ghost(axis, axis_local, rotation_snap)
					if event.scancode == KEY_Y:
						if event.control:
							pass
						elif event.alt:
							pass
						else:
							axis_local = false
							if not z_up:
								axis = AXIS_ENUM.Y
							else:
								axis = AXIS_ENUM.Z
								
							if event.shift:
								rotate_ghost(axis, axis_local, -rotation_snap)
							else:
								rotate_ghost(axis, axis_local, rotation_snap)
							
					if event.scancode == KEY_Z:
						if event.control:
							pass
						elif event.alt:
							pass
						else:
							axis_local = false
							if not z_up:
								axis = AXIS_ENUM.Z
							else:
								axis = AXIS_ENUM.Y
								
							if event.shift:
								rotate_ghost(axis, axis_local, -rotation_snap)
							else:
								rotate_ghost(axis, axis_local, rotation_snap)
							
							
				EDIT_MODES.SCALE:
					if event.scancode == KEY_R:
						if event.alt:
							ghost.rotation = Vector3()
							ghost_init_rotation = Vector3()
						else:
							_start_edit_mode_rotate(event, camera, false)
							
					if event.scancode == KEY_X:
						if event.control:
							pass
						elif event.alt:
							pass
						else:
							if event.shift:
								if not axis == AXIS_ENUM.YZ:
									axis = AXIS_ENUM.YZ
									axis_local = false
								else:
									axis_local = not axis_local
							else:
								if not axis == AXIS_ENUM.X:
									axis = AXIS_ENUM.X
									axis_local = false
								else:
									axis_local = not axis_local
							update_overlays()
					elif event.scancode == KEY_Y:
						if event.control:
							pass
						elif event.alt:
							pass
						else:
							if not z_up:
								if event.shift:
									if not axis == AXIS_ENUM.XZ:
										axis = AXIS_ENUM.XZ
										axis_local = false
									else:
										axis_local = not axis_local
								else:
									if not axis == AXIS_ENUM.Y:
										axis = AXIS_ENUM.Y
										axis_local = false
									else:
										axis_local = not axis_local
									
							else:
								if event.shift:
									if not axis == AXIS_ENUM.XY:
										axis = AXIS_ENUM.XY
										axis_local = false
									else:
										axis_local = not axis_local
								else:
									if not axis == AXIS_ENUM.Z:
										axis = AXIS_ENUM.Z
										axis_local = false
									else:
										axis_local = not axis_local
							update_overlays()
					elif event.scancode == KEY_Z:
						if event.control:
							pass
						elif event.alt:
							pass
						else:
							if not z_up:
								if event.shift:
									axis = AXIS_ENUM.XY
									if not axis == AXIS_ENUM.XY:
										axis = AXIS_ENUM.XY
										axis_local = false
									else:
										axis_local = not axis_local
								else:
									if not axis == AXIS_ENUM.Z:
										axis = AXIS_ENUM.Z
										axis_local = false
									else:
										axis_local = not axis_local
							else:
								if event.shift:
									if not axis == AXIS_ENUM.XZ:
										axis = AXIS_ENUM.XZ
										axis_local = false
									else:
										axis_local = not axis_local
								else:
									if not axis == AXIS_ENUM.Y:
										axis = AXIS_ENUM.Y
										axis_local = false
									else:
										axis_local = not axis_local
							update_overlays()
					elif event.scancode == KEY_S:
						if event.alt:
							ghost.scale = Vector3(1,1,1)
							ghost_init_scale = Vector3(1,1,1)
						elif event.shift:
							ghost.scale = ghost_init_scale
						else:
							axis = AXIS_ENUM.XYZ
				EDIT_MODES.ROTATE:
					if event.scancode == KEY_S:
						if event.alt:
							ghost.scale = Vector3(1,1,1)
							ghost_init_scale = Vector3(1,1,1)
						else:
							_start_edit_mode_scale(event, camera, false)
							
					if event.scancode == KEY_X:
						if event.control:
							pass
						elif event.alt:
							pass
						else:
							if axis != AXIS_ENUM.X:
								axis_local = false
								axis = AXIS_ENUM.X
							else:
								axis_local = not axis_local
						update_overlays()
					elif event.scancode == KEY_Y:
						if event.control:
							pass
						elif event.alt:
							pass
						else:
							if not z_up:
								if axis != AXIS_ENUM.Y:
									axis_local = false
									axis = AXIS_ENUM.Y
								else:
									axis_local = not axis_local
							else:
								if axis != AXIS_ENUM.Z:
									axis_local = false
									axis = AXIS_ENUM.Z
								else:
									axis_local = not axis_local
						update_overlays()
					elif event.scancode == KEY_Z:
						if event.control:
							pass
						elif event.alt:
							pass
						else:
							if not z_up:
								if axis != AXIS_ENUM.Z:
									axis_local = false
									axis = AXIS_ENUM.Z
								else:
									axis_local = not axis_local
							else:
								if axis != AXIS_ENUM.Y:
									axis_local = false
									axis = AXIS_ENUM.Y
								else:
									axis_local = not axis_local
						update_overlays()
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
	rot_val.rotation = new_rot
	
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
	if not new_scale.is_equal_approx(ghost.scale):
		var old_basis = obj.global_transform.basis
		old_basis.x = old_basis.x * new_scale.x
		old_basis.y = old_basis.y * new_scale.y
		old_basis.z = old_basis.z * new_scale.z
		obj.global_transform.basis = old_basis
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
	ghost.hide()

func remove_ghost():
	if ghost:
		ghost.hide()
		ghost.queue_free()

func scale_ghost(dist):
	var new_scale = ghost_init_scale
	if axis_local:
		match axis :
			AXIS_ENUM.XYZ:
				new_scale *= dist
			AXIS_ENUM.X:
				new_scale.x = ghost_init_scale.x * dist
			AXIS_ENUM.Y:
				new_scale.y = ghost_init_scale.y * dist
			AXIS_ENUM.Z:
				new_scale.z = ghost_init_scale.z * dist
			AXIS_ENUM.XY:
				new_scale.x = ghost_init_scale.x * dist
				new_scale.y = ghost_init_scale.y * dist
			AXIS_ENUM.XZ:
				new_scale.x = ghost_init_scale.x * dist
				new_scale.z = ghost_init_scale.z * dist
			AXIS_ENUM.YZ:
				new_scale.y = ghost_init_scale.y * dist
				new_scale.z = ghost_init_scale.z * dist
		ghost.scale = new_scale
	else:
		var new_basis_x = ghost_init_basis.x
		var new_basis_y = ghost_init_basis.y
		var new_basis_z = ghost_init_basis.z
		var modi = 0.5
		if axis == AXIS_ENUM.X or axis == AXIS_ENUM.XY or axis == AXIS_ENUM.XYZ or axis == AXIS_ENUM.XZ:
			new_basis_x.x = new_basis_x.x * dist * modi
			new_basis_y.x = new_basis_y.x * dist * modi
			new_basis_z.x = new_basis_z.x * dist * modi
		if axis == AXIS_ENUM.XY or axis == AXIS_ENUM.XYZ or axis == AXIS_ENUM.Y or axis == AXIS_ENUM.YZ:
			new_basis_x.y = new_basis_x.y * dist * modi
			new_basis_y.y = new_basis_y.y * dist * modi
			new_basis_z.y = new_basis_z.y * dist * modi
		if axis == AXIS_ENUM.XYZ or axis == AXIS_ENUM.XZ or axis == AXIS_ENUM.YZ or axis == AXIS_ENUM.Z:
			new_basis_x.z = new_basis_x.z * dist * modi
			new_basis_y.z = new_basis_y.z * dist * modi
			new_basis_z.z = new_basis_z.z * dist * modi
		ghost.global_transform.basis = Basis(new_basis_x, new_basis_y, new_basis_z)
		
		
func rotate_ghost(paxis, paxis_local, angle, init_basis = false):
	
	var ghost_basis = ghost.global_transform.basis
	if init_basis:
		ghost_basis = ghost_init_basis
	
	var vector_axis = Vector3.UP
	if paxis == AXIS_ENUM.X:
		if paxis_local:
			vector_axis = ghost.global_transform.basis.x
		else:
			vector_axis = Vector3.RIGHT
	if paxis == AXIS_ENUM.Y:
		if paxis_local:
			vector_axis = ghost.global_transform.basis.y
		else:
			vector_axis = Vector3.UP
	if paxis == AXIS_ENUM.Z:
		if paxis_local:
			vector_axis = ghost.global_transform.basis.z
		else:
			vector_axis = Vector3.BACK
	var new_x = ghost_basis.x
	var new_y = ghost_basis.y
	var new_z = ghost_basis.z
	
	var dot = vector_axis.normalized().dot((-camera_last.global_transform.basis.z).normalized())
	var degree = angle
	if dot < 0:
		degree *= -1
	if axis_local:
		if axis == AXIS_ENUM.X:
			new_y = (ghost_basis.y).rotated(vector_axis.normalized(), degree)
			new_z = (ghost_basis.z).rotated(vector_axis.normalized(), degree)
		if axis == AXIS_ENUM.Y:
			new_x = (ghost_basis.x).rotated(vector_axis.normalized(), degree)
			new_z = (ghost_basis.z).rotated(vector_axis.normalized(), degree)
		if axis == AXIS_ENUM.Z:
			new_x = (ghost_basis.x).rotated(vector_axis.normalized(), degree)
			new_y = (ghost_basis.y).rotated(vector_axis.normalized(), degree)
	else:
		new_x = (ghost_basis.x).rotated(vector_axis.normalized(), degree)
		new_y = (ghost_basis.y).rotated(vector_axis.normalized(), degree)
		new_z = (ghost_basis.z).rotated(vector_axis.normalized(), degree)
	ghost.global_transform.basis = Basis(new_x, new_y, new_z)
	

func _on_timer_click_timeout():
	update_overlays()
	pass
	
func forward_spatial_draw_over_viewport(overlay):
	var local_pos = overlay.get_local_mouse_position()
	var global_pos = overlay.get_global_mouse_position()
	overlay_pos_top_left = global_pos - local_pos
	
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
		#overlay.draw_circle(circle_center, radius, color1)
		
		var mouse_pos = overlay.get_local_mouse_position()
		draw_line_dotted(overlay, mouse_pos, circle_center, 4.0, 4.0, Color.white, 1.0, true)
		
		if axis == AXIS_ENUM.X or axis == AXIS_ENUM.XY or axis == AXIS_ENUM.XYZ or axis == AXIS_ENUM.XZ:
			draw_axis(overlay, "X", axis_local)
		if axis == AXIS_ENUM.XY or axis == AXIS_ENUM.XYZ or axis == AXIS_ENUM.Y or axis == AXIS_ENUM.YZ:
			draw_axis(overlay, "Y", axis_local)
		if axis == AXIS_ENUM.XYZ or axis == AXIS_ENUM.XZ or axis == AXIS_ENUM.YZ or axis == AXIS_ENUM.Z:
			draw_axis(overlay, "Z", axis_local)
			
	# DRAW CIRCLE WHEN PLACING OBJECT
	if timer_click.time_left > 0:
		if first_draw:
			circle_center = overlay.get_local_mouse_position()
			first_draw = false
		var color0 = Color(0.0, 1.0, 0.0, 0.8)
		overlay.draw_circle(circle_center, 10, color0)
	
func start_painting():
	Interop.grab_full_input(self)
	edit_mode = EDIT_MODES.NORMAL
	
	
func stop_painting():
	Interop.release_full_input(self)
	edit_mode = EDIT_MODES.NONE
	if ghost:
		ghost.hide()
	if grid_overlay:
		grid_overlay.hide()
	update_overlays()
	
	
func draw_line_dotted(control: CanvasItem, from: Vector2, to: Vector2, dot_len: float, space_len: float, color: Color, width: float = 1.0, antialiased: bool = false):
	var normal := (to - from).normalized()
	
	var start := from
	var end := from + normal * dot_len
	var length = (to - from).length()
	
	while length > (start - from).length():
		if length < (end - from).length():
			end = to
		
		control.draw_line(start, end, color, width, antialiased)
		
		start = end + normal * space_len
		end = start + normal * dot_len

func draw_axis(control, paxis, plocal):
	if not camera_last:
		return
		
	var start_3d = ghost.global_transform.origin
	var end_3d
	var color
	var changer = Vector3.RIGHT
	if paxis == "X":
		color = Color(1, 0.6, 0.6, 1)
		changer = Vector3.RIGHT
		if plocal:
			changer = ghost_init_basis.x.normalized()
	if paxis == "Y":
		color = Color(0.6, 1, 0.6, 1)
		changer = Vector3.UP
		if plocal:
			changer = ghost_init_basis.y.normalized()
		else:
			pass
	if paxis == "Z":
		color = Color(0.6, 0.6, 1, 1)
		changer = Vector3.BACK
		if plocal:
			changer = ghost_init_basis.z.normalized()
		
	var line_width = 1.0
	var line_length = 10
	if not plocal:
		line_length = 20
		line_width = 2.0
	end_3d = start_3d + (changer * line_length)
	var end_3d2 = start_3d - (changer * line_length)
	
	var start = camera_last.unproject_position(start_3d)
	var end = camera_last.unproject_position(end_3d)
	var end2 = camera_last.unproject_position(end_3d2)
	control.draw_line(start, end, color, line_width)
	control.draw_line(start, end2, color, line_width)
	
func set_init_ghost_pos():
	var panel_data = panel.get_current_tab_data()
	if not panel_data.has("tabdata"):
		return
	var tab_data = panel_data["tabdata"]
	var ray_result = null
	var event_position = get_viewport().get_mouse_position() - overlay_pos_top_left
	if tab_data.chk_grid:
		ray_result = _intersect_with_plane(camera_last, event_position, float(tab_data.le_gridsize), panel_data["paneldata"].grid_level, tab_data.opt_grid)
	else:
		ray_result = _intersect_with_colliders(camera_last, event_position)
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
				
func kill_ghost():
	if ghost:
		ghost = null

func update_grid_overlay(pposition, ptab_data):
	grid_overlay.show()
	grid_overlay.global_transform.origin = pposition
	grid_overlay.set_grid_param(ptab_data.le_gridsize, ptab_data.opt_grid)
	
