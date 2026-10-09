class_name StoreBackend
extends Node

## A Node that lives in the tree while the app runs, since the plugin calls back into it.

signal changed

func buy(_id: String) -> void:
	pass

func restore(_quiet: bool) -> void:
	pass
