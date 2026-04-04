class_name UnitVisual
extends Node2D
var entity_id: int
var ecs: ECS
var color: Color = Color.CYAN
func _process(_delta: float) -> void:
	if not ecs or not ecs.is_alive(entity_id):
		queue_free()
		return
	if ecs.has_component(entity_id, "Position"):
		var pos: Dictionary = ecs.get_component(entity_id, "Position")
		position = Vector2(pos.x, pos.y)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(-12, -12, 24, 24), color)
	draw_line(Vector2.ZERO, Vector2(0, -16), color.lightened(0.3), 2.0)
