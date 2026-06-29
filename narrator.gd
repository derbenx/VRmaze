extends Node3D

@export var llama_url: String = "http://127.0.0.1:8080/completion"
@export var personality: String = "Instruction: You are a narrator for this maze game. It's a simple maze, with empty rooms. You are charmingly sarcastic and irritatingly insulting. You sometimes *try* and be nice but fail at it. Speak directly to the player, keep the words simple, their IQ is low. No stage directions or descriptions. Limit your response to at most 2-3 sentences and try to make each sentence unique. Avoid saying 'oh look'. "
@export var tts_rate: float = 1.15
@export var tts_pitch: float = 1.05
@export var debug: int = 0

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var maze = get_node_or_null("../maze")
@onready var player = get_node_or_null("../Player")

var swear=0
var visited_dead_ends = {} # Dictionary to track {floor_idx: {zone_id: count}}
var last_room = Vector2i(-1, -1)
var last_floor = -1
var last_zone_id = -1

var idle_timer: float = 0.0
var next_heckle_time: float = 0.0
var is_intro_playing: bool = false
var has_found_rope: bool = false
var has_found_down_rope: bool = false
var has_won: bool = false
var floors_congratulated = [] # Array to track floor indices where player was congratulated for finding rope
var start_room_visits = {} # {floor_idx: count}
var has_left_start_room = false

var request_queue = []
var is_requesting = false
var current_request_type = ""

var fallbacks = {
	"welcome": "Welcome to this game, AI server was not found.",
	"rope_up_0": "Use Q to climb the rope.",
	"rope_up_n": "You found the exit rope. Climb up!",
	"rope_down": "You're going backwards. The exit is the other way.",
	"insult": "Dead end. Turn around.",
	"heckle": "Are you still there? You haven't moved in a while.",
	"victory": "Congratulations! You've reached the roof and finished the maze."
}

func _ready():
	if (swear==1):
		personality+= "Swearing like a sailor is acceptable."
	if not http_request:
		http_request = HTTPRequest.new()
		add_child(http_request)

	if http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.disconnect(_on_request_completed)
	http_request.request_completed.connect(_on_request_completed)

	# Give the maze a moment to build before welcoming the player
	get_tree().create_timer(1.0).timeout.connect(trigger_welcome)
	_reset_heckle_timer()

	# Failsafe to ensure intro doesn't block forever
	get_tree().create_timer(5.0).timeout.connect(_on_intro_failsafe)

func _on_intro_failsafe():
	if is_intro_playing:
		print("Narrator: Intro failsafe triggered.")
		is_intro_playing = false

func _reset_heckle_timer():
	# Idle anywhere for 5+ minutes
	next_heckle_time = randf_range(60.0, 120.0)
	idle_timer = 0.0 

func trigger_welcome():
	var prompt = personality + " The player is just starting the game, give an encouraging welcome or advice.\n"
	prompt += "Response:"

	print("Narrator: Requesting welcome message...")
	send_llama_request(prompt, "welcome")

func _process(delta):
	if not maze or not player or maze.floors_data.is_empty():
		return

	if is_intro_playing:
		return

	# DECISION: We use the player's 'eyes' to decide which floor we're on for narration
	var current_floor_idx = int((player.position.y + 1.6) / maze.y_per_floor)

	# Handle state changes
	if current_floor_idx != last_floor:
		last_floor = current_floor_idx
		has_left_start_room = false
		_reset_heckle_timer()
		last_room = Vector2i(-1, -1) # Force room change detection on new floor

	if current_floor_idx < 0 or current_floor_idx >= maze.floors_data.size():
		# Victory check
		if current_floor_idx >= maze.maze_floors and not has_won:
			has_won = true
			trigger_victory()
		return

	var data = maze.floors_data[current_floor_idx]
	var cell_size = maze.cell_size
	# Room center detection (+0.5 logic) flips exactly at halfway point (0-2, 2-4, 4-6...)
	# Maze rooms are centered at 0.5, 1.5, 2.5, 3.5 ... * cell_size
	# To map pos to 1, 2, 3... use int(floor(pos / cell_size)) + 1
	var rx = int(floor(player.position.x / cell_size)) + 1
	var ry = int(floor(player.position.z / cell_size)) + 1
	var current_pos = Vector2i(rx, ry)

	var room_changed = (current_pos != last_room)
	if room_changed:
		last_room = current_pos
		_reset_heckle_timer()
		print("Narrator Debug: Entered Room ", current_pos, " on floor ", current_floor_idx)
		if current_pos != data.start_room:
			has_left_start_room = true

	# Prioritize Rope Interactions
	if player.near_rope:
		if current_pos == data.end_room:
			if current_floor_idx == 0:
				if not has_found_rope:
					has_found_rope = true
					trigger_rope_instruction(current_floor_idx)
			elif not current_floor_idx in floors_congratulated:
				floors_congratulated.append(current_floor_idx)
				trigger_rope_instruction(current_floor_idx)
			return # Exit early if near forward rope
		elif current_pos == data.start_room and current_floor_idx > 0:
			if has_left_start_room: # Only if they returned to it
				if not has_found_down_rope:
					has_found_down_rope = true
					trigger_down_rope_instruction()
				return # Exit early if near backward rope

	# Room Specific Triggers
	if room_changed:
		if current_pos == data.end_room:
			last_zone_id = -1
		elif current_pos == data.start_room:
			if has_left_start_room:
				# Re-entering start room
				if not start_room_visits.has(current_floor_idx):
					start_room_visits[current_floor_idx] = 0
				start_room_visits[current_floor_idx] += 1
				trigger_backtracking_mockery(current_floor_idx)
				has_left_start_room = false # Reset so we don't spam
			last_zone_id = -1
		else:
			# Dead end check
			var zone_id = -1
			if data.has("dead_end_zones") and data.dead_end_zones.has(current_pos):
				zone_id = data.dead_end_zones[current_pos]

			if zone_id != -1 and zone_id != last_zone_id:
				last_zone_id = zone_id
				check_for_dead_end(current_floor_idx, zone_id)
			elif zone_id == -1:
				last_zone_id = -1
	else:
		# Idling
		if not DisplayServer.tts_is_speaking():
			idle_timer += delta
			if idle_timer >= next_heckle_time:
				trigger_heckle(current_floor_idx, current_pos)
				_reset_heckle_timer()
		else:
			idle_timer = 0.0

func check_for_dead_end(floor_idx, zone_id):
	if zone_id != -1:
		if not visited_dead_ends.has(floor_idx):
			visited_dead_ends[floor_idx] = {}

		if not visited_dead_ends[floor_idx].has(zone_id):
			visited_dead_ends[floor_idx][zone_id] = 0

		visited_dead_ends[floor_idx][zone_id] += 1
		var count = visited_dead_ends[floor_idx][zone_id]
		trigger_insult(floor_idx, zone_id, count)

func trigger_heckle(_floor_idx, room):
	var prompt = personality + " The player has been standing still for a some time. Heckle them or ask if they are still alive.\n"
	prompt += "Response:"

	print("Narrator: Heckling player for idleness at ", room, "...")
	send_llama_request(prompt, "heckle")

func trigger_backtracking_mockery(floor_idx: int):
	var prompt = personality + ". The player managed to wander back to the START of the current floor (floor " + str(floor_idx) + "). Mock them for being hopelessly lost.\n"
	prompt += "Response:"

	print("Narrator: Mocking player for backtracking to start of floor ", floor_idx, "...")
	send_llama_request(prompt, "rope_down") # Re-using rope_down fallback for backtracking

func trigger_rope_instruction(floor_idx: int):
	var context = "The player just found a climbing rope leading UP."
	var type = "rope_up_n"
	if floor_idx == 0:
		context = "Tell the player to use 'Q' to climb the rope up to the next floor." + context
		type = "rope_up_0"
	else:
		context += " Congratulate them for finding the way out of this floor."

	var prompt = personality + ". " + context + ".\n"
	prompt += "Response:"

	print("Narrator: Triggering rope UP instruction for floor ", floor_idx, "...")
	send_llama_request(prompt, type)

func trigger_down_rope_instruction():
	var prompt = personality + ". The player just found a climbing rope leading DOWN to the previous floor. Mock them for finding a way to go backwards or for being lost.\n"
	prompt += "Response:"

	print("Narrator: Triggering rope DOWN instruction...")
	send_llama_request(prompt, "rope_down")

func trigger_victory():
	var prompt = personality + ". The player just finished the maze and climbed onto the roof. Provide a sarcastic, annoyed, and witty closing remark.\n"
	prompt += "Response:"

	print("Narrator: Triggering victory message...")
	send_llama_request(prompt, "victory")

func trigger_insult(_floor_idx, zone_id, count):
	var context = "The player just hit a dead end."
	if count > 1:
		context = "The player has returned to the SAME dead end for the " + str(count) + " time! Increase in frustrration as the number grows higher."

	var prompt = personality + ". " + context + ".\n"
	prompt += "Response:"

	print("Narrator: Insulting player for dead end zone ", zone_id, " (Visit count: ", count, ")...")
	send_llama_request(prompt, "insult")

func send_llama_request(prompt: String, type: String):
	request_queue.append({"prompt": prompt, "type": type})
	_process_queue()

func _process_queue():
	if is_requesting or request_queue.is_empty():
		return

	is_requesting = true
	var item = request_queue.pop_front()
	var prompt = item["prompt"]
	current_request_type = item["type"]

	var body = JSON.stringify({
		"prompt": prompt,
		"n_predict": 512,
		"stop": ["Instruction:", "Response:", "</s>"],
		"temperature": 0.9,
		"top_p": 0.9,
	})

	var headers = ["Content-Type: application/json"]
	var err = http_request.request(llama_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Narrator: Failed to send request: ", err)
		if is_intro_playing and current_request_type == "welcome":
			is_intro_playing = false
		_trigger_fallback(current_request_type)
		is_requesting = false
		_process_queue()

func _on_request_completed(_result, response_code, _headers, body):
	is_requesting = false

	# If we were in intro mode, we are definitely done with the intro now regardless of success
	if is_intro_playing:
		is_intro_playing = false

	var body_str = body.get_string_from_utf8()
	if debug == 1:
		print("Narrator Debug: Raw Response Body: ", body_str)

	if response_code == 200:
		var json = JSON.parse_string(body_str)
		if json and json.has("content"):
			var response = json["content"]
			process_response(response)
		else:
			print("Narrator: Unexpected response format: ", body_str)
			_trigger_fallback(current_request_type)
	else:
		print("Narrator: API Error ", response_code, ": ", body_str)
		_trigger_fallback(current_request_type)

	_process_queue()

func _trigger_fallback(type: String):
	if fallbacks.has(type):
		var text = fallbacks[type]
		print("Narrator (Fallback): ", text)
		_speak(text)

func _speak(text: String):
	if text == "": return
	var voices = DisplayServer.tts_get_voices_for_language("en")
	var voice_id = voices[0] if voices.size() > 0 else ""
	DisplayServer.tts_speak(text, voice_id, 50, tts_pitch, tts_rate)

func process_response(text: String):
	if debug == 1:
		print("Narrator Debug: Raw Text: '", text, "'")

	# 1. Strip thought tags
	var filtered_text = text
	var thought_regex = RegEx.new()
	thought_regex.compile("(?s)<thought>.*?</thought>")
	filtered_text = thought_regex.sub(filtered_text, "", true)

	if "<thought>" in filtered_text:
		filtered_text = filtered_text.split("<thought>")[0]

	# 2. Strip stage directions in parentheses or asterisks
	var direction_regex = RegEx.new()
	direction_regex.compile("(?s)\\(.*?\\)|\\*.*?\\*")
	filtered_text = direction_regex.sub(filtered_text, "", true)

	# 3. Final cleanup
	filtered_text = filtered_text.strip_edges()

	if debug == 1:
		print("Narrator Debug: Filtered Text: '", filtered_text, "'")

	if filtered_text == "":
		print("Narrator: (Received empty response content)")
		_trigger_fallback(current_request_type)
		return

	print("Narrator: ", filtered_text)

	# Godot TTS
	_speak(filtered_text)
