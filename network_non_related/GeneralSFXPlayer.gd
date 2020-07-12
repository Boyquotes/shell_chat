extends AudioStreamPlayer

export var windows_boot : AudioStream
export var windows_shutdown : AudioStream
export var msn_received : AudioStream

func play_stream(stream_ : AudioStream, from : float = 0):
	stream = stream_
	play(from)
