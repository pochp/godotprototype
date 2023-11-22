extends Area2D
var facingRight = true
var speed = 200
# Called when the node enters the scene tree for the first time.
func _ready():
	if !facingRight:
		$Sprite2D.flip_h = true
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var movement = delta * speed
	if !facingRight:
		movement = movement * -1
	position.x += movement
	var areas = get_overlapping_areas()
	for area in areas:
		if(area.is_in_group("enemy")):
			area.die()
			queue_free()
	pass

func _on_body_entered(body):
	if(body.is_in_group("enemy")):
		body.die()
	pass # Replace with function body.
