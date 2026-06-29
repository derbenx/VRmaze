extends Node3D

@export var maze_width: int = 5
@export var maze_height: int = 5
@export var maze_floors: int = 5
@export var cell_size: float = 4.0
@export var wall_thickness: float = 0.2
@export var wall_height: float = 3.0
@export var collisions: bool = true
@export var spheres: bool = false

var floors_data = [] # Array of Dictionaries {grid, solution_path, dead_ends, start_room, end_room}
var marker_container: Node3D
var slab_thickness: float = 0.4
var y_per_floor: float = 3.4

func _ready():
	randomize()
	generate_multi_floor_maze()

	marker_container = Node3D.new()
	marker_container.name = "MarkerContainer"
	marker_container.visible = spheres
	add_child(marker_container)

	build_maze()
	place_player()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H or event.physical_keycode == KEY_H:
			spheres = not spheres
			print("Maze: Toggling spheres. Visible: ", spheres)
			if marker_container:
				marker_container.visible = spheres

		# Fullscreen logic can be problematic in VR embedded windows.
		# If it fails, we simply log it and continue.
		if event.keycode == KEY_ENTER and event.alt_pressed:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func generate_multi_floor_maze():
	floors_data = []
	var current_start = Vector2i(1, 1)
	for f in range(maze_floors):
		var data = generate_single_floor(current_start)
		floors_data.append(data)
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
				var vdir = get_visited_neighbor_dir(grid, tmp_room.x, tmp_room.y)
				if vdir != -1:
					var px = tmp_room.x
					var py = tmp_room.y
					match vdir:
						0: py -= 1
						1: px += 1
						2: py += 1
						3: px -= 1
					parents[tmp_room] = Vector2i(px, py)
					x = tmp_room.x
					y = tmp_room.y
					var wx = x * 2 - 1
					var wy = y * 2 - 1
					match vdir:
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
			var px = x; var py = y
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

	var end_room = Vector2i(maze_width, maze_height)
	if start_room == end_room:
		end_room = Vector2i(1, 1) if start_room == Vector2i(maze_width, maze_height) else Vector2i(maze_width, maze_height)

	var solution_path = []
	var curr = end_room
	while parents.has(curr):
		solution_path.append(curr)
		curr = parents[curr]
	solution_path.append(curr)

	var dead_ends = []
	for ty in range(1, maze_height + 1):
		for tx in range(1, maze_width + 1):
			var open = 0; var wx = tx * 2 - 1; var wy = ty * 2 - 1
			if grid[wy - 1][wx] == 0: open += 1
			if grid[wy][wx + 1] == 0: open += 1
			if grid[wy + 1][wx] == 0: open += 1
			if grid[wy][wx - 1] == 0: open += 1
			if open == 1:
				var room = Vector2i(tx, ty)
				if room != start_room and room != end_room:
					dead_ends.append(room)

	var zones = calculate_dead_end_zones(grid, dead_ends)
	return { "grid": grid, "solution_path": solution_path, "dead_ends": dead_ends, "dead_end_zones": zones, "start_room": start_room, "end_room": end_room }

func calculate_dead_end_zones(grid, dead_ends):
	var zones = {} # Dictionary of { room: zone_id }
	var zone_id_counter = 0

	for de in dead_ends:
		var current_zone = [de]
		var curr = de
		var prev = Vector2i(-1, -1)

		# Trace back up to 5 rooms, but stop if we hit a junction or a turn
		var last_dir = Vector2i(0, 0)
		for i in range(4):
			var next = get_only_open_neighbor(grid, curr, prev)
			if next == Vector2i(-1, -1):
				break

			# Check if it's a junction (more than 2 openings)
			var openings = count_openings(grid, next)
			if openings > 2:
				break

			# Check if we turned
			var current_dir = next - curr
			if last_dir != Vector2i(0, 0) and current_dir != last_dir:
				# We turned, stop tracing
				break

			current_zone.append(next)
			last_dir = current_dir
			prev = curr
			curr = next

		for room in current_zone:
			zones[room] = zone_id_counter
		zone_id_counter += 1

	return zones

func count_openings(grid, room):
	var open = 0; var wx = room.x * 2 - 1; var wy = room.y * 2 - 1
	var rows = grid.size()
	var cols = grid[0].size()
	if wy - 1 >= 0 and grid[wy - 1][wx] == 0: open += 1
	if wx + 1 < cols and grid[wy][wx + 1] == 0: open += 1
	if wy + 1 < rows and grid[wy + 1][wx] == 0: open += 1
	if wx - 1 >= 0 and grid[wy][wx - 1] == 0: open += 1
	return open

func get_only_open_neighbor(grid, room, prev):
	var wx = room.x * 2 - 1; var wy = room.y * 2 - 1
	var neighbors = []
	var rows = grid.size()
	var cols = grid[0].size()
	if wy - 1 >= 0 and grid[wy - 1][wx] == 0: neighbors.append(Vector2i(room.x, room.y - 1))
	if wx + 1 < cols and grid[wy][wx + 1] == 0: neighbors.append(Vector2i(room.x + 1, room.y))
	if wy + 1 < rows and grid[wy + 1][wx] == 0: neighbors.append(Vector2i(room.x, room.y + 1))
	if wx - 1 >= 0 and grid[wy][wx - 1] == 0: neighbors.append(Vector2i(room.x - 1, room.y))

	for n in neighbors:
		if n != prev:
			return n
	return Vector2i(-1, -1)

func get_unvisited_neighbors(grid, rx, ry):
	var res = ""
	if ry > 1 and grid[(ry-2)*2+1][rx*2-1] == 1: res += "0"
	if rx < maze_width and grid[ry*2-1][rx*2+1] == 1: res += "1"
	if ry < maze_height and grid[ry*2+1][rx*2-1] == 1: res += "2"
	if rx > 1 and grid[ry*2-1][(rx-2)*2+1] == 1: res += "3"
	return res

func get_visited_neighbor_dir(grid, rx, ry):
	var dirs = [0,1,2,3]; dirs.shuffle()
	for d in dirs:
		var nx = rx; var ny = ry
		match d:
			0: ny -= 1
			1: nx += 1
			2: ny += 1
			3: nx -= 1
		if nx >= 1 and nx <= maze_width and ny >= 1 and ny <= maze_height:
			if grid[ny*2-1][nx*2-1] == 0: return d
	return -1

func build_maze():
	slab_thickness = wall_thickness * 2.0
	y_per_floor = wall_height + slab_thickness

	for f in range(maze_floors):
		var data = floors_data[f]
		var floor_y_base = f * y_per_floor
		build_floor(f, data, floor_y_base)

func build_floor(f_idx, data, floor_y_base):
	var grid = data.grid
	var gsz_x = maze_width * 2 + 1
	var gsz_y = maze_height * 2 + 1
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(randf(), randf(), randf())

	# Build slab everywhere except at hole
	for gy in range(gsz_y):
		for gx in range(gsz_x):
			var is_start_hole = (f_idx > 0 and Vector2i((gx+1)/2, (gy+1)/2) == data.start_room and gx % 2 == 1 and gy % 2 == 1)

			if not is_start_hole:
				# Floor slab at the very bottom of the floor stack
				create_slab_segment(gx, gy, floor_y_base, mat, true)

			# Ceiling for the very top floor
			if f_idx == maze_floors - 1:
				var is_end_hole = (Vector2i((gx+1)/2, (gy+1)/2) == data.end_room and gx % 2 == 1 and gy % 2 == 1)
				if not is_end_hole:
					# Ceiling slab sits above the walls
					create_slab_segment(gx, gy, floor_y_base + slab_thickness + wall_height, mat, false)

	# Walls sit on top of the floor slab
	var wall_y_start = floor_y_base + slab_thickness
	for y in range(gsz_y):
		for x in range(gsz_x):
			if grid[y][x] == 1:
				create_wall(x, y, wall_y_start)

	# Create rope for all floors including the last one (to the roof)
	create_rope(data.end_room, floor_y_base)

	# Always visualize path so it can be toggled via H key
	visualize_path(data, floor_y_base + slab_thickness)

func create_slab_segment(gx, gy, y_pos, mat, _is_floor):
	var is_room = (gx % 2 == 1 and gy % 2 == 1)
	var is_v = (gx % 2 == 0 and gy % 2 == 1)
	var is_h = (gx % 2 == 1 and gy % 2 == 0)
	var w = cell_size; var d = cell_size

	if is_room:
		w = cell_size - wall_thickness
		d = cell_size - wall_thickness
	elif is_v:
		w = wall_thickness
		d = cell_size - wall_thickness
	elif is_h:
		w = cell_size - wall_thickness
		d = wall_thickness
	else:
		w = wall_thickness
		d = wall_thickness

	# Subtract epsilon to avoid Z-fighting on horizontal seams
	w -= 0.01
	d -= 0.01

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(w, slab_thickness, d)
	mesh.mesh = box
	mesh.material_override = mat
	# Center the slab so its base is exactly at y_pos
	mesh.position = Vector3(gx * cell_size / 2.0, y_pos + slab_thickness/2.0, gy * cell_size / 2.0)
	add_child(mesh)

	if _is_floor:
		var sb = StaticBody3D.new()
		mesh.add_child(sb)
		var cs = CollisionShape3D.new()
		var bs = BoxShape3D.new()
		bs.size = box.size
		cs.shape = bs
		sb.add_child(cs)

func create_wall(gx, gy, y_pos):
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(randf(), randf(), randf())
	var wall = MeshInstance3D.new(); var box = BoxMesh.new()
	var is_v = (gx % 2 == 0 and gy % 2 == 1); var is_h = (gx % 2 == 1 and gy % 2 == 0)
	var w = cell_size; var d = cell_size
	if is_v: w = wall_thickness; d = cell_size - wall_thickness
	elif is_h: w = cell_size - wall_thickness; d = wall_thickness
	else: w = wall_thickness; d = wall_thickness

	# Subtract epsilon
	w -= 0.01
	d -= 0.01

	# Add tiny vertical gap to eliminate vertical Z-fighting with slabs
	box.size = Vector3(w, wall_height - 0.002, d)
	wall.mesh = box; wall.material_override = mat
	# Center the wall so its base is exactly at y_pos + gap
	wall.position = Vector3(gx * cell_size / 2.0, y_pos + wall_height / 2.0 + 0.001, gy * cell_size / 2.0)
	add_child(wall)
	var sb = StaticBody3D.new(); wall.add_child(sb)
	var cs = CollisionShape3D.new(); var bs = BoxShape3D.new()
	bs.size = box.size; cs.shape = bs; sb.add_child(cs)

func create_rope(room, floor_y_base):
	var rope = MeshInstance3D.new(); var cyl = CylinderMesh.new()
	# Rope hangs from the upper floor's ceiling slab, ending 1/4 wall_height above the floor.
	# Total span: slab_thickness + wall_height * 0.75 (within room) + slab_thickness (of floor above)
	# Simplification: Spans from ceiling base down to 0.25 room height.
	var rope_h = wall_height * 0.75 + slab_thickness
	cyl.top_radius = 0.05; cyl.bottom_radius = 0.05; cyl.height = rope_h
	rope.mesh = cyl; var mat = StandardMaterial3D.new(); mat.albedo_color = Color(0.5, 0.4, 0.2)
	rope.material_override = mat
	# Top of rope is at floor_y_base + y_per_floor (base of floor above)
	# Center is at floor_y_base + y_per_floor - rope_h/2.0
	rope.position = Vector3(room.x * cell_size - cell_size/2.0, floor_y_base + y_per_floor - rope_h/2.0, room.y * cell_size - cell_size/2.0)
	add_child(rope)
	var area = Area3D.new(); area.name = "RopeArea"
	var col = CollisionShape3D.new(); var cyl_shape = CylinderShape3D.new()
	cyl_shape.radius = 0.5; cyl_shape.height = rope_h
	col.shape = cyl_shape; area.add_child(col); rope.add_child(area)

func visualize_path(data, floor_y):
	var p_mat = StandardMaterial3D.new(); p_mat.albedo_color = Color(1, 0, 0); p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	for r in data.solution_path:
		var m = MeshInstance3D.new(); var s = SphereMesh.new()
		s.radius = 0.2; s.height = 0.4; m.mesh = s; m.material_override = p_mat
		m.position = Vector3(r.x * cell_size - cell_size/2.0, floor_y + 0.5, r.y * cell_size - cell_size/2.0)
		marker_container.add_child(m)

	var d_mat = StandardMaterial3D.new(); d_mat.albedo_color = Color(0, 0, 1); d_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

	# Visualize all rooms in dead end zones
	var visualized_rooms = []
	if data.has("dead_end_zones"):
		for r in data.dead_end_zones.keys():
			if r in data.solution_path: continue
			visualized_rooms.append(r)
			var m = MeshInstance3D.new(); var s = SphereMesh.new()
			s.radius = 0.2; s.height = 0.4; m.mesh = s; m.material_override = d_mat
			m.position = Vector3(r.x * cell_size - cell_size/2.0, floor_y + 0.5, r.y * cell_size - cell_size/2.0)
			marker_container.add_child(m)

	# Fallback for base dead ends if zones aren't used or somehow missed some
	for r in data.dead_ends:
		if r in data.solution_path or r in visualized_rooms: continue
		var m = MeshInstance3D.new(); var s = SphereMesh.new()
		s.radius = 0.2; s.height = 0.4; m.mesh = s; m.material_override = d_mat
		m.position = Vector3(r.x * cell_size - cell_size/2.0, floor_y + 0.5, r.y * cell_size - cell_size/2.0)
		marker_container.add_child(m)

func place_player():
	var player = get_node_or_null("../Player")
	if player:
		var start = floors_data[0].start_room
		# Feet should be exactly at top of floor slab
		player.position = Vector3(start.x * cell_size - cell_size/2.0, slab_thickness + 0.1, start.y * cell_size - cell_size/2.0)
