tool
extends Spatial

var grid_size = 0
var plane = 0

var mesh : MeshInstance
var height_par : float
var mesh_x = []
var mesh_z = []
# Called when the node enters the scene tree for the first time.
func _ready():
	mesh = get_node("x/1")
	height_par = mesh.mesh.height
	mesh_x.append(get_node("x/1"))
	mesh_x.append(get_node("x/2"))
	mesh_x.append(get_node("x/3"))
	mesh_x.append(get_node("x/4"))
	mesh_x.append(get_node("x/5"))
	mesh_x.append(get_node("x/6"))
	mesh_x.append(get_node("x/7"))
	mesh_x.append(get_node("x/8"))
	mesh_x.append(get_node("x/9"))
	mesh_x.append(get_node("x/10"))
	
	mesh_z.append(get_node("z/1"))
	mesh_z.append(get_node("z/2"))
	mesh_z.append(get_node("z/3"))
	mesh_z.append(get_node("z/4"))
	mesh_z.append(get_node("z/5"))
	mesh_z.append(get_node("z/6"))
	mesh_z.append(get_node("z/7"))
	mesh_z.append(get_node("z/8"))
	mesh_z.append(get_node("z/9"))
	mesh_z.append(get_node("z/10"))


func set_grid_param(psize, pplane):
	if float(grid_size) == float(psize):
		if int(plane) == int(pplane):
			return
		
	grid_size = float(psize)
	plane = int(pplane)
	
	mesh.mesh.height = grid_size * 10
	var start_pos = (-grid_size * 4) - (grid_size * 0.5)
	for i in 10:
		mesh_x[i].translation.x = start_pos + (i * grid_size)
		mesh_z[i].translation.z = start_pos + (i * grid_size)
		
	if plane == 0:
		rotation = Vector3.ZERO
	elif plane == 1:
		rotation_degrees = Vector3(90,0,0)
	elif plane == 2:
		rotation_degrees = Vector3(0,0,90)
