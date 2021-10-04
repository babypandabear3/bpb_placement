tool
extends WindowDialog
signal confirmed

var tab_idx = -1
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _input(event):
	if event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER )and not event.echo and visible:
		emit_signal("confirmed")
		yield(get_tree().create_timer(0.1), "timeout")
		hide()

func set_tab_idx(par):
	tab_idx = par
	
func get_data():
	var ret = {}
	ret.tab_idx = tab_idx
	ret.text = $le_input.text
	return ret

func do_focus():
	$le_input.grab_focus()
	
func clear_input():
	$le_input.text = ""
