extends Node

# Global, typed signals only: no state, no methods, no class_name (the autoload name is the access path).
# Cross-node events go through here instead of node paths up the tree. Faceplant's and Stickman's buses
# have the same shape; add signals as the game needs them.

signal game_started
signal game_over(score: int)
signal paused_changed(paused: bool)
