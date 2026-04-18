extends Control

## Minimap for open world — shows course path, player position, and direction arrow.
## Auto-scales to fit both the player and the course in view.

var waypoints: Array = []
var current_waypoint_idx: int = 0
var player_pos: Vector2 = Vector2.ZERO

func update_state(p_pos: Vector2, wp_idx: int) -> void:
	player_pos = p_pos
	current_waypoint_idx = wp_idx
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0 or waypoints.size() == 0:
		return

	# Background.
	draw_rect(Rect2(0, 0, w, h), Color(0.0, 0.02, 0.06, 0.55))
	draw_rect(Rect2(0, 0, w, h), Color(0.25, 0.45, 0.7, 0.3), false, 1.5)

	# Calculate bounds to fit player + all waypoints with padding.
	var all_points: Array[Vector2] = [player_pos]
	for wp: Vector2 in waypoints:
		all_points.append(wp)
	var min_pt := all_points[0]
	var max_pt := all_points[0]
	for pt: Vector2 in all_points:
		min_pt.x = minf(min_pt.x, pt.x)
		min_pt.y = minf(min_pt.y, pt.y)
		max_pt.x = maxf(max_pt.x, pt.x)
		max_pt.y = maxf(max_pt.y, pt.y)
	# Padding.
	var pad := 15.0
	min_pt -= Vector2(pad, pad)
	max_pt += Vector2(pad, pad)
	# Ensure minimum span so it doesn't zoom in too much.
	var span := max_pt - min_pt
	if span.x < 30.0:
		var cx := (min_pt.x + max_pt.x) * 0.5
		min_pt.x = cx - 15.0
		max_pt.x = cx + 15.0
	if span.y < 20.0:
		var cy := (min_pt.y + max_pt.y) * 0.5
		min_pt.y = cy - 10.0
		max_pt.y = cy + 10.0

	# Draw course line.
	for i in range(waypoints.size() - 1):
		var from := _to_map(waypoints[i], min_pt, max_pt, w, h)
		var to := _to_map(waypoints[i + 1], min_pt, max_pt, w, h)
		var is_past := i < current_waypoint_idx - 1
		var is_active := i >= current_waypoint_idx - 1 and i < current_waypoint_idx
		if is_past:
			draw_line(from, to, Color(0.3, 0.7, 0.3, 0.3), 1.0)
		elif is_active or i == current_waypoint_idx:
			draw_line(from, to, Color(1.0, 0.85, 0.3, 0.6), 1.5)
		else:
			draw_line(from, to, Color(0.5, 0.5, 0.7, 0.3), 1.0)

	# Draw waypoint dots.
	for i in waypoints.size():
		var mp := _to_map(waypoints[i], min_pt, max_pt, w, h)
		if i < current_waypoint_idx:
			draw_circle(mp, 3.0, Color(0.3, 0.8, 0.3, 0.5))
		elif i == current_waypoint_idx:
			var pulse := (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
			draw_circle(mp, 4.0 + pulse * 2.0, Color(1.0, 0.85, 0.3, 0.15))
			draw_circle(mp, 3.5, Color(1.0, 0.85, 0.3, 0.8))
		else:
			draw_circle(mp, 2.5, Color(0.5, 0.5, 0.7, 0.35))

	# Draw player.
	var pp := _to_map(player_pos, min_pt, max_pt, w, h)
	draw_circle(pp, 4.0, Color(0.3, 0.7, 1.0, 0.9))
	draw_circle(pp, 6.5, Color(0.3, 0.7, 1.0, 0.15))

	# Direction arrow to current waypoint (if not yet reached).
	if current_waypoint_idx < waypoints.size():
		var target_map := _to_map(waypoints[current_waypoint_idx], min_pt, max_pt, w, h)
		var dir := (target_map - pp)
		if dir.length() > 12.0:
			var arrow_start := pp + dir.normalized() * 8.0
			var arrow_end := pp + dir.normalized() * minf(dir.length() - 4.0, 18.0)
			draw_line(arrow_start, arrow_end, Color(1.0, 0.85, 0.3, 0.5), 1.5)

	# Labels.
	draw_string(ThemeDB.fallback_font, Vector2(4, 12), "COURSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.7, 1.0, 0.5))
	# Distance to next waypoint.
	if current_waypoint_idx < waypoints.size():
		var dist := player_pos.distance_to(waypoints[current_waypoint_idx])
		var dist_text := "%dm" % int(dist)
		draw_string(ThemeDB.fallback_font, Vector2(w - 40, 12), dist_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color(1.0, 0.85, 0.3, 0.6))

func _to_map(world_pos: Vector2, min_pt: Vector2, max_pt: Vector2, map_w: float, map_h: float) -> Vector2:
	var margin := 8.0
	var uw := map_w - margin * 2.0
	var uh := map_h - margin * 2.0
	var span := max_pt - min_pt
	var nx: float = (world_pos.x - min_pt.x) / maxf(span.x, 1.0)
	var ny: float = 1.0 - (world_pos.y - min_pt.y) / maxf(span.y, 1.0)
	return Vector2(margin + nx * uw, margin + ny * uh)
