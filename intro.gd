extends RefCounted

## Plumb's launch flourish (kit Intro): the icon's three marbles roll down their columns together, the way
## one swipe moves every marble at once, and drop into their holes, each on its own note.

const WAIT: float = 0.22
const ROLL: float = 0.42
const SINK: float = 0.2
## Between the three notes, so the drop is heard as a little run rather than one thud.
const NOTE_GAP: float = 0.06

static func play(stage: Control) -> float:
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
	return WAIT + ROLL + SINK + 0.1
