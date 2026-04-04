class_name SelectionBox
extends Node2D

## Drag-to-select rectangle drawn in screen space for the Field Marshal.
## Emits selection_complete with a world-space Rect2 when the drag ends.
##
## Usage: Add as a child of the UI layer (CanvasLayer or Control).
## The camera reference is needed to convert screen coords → world coords.

signal selection_complete(world_rect: Rect2)

## Minimum drag distance (pixels) before we count it as a box select.
const MIN_DRAG_DISTANCE: float = 4.0

var active: bool = false
var start_pos: Vector2  # Screen space
var end_pos: Vector2    # Screen space

## Injected by parent — needed for screen→world conversion.
var camera: CameraController

# ------------------------------------------------------------------
# Input
# ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and active:
		end_pos = event.position
		queue_redraw()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		active = true
		start_pos = event.position
		end_pos = event.position
	else:
		if active:
			active = false
			queue_redraw()
			# Only emit if the drag was large enough to be intentional.
			var drag_dist := start_pos.distance_to(end_pos)
			if drag_dist >= MIN_DRAG_DISTANCE:
				var world_rect := _screen_rect_to_world(
					Rect2(start_pos, end_pos - start_pos).abs()
				)
				selection_complete.emit(world_rect)


# ------------------------------------------------------------------
# Draw
# ------------------------------------------------------------------

func _draw() -> void:
	if not active:
		return
	var rect := Rect2(start_pos, end_pos - start_pos).abs()
	# Semi-transparent green fill.
	draw_rect(rect, Color(0.2, 0.8, 0.2, 0.2))
	# Solid border.
	draw_rect(rect, Color(0.2, 0.8, 0.2, 0.8), false)


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

## Convert a screen-space Rect2 to a world-space Rect2.
## Falls back to a raw screen-space rect if no camera is assigned.
func _screen_rect_to_world(screen_rect: Rect2) -> Rect2:
	if camera == null:
		push_warning("SelectionBox: no camera assigned — returning screen rect as world rect")
		return screen_rect

	var world_tl := camera.screen_to_world(screen_rect.position)
	var world_br := camera.screen_to_world(screen_rect.end)
	return Rect2(world_tl, world_br - world_tl).abs()
