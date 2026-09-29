class_name TiltMove
extends RefCounted

## What one tilt did, in the order the animation needs it: which marbles moved on each step, and when
## each one dropped into a hole or a pit.

var dir: int = 0
## One entry per step: the marbles that advanced one cell on that step.
var steps: Array[Array] = []
## {"step", "marble", "kind" (&"sink" or &"pit"), "cell"}
var events: Array[Dictionary] = []
## Marbles that moved and are still on the board when the tilt ends: they are the ones that bump.
var stopped: Array[int] = []

func changed() -> bool:
	return not steps.is_empty()

func moved(m: int) -> bool:
	for step: Array in steps:
		if step.has(m):
			return true
	return false

func length() -> int:
	return steps.size()
