class_name Glyph
extends RefCounted
## Drawing shared by the HUD and the weave tree, so a weave looks the same wherever
## it appears: a dark disc ringed by one arc per flow in its Power's colour, with
## the same flows crossing inside as loops, the way threads cross in a weave.

const GOLD := Color(0.95, 0.8, 0.45)
const INK := Color(0.04, 0.04, 0.07)
## Brighter than the 3D tints: these sit on dark discs, not in a lit world.
const TINT := {fire = Color(1.0, 0.45, 0.15), earth = Color(0.72, 0.56, 0.26), air = Color(0.75, 0.9, 1.0), water = Color(0.25, 0.55, 1.0), spirit = Color(0.97, 0.95, 1.0)}

static var _serif: Font

## A serif for names and titles; falls back to the engine font where none is installed.
static func serif() -> Font:
	if _serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Cinzel", "EB Garamond", "Libertinus Serif", "Linux Libertine O", "Gentium Book Plus", "DejaVu Serif", "Noto Serif", "Liberation Serif", "serif"])
		f.allow_system_fallback = true
		_serif = f
	return _serif

static func sans() -> Font:
	return ThemeDB.fallback_font

## Text with a dark edge, anchored by `align` (-1 left, 0 centre, 1 right) at `at`.
static func text(ci: CanvasItem, font: Font, at: Vector2, s: String, px: int, col: Color, align := -1) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := at - Vector2(w * 0.5 * (align + 1), 0)
	ci.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(px / 5, 3), Color(0, 0, 0, 0.85 * col.a))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

## One entry per flow, in a fixed order, so the same weave always draws the same.
static func threads(flows: Dictionary) -> Array:
	var out := []
	for e in ["fire", "air", "water", "spirit", "earth"]:
		for i in int(flows.get(e, 0)):
			out.append(e)
	return out

## `bright` 0..1 dims a weave that is not yet yours.
static func weave(ci: CanvasItem, c: Vector2, r: float, flows: Dictionary, bright := 1.0, spin := 0.0) -> void:
	var th := threads(flows)
	var n := th.size()
	ci.draw_circle(c, r, Color(INK, 0.88))
	if n == 0:
		return
	var gap := 0.0 if n == 1 else 0.16
	for i in n:
		var col: Color = TINT[th[i]]
		col = col.lerp(Color(0.3, 0.3, 0.34), 1.0 - bright); col.a = lerpf(0.45, 1.0, bright)
		var a0 := -PI * 0.5 + spin + i * TAU / n
		ci.draw_arc(c, r * 0.9, a0 + gap * 0.5, a0 + TAU / n - gap * 0.5, 24, col, r * 0.14, true)
		# The crossing inside: each flow is a loop leaning out from the centre.
		if n == 1:
			ci.draw_arc(c, r * 0.42, 0, TAU, 28, col, r * 0.1, true)
			ci.draw_circle(c, r * 0.14, col)
		else:
			var mid := a0 + TAU / n * 0.5
			ci.draw_arc(c + Vector2(cos(mid), sin(mid)) * r * 0.26, r * 0.36, 0, TAU, 28, Color(col, col.a * 0.9), r * 0.085, true)

## A weapon on the bar: the same dark disc as a weave, ringed in steel, with the
## outline of its family inside.
static func weapon(ci: CanvasItem, c: Vector2, r: float, family: String, bright := 1.0) -> void:
	var col := Color(0.8, 0.82, 0.88).lerp(Color(0.3, 0.3, 0.34), 1.0 - bright)
	var wood := Color(0.72, 0.52, 0.3).lerp(Color(0.3, 0.3, 0.34), 1.0 - bright)
	ci.draw_circle(c, r, Color(INK, 0.88))
	ci.draw_arc(c, r * 0.9, 0, TAU, 40, Color(col, 0.75), r * 0.07, true)
	# Drawn on a diagonal, hilt bottom-left, point top-right.
	var d := Vector2(0.7, -0.7)
	var n := Vector2(0.7, 0.7)
	var w := r * 0.11
	match family:
		"sword":
			ci.draw_line(c - d * r * 0.62, c - d * r * 0.3, wood, w, true)
			ci.draw_line(c - d * r * 0.3 - n * r * 0.22, c - d * r * 0.3 + n * r * 0.22, col, w, true)
			ci.draw_line(c - d * r * 0.3, c + d * r * 0.66, col, w * 1.25, true)
		"knife":
			ci.draw_line(c - d * r * 0.45, c - d * r * 0.1, wood, w, true)
			ci.draw_line(c - d * r * 0.1, c + d * r * 0.45, col, w * 1.4, true)
		"spear":
			ci.draw_line(c - d * r * 0.7, c + d * r * 0.4, wood, w * 0.8, true)
			ci.draw_colored_polygon(PackedVector2Array([c + d * r * 0.74, c + d * r * 0.36 + n * r * 0.13, c + d * r * 0.36 - n * r * 0.13]), col)
		"staff":
			ci.draw_line(c - d * r * 0.7, c + d * r * 0.7, wood, w, true)
		"axe":
			ci.draw_line(c - d * r * 0.66, c + d * r * 0.5, wood, w * 0.9, true)
			ci.draw_arc(c + d * r * 0.36, r * 0.3, -PI * 0.5 - 0.3, PI * 0.25, 14, col, w * 1.5, true)
		"bow":
			ci.draw_arc(c + n * r * 0.5 - d * 0.0, r * 0.82, PI * 1.05, PI * 1.45, 16, wood, w, true)
			var a := c + n * r * 0.5 + Vector2(cos(PI * 1.05), sin(PI * 1.05)) * r * 0.82
			var b := c + n * r * 0.5 + Vector2(cos(PI * 1.45), sin(PI * 1.45)) * r * 0.82
			ci.draw_line(a, b, Color(col, 0.8), 1.2, true)
			ci.draw_line(c + n * r * 0.1 - d * r * 0.1, c - n * r * 0.55 + d * r * 0.1, col, w * 0.6, true)
		"thrown":
			for k in [-1.0, 0.0, 1.0]:
				ci.draw_line(c + n * r * 0.26 * k - d * r * 0.35, c + n * r * 0.26 * k + d * r * 0.35, col, w, true)
		_:
			# Bare hands.
			ci.draw_circle(c, r * 0.3, wood)
			ci.draw_arc(c, r * 0.3, 0, TAU, 20, col, 1.5, true)

## A bar with slanted ends. `fill` 0..1.
static func bar(ci: CanvasItem, at: Vector2, w: float, h: float, fill: float, col: Color, col2: Color) -> void:
	var sk := h * 0.7
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(sk, 0), at + Vector2(w + sk, 0), at + Vector2(w, h), at + Vector2(0, h)]), Color(INK, 0.75))
	var fw := w * clampf(fill, 0.0, 1.0)
	if fw > 1.0:
		ci.draw_polygon(PackedVector2Array([at + Vector2(sk, 0), at + Vector2(fw + sk, 0), at + Vector2(fw, h), at + Vector2(0, h)]), PackedColorArray([col2, col, col.darkened(0.25), col2.darkened(0.25)]))
	ci.draw_polyline(PackedVector2Array([at + Vector2(sk, 0), at + Vector2(w + sk, 0), at + Vector2(w, h), at + Vector2(0, h), at + Vector2(sk, 0)]), Color(GOLD, 0.55), 1.2, true)

## The one card every panel and notice is drawn on: near-black glass, a thin rule
## of colour, small corners. Content goes in as the card's single child.
static func card(edge := Color(GOLD, 0.35), alpha := 0.86) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.055, 0.055, 0.07, alpha)
	sb.border_color = edge; sb.set_border_width_all(1); sb.set_corner_radius_all(5)
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
