extends Spatial

var stage = 0
var curr_unit
var attackable_unit

var tactics_camera = null
var map = null
var targets = null


func can_act():
	for p in get_children():
		if p.can_act() : return true
	return stage > 0


func reset(): 
	for p in get_children(): p.reset()


func configure(var my_map, var my_camera):
	tactics_camera = my_camera
	map = my_map
	curr_unit = get_children().front()


func choose_unit():
	map.reset()
	for p in get_children():
		if p.can_act(): curr_unit = p 
	stage = 1


func chase_nearest_enemy():
	map.reset()
	map.link_tiles(curr_unit.get_tile(), curr_unit.jump_height, get_children())
	map.mark_reachable_tiles(curr_unit.get_tile(), curr_unit.move_radious)
	var to = map.get_nearest_neighbor_to_unit(curr_unit, targets.get_children())
	curr_unit.path_stack = map.generate_path_stack(to)
	tactics_camera.target = to
	stage = 2


func move_unit():
	if curr_unit.path_stack.empty(): 
		stage = 3


func choose_unit_to_attack():
	map.reset()
	map.link_tiles(curr_unit.get_tile(), curr_unit.attack_radious)
	map.mark_attackable_tiles(curr_unit.get_tile(), curr_unit.attack_radious)
	attackable_unit = map.get_weakest_unit_to_attack(targets.get_children())
	if attackable_unit: 
		attackable_unit.display_unit_stats(true)
		tactics_camera.target = attackable_unit
	stage = 4 


func attack_unit(var delta):
	if !attackable_unit: curr_unit.can_attack = false
	else:
		if !curr_unit.do_attack(attackable_unit, delta): return
		attackable_unit.display_unit_stats(false)
		tactics_camera.target = curr_unit
	attackable_unit = null
	stage = 0


func act(var delta):
	targets = get_parent().get_node("Player")
	match stage:
		0: choose_unit()
		1: chase_nearest_enemy()
		2: move_unit()
		3: choose_unit_to_attack()
		4: attack_unit(delta)
