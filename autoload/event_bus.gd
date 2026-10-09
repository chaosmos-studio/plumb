extends Node

# Typed signals only: no state, no methods, and no class_name, since the autoload name is the access path.

signal level_started(index: int)
signal level_won(index: int, moves: int, stars: int)
signal settings_changed
signal theme_changed
