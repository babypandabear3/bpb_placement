# BPB PLACEMENT

A plugin to help placing objects / scene onto level

Installation
-----------
copy the folder addons/bpb_placement into your project and activate the add-on from the Project -> Project Settings... -> Plugins menu.

Purpose
-------
To make it easier to place objects onto level. I decided to use tabbed interface, where each tab has it's own default placement parameters user can set. 

Usage
-----
Once the addon is active, you get BPB Placement panel on bottom panel (next to Output, Debugger, Audio, Animation...)
Click Add Tab button and set name for newly made tab
In tab, click Add button and choose scene file you want to add
Scene will be available on list on right, displayed as thumbnail
To start placing objects, choose one from list and click Paint button on main Panel. 
Point mouse to where you want to instance the scene. A temporary pointer mesh will be shown at mouse position. 
To instance object, Left Click 


Panel Options
-------------
On panel, following parameters can be set
- *Grid Level* - Used to determined level / layer of grid currently used for grid placement
- *Rotation Snap* - In Degree. Used for rotating pointer mesh
- *Z for up* - Swaps the z and y shortcut keys for people who want the same shortcuts Blender uses

On tab,
- *Rapid Placement* - Allowing rapid placement while holding and dragging Left Mouse button
- *Grid* - Use Grid-like position for placement
- *Options : Grid XZ | Grid XY | Grid YZ* - Choose grid type. XZ is a plane along x and z axis, XY is a plane on xy axis, YZ is on yz axis
- *Size* : Size of grid
- *Rand Rotation : X Y Z* - Random rotation will be applied to chosen axis. If used, then this will overwrite rotation values provided by pointer mesh 
- *Y align Normal* - if true object will be rotated the way it's local Y axis is align with surface normal. If using grid placement, this option is ignored
- *Rand Scale : X min, X max, y min, Y max, Z min, Z max* - if selected, random value will be generated in range min to max for each axis and will be applied instance scene. If used, then this will overwrite scale values provided by pointer mesh 

Editing
-------
Other than random rotation and scale, this plugin also allows for simple scale / rotation manipulation.
When Paint mode is on, following shortcut is available:
- X Y Z (+shift) : rotate pointer mesh on each global axis with degree value set in *Rotation Snap*. Hold shift for reverse
- Alt S : Reset pointer mesh scale to default (1,1,1)
- Alt R : Reset pointer mesh rotation to default (0,0,0)
S : Enter Scale mode
R : Enter Rotation mode

*Scale mode*
Move mouse further from pointer mesh to scale up, and closer to scale down. Left click to accept new scale, Right click to cancel. By default new scale will be applied to all axis.
Following shortcut available in scale mode
X Y Z : Scale along chosen axis
Shift + X Y Z : Scale while exclude axis
S : Set scale to all axis (default behavior)
Shift S : Return scale value to first value when entering scale mode
Alt S : Reset scale to default (1,1,1)
R : Enter Rotation mode

*Rotation mode*
mouse mouse right or left to rotate pointer mesh. By default, rotation will be done using Y axis (global UP).
Following shortcut available in scale mode
X Y Z : Rotate using chosen axis
Shift R : Return rotation value to first value when entering rotation mode
Alt R : Return rotation value to default (0,0,0)
S : Enter Scale mode

Acknowledgements
---------------
Several people in the Godot community have helped me out with this. They answer a lot of questions that helps tremendously in writing features for this plugins
* z-one 
* HungryProton
* pycbouh
* samsfacee
