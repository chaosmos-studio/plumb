class_name TiltMove
extends RefCounted

var dir: int = 0
## One entry per step: the marbles that advanced one cell on that step.
var steps: Array[Array] = []
## For each step, the cell each of those marbles landed on, in the same order: the next cell along its
## heading, or a portal's twin.
var cells: Array[PackedInt32Array] = []
## {"step", "marble", "kind", "cell"}, kind one of &"sink", &"pit", &"fill", &"plug", &"paint", &"crack",
## &"portal", &"jump" and &"wrap" (each with "to"), &"bounce", &"key" (with "colour" and "opened") and
## &"shatter". Sinks into ice holes and shatters come once the board has stopped, on the step after the
## last.
var events: Array[Dictionary] = []
## Marbles that moved and are still on the board when the tilt ends: they are the ones that bump.
var stopped: Array[int] = []

## Whether the board stopped with a marble dropped into an ice hole or glass shattered, which counts as a
## move even when nothing rolled.
var settled: bool = false

func changed() -> bool:
	return not steps.is_empty() or settled

func moved(m: int) -> bool:
	for step: Array in steps:
		if step.has(m):
			return true
	return false

func length() -> int:
	return steps.size()
