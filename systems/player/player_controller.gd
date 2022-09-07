extends Spatial

var curr_unit = null
var attackable_unit = null

# wait
var wait_time = 0

# controller status
var is_joystick = false

var map = null
var tactics_camera = null

# stage control
var stage = 0

var ui_control


func configure(var my_map, var my_camera, var my_control):
	map = my_map
	tactics_camera = my_camera
	ui_control = my_control
	tactics_camera.target = get_children().front()

	ui_control.get_act("Move").connect("pressed", self, "player_wants_to_move")
	ui_control.get_act("Wait").connect("pressed", self, "player_wants_to_wait")
	ui_control.get_act("Cancel").connect("pressed", self, "player_wants_to_cancel")
	ui_control.get_act("Attack").connect("pressed", self, "player_wants_to_attack")


func get_mouse_over_object(var lmask):
	if ui_control.is_mouse_hover_button(): return
	var camera = get_viewport().get_camera()
	var origin = get_viewport().get_mouse_position() if !is_joystick else get_viewport().size/2
	var from = camera.project_ray_origin(origin)
	var to = from + camera.project_ray_normal(origin)*1000000
	return get_world().direct_space_state.intersect_ray(from, to, [], lmask).get("collider")


func can_act():
	for unit in get_children(): 
		if unit.can_act(): return true 
	return stage > 0


func reset():
	for unit in get_children(): 
		unit.reset()


# --- user action inputs --- #
func player_wants_to_move(): stage = 2
func player_wants_to_cancel(): stage = 1 if stage > 1 else 0
func player_wants_to_wait(): 
	curr_unit.do_wait()
	stage = 0
func player_wants_to_attack(): stage = 5


# --- aux stage funcs --- #
func _aux_select_unit():
	var unit = get_mouse_over_object(2)
	var tile = get_mouse_over_object(1) if !unit else unit.get_tile()
	map.mark_hover_tile(tile)
	return unit if unit else tile.get_object_above() if tile else null

func _aux_select_tile():
	var unit = get_mouse_over_object(2)
	var tile = get_mouse_over_object(1) if !unit else unit.get_tile()
	map.mark_hover_tile(tile)
	return tile


# --- stages ---- #
func select_unit():
	map.reset()
	if curr_unit: curr_unit.display_unit_stats(false)
	curr_unit = _aux_select_unit()
	if !curr_unit : return
	curr_unit.display_unit_stats(true)
	if Input.is_action_just_pressed("ui_accept") and curr_unit.can_act() and curr_unit in get_children():
		tactics_camera.target = curr_unit
		stage = 1

func display_available_actions_for_unit():
	curr_unit.display_unit_stats(true)
	map.reset()
	map.mark_hover_tile(curr_unit.get_tile())

func display_available_movements():
	map.reset()
	if !curr_unit: return
	tactics_camera.target = curr_unit
	map.link_tiles(curr_unit.get_tile(), curr_unit.jump_height, get_children())
	map.mark_reachable_tiles(curr_unit.get_tile(), curr_unit.move_radious)
	stage = 3

func display_attackable_targets():
	map.reset()
	if !curr_unit: return
	tactics_camera.target = curr_unit
	map.link_tiles(curr_unit.get_tile(), curr_unit.attack_radious)
	map.mark_attackable_tiles(curr_unit.get_tile(), curr_unit.attack_radious)
	stage = 6

func select_new_location():
	var tile = get_mouse_over_object(1)
	map.mark_hover_tile(tile) 
	if Input.is_action_just_pressed("ui_accept"):
		if tile and tile.reachable:
			curr_unit.path_stack = map.generate_path_stack(tile)
			tactics_camera.target = tile
			stage = 4

func select_unit_to_attack():
	curr_unit.display_unit_stats(true)
	if attackable_unit: attackable_unit.display_unit_stats(false)
	var tile = _aux_select_tile()
	attackable_unit = tile.get_object_above() if tile else null
	if attackable_unit: attackable_unit.display_unit_stats(true)
	if Input.is_action_just_pressed("ui_accept") and tile and tile.attackable:
		tactics_camera.target = attackable_unit
		stage = 7

func move_unit():
	curr_unit.display_unit_stats(false)
	if curr_unit.path_stack.empty(): 
		stage = 0 if !curr_unit.can_act() else 1

func attack_unit(var delta):
	if !attackable_unit: curr_unit.can_attack = false
	else:
		if !curr_unit.do_attack(attackable_unit, delta): return
		attackable_unit.display_unit_stats(false)
		tactics_camera.target = curr_unit
	attackable_unit = null
	stage = 0 if !curr_unit.can_act() else 1

# --- camera --- #
func move_camera():
	var h = -Input.get_action_strength("camera_left")+Input.get_action_strength("camera_right")
	var v = Input.get_action_strength("camera_forward")-Input.get_action_strength("camera_backwards")
	tactics_camera.move_camera(h, v, is_joystick)

func camera_rotation():
	if Input.is_action_just_pressed("camera_rotate_left"): tactics_camera.y_rot -= 90
	if Input.is_action_just_pressed("camera_rotate_right"): tactics_camera.y_rot += 90


func act(var delta):
	move_camera()
	camera_rotation()
	ui_control.set_visibility_of_actions_menu(stage in [1,2,3,5,6], curr_unit)
	match stage:
		0: select_unit()
		1: display_available_actions_for_unit()
		2: display_available_movements()
		3: select_new_location()
		4: move_unit()
		5: display_attackable_targets()
		6: select_unit_to_attack()
		7: attack_unit(delta)

func _process(var _delta):
	Input.set_mouse_mode(is_joystick)

func _input(var event):
	is_joystick = event is InputEventJoypadButton or event is InputEventJoypadMotion
	ui_control.is_joystick = is_joystick
