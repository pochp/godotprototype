class_name character_state
#states in this case refer to either Idle in which you have standard movement
#or specific states which lock you out of most actions
enum States {Idle, Hitstun, Airdash, Attack}

var stateType: States = States.Idle
var endTime = -1
var ignoresGravity = false
var facingRight = true
