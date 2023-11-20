extends CharacterBody2D

# --------- VARIABLES ---------- #

@export_category("Player Properties") # You can tweak these changes according to your likings
@export var move_speed : float = 400
@export var jump_force : float = 600
@export var gravity : float = 0.3
@export var max_jump_count : int = 2
var jump_count : int = 2

@export_category("Toggle Functions") # Double jump feature is disable by default (Can be toggled from inspector)
@export var double_jump : = false

var is_grounded : bool = false

@onready var player_sprite = $AnimatedSprite2D
@onready var spawn_point = %SpawnPoint
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

var inputHistory = [];

#temporary stuff
var Fireball = preload("res://Scenes/Prefabs/Fireball.tscn")
@onready var throwHand = %Marker2D
var hadoukenCooldown = 2000
var lastHadoukenTimestamp = 0

# --------- BUILT-IN FUNCTIONS ---------- #

func _process(_delta):
	# Calling functions
	movement()
	player_animations()
	flip_player()
	
	_handeInputs()
	
# --------- CUSTOM FUNCTIONS ---------- #

# <-- Player Movement Code -->
func movement():
	# Gravity
	if !is_on_floor():
		velocity.y += gravity
	elif is_on_floor():
		jump_count = max_jump_count
	
	handle_jumping()
	
	# Move Player
	var inputAxis = Input.get_axis("Left", "Right")
	velocity = Vector2(inputAxis * move_speed, velocity.y)
	move_and_slide()

# Handles jumping functionality (double jump or single jump, can be toggled from inspector)
func handle_jumping():
	if Input.is_action_just_pressed("Jump"):
		if is_on_floor() and !double_jump:
			jump()
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

# Player jump
func jump():
	jump_tween()
	AudioManager.jump_sfx.play()
	velocity.y = -jump_force

# Handle Player Animations
func player_animations():
	particle_trails.emitting = false
	
	if is_on_floor():
		if abs(velocity.x) > 0:
			particle_trails.emitting = true
			player_sprite.play("Walk", 1.5)
		else:
			player_sprite.play("Idle")
	else:
		player_sprite.play("Jump")

# Flip player sprite based on X velocity
func flip_player():
	if velocity.x < 0: 
		player_sprite.flip_h = true
	elif velocity.x > 0:
		player_sprite.flip_h = false

# Tween Animations
func death_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tween.finished
	global_position = spawn_point.global_position
	await get_tree().create_timer(0.3).timeout
	AudioManager.respawn_sfx.play()
	respawn_tween()

func respawn_tween():
	var tween = create_tween()
	tween.stop(); tween.play()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15) 

func jump_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

# --------- SIGNALS ---------- #

# Reset the player's position to the current level spawn point if collided with any trap
func _on_collision_body_entered(_body):
	if _body.is_in_group("Traps"):
		AudioManager.death_sfx.play()
		death_particles.emitting = true
		death_tween()


# ------------ input handling --------- #
func _handeInputs():
	_updateInputHistory()
	motionDetection()

func _updateInputHistory():
	#initialize current inputs
	var currentInputs: player_inputs = player_inputs.new()
	currentInputs.a = Input.is_action_pressed("A")
	currentInputs.b = Input.is_action_pressed("B")
	currentInputs.c = Input.is_action_pressed("C")
	currentInputs.d = Input.is_action_pressed("D")
	if(Input.is_action_pressed("Down")):
		if(Input.is_action_pressed("Left")):
			currentInputs.joystick = 1
		elif(Input.is_action_pressed("Right")):
			currentInputs.joystick = 3
		else:
			currentInputs.joystick = 2
	elif(Input.is_action_pressed("Jump")):
		if(Input.is_action_pressed("Left")):
			currentInputs.joystick = 7
		elif(Input.is_action_pressed("Right")):
			currentInputs.joystick = 9
		else:
			currentInputs.joystick = 8
	else:
		if(Input.is_action_pressed("Left")):
			currentInputs.joystick = 4
		elif(Input.is_action_pressed("Right")):
			currentInputs.joystick = 6
		else:
			currentInputs.joystick = 5
	
	#compare with last inputs
	if(inputHistory.size() == 0):
		addInputsToHistory(currentInputs)
	else:
		var lastInputs:player_inputs = inputHistory.front()
		if(currentInputs.a != lastInputs.a ||
			currentInputs.b != lastInputs.b ||
			currentInputs.c != lastInputs.c ||
			currentInputs.d != lastInputs.d ||
			currentInputs.joystick != lastInputs.joystick):
				addInputsToHistory(currentInputs)
	
func addInputsToHistory(inputs: player_inputs):
	inputs.timeStamp = Time.get_ticks_msec()
	inputHistory.push_front(inputs)
	inputHistory.front().printToLog()
	
#--- motion detection ---#
func motionDetection():
	var now = Time.get_ticks_msec()
	if(now - lastHadoukenTimestamp < hadoukenCooldown):
		return
	#gonna start strict and then make them more lenient
	#hadouken first, right facing only, needs 236A
	var two = false
	var three = false
	var six = false
	var buttonA = false
	var currentInput: player_inputs = inputHistory.front()
	if(currentInput.a && currentInput.joystick == 6):
		buttonA = true
		six = true
		for inputRaw in inputHistory:
			var input: player_inputs = inputRaw
			if(now - input.timeStamp > 1000):
				break
			if(input.joystick == 3):
				three = true
			if(input.joystick == 2 && three):
				two = true;
				break;
	
	if(two && three && six && buttonA):
		print("Hadouken")
		lastHadoukenTimestamp = now
		var projectile = Fireball.instantiate()
		#add_child(projectile)
		projectile.position = position
		projectile.position.x += 40
		get_tree().current_scene.add_child(projectile)
