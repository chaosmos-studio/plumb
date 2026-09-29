extends Node

# Global, typed signals only: no state, no methods, no class_name (the autoload name is the access path).
# Cross-node events go through here instead of node paths up the tree.

signal level_started(index: int)
signal level_won(index: int, moves: int, stars: int)
signal settings_changed
