extends Node3D

@export var llama_url: String = "http://127.0.0.1:8080/completion"
@export var personality: String = "witty, sarcastic, annoyed, insulting"

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var maze = get_node("../maze")
@onready var player = get_node("../Player")

var visited_dead_ends = {} # Dictionary to track {floor_idx: {zone_id: count}}
var last_room = Vector2i(-1, -1)
var last_floor = -1
var last_zone_id = -1

var idle_timer: float = 0.0
var next_heckle_time: float = 0.0
var is_intro_playing: bool = true
var has_found_rope: bool = false
var has_won: bool = false

var request_queue = []
var is_requesting = false

func _ready():
	if not http_request:
		http_request = HTTPRequest.new()
		add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	print("Narrator initialized. Llama URL: ", llama_url)

	# Give the maze a moment to build before welcoming the player
	get_tree().create_timer(1.0).timeout.connect(trigger_welcome)
	_reset_heckle_timer()

func _reset_heckle_timer():
	# Dead space of 2-5 minutes
	next_heckle_time = randf_range(120.0, 300.0)
	idle_timer = 0.0

func trigger_welcome():
	var prompt = "Instruction: You are a " + personality + " narrator. *try* and be nice, the player is just starting the game, give a welcome of some sort. Do not start with 'Oh, look'. Speak directly to the player. No stage directions, sighs, or descriptions in parentheses or asterisks.\n"
	prompt += "Response:"

	print("Narrator: Requesting welcome message...")
	send_llama_request(prompt)

func _process(delta):
	if not maze or not player or maze.floors_data.is_empty():
		return

	if is_intro_playing:
		return

	# Handle rope discovery
	if player.near_rope:
		if not has_found_rope:
			has_found_rope = true
			trigger_rope_instruction()
		return # Prioritize rope and skip dead end insults while near one

	var current_floor = int((player.position.y + maze.wall_height / 2.0) / maze.wall_height)

	# Check for victory (reaching the roof)
	if current_floor >= maze.maze_floors and not has_won:
		has_won = true
		trigger_victory()
		return

	if current_floor < 0 or current_floor >= maze.floors_data.size():
		return

	var cell_size = maze.cell_size
	var rx = int(floor(player.position.x / cell_size)) + 1
	var ry = int(floor(player.position.z / cell_size)) + 1
	var current_room = Vector2i(rx, ry)

	var data = maze.floors_data[current_floor]
	var zone_id = -1
	if data.has("dead_end_zones") and data.dead_end_zones.has(current_room):
		zone_id = data.dead_end_zones[current_room]

	if current_room != last_room or current_floor != last_floor:
		last_room = current_room
		last_floor = current_floor

		# Check if we've entered a new dead end zone
		if zone_id != -1 and zone_id != last_zone_id:
			last_zone_id = zone_id
			_reset_heckle_timer()
			check_for_dead_end(current_floor, zone_id)
		elif zone_id == -1:
			last_zone_id = -1
			_reset_heckle_timer()
	else:
		# Player is staying in the same room
		# Only increment idle timer if narrator isn't currently speaking
		if not DisplayServer.tts_is_speaking():
			if zone_id != -1:
				idle_timer += delta
				if idle_timer >= next_heckle_time:
					trigger_heckle(current_floor, current_room)
					_reset_heckle_timer()
		else:
			# Reset timer while speaking to ensure dead space starts AFTER speech ends
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
	var prompt = "Instruction: You are a " + personality + " narrator. The player has been standing still in a dead end for a long time. Heckle them. Avoid repetitive phrases like 'Oh, look'. Speak directly to the player. No stage directions, sighs, or descriptions in parentheses or asterisks.\n"
	prompt += "Response:"

	print("Narrator: Heckling player for idleness at ", room, "...")
	send_llama_request(prompt)

func trigger_rope_instruction():
	var prompt = "Instruction: You are a " + personality + " narrator. The player just found a climbing rope. Tell them to use 'Q' to climb up to the next floor. Be sarcastic and unique, don't use 'Oh, look'. Speak directly to the player. No stage directions, sighs, or descriptions in parentheses or asterisks.\n"
	prompt += "Response:"

	print("Narrator: Triggering rope instruction...")
	send_llama_request(prompt)

func trigger_victory():
	var prompt = "Instruction: You are a " + personality + " narrator. The player just finished the maze and climbed onto the roof. Provide a sarcastic, annoyed, and witty closing remark. Speak directly to the player. No stage directions.\n"
	prompt += "Response:"

	print("Narrator: Triggering victory message...")
	send_llama_request(prompt)

func trigger_insult(_floor_idx, zone_id, count):
	var context = "The player just hit a dead end."
	if count > 1:
		context = "The player has returned to the SAME dead end for the " + str(count) + " time."

	var prompt = "Instruction: You are a " + personality + " narrator. " + context + " Provide a short, mean, and witty insult. Vary your response, avoid starting with 'Oh, look'. Speak directly to the player. No stage directions, sighs, or descriptions in parentheses or asterisks.\n"
	prompt += "Response:"

	print("Narrator: Insulting player for dead end zone ", zone_id, " (Visit count: ", count, ")...")
	send_llama_request(prompt)

func send_llama_request(prompt: String):
	request_queue.append(prompt)
	_process_queue()

func _process_queue():
	if is_requesting or request_queue.is_empty():
		return

	is_requesting = true
	var prompt = request_queue.pop_front()

	var body = JSON.stringify({
		"prompt": prompt,
		"n_predict": 256,
		"stop": ["Instruction:", "Response:", "</s>"],
		"temperature": 0.9,
		"top_p": 0.9,
	})

	var headers = ["Content-Type: application/json"]
	var err = http_request.request(llama_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Narrator: Failed to send request: ", err)
		is_requesting = false
		_process_queue()

func _on_request_completed(_result, response_code, _headers, body):
	is_requesting = false
	var body_str = body.get_string_from_utf8()
	if response_code == 200:
		var json = JSON.parse_string(body_str)
		if json and json.has("content"):
			var response = json["content"]
			process_response(response)
		else:
			print("Narrator: Unexpected response format: ", body_str)
	else:
		print("Narrator: API Error ", response_code, ": ", body_str)

	_process_queue()

func process_response(text: String):
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

	# 2. Final cleanup
	filtered_text = filtered_text.strip_edges()

	# If we just finished the intro, allow other logic to run
	if is_intro_playing:
		is_intro_playing = false

	if filtered_text == "":
		print("Narrator: (Received empty response content)")
		return

	print("Narrator: ", filtered_text)

	# Godot TTS
	var voices = DisplayServer.tts_get_voices_for_language("en")
	var voice_id = voices[0] if voices.size() > 0 else ""
	DisplayServer.tts_speak(filtered_text, voice_id)
