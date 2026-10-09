extends RefCounted

const WAIT: float = 0.22
const ROLL: float = 0.42
const SINK: float = 0.2
## Between the three notes, so the drop is heard as a little run rather than one thud.
const NOTE_GAP: float = 0.06
## The seesaw's marbles that the icon's coral, amber and violet ones become.
const SEESAW: Array[int] = [0, 2, 3]

static func play(stage: Control, host: Node) -> float:
	var pours: bool = host.has_method("hold_marbles")
	if pours:
		host.call("hold_marbles", SEESAW)
	Intro.part(stage, "board")
	for k: int in range(3):
		var streak: TextureRect = Intro.part(stage, "trail_%d" % k)
		streak.create_tween().tween_property(streak, "modulate:a", 0.0, ROLL * 0.6).set_delay(WAIT)
		var marble: TextureRect = Intro.part(stage, "marble_%d" % k)
		var from: Vector2 = Intro.centre(stage, "marble_%d" % k)
		var to: Vector2 = Intro.centre(stage, "hole_%d" % k)
		marble.pivot_offset = from
		var t: Tween = marble.create_tween()
		t.tween_interval(WAIT)
		t.tween_property(marble, "position", to - from, ROLL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(marble, "scale", Vector2(0.2, 0.2), SINK).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(marble, "modulate:a", 0.0, SINK).set_ease(Tween.EASE_IN)
		stage.get_tree().create_timer(WAIT + ROLL + NOTE_GAP * k).timeout.connect(func() -> void: Audio.sink(k))
	stage.get_tree().create_timer(WAIT + ROLL).timeout.connect(func() -> void: Audio.buzz(12))
	if pours:
		stage.get_tree().create_timer(WAIT + ROLL + SINK * 0.6).timeout.connect(func() -> void:
			# The player may already have left the title.
			if not is_instance_valid(stage) or not is_instance_valid(host) or not host.is_inside_tree():
				return
			var points: Array[Vector2] = []
			for k: int in range(3):
				points.append(stage.get_global_transform_with_canvas() * Intro.centre(stage, "hole_%d" % k))
			host.call("drop_marbles", SEESAW, points))
	return WAIT + ROLL + SINK
