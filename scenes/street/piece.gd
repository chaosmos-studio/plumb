class_name StreetPiece
extends Node2D

## One painted piece as a node, drawn about its base point at `k` times its near-edge size, so the rewards' moments can
## tween, spin and wobble each piece on its own.

var piece: String
var k: float = 1.0
var tint: Color = Color.WHITE

func _init(name: String = "", scale_k: float = 1.0) -> void:
	piece = name
	k = scale_k

## Its painted size on screen at scale 1.
func extent() -> Vector2:
	return StreetArt.size(piece) * k

## Whether a point in its parent's space is on it.
func hit(at: Vector2) -> bool:
	var local: Vector2 = (at - position) / maxf(scale.y, 0.01)
	var s: Vector2 = extent()
	var a: Vector2 = StreetArt.anchor(piece) * s / StreetArt.rect(piece).size
	return Rect2(-a, s).has_point(local)

func _draw() -> void:
	if piece != "":
		StreetArt.draw(self, piece, Vector2.ZERO, k, tint)
