extends CharacterBody2D

# --------- VARIABLES ---------- #

@export_category("Player Properties") # You can tweak these changes according to your likings
@export var move_speed : float = 250
@export var dash_speed : float = 450
@export var airdash_duration : float = 300
@export var airdash_cooldown : float = 500 #cant airdash too fast after a jump
@export var jump_force : float = 700
@export var jump_horizontal_momentum : float = 300
@export var gravity : float = 0.5
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
var cantAirdashUntil = 0
var currentState: character_state = character_state.new()

# --------- BUILT-IN FUNCTIONS ---------- #

func _process(_delta):
	updateState(_delta)
	# Calling functions
	movement()
	player_animations()
	flip_player()
	
	_handeInputs()
	
# --------- CUSTOM FUNCTIONS ---------- #

# <-- Player Movement Code -->
func movement():
	# Gravity
	if !is_on_floor() && !currentState.ignoresGravity:
		velocity.y += gravity
	elif is_on_floor():
		jump_count = max_jump_count
	
	handle_jumping()
	
	# Move Player
	if(is_on_floor()):
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
	elif !is_on_floor():
		handleAirdash()

# Player jump
func jump():
	jump_tween()
	AudioManager.jump_sfx.play()
	var inputAxis = Input.get_axis("Left", "Right")
	velocity = Vector2(inputAxis * jump_horizontal_momentum, velocity.y)
	velocity.y = -jump_force
	cantAirdashUntil = Time.get_ticks_msec() + airdash_cooldown

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
	#motionDetection()
	checkHadouken()

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
		
func checkForwardAirdash():
	if(jump_count < 1):
		return
	var one: player_inputs = player_inputs.new()
	one.joystick = 6
	var two: player_inputs = player_inputs.new()
	two.joystick = 5
	var three: player_inputs = player_inputs.new()
	three.joystick = 6
	
	if (detectMotion([one, two, three], 500)):
		setStateAirdash(true)
	elif (detectMotion([one, two, three], 500, true)):
		setStateAirdash(false)

func checkHadouken():
	var now = Time.get_ticks_msec()
	if(now - lastHadoukenTimestamp < hadoukenCooldown):
		return
		
	var two: player_inputs = player_inputs.new()
	two.joystick = 2
	var three: player_inputs = player_inputs.new()
	three.joystick = 3
	var sixA: player_inputs = player_inputs.new()
	sixA.joystick = 6
	sixA.a = true
	
	var sendHadouken = false
	var facingRight = true
	if (detectMotion([two, three, sixA], 1000)):
		sendHadouken = true
	if (detectMotion([two, three, sixA], 1000, true)):
		sendHadouken = true
		facingRight = false
	if sendHadouken:
		print("Hadouken")
		lastHadoukenTimestamp = now
		var projectile = Fireball.instantiate()
		#add_child(projectile)
		projectile.position = position
		projectile.facingRight = facingRight
		if facingRight:
			projectile.position.x += 40
		else:
			projectile.position.x -= 40
		get_tree().current_scene.add_child(projectile)
		

func detectMotion(requiredInputs: Array[player_inputs], maxDelay = 1000, mirror = false):
	#var requiredInputs: Array[player_inputs] = inputSequence
	var validInputIndex = requiredInputs.size() - 1
	var now = Time.get_ticks_msec()
	for inputRaw in inputHistory:
		if(validInputIndex < 0):
			break
		var input: player_inputs = inputRaw
		if(now - input.timeStamp > maxDelay):
			break
		var inputToMatch: player_inputs = requiredInputs[validInputIndex]
		var joystickDir = input.joystick
		if(mirror):
			if(joystickDir == 1):
				joystickDir = 3
			elif(joystickDir == 3):
				joystickDir = 1
			elif(joystickDir == 4):
				joystickDir = 6
			elif(joystickDir == 6):
				joystickDir = 4
			elif(joystickDir == 7):
				joystickDir = 9
			elif(joystickDir == 9):
				joystickDir = 7
		if(inputToMatch.joystick != joystickDir):
			continue
		if(inputToMatch.a && !input.a):
			continue
		if(inputToMatch.b && !input.b):
			continue
		if(inputToMatch.c && !input.c):
			continue
		if(inputToMatch.d && !input.d):
			continue
		validInputIndex -= 1
	return validInputIndex < 0

func setStateIdle():
	currentState = character_state.new()
	
func setStateAirdash(facingRight):
	currentState = character_state.new()
	currentState.endTime = Time.get_ticks_msec() + airdash_duration
	currentState.stateType = character_state.States.Airdash
	currentState.ignoresGravity = true
	currentState.facingRight = facingRight
	jump_count -= 1
	
func handleAirdash():
	if(Time.get_ticks_msec() > cantAirdashUntil):
		checkForwardAirdash()
	if(currentState.stateType == character_state.States.Airdash):
		if(currentState.facingRight):
			velocity = Vector2(dash_speed, 0)
		else:
			velocity = Vector2(dash_speed * -1, 0)

func updateState(delta):
	var now = Time.get_ticks_msec()
	if(currentState.stateType != character_state.States.Idle):
		if(now > currentState.endTime):
			setStateIdle()
			
