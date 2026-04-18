extends Control

## Fully procedural animated deep space background.
## Multiple star layers at different speeds (parallax), drifting nebula clouds,
## occasional shooting stars, and optional floating debris (rocks + ships).

@export var star_layers: int = 3
@export var stars_per_layer: Array[int] = [40, 70, 140]
@export var layer_speeds: Array[float] = [0.3, 0.7, 1.5]
@export var layer_sizes: Array[float] = [2.8, 1.8, 0.9]
@export var nebula_count: int = 6
@export var shooting_star_chance: float = 0.006
@export var show_debris: bool = false  ## floating rocks + distant ships (menu only)

var _star_layers: Array[Array] = []
var _nebulae: Array[Dictionary] = []
var _shooting_stars: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _ships: Array[Dictionary] = []
var _time: float = 0.0

func _ready() -> void:
	var bg_node := get_node_or_null("BG")
	if bg_node:
		bg_node.visible = false
	_generate_stars()
	_generate_nebulae()
	if show_debris:
		_generate_debris()
		_generate_ships()

func _process(delta: float) -> void:
	_time += delta
	_update_shooting_stars(delta)
	queue_redraw()

# ── Star generation ──

func _generate_stars() -> void:
	_star_layers.clear()
	for layer_idx in star_layers:
		var count: int = stars_per_layer[layer_idx] if layer_idx < stars_per_layer.size() else 60
		var layer: Array[Dictionary] = []
		for i in count:
			layer.append({
				"x": randf(),
				"y": randf(),
				"size": randf_range(0.5, 1.0),
				"phase": randf() * TAU,
				"twinkle_speed": randf_range(0.6, 4.0),
				"brightness": randf_range(0.4, 1.0),
				"color_idx": randi() % 5,
			})
		_star_layers.append(layer)

func _generate_nebulae() -> void:
	_nebulae.clear()
	for i in nebula_count:
		_nebulae.append({
			"cx": randf(),
			"cy": randf(),
			"rx": randf_range(0.12, 0.3),
			"ry": randf_range(0.08, 0.22),
			"color_idx": randi() % 4,
			"drift_speed": randf_range(0.002, 0.008),
			"drift_phase": randf() * TAU,
			"alpha": randf_range(0.03, 0.08),
		})

# ── Debris + ships (menu decoration only) ──

func _generate_debris() -> void:
	_debris.clear()
	for i in 18:
		_debris.append({
			"x": randf_range(-0.1, 1.1),
			"y": randf_range(-0.1, 1.1),
			"speed_x": randf_range(0.005, 0.018) * (1.0 if randf() > 0.5 else -1.0),
			"speed_y": randf_range(0.002, 0.008),
			"radius": randf_range(18.0, 65.0),
			"bumps": randi_range(5, 9),
			"bump_offsets": _random_bump_offsets(randi_range(5, 9)),
			"rotation": randf() * TAU,
			"spin": randf_range(-0.3, 0.3),
			"alpha": randf_range(0.12, 0.35),
			"color_idx": randi() % 3,
			"depth": randf_range(0.4, 1.0),
		})

func _random_bump_offsets(count: int) -> Array[float]:
	var offsets: Array[float] = []
	for i in count:
		offsets.append(randf_range(0.6, 1.0))
	return offsets

func _generate_ships() -> void:
	_ships.clear()
	for i in 8:
		_ships.append({
			"x": randf_range(-0.1, 1.1),
			"y": randf_range(0.1, 0.9),
			"speed_x": randf_range(0.004, 0.014),
			"speed_y": randf_range(-0.002, 0.002),
			"scale": randf_range(1.2, 3.0),
			"alpha": randf_range(0.12, 0.3),
			"type": randi() % 3,  # 0=cruiser, 1=fighter, 2=transport
			"engine_phase": randf() * TAU,
			"facing_right": randf() > 0.4,
		})

# ── Shooting stars ──

func _update_shooting_stars(delta: float) -> void:
	if randf() < shooting_star_chance:
		_shooting_stars.append({
			"x": randf_range(0.1, 0.9),
			"y": randf_range(0.0, 0.5),
			"dx": randf_range(0.4, 0.9),
			"dy": randf_range(0.15, 0.45),
			"life": 0.0,
			"max_life": randf_range(0.4, 0.8),
			"length": randf_range(60.0, 140.0),
			"brightness": randf_range(0.6, 1.0),
		})
	var alive: Array[Dictionary] = []
	for ss in _shooting_stars:
		ss["life"] += delta
		if ss["life"] < ss["max_life"]:
			alive.append(ss)
	_shooting_stars = alive

# ── Drawing ──

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return

	# === DEEP SPACE BASE ===
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.06, 1.0))
	for i in 8:
		var t := float(i) / 8.0
		var y_start := h * t
		var band_h := h / 8.0
		var a := (1.0 - t) * 0.025
		draw_rect(Rect2(0, y_start, w, band_h), Color(0.1, 0.08, 0.2, a))

	# === NEBULA CLOUDS ===
	for neb in _nebulae:
		var cx: float = fmod(neb["cx"] + sin(_time * neb["drift_speed"] + neb["drift_phase"]) * 0.02 + _time * 0.001, 1.0)
		var cy: float = fmod(neb["cy"] + cos(_time * neb["drift_speed"] * 0.7 + neb["drift_phase"]) * 0.015, 1.0)
		var base_alpha: float = neb["alpha"]
		var col := Color.WHITE
		match neb["color_idx"]:
			0: col = Color(0.3, 0.15, 0.5, base_alpha)
			1: col = Color(0.1, 0.2, 0.45, base_alpha)
			2: col = Color(0.4, 0.12, 0.18, base_alpha)
			3: col = Color(0.1, 0.3, 0.25, base_alpha)
		var rx_px: float = neb["rx"] * w
		var ry_px: float = neb["ry"] * h
		for ring in range(12, 0, -1):
			var frac := float(ring) / 12.0
			var ring_alpha := col.a * frac * 0.4
			var ring_col := Color(col.r, col.g, col.b, ring_alpha)
			_draw_ellipse(Vector2(cx * w, cy * h), rx_px * frac, ry_px * frac, ring_col)

	# === FLOATING DEBRIS (rocks) ===
	if show_debris:
		for deb in _debris:
			var depth: float = deb["depth"]
			var dx: float = fmod(deb["x"] + _time * deb["speed_x"] * depth, 1.4) - 0.2
			var dy: float = fmod(deb["y"] + _time * deb["speed_y"] * depth, 1.4) - 0.2
			var rot: float = deb["rotation"] + _time * deb["spin"]
			var r: float = deb["radius"] * depth
			var a: float = deb["alpha"] * depth
			var col := Color.WHITE
			match deb["color_idx"]:
				0: col = Color(0.35, 0.28, 0.2, a)   # brown rock
				1: col = Color(0.3, 0.3, 0.32, a)     # grey rock
				2: col = Color(0.4, 0.32, 0.25, a)    # warm rock
			_draw_rock(Vector2(dx * w, dy * h), r, rot, deb["bumps"], deb["bump_offsets"], col)

	# === STAR LAYERS (parallax) ===
	for layer_idx in _star_layers.size():
		var speed: float = layer_speeds[layer_idx] if layer_idx < layer_speeds.size() else 1.0
		var base_size: float = layer_sizes[layer_idx] if layer_idx < layer_sizes.size() else 1.0
		var layer: Array = _star_layers[layer_idx]
		for star in layer:
			var sx: float = fmod(star["x"] + _time * speed * 0.005, 1.0) * w
			var sy: float = fmod(star["y"] + _time * speed * 0.002, 1.0) * h
			var twinkle: float = (sin(_time * star["twinkle_speed"] + star["phase"]) + 1.0) * 0.5
			var a: float = star["brightness"] * (0.25 + twinkle * 0.75)
			var sz: float = base_size * star["size"] * (0.6 + twinkle * 0.4)
			var col := Color.WHITE
			match star["color_idx"]:
				0: col = Color(1.0, 1.0, 1.0, a)
				1: col = Color(0.65, 0.8, 1.0, a)
				2: col = Color(1.0, 0.88, 0.7, a)
				3: col = Color(0.8, 0.7, 1.0, a)
				4: col = Color(1.0, 0.75, 0.7, a)
			draw_circle(Vector2(sx, sy), sz, col)
			if base_size > 1.5 and star["brightness"] > 0.7:
				draw_circle(Vector2(sx, sy), sz * 3.0, Color(col.r, col.g, col.b, a * 0.12))
			if base_size > 2.0 and star["brightness"] > 0.85 and twinkle > 0.75:
				var fl := sz * 5.0
				var fc := Color(col.r, col.g, col.b, a * 0.25)
				draw_line(Vector2(sx - fl, sy), Vector2(sx + fl, sy), fc, 0.7)
				draw_line(Vector2(sx, sy - fl), Vector2(sx, sy + fl), fc, 0.7)

	# === DISTANT SHIPS ===
	if show_debris:
		for ship in _ships:
			var spd_x: float = ship["speed_x"] * (1.0 if ship["facing_right"] else -1.0)
			var sx: float = fmod(ship["x"] + _time * spd_x, 1.4) - 0.2
			var sy: float = ship["y"] + sin(_time * 0.3 + ship["engine_phase"]) * 0.01
			var sc: float = ship["scale"]
			var a: float = ship["alpha"]
			var engine_pulse: float = (sin(_time * 8.0 + ship["engine_phase"]) + 1.0) * 0.5
			_draw_ship(Vector2(sx * w, sy * h), sc, a, ship["type"], ship["facing_right"], engine_pulse)

	# === SHOOTING STARS ===
	for ss in _shooting_stars:
		var progress: float = ss["life"] / ss["max_life"]
		var fade: float = 1.0 - progress
		var head_x: float = (ss["x"] + ss["dx"] * progress) * w
		var head_y: float = (ss["y"] + ss["dy"] * progress) * h
		var tail_len: float = ss["length"] * fade
		var tail_x: float = head_x - (ss["dx"] / (ss["dx"] + ss["dy"])) * tail_len
		var tail_y: float = head_y - (ss["dy"] / (ss["dx"] + ss["dy"])) * tail_len
		var head_col := Color(1.0, 1.0, 1.0, ss["brightness"] * fade)
		var tail_col := Color(0.6, 0.7, 1.0, 0.0)
		for i in 8:
			var t := float(i) / 8.0
			var px: float = lerpf(head_x, tail_x, t)
			var py: float = lerpf(head_y, tail_y, t)
			var seg_alpha: float = head_col.a * (1.0 - t)
			var seg_width: float = (1.0 - t) * 2.0 + 0.3
			var seg_col := Color(
				lerpf(head_col.r, tail_col.r, t),
				lerpf(head_col.g, tail_col.g, t),
				lerpf(head_col.b, tail_col.b, t),
				seg_alpha
			)
			if i > 0:
				var prev_t := float(i - 1) / 8.0
				var ppx: float = lerpf(head_x, tail_x, prev_t)
				var ppy: float = lerpf(head_y, tail_y, prev_t)
				draw_line(Vector2(ppx, ppy), Vector2(px, py), seg_col, seg_width)
		draw_circle(Vector2(head_x, head_y), 2.0 * fade, head_col)

# ── Shape helpers ──

func _draw_rock(center: Vector2, radius: float, rot: float, bumps: int, offsets: Array, col: Color) -> void:
	if radius < 2.0:
		return
	var points := PackedVector2Array()
	for i in bumps:
		var angle: float = rot + TAU * float(i) / float(bumps)
		var r: float = radius * (offsets[i] if i < offsets.size() else 0.8)
		points.append(Vector2(center.x + cos(angle) * r, center.y + sin(angle) * r))
	if points.size() < 3:
		return

	# Shadow behind rock.
	var shadow_off := Vector2(radius * 0.12, radius * 0.12)
	var shadow_pts := PackedVector2Array()
	for p in points:
		shadow_pts.append(p + shadow_off)
	var shadow_cols := PackedColorArray()
	for i in shadow_pts.size():
		shadow_cols.append(Color(0, 0, 0, col.a * 0.3))
	draw_polygon(shadow_pts, shadow_cols)

	# Base fill.
	var base_cols := PackedColorArray()
	for i in points.size():
		base_cols.append(col)
	draw_polygon(points, base_cols)

	# Inner darker layer for depth — same shape shrunk toward center.
	var inner_pts := PackedVector2Array()
	for p in points:
		inner_pts.append(center + (p - center) * 0.7)
	var dark_col := Color(col.r * 0.65, col.g * 0.65, col.b * 0.65, col.a * 0.6)
	var dark_cols := PackedColorArray()
	for i in inner_pts.size():
		dark_cols.append(dark_col)
	draw_polygon(inner_pts, dark_cols)

	# Highlight edge — lit side (upper-left).
	var highlight_col := Color(col.r * 1.8, col.g * 1.8, col.b * 1.8, col.a * 0.4)
	for i in points.size():
		var next_i := (i + 1) % points.size()
		var mid := (points[i] + points[next_i]) * 0.5
		if mid.y < center.y and mid.x < center.x:
			draw_line(points[i], points[next_i], highlight_col, 1.5)

	# Outline.
	var outline_col := Color(col.r * 1.2, col.g * 1.2, col.b * 1.2, col.a * 0.35)
	for i in points.size():
		var next_i := (i + 1) % points.size()
		draw_line(points[i], points[next_i], outline_col, 1.0)

	# Craters.
	var crater_dark := Color(col.r * 0.4, col.g * 0.4, col.b * 0.4, col.a * 0.5)
	var crater_rim := Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, col.a * 0.25)
	# Large crater.
	var c1 := center + Vector2(radius * 0.2, -radius * 0.15)
	draw_circle(c1, radius * 0.22, crater_dark)
	draw_arc(c1, radius * 0.22, -PI * 0.8, PI * 0.2, 12, crater_rim, 1.0)
	# Small craters.
	var c2 := center + Vector2(-radius * 0.25, radius * 0.2)
	draw_circle(c2, radius * 0.12, crater_dark)
	var c3 := center + Vector2(radius * 0.3, radius * 0.15)
	draw_circle(c3, radius * 0.09, crater_dark)

	# Surface texture dots.
	var speckle_col := Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, col.a * 0.2)
	for i in 6:
		var angle: float = rot + i * 1.1
		var dist: float = radius * 0.3 * (0.5 + fmod(float(i) * 0.7, 1.0))
		var sp := center + Vector2(cos(angle) * dist, sin(angle) * dist)
		draw_circle(sp, 1.0 + radius * 0.02, speckle_col)

func _draw_ship(center: Vector2, sc: float, alpha: float, ship_type: int, facing_right: bool, engine_pulse: float) -> void:
	var dir: float = 1.0 if facing_right else -1.0
	var hull_col := Color(0.3, 0.36, 0.5, alpha)
	var hull_light := Color(0.45, 0.52, 0.68, alpha * 0.8)
	var hull_dark := Color(0.18, 0.22, 0.32, alpha * 0.9)
	var accent_col := Color(0.55, 0.65, 0.85, alpha * 0.6)
	var window_col := Color(0.5, 0.8, 1.0, alpha * 0.7)
	var engine_col := Color(0.3, 0.65, 1.0, alpha * (0.6 + engine_pulse * 0.4))
	var engine_glow := Color(0.4, 0.7, 1.0, alpha * 0.15 * (0.5 + engine_pulse * 0.5))
	var trail_col := Color(0.3, 0.55, 1.0, alpha * 0.08 * (0.3 + engine_pulse * 0.7))

	match ship_type:
		0:  # Cruiser
			# Engine trail.
			for t in 5:
				var tf := float(t) / 5.0
				var tw := (5.0 - tf * 4.0) * sc
				draw_line(
					center + Vector2((-20 - tf * 35) * dir, 0) * sc,
					center + Vector2((-20 - tf * 35 - 6) * dir, 0) * sc,
					Color(trail_col.r, trail_col.g, trail_col.b, trail_col.a * (1.0 - tf)),
					tw
				)
			# Main hull.
			var body := PackedVector2Array([
				center + Vector2(-20 * dir, 0) * sc,
				center + Vector2(-14 * dir, -7) * sc,
				center + Vector2(-4 * dir, -8) * sc,
				center + Vector2(14 * dir, -5) * sc,
				center + Vector2(24 * dir, -1) * sc,
				center + Vector2(24 * dir, 1) * sc,
				center + Vector2(14 * dir, 5) * sc,
				center + Vector2(-4 * dir, 8) * sc,
				center + Vector2(-14 * dir, 7) * sc,
			])
			_draw_poly(body, hull_col)
			# Upper hull highlight.
			var top_hull := PackedVector2Array([
				center + Vector2(-14 * dir, -7) * sc,
				center + Vector2(-4 * dir, -8) * sc,
				center + Vector2(14 * dir, -5) * sc,
				center + Vector2(24 * dir, -1) * sc,
				center + Vector2(14 * dir, -2) * sc,
				center + Vector2(-4 * dir, -3) * sc,
				center + Vector2(-14 * dir, -2) * sc,
			])
			_draw_poly(top_hull, hull_light)
			# Wings.
			var wing_top := PackedVector2Array([
				center + Vector2(-2 * dir, -7) * sc,
				center + Vector2(6 * dir, -14) * sc,
				center + Vector2(12 * dir, -13) * sc,
				center + Vector2(8 * dir, -5) * sc,
			])
			_draw_poly(wing_top, hull_dark)
			var wing_bot := PackedVector2Array([
				center + Vector2(-2 * dir, 7) * sc,
				center + Vector2(6 * dir, 14) * sc,
				center + Vector2(12 * dir, 13) * sc,
				center + Vector2(8 * dir, 5) * sc,
			])
			_draw_poly(wing_bot, hull_dark)
			# Cockpit window.
			draw_circle(center + Vector2(18 * dir, 0) * sc, 2.5 * sc, window_col)
			draw_circle(center + Vector2(18 * dir, 0) * sc, 4.0 * sc, Color(window_col.r, window_col.g, window_col.b, window_col.a * 0.2))
			# Panel lines.
			draw_line(center + Vector2(0 * dir, -6) * sc, center + Vector2(0 * dir, 6) * sc, accent_col, 0.5)
			draw_line(center + Vector2(8 * dir, -4) * sc, center + Vector2(8 * dir, 4) * sc, accent_col, 0.5)
			# Engine glows.
			draw_circle(center + Vector2(-19 * dir, -3) * sc, 3.0 * sc, engine_col)
			draw_circle(center + Vector2(-19 * dir, 3) * sc, 3.0 * sc, engine_col)
			draw_circle(center + Vector2(-19 * dir, 0) * sc, 6.0 * sc, engine_glow)

		1:  # Fighter
			# Engine trail.
			for t in 4:
				var tf := float(t) / 4.0
				draw_line(
					center + Vector2((-11 - tf * 28) * dir, 0) * sc,
					center + Vector2((-11 - tf * 28 - 5) * dir, 0) * sc,
					Color(trail_col.r, trail_col.g, trail_col.b, trail_col.a * (1.0 - tf)),
					(3.5 - tf * 2.5) * sc
				)
			# Main body.
			var body := PackedVector2Array([
				center + Vector2(18 * dir, 0) * sc,
				center + Vector2(8 * dir, -4) * sc,
				center + Vector2(-6 * dir, -3) * sc,
				center + Vector2(-10 * dir, 0) * sc,
				center + Vector2(-6 * dir, 3) * sc,
				center + Vector2(8 * dir, 4) * sc,
			])
			_draw_poly(body, hull_col)
			# Top highlight.
			var top_body := PackedVector2Array([
				center + Vector2(18 * dir, 0) * sc,
				center + Vector2(8 * dir, -4) * sc,
				center + Vector2(-6 * dir, -3) * sc,
				center + Vector2(4 * dir, -1) * sc,
			])
			_draw_poly(top_body, hull_light)
			# Wings — swept back.
			var wing_t := PackedVector2Array([
				center + Vector2(2 * dir, -3) * sc,
				center + Vector2(-4 * dir, -12) * sc,
				center + Vector2(4 * dir, -11) * sc,
				center + Vector2(8 * dir, -4) * sc,
			])
			_draw_poly(wing_t, hull_dark)
			var wing_b := PackedVector2Array([
				center + Vector2(2 * dir, 3) * sc,
				center + Vector2(-4 * dir, 12) * sc,
				center + Vector2(4 * dir, 11) * sc,
				center + Vector2(8 * dir, 4) * sc,
			])
			_draw_poly(wing_b, hull_dark)
			# Wing tip lights.
			draw_circle(center + Vector2(-3 * dir, -12) * sc, 1.2 * sc, Color(1, 0.3, 0.2, alpha * 0.7))
			draw_circle(center + Vector2(-3 * dir, 12) * sc, 1.2 * sc, Color(0.2, 1, 0.3, alpha * 0.7))
			# Cockpit.
			draw_circle(center + Vector2(12 * dir, 0) * sc, 2.0 * sc, window_col)
			# Engine.
			draw_circle(center + Vector2(-9 * dir, 0) * sc, 2.5 * sc, engine_col)
			draw_circle(center + Vector2(-9 * dir, 0) * sc, 5.0 * sc, engine_glow)

		2:  # Transport
			# Engine trail — twin.
			for t in 4:
				var tf := float(t) / 4.0
				for ey in [-4, 4]:
					draw_line(
						center + Vector2((-16 - tf * 25) * dir, ey) * sc,
						center + Vector2((-16 - tf * 25 - 5) * dir, ey) * sc,
						Color(trail_col.r, trail_col.g, trail_col.b, trail_col.a * (1.0 - tf)),
						(3.0 - tf * 2.0) * sc
					)
			# Main hull.
			var body := PackedVector2Array([
				center + Vector2(-15 * dir, -6) * sc,
				center + Vector2(12 * dir, -6) * sc,
				center + Vector2(16 * dir, -3) * sc,
				center + Vector2(16 * dir, 3) * sc,
				center + Vector2(12 * dir, 6) * sc,
				center + Vector2(-15 * dir, 6) * sc,
			])
			_draw_poly(body, hull_col)
			# Top highlight.
			var top_hull := PackedVector2Array([
				center + Vector2(-15 * dir, -6) * sc,
				center + Vector2(12 * dir, -6) * sc,
				center + Vector2(16 * dir, -3) * sc,
				center + Vector2(12 * dir, -2) * sc,
				center + Vector2(-15 * dir, -2) * sc,
			])
			_draw_poly(top_hull, hull_light)
			# Cargo bay panel.
			var cargo := PackedVector2Array([
				center + Vector2(-12 * dir, -4) * sc,
				center + Vector2(4 * dir, -4) * sc,
				center + Vector2(4 * dir, 4) * sc,
				center + Vector2(-12 * dir, 4) * sc,
			])
			_draw_poly(cargo, hull_dark)
			# Windows row.
			for i in 5:
				var wx: float = center.x + (-10 + i * 4) * dir * sc
				draw_circle(Vector2(wx, center.y - 4.5 * sc), 1.2 * sc, window_col)
			# Antenna.
			draw_line(center + Vector2(6 * dir, -6) * sc, center + Vector2(8 * dir, -11) * sc, accent_col, 0.8)
			draw_circle(center + Vector2(8 * dir, -11) * sc, 1.0 * sc, Color(1, 0.3, 0.2, alpha * 0.5))
			# Engines.
			draw_circle(center + Vector2(-14 * dir, -4) * sc, 2.5 * sc, engine_col)
			draw_circle(center + Vector2(-14 * dir, 4) * sc, 2.5 * sc, engine_col)
			draw_circle(center + Vector2(-14 * dir, 0) * sc, 6.0 * sc, engine_glow)

func _draw_poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var cols := PackedColorArray()
	for i in pts.size():
		cols.append(col)
	draw_polygon(pts, cols)

func _draw_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx < 1.0 or ry < 1.0:
		return
	var segments := 24
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(center.x + cos(angle) * rx, center.y + sin(angle) * ry))
	if points.size() >= 3:
		for i in range(1, points.size()):
			var tri := PackedVector2Array([center, points[i - 1], points[i]])
			var tri_cols := PackedColorArray([col, col, col])
			draw_polygon(tri, tri_cols)
