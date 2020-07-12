extends AudioStreamPlayer

export(Array, String, FILE) var sfxs : Array

var streams := Array()
var last_hit := OS.get_ticks_msec()

func _ready() -> void:
	for sfx in sfxs:
		streams.append(load(sfx))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and OS.get_ticks_msec() - last_hit > 1000:
		stream = streams[randi() % sfxs.size()]
		pitch_scale = rand_range(.95, 1.15)
		play()
