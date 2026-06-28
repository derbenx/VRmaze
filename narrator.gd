extends Node3D

@export var llama_url: String = "http://127.0.0.1:8080/completion"
@export var personality: String = "witty, sarcastic, maybe annoyed, insulting"

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var maze = get_node("../maze")
@onready var player = get_node("../Player")

var visited_dead_ends = {} # Dictionary to track {floor_idx: {room: count}}
var last_room = Vector2i(-1, -1)
var last_floor = -1

var idle_timer: float = 0.0
var next_heckle_time: float = 0.0

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
	var prompt = "Instruction: You are a " + personality + " narrator. *try* and be nice, the player is just starting the game, give a welcome of some sort.\n"
	prompt += "Response:"

	print("Narrator: Requesting welcome message...")
	send_llama_request(prompt)

func _process(delta):
	if not maze or not player or maze.floors_data.is_empty():
		return

	var current_floor = int((player.position.y + maze.wall_height / 2.0) / maze.wall_height)
	if current_floor < 0 or current_floor >= maze.floors_data.size():
		return

	var cell_size = maze.cell_size
	var rx = int(floor(player.position.x / cell_size)) + 1
	var ry = int(floor(player.position.z / cell_size)) + 1
	var current_room = Vector2i(rx, ry)

	if current_room != last_room or current_floor != last_floor:
		last_room = current_room
		last_floor = current_floor
		_reset_heckle_timer()
		check_for_dead_end(current_floor, current_room)
	else:
		# Player is staying in the same room
		# Only increment idle timer if narrator isn't currently speaking
		if not DisplayServer.tts_is_speaking():
			var data = maze.floors_data[current_floor]
			if current_room in data.dead_ends:
				idle_timer += delta
				if idle_timer >= next_heckle_time:
					trigger_heckle(current_floor, current_room)
					_reset_heckle_timer()
		else:
			# Reset timer while speaking to ensure dead space starts AFTER speech ends
			idle_timer = 0.0

func check_for_dead_end(floor_idx, room):
	var data = maze.floors_data[floor_idx]
	if room in data.dead_ends:
		if not visited_dead_ends.has(floor_idx):
			visited_dead_ends[floor_idx] = {}

		if not visited_dead_ends[floor_idx].has(room):
			visited_dead_ends[floor_idx][room] = 0

		visited_dead_ends[floor_idx][room] += 1
		var count = visited_dead_ends[floor_idx][room]
		trigger_insult(floor_idx, room, count)

func trigger_heckle(_floor_idx, room):
	var prompt = "Instruction: You are a " + personality + " narrator. The player has been standing still in a dead end for a long time. Heckle them or see if they are still alive.\n"
	prompt += "Response:"

	print("Narrator: Heckling player for idleness at ", room, "...")
	send_llama_request(prompt)

func trigger_insult(_floor_idx, room, count):
	var context = "The player just hit a dead end."
	if count > 1:
		context = "The player has returned to the SAME dead end for the " + str(count) + " time."

	var prompt = "Instruction: You are a " + personality + " narrator. " + context + " Provide a short, mean, and witty insult.\n"
	prompt += "Response:"

	print("Narrator: Insulting player for dead end at ", room, " (Visit count: ", count, ")...")
	send_llama_request(prompt)

func send_llama_request(prompt: String):
	var body = JSON.stringify({
		"prompt": prompt,
		"n_predict": 96,
		"stop": ["Instruction:", "Response:", "</s>"],
		"temperature": 0.9,
		"top_p": 0.9,
	})

	var headers = ["Content-Type: application/json"]
	var err = http_request.request(llama_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Narrator: Failed to send request: ", err)

func _on_request_completed(_result, response_code, _headers, body):
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

func process_response(text: String):
	# 1. Strip thought tags
	var filtered_text = text
	var regex = RegEx.new()
	regex.compile("(?s)<thought>.*?</thought>")
	filtered_text = regex.sub(filtered_text, "", true)

	if "<thought>" in filtered_text:
		filtered_text = filtered_text.split("<thought>")[0]

	# 2. Final cleanup
	filtered_text = filtered_text.strip_edges()

	if filtered_text == "":
		print("Narrator: (Received empty response content)")
		return

	print("Narrator: ", filtered_text)

	# Godot TTS
	var voices = DisplayServer.tts_get_voices_for_language("en")
	var voice_id = voices[0] if voices.size() > 0 else ""
	DisplayServer.tts_speak(filtered_text, voice_id)
