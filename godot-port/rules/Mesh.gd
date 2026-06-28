# Maillage Voronoï — port fidèle de geoVoronoi()/buildAdj()/reach()/hops()/los() du jeu JS.
# La génération consomme le Rng dans le MÊME ordre que le JS → maillage identique à seed égal.
class_name VMesh
extends RefCounted

const Rng = preload("res://rules/Rng.gd")

var cells: Array = []        # {id, poly:Array[Vector2], cx, cy, nb:Array[int], terr:String, elev:int}
var W: float = 0.0
var H: float = 0.0
var walls := {}              # murets : clé d'arête -> true
var wall_seg := {}           # clé d'arête -> [Vector2, Vector2] (segment partagé)
var smoke := {}              # cases enfumées (bloquent la LdV) : id -> tours restants

static func wkey(a: int, b: int) -> String: return "%d-%d" % [min(a, b), max(a, b)]
func wall_between(a: int, b: int) -> bool: return walls.has(wkey(a, b))

# ---- géométrie ----
static func poly_centroid(p: Array) -> Vector2:
	var A := 0.0; var cx := 0.0; var cy := 0.0
	for i in p.size():
		var a: Vector2 = p[i]; var b: Vector2 = p[(i + 1) % p.size()]
		var cr := a.x * b.y - b.x * a.y
		A += cr; cx += (a.x + b.x) * cr; cy += (a.y + b.y) * cr
	A *= 0.5
	if abs(A) < 1e-6:
		var s := Vector2.ZERO
		for v in p: s += v
		return s / p.size()
	return Vector2(cx / (6.0 * A), cy / (6.0 * A))

static func _point_in(poly: Array, x: float, y: float) -> bool:
	var c := false; var j := poly.size() - 1
	for i in poly.size():
		var pi: Vector2 = poly[i]; var pj: Vector2 = poly[j]
		if ((pi.y > y) != (pj.y > y)) and (x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x):
			c = not c
		j = i
	return c

func cell_at(x: float, y: float) -> int:
	for c in cells:
		if _point_in(c.poly, x, y): return c.id
	return -1

# ---- demi-plan de clip (Sutherland-Hodgman vs bissectrice p|q) ----
static func _clip(poly: Array, p: Vector2, q: Vector2) -> Array:
	var m := (p + q) * 0.5
	var n := p - q
	var out: Array = []
	for i in poly.size():
		var a: Vector2 = poly[i]; var b: Vector2 = poly[(i + 1) % poly.size()]
		var ia := (a - m).dot(n) >= 0.0
		var ib := (b - m).dot(n) >= 0.0
		if ia: out.append(a)
		if ia != ib:
			var den := (b - a).dot(n)
			if den != 0.0:
				var tt := (m - a).dot(n) / den
				out.append(a + (b - a) * tt)
	return out

# ---- génération (réplique geoVoronoi : carré/hexa/pentagone + jitter + Voronoï + île) ----
func generate(seed_value: int, w: float, h: float, g: float, dist_pct: float = 28.0) -> void:
	W = w; H = h
	var rng := Rng.new(seed_value)
	var hh := g * 0.866
	var dist := dist_pct / 100.0
	var seeds: Array = []
	var j := -1
	while j * min(g, hh) < H + g:
		var i := -1
		while i * g < W + g:
			var x := i * g; var y := j * g
			var t: String = ["square", "hex", "pentagon"][int(rng.next() * 3.0)]
			var amp := dist * g * 0.42
			if t == "hex":
				x = i * g + (g / 2.0 if (j & 1) else 0.0); y = j * hh
			elif t == "pentagon":
				x = i * g + (g / 2.0 if (j & 1) else 0.0); amp += g * 0.16
			x += (rng.next() * 2.0 - 1.0) * amp
			y += (rng.next() * 2.0 - 1.0) * amp
			if x > -g and x < W + g and y > -g and y < H + g:
				var md2 := (g * 0.5) * (g * 0.5); var ok := true
				for s in seeds:
					var dx: float = s.x - x; var dy: float = s.y - y
					if dx * dx + dy * dy < md2: ok = false; break
				if ok: seeds.append(Vector2(x, y))
			i += 1
		j += 1
	var box := [Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]
	var R := g * 2.8
	var raw: Array = []
	for a in seeds.size():
		var p: Vector2 = seeds[a]; var poly: Array = box
		for k in seeds.size():
			if k == a: continue
			var qq: Vector2 = seeds[k]
			if abs(qq.x - p.x) > R or abs(qq.y - p.y) > R: continue
			poly = _clip(poly, p, qq)
			if poly.size() < 3: break
		if poly.size() >= 3:
			var cl: Array = []
			for v in poly:
				var prev = cl[-1] if cl.size() else null
				if prev == null or (v - prev).length() > 0.8: cl.append(v)
			if cl.size() >= 2 and (cl[0] - cl[-1]).length() < 0.8: cl.pop_back()
			if cl.size() >= 3:
				var rp: Array = []
				for v in cl: rp.append(Vector2(round(v.x), round(v.y)))
				raw.append(rp)
	# effet « île » : on retire les cellules qui touchent le bord
	var eps := 0.6
	cells = []
	for rp in raw:
		var touches := false
		for v in rp:
			if v.x <= eps or v.x >= W - eps or v.y <= eps or v.y >= H - eps: touches = true; break
		if touches: continue
		var ct := poly_centroid(rp)
		cells.append({"id": cells.size(), "poly": rp, "cx": ct.x, "cy": ct.y, "nb": [], "terr": "plain", "elev": 0})
	_build_adj()

# charge une carte AUTHORED (format exportObj de l'éditeur HTML) : cellules + murets.
func load_from_data(cells_data: Array, walls_data: Array) -> void:
	cells = []
	var maxx := 1.0; var maxy := 1.0
	for i in cells_data.size():
		var c = cells_data[i]
		var poly: Array = []
		for p in c.poly:
			var v := Vector2(float(p[0]), float(p[1])); poly.append(v)
			maxx = max(maxx, v.x); maxy = max(maxy, v.y)
		var ct := poly_centroid(poly)
		cells.append({"id":i, "poly":poly, "cx":ct.x, "cy":ct.y, "nb":[],
			"terr":String(c.get("terr", "plain")), "elev":int(c.get("elev", 0))})
	W = maxx; H = maxy
	_build_adj()
	walls = {}
	for k in walls_data: walls[String(k)] = true

func _build_adj() -> void:
	var map := {}
	var seg_of := {}
	for c in cells: c.nb = []
	for c in cells:
		var p: Array = c.poly
		for k in p.size():
			var a: Vector2 = p[k]; var b: Vector2 = p[(k + 1) % p.size()]
			var key := "%d,%d" % [round((a.x + b.x) / 5.0), round((a.y + b.y) / 5.0)]
			if not map.has(key): map[key] = []; seg_of[key] = [a, b]
			map[key].append(c.id)
	wall_seg = {}
	for key in map:
		var arr: Array = map[key]
		for a in arr.size():
			for b in range(a + 1, arr.size()):
				var x: int = arr[a]; var y: int = arr[b]
				if x != y and not cells[x].nb.has(y):
					cells[x].nb.append(y); cells[y].nb.append(x)
					wall_seg[wkey(x, y)] = seg_of[key]

# ---- relief + couvert (proche de genMission) ----
func decorate(seed_value: int, cover: float = 0.30) -> void:
	var rng := Rng.new(seed_value)
	for c in cells: c.terr = "plain"; c.elev = 0
	var nh := 2 + int(rng.next() * 2.0)
	for k in nh:
		var hx := rng.next() * W; var hy := rng.next() * H
		var rad := W * (0.12 + rng.next() * 0.13); var pk := 1 + int(rng.next() * 3.0)
		for c in cells:
			var dd := Vector2(c.cx - hx, c.cy - hy).length()
			if dd < rad: c.elev = min(3, max(c.elev, int(round(pk * (1.0 - dd / rad)))))
	for c in cells:
		if c.elev > 0: continue
		var r := rng.next()
		if r < cover * 0.35: c.terr = "wall"
		elif r < cover: c.terr = "rough"
	# murets sur quelques arêtes (couvert partiel directionnel) — pas entre deux rochers
	walls = {}
	for key in wall_seg:
		var ab: PackedStringArray = key.split("-")
		var x: int = int(ab[0]); var y: int = int(ab[1])
		if cells[x].terr == "wall" or cells[y].terr == "wall": continue
		if rng.next() < 0.15: walls[key] = true

# ---- distorsion progressive (port de distortTerrain/sharedEdge) ----
# Déplace chaque sommet par un bruit DÉTERMINISTE de sa position : deux cellules qui
# partagent un sommet le déplacent à l'identique → arêtes jointes, adjacence conservée.
# La topologie (qui est voisin de qui) est FIGÉE avant la déformation : seule la géométrie change.
func distort(level: float) -> void:
	if level <= 0.0 or cells.is_empty(): return
	var A := level * 9.0
	var keep: Array = []
	for c in cells: keep.append((c.nb as Array).duplicate())
	for c in cells:
		var np: Array = []
		for pt in c.poly:
			var x: float = pt.x; var y: float = pt.y
			var sx := sin(x * 0.045 + y * 0.021) + sin(x * 0.017 - y * 0.039)
			var sy := cos(x * 0.031 - y * 0.05) + cos(x * 0.023 + y * 0.041)
			np.append(Vector2(x + sx * A * 0.5, y + sy * A * 0.5))
		c.poly = np
	for c in cells:
		var ct := poly_centroid(c.poly); c.cx = ct.x; c.cy = ct.y
	for i in cells.size(): cells[i].nb = (keep[i] as Array).duplicate()   # adjacence préservée à l'identique
	# arêtes-murets reconstruites depuis les polygones tordus, restreintes aux vraies paires de voisins
	wall_seg = {}
	for c in cells:
		for j in c.nb:
			if j <= c.id: continue
			var seg := _shared_edge(c, cells[j])
			if seg.size() == 2: wall_seg[wkey(c.id, j)] = seg

# arête de A dont le milieu est le plus proche d'une arête de B (robuste sur maillage tordu)
func _shared_edge(a, b) -> Array:
	var best: Array = []; var bd := 1e30
	var pa: Array = a.poly; var pb: Array = b.poly
	for i in pa.size():
		var a0: Vector2 = pa[i]; var a1: Vector2 = pa[(i + 1) % pa.size()]
		var am := (a0 + a1) * 0.5
		for j in pb.size():
			var b0: Vector2 = pb[j]; var b1: Vector2 = pb[(j + 1) % pb.size()]
			var d := am.distance_to((b0 + b1) * 0.5)
			if d < bd: bd = d; best = [a0, a1]
	return best

# ---- déplacement / vision ----
func passable(id: int) -> bool:
	return id >= 0 and id < cells.size() and cells[id].terr != "wall"

func enter_cost(_a: int, b: int) -> int:
	if not passable(b): return -1
	return 2 if cells[b].terr == "rough" else 1

func hops(a: int, b: int) -> int:
	if a < 0 or b < 0: return 1 << 30
	var seen := {a: 0}; var q := [a]
	while q.size():
		var id: int = q.pop_front()
		if id == b: return seen[id]
		for n in cells[id].nb:
			if passable(n) and not seen.has(n): seen[n] = seen[id] + 1; q.append(n)
	return 1 << 30

func reach(start: int, budget: int, occupied: Dictionary) -> Dictionary:
	var dist := {start: 0}; var pq := [[0, start]]
	while pq.size():
		var bi := 0
		for k in range(1, pq.size()):
			if pq[k][0] < pq[bi][0]: bi = k
		var top: Array = pq.pop_at(bi)
		var d: int = top[0]; var id: int = top[1]
		if d > dist[id]: continue
		for n in cells[id].nb:
			if occupied.has(n): continue
			var c := enter_cost(id, n)
			if c == -1: continue
			var nd := d + c
			if nd <= budget and (not dist.has(n) or nd < dist[n]):
				dist[n] = nd; pq.append([nd, n])
	dist.erase(start)
	return dist

# chemin le moins coûteux start→goal (cases incluses), [] si inatteignable — pour l'aperçu mauve au survol
func path_to(start: int, goal: int, occupied: Dictionary) -> Array:
	if start == goal: return [start]
	var dist := {start: 0}; var prev := {}; var pq := [[0, start]]
	while pq.size():
		var bi := 0
		for k in range(1, pq.size()):
			if pq[k][0] < pq[bi][0]: bi = k
		var top: Array = pq.pop_at(bi)
		var d: int = top[0]; var id: int = top[1]
		if d > dist[id]: continue
		for n in cells[id].nb:
			if n != goal and occupied.has(n): continue   # la case d'arrivée peut être l'objectif
			var c := enter_cost(id, n)
			if c == -1: continue
			var nd := d + c
			if not dist.has(n) or nd < dist[n]:
				dist[n] = nd; prev[n] = id; pq.append([nd, n])
	if not prev.has(goal): return []
	var path := [goal]; var cur: int = goal
	while cur != start:
		cur = prev[cur]; path.push_front(cur)
	return path

func los(a: int, b: int) -> bool:
	var A: Vector2 = Vector2(cells[a].cx, cells[a].cy)
	var B: Vector2 = Vector2(cells[b].cx, cells[b].cy)
	var n := max(2, int(round(A.distance_to(B) / 8.0)))
	for s in range(1, n):
		var t: float = float(s) / n
		var px: float = A.x + (B.x - A.x) * t
		var py: float = A.y + (B.y - A.y) * t
		var id: int = cell_at(px, py)
		if id >= 0 and id != a and id != b and (cells[id].terr == "wall" or smoke.has(id)): return false
	return true
