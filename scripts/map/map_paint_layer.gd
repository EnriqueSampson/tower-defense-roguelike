class_name MapPaintLayer
extends Node2D

## Delegates drawing to a painter callable so WintermaulMap can split static
## terrain from per-frame overlays without extra scene scripts.
var painter := Callable()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
