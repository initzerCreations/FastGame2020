extends Node2D

onready var player = $Player
onready var exit = $Exit
onready var tilemap = $TileMap
onready var world_generator = $WorldGenerator
var cur_level = 0

var player_looking_at = [0, -1]

var enemies = {}
var doors = {}
var potions = {}
var long_range_guns = {}
var short_range_guns = {}
var keys = {}
var treasure_data = {} # {object: {<loc>:<obj>}, header:string, message:string}
var astar = null
var astar_points_cache = {}

const RIGHT = [1, 0]
const LEFT = [-1, 0]
const UP = [0, -1]
const DOWN = [0, 1]

var keys_held = 0
var object_held = OBJ_RANGED_SHORT
var treasures_found = 0
var dead = false

const OBJ_POTION = "Poción"
const OBJ_RANGED_LONG = "Bazooka"
const OBJ_RANGED_SHORT = "Martillo"

var time_held_move_key = 0.0
const TIME_TO_HOLD_MOVE_KEY_BEFORE_MOVING = 0.2
const MIN_MOVES_PER_TURN = 2
var moves_left = MIN_MOVES_PER_TURN

func _ready():
	randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	world_generator.init(self,  $TileMap, $Player, $Exit)
	generate_new_world()

# for debugging astar grid
#func _draw():
#	for point in astar.get_points():
#		var pos = tilemap.map_to_world(astar.get_point_position(point)) + Vector2.ONE * 8
#		for c in astar.get_point_connections(point):
#			var pos2 = tilemap.map_to_world(astar.get_point_position(c)) + Vector2.ONE * 8
#			draw_line(pos, pos2, Color.green, 1)
#		draw_circle(pos, 4, Color.red)

func generate_new_world():
	dead = false
	moves_left = MIN_MOVES_PER_TURN
	update_collection_info()
	update_steps_info()
	player.get_node("AnimationPlayer").play("walk")
	var world_data = world_generator.generate_world(cur_level, treasures_found)
	enemies = world_data.enemies
	doors = world_data.doors
	potions = world_data.potions
	long_range_guns = world_data.long_range_guns
	short_range_guns = world_data.short_range_guns
	treasure_data = world_data.treasure_data
	keys = world_data.keys
	astar = world_data.astar
	astar_points_cache = world_data.astar_points_cache
	$StartLevelSound.play()

func _process(delta):
	if Input.is_action_just_pressed("exit"):
		get_tree().change_scene("res://MainMenu.tscn")
	if Input.is_action_just_pressed("restart"): 
		restart()
	
	if dead:
		return
	
	var move_dir = [0, 0]
	if Input.is_action_just_pressed("move_up"):
		move_dir = UP
	if Input.is_action_just_pressed("move_down"):
		move_dir = DOWN
	if Input.is_action_just_pressed("move_right"):
		move_dir = RIGHT
	if Input.is_action_just_pressed("move_left"):
		move_dir = LEFT
	
	if Input.is_action_pressed("move_up"):
		time_held_move_key += delta
		if time_held_move_key >= TIME_TO_HOLD_MOVE_KEY_BEFORE_MOVING:
			time_held_move_key = 0.0
			move_dir = UP
	elif Input.is_action_pressed("move_down"):
		time_held_move_key += delta
		if time_held_move_key >= TIME_TO_HOLD_MOVE_KEY_BEFORE_MOVING:
			time_held_move_key = 0.0
			move_dir = DOWN
	elif Input.is_action_pressed("move_right"):
		time_held_move_key += delta
		if time_held_move_key >= TIME_TO_HOLD_MOVE_KEY_BEFORE_MOVING:
			time_held_move_key = 0.0
			move_dir = RIGHT
	elif Input.is_action_pressed("move_left"):
		time_held_move_key += delta
		if time_held_move_key >= TIME_TO_HOLD_MOVE_KEY_BEFORE_MOVING:
			time_held_move_key = 0.0
			move_dir = LEFT
	else:
		time_held_move_key = 0.0
	
	if Input.is_action_just_pressed("use_object") and object_held != null:
		use_object()
	
	if Input.is_action_just_pressed("skip_action"):
		$SkipTurnSound.play()
		$CanvasLayer/TreasureDisplay.hide()
		moves_left = 0
		update_steps_info()
	elif move_dir != [0, 0]:
		$CanvasLayer/TreasureDisplay.hide()
		var moved = move_character(player, move_dir)
		if moved:
			moves_left -= 1
		update_steps_info()
		var player_pos = world_pos_to_map_coord(player.global_position)
		for enemy in enemies.values():
			var enemy_pos = world_pos_to_map_coord(enemy.global_position)
			if !enemy.alerted and enemy.has_line_of_sight(player_pos, enemy_pos, tilemap):
				enemy.alert()
	if moves_left <= 0:
		moves_left = MIN_MOVES_PER_TURN
		update_steps_info()
		var enemies_to_move = []
		for enemy_pos_ind in enemies:
			var enemy = enemies[enemy_pos_ind]
			if enemy.alerted:
				enemies_to_move.append(enemy)
		for enemy in enemies_to_move:
			var enemy_pos = world_pos_to_map_coord(enemy.global_position)
			var player_pos = world_pos_to_map_coord(player.global_position)
			var path = enemy.get_grid_path(enemy_pos, player_pos, astar, astar_points_cache)
			if path.size() > 1:
				if enemy_pos[0] < int(round(path[1].x)):
					move_character(enemy, RIGHT)
				elif enemy_pos[0] > int(round(path[1].x)):
					move_character(enemy, LEFT)
				elif enemy_pos[1] < int(round(path[1].y)):
					move_character(enemy, DOWN)
				elif enemy_pos[1] > int(round(path[1].y)):
					move_character(enemy, UP)

func move_character(character, dir):
	var is_player = character == player
	var coords = world_pos_to_map_coord(character.global_position)
	var old_coords = coords.duplicate()
	coords[0] += dir[0]
	coords[1] += dir[1]
	if is_player:
		player_looking_at = dir
	var moved = false
	if can_move_to_coords(coords, is_player):
		moved = true
		character.global_position = world_generator.map_coord_to_world_pos(coords)
			
		if is_player:
			$FootStepSounds.get_child(randi() % $FootStepSounds.get_child_count()).play()
			player.get_node("AnimationPlayer").stop()
			player.get_node("AnimationPlayer").play("walk")
			character.get_node("Sprite").flip_h = !character.get_node("Sprite").flip_h
			var player_sprite = player.get_node("Sprite")
			player_sprite.frame = (player_sprite.frame + 1) % 2
			var scoords = str(coords)
			if scoords in enemies:
				kill()
			if scoords in keys:
				add_key()
				var key = keys[scoords]
				keys.erase(scoords)
				key.queue_free()
			if scoords in potions:
				add_potion()
				var potion = potions[scoords]
				potions.erase(scoords)
				potion.queue_free()
			if scoords in short_range_guns:
				add_short_range_gun()
				var short_range_gun = short_range_guns[scoords]
				short_range_guns.erase(scoords)
				short_range_gun.queue_free()
			if scoords in long_range_guns:
				add_long_range_gun()
				var long_range_gun = long_range_guns[scoords]
				long_range_guns.erase(scoords)
				long_range_gun.queue_free()
			if treasure_data.size() > 0 and scoords in treasure_data.object_data:
				treasure_data.object_data[scoords].queue_free()
				treasure_data.object_data.erase(scoords)
				$CanvasLayer/TreasureDisplay.show()
				$CanvasLayer/TreasureDisplay/Header.text = treasure_data.header
				$CanvasLayer/TreasureDisplay/Message.text = treasure_data.message
				$CanvasLayer/TreasureDisplay/Portrait.texture = treasure_data.image
				if treasures_found < $TreasureSounds.get_child_count():
					$TreasureSounds.get_child(treasures_found).play()
				treasures_found += 1
				update_collection_info()
			if coords == world_pos_to_map_coord(exit.global_position):
				cur_level += 1
				generate_new_world()
			player.get_node("Camera2D").force_update_scroll()
		else:
			enemies.erase(str(old_coords))
			enemies[str(coords)] = character
			var enemy_sprite = character.get_node("Sprite")
			var player_pos = world_pos_to_map_coord(player.global_position)
			if player_pos[0] > coords[0] and !enemy_sprite.flip_h:
				enemy_sprite.flip_h = true
			if player_pos[0] < coords[0] and enemy_sprite.flip_h:
				enemy_sprite.flip_h = false
			if coords == player_pos:
				kill()
	return moved

func can_move_to_coords(coords, is_player):
	if tilemap.get_cell(coords[0], coords[1]) >= 0:
		return false
	var scoords = str(coords)
	var door_in_way = scoords in doors
	if door_in_way:
		var door = doors[scoords]
		if is_player and keys_held > 0:
			remove_key()
			doors.erase(scoords)
			door.queue_free()
			$DoorUnlockSound.play()
		else:
			return false
	if !is_player and str(coords) in enemies:
		if !enemies[str(coords)].alerted:
			enemies[str(coords)].alert()
		return false
	return true

func add_key():
	keys_held += 1
	update_collection_info()
	$KeyPickupSound.play()

func remove_key():
	keys_held -= 1
	update_collection_info()

func add_potion():
	object_held = OBJ_POTION
	update_collection_info()
	$PotionPickupSound.play()

func add_long_range_gun():
	object_held = OBJ_RANGED_LONG
	update_collection_info()
	$PotionPickupSound.play()

func add_short_range_gun():
	object_held = OBJ_RANGED_SHORT
	update_collection_info()
	$PotionPickupSound.play()

func use_object():
	if object_held == OBJ_POTION:
		moves_left += 3
		$PotionDrinkSound.play()
		player.get_node("AnimationPlayer").play("drink_potion")
	elif object_held == OBJ_RANGED_LONG or object_held == OBJ_RANGED_SHORT:
		moves_left -= 1
		var range_ = 4
		if object_held == OBJ_RANGED_SHORT:
			range_ = 1
		# Kill first enemy in line
		var pl_coords = world_pos_to_map_coord(player.global_position)
		var leftRight = player_looking_at[0] == 0
		for i in range(range_+1):
			var coords = [pl_coords[0] + player_looking_at[0] * i, pl_coords[1] + player_looking_at[1] * i]
			if str(coords) in enemies:
				var enemy = enemies[str(coords)]
				enemy.queue_free()
				enemies.erase(str(coords))
		if range_ > 1:
			$ExplosionSound.play()
			player.get_node("AnimationPlayer").play("shoot_long_gun")
		else:
			$HammerSound.play(1.3)
			player.get_node("AnimationPlayer").play("shoot_short_gun")
	object_held = null
	update_collection_info()
	update_steps_info()

func update_collection_info():
	var new_display_text = ""
	new_display_text += "Nivel: " + str(cur_level + 1) + "\n"
	new_display_text += "Llaves: " + str(keys_held) + "/3\n"
	if object_held == null:
		new_display_text += "Objeto: \n"
	else:
		new_display_text += "Objeto: " + str(object_held) + "\n"
	new_display_text += "Tesoros: " + str(treasures_found) + "/5"
	$CanvasLayer/CollectionInfo.text = new_display_text

func update_steps_info():
	var step_display = $CanvasLayer/StepsItems
	var steps_to_show = clamp(moves_left-1, 0, step_display.get_child_count())
	for child in step_display.get_children():
		child.hide()
	for i in range(steps_to_show):
		step_display.get_child(i).show()

func world_pos_to_map_coord(pos: Vector2):
	var vcoords = tilemap.world_to_map(pos)
	var coords = [int(round(vcoords.x)), int(round(vcoords.y))]
	return coords

func kill():
	dead = true
	player.get_node("AnimationPlayer").play("die")
	$CanvasLayer/KilledRestartMessage.show()
	$DeathSounds.get_child(randi() % $DeathSounds.get_child_count()).play()
	$HitSound.play()

func restart():
	keys_held = 0
	object_held = null
	treasures_found = 0
	$CanvasLayer/KilledRestartMessage.hide()
	#cur_level += 1
	cur_level = 0
	generate_new_world()
