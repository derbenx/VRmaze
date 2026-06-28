extends Node3D

@export var llama_url: String = "http://127.0.0.1:8080/completion"
@export var personality: String = "witty, sarcastic, maybe annoyed, insulting"

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var maze = get_node("../maze")
@onready var player = get_node("../Player")

var visited_dead_ends = {} # Dictionary to track {floor_idx: [Vector2i, ...]}
var last_room = Vector2i(-1, -1)
var last_floor = -1

func _ready():
	if not http_request:
		http_request = HTTPRequest.new()
		add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func _process(_delta):
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
		check_for_dead_end(current_floor, current_room)

func check_for_dead_end(floor_idx, room):
	var data = maze.floors_data[floor_idx]
	if room in data.dead_ends:
		if not visited_dead_ends.has(floor_idx):
			visited_dead_ends[floor_idx] = []

		if not room in visited_dead_ends[floor_idx]:
			visited_dead_ends[floor_idx].append(room)
			trigger_insult(floor_idx, room)

func trigger_insult(_floor_idx, _room):
	var prompt = "System: You are a narrator for a VR maze game. Your personality is " + personality + ". Do not use <thought> tags or perform internal reasoning. Respond immediately and concisely.\n"
	prompt += "User: I just walked into another dead end in this maze. What do you have to say about that?\n"
	prompt += "Assistant: "

	var body = JSON.stringify({
		"prompt": prompt,
		"n_predict": 128,
		"stop": ["\n", "User:", "System:"],
		"temperature": 0.8,
		"include_reasoning": false
	})

	var headers = ["Content-Type: application/json"]
	http_request.request(llama_url, headers, HTTPClient.METHOD_POST, body)

func _on_request_completed(_result, response_code, _headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("content"):
			var response = json["content"].strip_edges()
			process_response(response)
	else:
		print("Error connecting to Llama: ", response_code)

func process_response(text: String):
	# Remove <thought> tags if present
	var filtered_text = text
	while "<thought>" in filtered_text:
		var start_idx = filtered_text.find("<thought>")
		var end_idx = filtered_text.find("</thought>")
		if end_idx != -1:
			filtered_text = filtered_text.erase(start_idx, end_idx - start_idx + 10)
		else:
			# If </thought> is missing, just remove from <thought> to end
			filtered_text = filtered_text.left(start_idx)

	filtered_text = filtered_text.strip_edges()

	print("Narrator: ", filtered_text)

	# Godot TTS
	var voices = DisplayServer.tts_get_voices_for_language("en")
	if voices.size() > 0:
		DisplayServer.tts_speak(filtered_text, voices[0])
	else:
		DisplayServer.tts_speak(filtered_text, "")
