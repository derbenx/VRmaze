extends Node3D

@export var maze_width: int = 5
@export var maze_height: int = 5
@export var maze_floors: int = 5
@export var cell_size: float = 4.0
@export var wall_thickness: float = 0.2
@export var wall_height: float = 3.0
@export var collisions: bool = true
@export var spheres: bool = true

var floors_data = [] # Array of Dictionaries {grid, solution_path, dead_ends, start_room, end_room}

func _ready():
	randomize()
	generate_multi_floor_maze()
	build_maze()
	place_player()

func generate_multi_floor_maze():
	floors_data = []
	var current_start = Vector2i(1, 1)

	for f in range(maze_floors):
		var data = generate_single_floor(current_start)
		floors_data.append(data)
		# The start of the next floor is the end of this one
		current_start = data.end_room

func generate_single_floor(start_room: Vector2i) -> Dictionary:
	var gsz_x = maze_width * 2 + 1
	var gsz_y = maze_height * 2 + 1

	var grid = []
	for y in range(gsz_y):
		var row = []
		for x in range(gsz_x):
			row.append(1)
		grid.append(row)

	var rooms_to_visit = []
	for tx in range(1, maze_width + 1):
		for ty in range(1, maze_height + 1):
			rooms_to_visit.append(Vector2i(tx, ty))

	var parents = {}
	var current = start_room
	rooms_to_visit.erase(current)
	grid[current.y * 2 - 1][current.x * 2 - 1] = 0

	var x = current.x
	var y = current.y
	var dc = randi() % 4

	while rooms_to_visit.size() > 0:
		var dl = get_unvisited_neighbors(grid, x, y)

		if dl.length() == 0:
			var found = false
			var attempts = 0
			while not found and attempts < 200:
				attempts += 1
				var tmp_room = rooms_to_visit[randi() % rooms_to_visit.size()]
				var visited_neighbor_dir = get_visited_neighbor_dir(grid, tmp_room.x, tmp_room.y)
				if visited_neighbor_dir != -1:
					var px = tmp_room.x
					var py = tmp_room.y
					match visited_neighbor_dir:
						0: py -= 1
						1: px += 1
						2: py += 1
						3: px -= 1
					parents[tmp_room] = Vector2i(px, py)
					x = tmp_room.x
					y = tmp_room.y
					var wx = x * 2 - 1
					var wy = y * 2 - 1
					match visited_neighbor_dir:
						0: grid[wy - 1][wx] = 0
						1: grid[wy][wx + 1] = 0
						2: grid[wy + 1][wx] = 0
						3: grid[wy][wx - 1] = 0
					rooms_to_visit.erase(Vector2i(x, y))
					grid[wy][wx] = 0
					found = true
			if not found: break
		else:
			var preferred_dl = dl
			if preferred_dl.length() > 1:
				if dc == 0: preferred_dl = preferred_dl.replace("2", "")
				elif dc == 1: preferred_dl = preferred_dl.replace("3", "")
				elif dc == 2: preferred_dl = preferred_dl.replace("0", "")
				elif dc == 3: preferred_dl = preferred_dl.replace("1", "")
			var tmp_dir = int(preferred_dl[randi() % preferred_dl.length()])
			var threshold = log(maze_width * maze_height)
			if int(threshold) > 1 and randi() % int(threshold) > 1:
				if dl.contains(str(dc)): pass
				else: dc = tmp_dir
			else: dc = tmp_dir

			var px = x
			var py = y
			match dc:
				0: y -= 1
				1: x += 1
				2: y += 1
				3: x -= 1
			var next_room = Vector2i(x, y)
			parents[next_room] = Vector2i(px, py)
			if dc == 0: grid[py * 2 - 2][px * 2 - 1] = 0
			elif dc == 1: grid[py * 2 - 1][px * 2] = 0
			elif dc == 2: grid[py * 2][px * 2 - 1] = 0
			elif dc == 3: grid[py * 2 - 1][px * 2 - 2] = 0
			rooms_to_visit.erase(next_room)
			grid[y * 2 - 1][x * 2 - 1] = 0

	# End room (opposite corner if start is 1,1)
	var end_room = Vector2i(maze_width, maze_height)
	if start_room == end_room:
		end_room = Vector2i(1, 1) if start_room == Vector2i(maze_width, maze_height) else Vector2i(maze_width, maze_height)

	# Solution Path
	var solution_path = []
	var curr = end_room
	while parents.has(curr):
		solution_path.append(curr)
		curr = parents[curr]
	solution_path.append(curr)

	# Dead Ends
	var dead_ends = []
	for ty in range(1, maze_height + 1):
		for tx in range(1, maze_width + 1):
			var open = 0
			var wx = tx * 2 - 1
			var wy = ty * 2 - 1
			if grid[wy - 1][wx] == 0: open += 1
			if grid[wy][wx + 1] == 0: open += 1
			if grid[wy + 1][wx] == 0: open += 1
			if grid[wy][wx - 1] == 0: open += 1
			if open == 1: dead_ends.append(Vector2i(tx, ty))

	return {
		"grid": grid,
		"solution_path": solution_path,
		"dead_ends": dead_ends,
		"start_room": start_room,
		"end_room": end_room
	}

func get_unvisited_neighbors(grid, rx, ry):
	var res = ""
	# Check north
	if ry > 1 and grid[(ry-1)*2-1][rx*2-1] == 1: res += "0"
	# Check east
	if rx < maze_width and grid[ry*2-1][(rx+1)*2-1] == 1: res += "1"
	# Check south
	if ry < maze_height and grid[(ry+1)*2-1][rx*2-1] == 1: res += "2"
	# Check west
	if rx > 1 and grid[ry*2-1][(rx-1)*2-1] == 1: res += "3"
	return res

func get_visited_neighbor_dir(grid, rx, ry):
	var dirs = [0,1,2,3]
	dirs.shuffle()
	for d in dirs:
		var nx = rx
		var ny = ry
		match d:
			0: ny -= 1
			1: nx += 1
			2: ny += 1
			3: nx -= 1
		if nx >= 1 and nx <= maze_width and ny >= 1 and ny <= maze_height:
			if grid[ny*2-1][nx*2-1] == 0: return d
	return -1

func build_maze():
	for f in range(maze_floors):
		var data = floors_data[f]
		var floor_y = f * wall_height
		build_floor(f, data, floor_y)

func build_floor(f_idx, data, floor_y):
	var grid = data.grid
	var gsz_x = maze_width * 2 + 1
	var gsz_y = maze_height * 2 + 1

	# Floor Plane
	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(maze_width * cell_size, maze_height * cell_size)
	floor_mesh.mesh = plane
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.1 + f_idx*0.1, 0.1, 0.1)
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(maze_width * cell_size / 2.0, floor_y, maze_height * cell_size / 2.0)
	add_child(floor_mesh)

	var static_body = StaticBody3D.new()
	floor_mesh.add_child(static_body)
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(maze_width * cell_size, 0.1, maze_height * cell_size)
	col.shape = box
	col.position.y = -0.05
	static_body.add_child(col)

	# Walls
	for y in range(gsz_y):
		for x in range(gsz_x):
			if grid[y][x] == 1:
				create_wall(x, y, floor_y)

	# Ropes
	if f_idx < maze_floors - 1:
		create_rope(data.end_room, floor_y) # Up

	# Spheres
	if spheres:
		visualize_path(data, floor_y)

func create_wall(gx, gy, floor_y):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(randf(), randf(), randf())
	var wall = MeshInstance3D.new()
	var box = BoxMesh.new()
	var is_v = (gx % 2 == 0 and gy % 2 == 1)
	var is_h = (gx % 2 == 1 and gy % 2 == 0)
	var w = cell_size
	var d = cell_size
	if is_v:
		w = wall_thickness
		d = cell_size - wall_thickness
	elif is_h:
		w = cell_size - wall_thickness
		d = wall_thickness
	else:
		w = wall_thickness
		d = wall_thickness
	box.size = Vector3(w, wall_height, d)
	wall.mesh = box
	wall.material_override = mat
	wall.position = Vector3(gx * cell_size / 2.0, floor_y + wall_height / 2.0, gy * cell_size / 2.0)
	add_child(wall)
	var sb = StaticBody3D.new()
	wall.add_child(sb)
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = box.size
	cs.shape = bs
	sb.add_child(cs)

func create_rope(room, floor_y):
	var rope = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = wall_height
	rope.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.4, 0.2)
	rope.material_override = mat
	rope.position = Vector3(room.x * cell_size - cell_size/2.0, floor_y + wall_height/2.0, room.y * cell_size - cell_size/2.0)
	add_child(rope)
	# Area3D for detection
	var area = Area3D.new()
	area.name = "RopeArea"
	var col = CollisionShape3D.new()
	var cyl_shape = CylinderShape3D.new()
	cyl_shape.radius = 0.5
	cyl_shape.height = wall_height
	col.shape = cyl_shape
	area.add_child(col)
	rope.add_child(area)

func visualize_path(data, floor_y):
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(1, 0, 0)
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	for r in data.solution_path:
		var m = MeshInstance3D.new()
		var s = SphereMesh.new()
		s.radius = 0.2; s.height = 0.4
		m.mesh = s; m.material_override = p_mat
		m.position = Vector3(r.x * cell_size - cell_size/2.0, floor_y + 0.5, r.y * cell_size - cell_size/2.0)
		add_child(m)
	var d_mat = StandardMaterial3D.new()
	d_mat.albedo_color = Color(0, 0, 1)
	d_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	for r in data.dead_ends:
		if r in data.solution_path: continue
		var m = MeshInstance3D.new()
		var s = SphereMesh.new()
		s.radius = 0.2; s.height = 0.4
		m.mesh = s; m.material_override = d_mat
		m.position = Vector3(r.x * cell_size - cell_size/2.0, floor_y + 0.5, r.y * cell_size - cell_size/2.0)
		add_child(m)

func place_player():
	var player = get_node("../Player")
	if player:
		var start = floors_data[0].start_room
		player.position = Vector3(start.x * cell_size - cell_size/2.0, 0, start.y * cell_size - cell_size/2.0)
