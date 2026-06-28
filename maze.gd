extends Node3D

@export var maze_width: int = 4
@export var maze_height: int = 5
@export var cell_size: float = 4.0
@export var wall_thickness: float = 0.2
@export var wall_height: float = 3.0
@export var collisions: bool = true
@export var spheres: bool = true

var grid = []
var rooms_to_visit = []
var gsz_x: int
var gsz_y: int

var parents = {} # Dictionary to track parent of each room: Vector2i -> Vector2i
var solution_path = [] # Array of Vector2i rooms
var dead_ends = [] # Array of Vector2i rooms

func _ready():
	randomize()
	generate_maze()
	find_solution()
	find_dead_ends()
	build_maze()
	place_player()

func generate_maze():
	gsz_x = maze_width * 2 + 1
	gsz_y = maze_height * 2 + 1

	grid = []
	for y in range(gsz_y):
		var row = []
		for x in range(gsz_x):
			row.append(1) # 1 is wall
		grid.append(row)

	rooms_to_visit = []
	for tx in range(1, maze_width + 1):
		for ty in range(1, maze_height + 1):
			rooms_to_visit.append(Vector2i(tx, ty))

	# Start at (1,1) room
	var current_room = Vector2i(1, 1)
	remove_room(current_room)
	grid[current_room.y * 2 - 1][current_room.x * 2 - 1] = 0

	var x = current_room.x
	var y = current_room.y
	var dc = randi() % 4

	while rooms_to_visit.size() > 0:
		var dl = get_unvisited_neighbors(x, y)

		if dl.length() == 0:
			# Backtrack/Jump
			var found = false
			var attempts = 0
			while not found and attempts < 100:
				attempts += 1
				var tmp_room = rooms_to_visit[randi() % rooms_to_visit.size()]
				var visited_neighbor_dir = get_visited_neighbor_dir(tmp_room.x, tmp_room.y)
				if visited_neighbor_dir != -1:
					var parent_x = tmp_room.x
					var parent_y = tmp_room.y
					match visited_neighbor_dir:
						0: parent_y -= 1
						1: parent_x += 1
						2: parent_y += 1
						3: parent_x -= 1

					parents[tmp_room] = Vector2i(parent_x, parent_y)

					x = tmp_room.x
					y = tmp_room.y
					var wx = x * 2 - 1
					var wy = y * 2 - 1
					match visited_neighbor_dir:
						0: grid[wy - 1][wx] = 0
						1: grid[wy][wx + 1] = 0
						2: grid[wy + 1][wx] = 0
						3: grid[wy][wx - 1] = 0

					remove_room(Vector2i(x, y))
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
				if dl.contains(str(dc)):
					pass
				else:
					dc = tmp_dir
			else:
				dc = tmp_dir

			var px = x
			var py = y
			match dc:
				0: y -= 1
				1: x += 1
				2: y += 1
				3: x -= 1

			var next_room = Vector2i(x, y)
			parents[next_room] = Vector2i(px, py)

			# Break wall
			if dc == 0: grid[py * 2 - 2][px * 2 - 1] = 0
			elif dc == 1: grid[py * 2 - 1][px * 2] = 0
			elif dc == 2: grid[py * 2][px * 2 - 1] = 0
			elif dc == 3: grid[py * 2 - 1][px * 2 - 2] = 0

			remove_room(next_room)
			grid[y * 2 - 1][x * 2 - 1] = 0

func remove_room(room: Vector2i):
	for i in range(rooms_to_visit.size()):
		if rooms_to_visit[i] == room:
			rooms_to_visit.remove_at(i)
			return

func is_visited(rx, ry):
	if rx < 1 or rx > maze_width or ry < 1 or ry > maze_height:
		return true
	return grid[ry * 2 - 1][rx * 2 - 1] == 0

func get_unvisited_neighbors(rx, ry) -> String:
	var res = ""
	if not is_visited(rx, ry - 1): res += "0"
	if not is_visited(rx + 1, ry): res += "1"
	if not is_visited(rx, ry + 1): res += "2"
	if not is_visited(rx - 1, ry): res += "3"
	return res

func get_visited_neighbor_dir(rx, ry) -> int:
	var dirs = [0, 1, 2, 3]
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
			if grid[ny * 2 - 1][nx * 2 - 1] == 0:
				return d
	return -1

func find_solution():
	var start = Vector2i(1, 1)
	var end = Vector2i(maze_width, maze_height)

	solution_path = []
	var current = end

	while parents.has(current):
		solution_path.append(current)
		current = parents[current]

	solution_path.append(current)

func find_dead_ends():
	dead_ends = []
	for ty in range(1, maze_height + 1):
		for tx in range(1, maze_width + 1):
			var open_passages = 0
			var wx = tx * 2 - 1
			var wy = ty * 2 - 1

			# Check neighbors in grid (up, right, down, left)
			if grid[wy - 1][wx] == 0: open_passages += 1
			if grid[wy][wx + 1] == 0: open_passages += 1
			if grid[wy + 1][wx] == 0: open_passages += 1
			if grid[wy][wx - 1] == 0: open_passages += 1

			if open_passages == 1:
				dead_ends.append(Vector2i(tx, ty))

func build_maze():
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.2, 0.2)

	# Floor
	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(maze_width * cell_size, maze_height * cell_size)
	floor_mesh.mesh = plane
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(maze_width * cell_size / 2.0, 0, maze_height * cell_size / 2.0)
	add_child(floor_mesh)

	var static_body = StaticBody3D.new()
	floor_mesh.add_child(static_body)
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(maze_width * cell_size, 0.1, maze_height * cell_size)
	collision_shape.shape = box_shape
	collision_shape.position.y = -0.05
	static_body.add_child(collision_shape)

	# Walls
	for y in range(gsz_y):
		for x in range(gsz_x):
			if grid[y][x] == 1:
				create_wall(x, y)

	# Visualize Path and Dead Ends
	if spheres:
		var path_mat = StandardMaterial3D.new()
		path_mat.albedo_color = Color(1, 0, 0)
		path_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

		for room in solution_path:
			var marker = MeshInstance3D.new()
			var sphere_mesh = SphereMesh.new()
			sphere_mesh.radius = 0.2
			sphere_mesh.height = 0.4
			marker.mesh = sphere_mesh
			marker.material_override = path_mat
			marker.position = Vector3(room.x * cell_size - cell_size/2.0, 0.5, room.y * cell_size - cell_size/2.0)
			add_child(marker)

		var dead_end_mat = StandardMaterial3D.new()
		dead_end_mat.albedo_color = Color(0, 0, 1)
		dead_end_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

		for room in dead_ends:
			# Don't mark if it's already part of the solution path (optional, usually start/end)
			if room in solution_path: continue

			var marker = MeshInstance3D.new()
			var sphere_mesh = SphereMesh.new()
			sphere_mesh.radius = 0.2
			sphere_mesh.height = 0.4
			marker.mesh = sphere_mesh
			marker.material_override = dead_end_mat
			marker.position = Vector3(room.x * cell_size - cell_size/2.0, 0.5, room.y * cell_size - cell_size/2.0)
			add_child(marker)

func create_wall(gx, gy):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(randf(), randf(), randf())

	var wall = MeshInstance3D.new()
	var box = BoxMesh.new()

	var is_v_wall = (gx % 2 == 0 and gy % 2 == 1)
	var is_h_wall = (gx % 2 == 1 and gy % 2 == 0)
	var is_corner = (gx % 2 == 0 and gy % 2 == 0)

	var w_width = cell_size
	var w_depth = cell_size

	if is_v_wall:
		w_width = wall_thickness
		w_depth = cell_size - wall_thickness
	elif is_h_wall:
		w_width = cell_size - wall_thickness
		w_depth = wall_thickness
	elif is_corner:
		w_width = wall_thickness
		w_depth = wall_thickness

	box.size = Vector3(w_width, wall_height, w_depth)
	wall.mesh = box
	wall.material_override = mat

	wall.position = Vector3(gx * cell_size / 2.0, wall_height / 2.0, gy * cell_size / 2.0)
	add_child(wall)

	var static_body = StaticBody3D.new()
	wall.add_child(static_body)
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = box.size
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)

func place_player():
	var player = get_node("../Player")
	if player:
		# Always place at start of solution path (root)
		if solution_path.size() > 0:
			var start_room = solution_path.back()
			player.position = Vector3(start_room.x * cell_size - cell_size/2.0, 0, start_room.y * cell_size - cell_size/2.0)
		else:
			player.position = Vector3(cell_size / 2.0, 0, cell_size / 2.0)
