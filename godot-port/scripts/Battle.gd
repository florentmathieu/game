extends Node3D
# Tranche combat 3D (vue XCOM, élévation visible). Règles = rules/ (port fidèle).
# Maillage Voronoï extrudé, sphères par équipe (orientées = bec), murets, sélection/déplacement/tir.

const VMesh := preload("res://rules/Mesh.gd")
const Data := preload("res://rules/Data.gd")
const Combat := preload("res://rules/Combat.gd")

const S := 0.06          # px -> unités monde
const STEP := 2.2        # hauteur monde par niveau d'élévation
const AP_MAX := 2

var CL := {}
var mesh: VMesh
var units: Array = []
var sel := -1
var reachable := {}
var turn := "player"
var seen_cells := {}         # cases vues par le joueur (brouillard)
var evisible := {}           # cases vues par les ennemis éveillés
var pod_alerted := {}        # pods déjà réveillés
var _pod_centers = null
var pivot: Node3D
var cam: Camera3D
var hud: Label
var _yaw := 0.6
var _dist := 50.0
var _dragging := false
var _markers: Array = []

func _ready() -> void:
	randomize()
	CL = Data.classes()
	_setup_world()
	_gen_battle(int(Time.get_unix_time_from_system()) & 0x7fffffff)
	_build_tiles()
	_build_walls()
	_spawn_units()
	_setup_camera()
	compute_vis(); detect_enemies()
	_refresh()

# ---------- monde / lumière ----------
func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.05, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.48)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_energy = 1.7; sun.shadow_enabled = true
	add_child(sun)
	hud = Label.new(); hud.position = Vector2(14, 10)
	hud.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	var ci := CanvasLayer.new(); ci.add_child(hud); add_child(ci)

# ---------- génération ----------
func _gen_battle(seed_value: int) -> void:
	mesh = VMesh.new()
	mesh.generate(seed_value, 720.0, 560.0, 50.0, 28.0)
	mesh.decorate(seed_value ^ 0x9e37, 0.30)

func _cell_top(id: int) -> float: return mesh.cells[id].elev * STEP
func world(id: int) -> Vector3:
	var c = mesh.cells[id]
	return Vector3(c.cx * S, _cell_top(id), c.cy * S)

func _tile_color(c) -> Color:
	if c.terr == "wall": return Color(0.46, 0.46, 0.50)
	if c.terr == "rough": return Color(0.46, 0.39, 0.26)
	if c.terr == "cover": return Color(0.30, 0.42, 0.28)
	var e: int = c.elev
	return [Color(0.34,0.30,0.24), Color(0.46,0.39,0.28), Color(0.58,0.48,0.33), Color(0.72,0.58,0.38)][min(e,3)]

func _build_tiles() -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in mesh.cells:
		var col := _tile_color(c)
		var top: float = c.elev * STEP
		var ctr := Vector3(c.cx * S, top, c.cy * S)
		var p: Array = c.poly
		var c2 := Vector2(c.cx, c.cy)
		for k in p.size():
			var a: Vector2 = p[k]; var b: Vector2 = p[(k + 1) % p.size()]
			st.set_normal(Vector3.UP); st.set_color(col); st.add_vertex(ctr)
			st.set_normal(Vector3.UP); st.set_color(col); st.add_vertex(Vector3(b.x * S, top, b.y * S))
			st.set_normal(Vector3.UP); st.set_color(col); st.add_vertex(Vector3(a.x * S, top, a.y * S))
		var side := col.darkened(0.45)
		for k in p.size():
			var a: Vector2 = p[k]; var b: Vector2 = p[(k + 1) % p.size()]
			var midp := (a + b) * 0.5
			var nd := (midp - c2); nd = nd.normalized() if nd.length() > 0.001 else Vector2(1, 0)
			var nrm := Vector3(nd.x, 0, nd.y)
			var ta := Vector3(a.x * S, top, a.y * S); var tb := Vector3(b.x * S, top, b.y * S)
			var ba := Vector3(a.x * S, 0.0, a.y * S); var bb := Vector3(b.x * S, 0.0, b.y * S)
			for v in [ta, bb, tb, ta, ba, bb]:
				st.set_normal(nrm); st.set_color(side); st.add_vertex(v)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true; mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); add_child(mi)

# ---------- murets ----------
func _build_walls() -> void:
	for key in mesh.walls:
		var seg = mesh.wall_seg.get(key)
		if seg == null: continue
		var ab: PackedStringArray = key.split("-")
		var x: int = int(ab[0]); var y: int = int(ab[1])
		var top: float = max(_cell_top(x), _cell_top(y)) + 0.25
		var p0 := Vector2(seg[0].x, seg[0].y) * S; var p1 := Vector2(seg[1].x, seg[1].y) * S
		var midp := (p0 + p1) * 0.5
		var len := p0.distance_to(p1)
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(len, 0.5, 0.12)
		bar.mesh = bm
		var mt := StandardMaterial3D.new(); mt.albedo_color = Color(0.62, 0.5, 0.28); mt.roughness = 0.9
		bar.material_override = mt
		bar.position = Vector3(midp.x, top, midp.y)
		bar.rotation.y = -atan2(p1.y - p0.y, p1.x - p0.x)
		add_child(bar)

# ---------- unités ----------
func _team_color(team: String) -> Color:
	return Data.PLAYER_COL if team == "player" else (Data.ENEMY_COL if team == "enemy" else Data.NEUTRAL_COL)

func _make_unit(team: String, cls: String, cell: int) -> void:
	var d = CL[cls]; var w = d.w
	var wtype := "ranged" if w.has("ranged") else "melee"
	var u := {"team":team, "cls":cls, "cell":cell, "hp":int(d.hp), "max":int(d.hp), "ap":AP_MAX,
		"mob":int(d.mob), "facing":(PI if team == "enemy" else 0.0), "w":w, "wtype":wtype,
		"shieldBlock":int(d.get("shieldBlock", 0)), "parry":int(d.get("parry", 0)), "stealth":d.get("stealth", false),
		"civ":d.get("civ", false), "aimBonus":0, "dmgBonus":0, "rangeBonus":0, "reacted":false, "bracing":false, "wallStance":false,
		"asleep":false, "pod":-1, "home":cell}
	if wtype == "ranged" and w.ranged.has("clip"): u.clip = int(w.ranged.clip); u.ammo = int(w.ranged.clip)
	var node := Node3D.new(); add_child(node)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.6; sm.height = 1.2; ball.mesh = sm
	var mat := StandardMaterial3D.new(); mat.albedo_color = _team_color(team)
	mat.emission_enabled = true; mat.emission = _team_color(team) * 0.32
	ball.material_override = mat; node.add_child(ball)
	# bec = orientation
	var beak := MeshInstance3D.new()
	var bk := BoxMesh.new(); bk.size = Vector3(0.5, 0.18, 0.18); beak.mesh = bk
	beak.material_override = mat; beak.position = Vector3(0.62, 0, 0); node.add_child(beak)
	u.node = node
	units.append(u); _place(u)

func _place(u) -> void:
	u.node.position = world(u.cell) + Vector3(0, 0.85, 0)
	u.node.rotation.y = -float(u.facing)

func _occupied(except_idx := -1) -> Dictionary:
	var o := {}
	for i in units.size():
		if i != except_idx and units[i].hp > 0: o[units[i].cell] = true
	return o

func _spawn_units() -> void:
	var pass_cells := []
	for c in mesh.cells:
		if mesh.passable(c.id): pass_cells.append(c.id)
	pass_cells.sort_custom(func(a, b): return (mesh.cells[a].cx + mesh.cells[a].cy) < (mesh.cells[b].cx + mesh.cells[b].cy))
	var used := {}
	for cls in ["soldat", "archer", "garde", "brute"]:
		for id in pass_cells:
			if used.has(id): continue
			var ok := true
			for k in used: if mesh.hops(k, id) < 2: ok = false; break
			if ok: _make_unit("player", cls, id); used[id] = true; break
	var far := pass_cells.duplicate(); far.reverse()
	var pod := 0
	for cls in ["garde", "archer", "shieldbearer", "brute"]:
		for id in far:
			if used.has(id): continue
			var ok := true
			for k in used: if mesh.hops(k, id) < 4: ok = false; break
			if ok:
				_make_unit("enemy", cls, id); used[id] = true
				units[-1].asleep = true; units[-1].pod = pod; pod += 1
				break

# ---------- vision / brouillard ----------
func compute_vis() -> void:
	seen_cells = {}
	for u in units:
		if u.team == "player" and u.hp > 0:
			for c in mesh.cells:
				if mesh.hops(u.cell, c.id) <= 7 and mesh.los(u.cell, c.id): seen_cells[c.id] = true

func compute_evis() -> void:
	evisible = {}
	for u in units:
		if u.team == "enemy" and u.hp > 0 and not u.asleep:
			for c in mesh.cells:
				if mesh.hops(u.cell, c.id) <= Combat.ENEMY_VIS and mesh.los(u.cell, c.id): evisible[c.id] = true

func enemy_active(e) -> bool: return not e.asleep

# ---------- pods : réveil + patrouille (zones de Voronoï disjointes) ----------
func wake_pod(pid: int) -> void:
	if pod_alerted.has(pid): return
	pod_alerted[pid] = true
	for u in units:
		if u.team == "enemy" and u.pod == pid: u.asleep = false
	_pod_centers = null

func wake_enemy(e) -> void:
	if e.team != "enemy": return
	if e.pod >= 0: wake_pod(e.pod)
	elif e.asleep: e.asleep = false

func detect_enemies() -> void:
	for e in units:
		if e.team == "enemy" and e.hp > 0 and e.asleep:
			for p in units:
				if p.team == "player" and p.hp > 0 and Combat.enemy_sees_p(mesh, e, p): wake_enemy(e); break

func pod_centers() -> Dictionary:
	if _pod_centers != null: return _pod_centers
	var acc := {}
	for u in units:
		if u.team == "enemy" and u.hp > 0 and u.pod >= 0:
			if not acc.has(u.pod): acc[u.pod] = []
			acc[u.pod].append(int(u.get("home", u.cell)))
	_pod_centers = {}
	for k in acc:
		var cs: Array = acc[k]; var best: int = cs[0]; var bs := 1 << 30
		for c in cs:
			var s := 0
			for d in cs: s += mesh.hops(c, d)
			if s < bs: bs = s; best = c
		_pod_centers[k] = best
	return _pod_centers

func pod_owns(e, cell: int) -> bool:
	if e.pod < 0: return true
	var ctr := pod_centers(); if not ctr.has(e.pod): return true
	var myd: int = mesh.hops(cell, ctr[e.pod])
	for k in ctr:
		if k != e.pod and mesh.hops(cell, ctr[k]) < myd: return false
	return true

func patrol_step(e) -> void:
	var leash := 3
	var ball := {}
	var q := [e.home]; ball[e.home] = 0
	while q.size():
		var id: int = q.pop_front()
		if ball[id] >= leash: continue
		for n in mesh.cells[id].nb:
			if mesh.passable(n) and not ball.has(n): ball[n] = ball[id] + 1; q.append(n)
	var occ := _occupied(units.find(e))
	var zone := []
	for id in ball:
		if pod_owns(e, id) and (id == e.cell or not occ.has(id)): zone.append(id)
	if zone.is_empty(): return
	var goal: int = zone[randi() % zone.size()]
	var best := -1; var bd: int = mesh.hops(e.cell, goal)
	for n in mesh.cells[e.cell].nb:
		if not mesh.passable(n) or occ.has(n) or not ball.has(n) or not pod_owns(e, n): continue
		var dd: int = mesh.hops(n, goal)
		if dd < bd: bd = dd; best = n
	if best >= 0:
		e.facing = atan2(mesh.cells[best].cy - mesh.cells[e.cell].cy, mesh.cells[best].cx - mesh.cells[e.cell].cx)
		e.cell = best; _place(e)

# ---------- caméra ----------
func _setup_camera() -> void:
	pivot = Node3D.new(); pivot.position = Vector3(720 * S * 0.5, 0, 560 * S * 0.5); add_child(pivot)
	cam = Camera3D.new(); cam.fov = 46; pivot.add_child(cam); _update_cam()

func _update_cam() -> void:
	if not cam: return
	var pitch := deg_to_rad(52.0)
	cam.position = Vector3(sin(_yaw) * cos(pitch) * _dist, sin(pitch) * _dist, cos(_yaw) * cos(pitch) * _dist)
	cam.look_at(pivot.global_position, Vector3.UP)

# ---------- sélection / combat ----------
func _unit_at(cell: int) -> int:
	for i in units.size():
		if units[i].hp > 0 and units[i].cell == cell: return i
	return -1

func _compute_reach() -> void:
	reachable = {}
	if sel >= 0 and units[sel].ap > 0:
		var r := mesh.reach(units[sel].cell, units[sel].mob, _occupied(sel))
		for cell in r:
			if seen_cells.has(cell): reachable[cell] = r[cell]   # pas de déplacement dans le brouillard

func _can_attack(att, tgt) -> bool:
	if att.wtype == "ranged" and att.has("ammo") and att.ammo <= 0: return false
	return Combat.in_range(mesh, att, tgt, att.wtype)

func _do_attack(ai: int, ti: int) -> void:
	var att = units[ai]; var tgt = units[ti]
	if att.ap <= 0 or not _can_attack(att, tgt): return
	var res := Combat.do_attack(mesh, units, att, tgt, att.wtype)
	var hit_tgt = res.target
	if hit_tgt.team == "enemy" and hit_tgt.hp > 0: wake_enemy(hit_tgt)   # le bruit réveille le pod visé
	if res.dmg > 0: _flash(hit_tgt, str(res.dmg), Color(1, 0.5, 0.4))
	else: _flash(hit_tgt, res.txt, Color(0.85, 0.85, 0.9))
	for u in units:
		if u.hp <= 0 and is_instance_valid(u.node): u.node.visible = false
	_place(att)
	_compute_reach(); _refresh(); _check_end()

func _flash(u, txt: String, col: Color) -> void:
	var l := Label3D.new(); l.text = txt; l.modulate = col; l.font_size = 64
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
	l.position = world(u.cell) + Vector3(0, 2.2, 0); add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", l.position + Vector3(0, 1.5, 0), 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)

# ---------- entrées ----------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT: _dragging = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed: _dist = max(16, _dist - 4); _update_cam()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed: _dist = min(90, _dist + 4); _update_cam()
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed: _click(e.position)
	elif e is InputEventMouseMotion and _dragging:
		_yaw -= e.relative.x * 0.01; _update_cam()
	elif e is InputEventKey and e.pressed and e.keycode == KEY_SPACE:
		_end_turn()

func _pick_cell(screen: Vector2) -> int:
	if not cam: return -1
	var from := cam.project_ray_origin(screen); var dir := cam.project_ray_normal(screen)
	var hit = Plane(Vector3.UP, 0).intersects_ray(from, dir)
	if hit == null: return -1
	return mesh.cell_at(hit.x / S, hit.z / S)

func _click(screen: Vector2) -> void:
	if turn != "player": return
	var cell := _pick_cell(screen)
	if cell < 0: return
	var ui := _unit_at(cell)
	if ui >= 0 and units[ui].team == "player":
		sel = ui; _compute_reach(); _refresh(); return
	if sel >= 0:
		var u = units[sel]
		if ui >= 0 and units[ui].team == "enemy":
			if _can_attack(u, units[ui]): _do_attack(sel, ui)
			return
		if reachable.has(cell) and u.ap > 0:
			u.ap -= 1; u.facing = atan2(mesh.cells[cell].cy - mesh.cells[u.cell].cy, mesh.cells[cell].cx - mesh.cells[u.cell].cx)
			u.cell = cell; _place(u); detect_enemies(); _compute_reach(); _refresh()

# ---------- tours ----------
func _end_turn() -> void:
	if turn != "player": return
	turn = "enemy"; sel = -1; reachable = {}; _refresh()
	await _enemy_turn()
	for u in units:
		if u.hp > 0: u.ap = AP_MAX; u.reacted = false; u.bracing = false
	turn = "player"; _refresh()

func _nearest_player(e) -> int:
	var best := -1; var bd := 1 << 30
	for j in units.size():
		if units[j].team == "player" and units[j].hp > 0:
			var h: int = mesh.hops(e.cell, units[j].cell)
			if h < bd: bd = h; best = j
	return best

func _best_target(e) -> int:
	var best := -1; var bk := -1e18
	for j in units.size():
		var p = units[j]
		if p.team != "enemy" and p.hp > 0 and _can_attack(e, p):
			var k: float = Combat.shot_from(mesh, units, e, e.cell, p, e.wtype) * 1000.0 - p.hp
			if k > bk: bk = k; best = j
	return best

func _enemy_turn() -> void:
	compute_evis()
	for i in units.size():
		var e = units[i]
		if e.team != "enemy" or e.hp <= 0: continue
		if not enemy_active(e):
			patrol_step(e); detect_enemies(); _refresh(); await get_tree().create_timer(0.04).timeout
			continue
		# cibles vues par cet ennemi
		var tgts := []
		for j in units.size():
			if units[j].team == "player" and units[j].hp > 0 and Combat.enemy_sees_p(mesh, e, units[j]): tgts.append(j)
		if tgts.is_empty():
			var foe := _nearest_player(e)
			if foe >= 0:
				var d := mesh.reach(e.cell, e.mob, _occupied(i))
				var best: int = e.cell; var bd: int = mesh.hops(e.cell, units[foe].cell)
				for c in d:
					var h: int = mesh.hops(c, units[foe].cell)
					if h < bd: bd = h; best = c
				if best != e.cell:
					e.facing = atan2(mesh.cells[best].cy - mesh.cells[e.cell].cy, mesh.cells[best].cx - mesh.cells[e.cell].cx)
					e.cell = best; _place(e); detect_enemies()
			await get_tree().create_timer(0.12).timeout
			continue
		var guard := 0
		while e.ap > 0 and guard < 4:
			guard += 1
			var bt := _best_target(e)
			if bt >= 0:
				_do_attack(i, bt); await get_tree().create_timer(0.25).timeout
				break
			# déplacement par scoring (offense - menace - distance + relief - agglutinement)
			var d := mesh.reach(e.cell, e.mob, _occupied(i))
			var cands := [e.cell]; for c in d: cands.append(c)
			var best: int = e.cell; var bs := -1e18
			var ranged_dry: bool = e.wtype == "ranged" and e.has("ammo") and e.ammo <= 0
			for cell in cands:
				var off := 0; var thr := 0; var near := 1 << 30
				for tj in tgts:
					var p = units[tj]
					if not ranged_dry: off = max(off, Combat.shot_from(mesh, units, e, cell, p, e.wtype))
					near = min(near, mesh.hops(cell, p.cell))
					var ghost := {"cell":cell, "team":"enemy"}
					thr = max(thr, Combat.shot_from(mesh, units, p, p.cell, ghost, p.wtype))
				var clump := 0
				for o in units:
					if o != e and o.team == "enemy" and o.hp > 0 and mesh.hops(cell, o.cell) <= 1: clump += 6
				var sc: float = off - 0.7 * thr - 1.5 * near + 0.5 * int(mesh.cells[cell].elev) - clump
				if sc > bs: bs = sc; best = cell
			if best == e.cell: break
			e.ap -= 1; e.facing = atan2(mesh.cells[best].cy - mesh.cells[e.cell].cy, mesh.cells[best].cx - mesh.cells[e.cell].cx)
			e.cell = best; _place(e); detect_enemies(); await get_tree().create_timer(0.18).timeout

func _check_end() -> void:
	var pa := units.any(func(u): return u.team == "player" and u.hp > 0)
	var ea := units.any(func(u): return u.team == "enemy" and u.hp > 0)
	if not ea: hud.text = "VICTOIRE"
	elif not pa: hud.text = "DÉFAITE"

# ---------- HUD / surbrillance ----------
func _update_fog() -> void:
	compute_vis()
	for u in units:
		if not is_instance_valid(u.node): continue
		if u.hp <= 0: u.node.visible = false; continue
		# brouillard : un ennemi n'est visible que si une de ses cases est vue
		u.node.visible = (u.team != "enemy") or seen_cells.has(u.cell)

func _refresh() -> void:
	_update_fog()
	_update_markers()
	var live_e := 0
	for u in units: if u.team == "enemy" and u.hp > 0: live_e += 1
	var s := "Tour : %s   |   ennemis : %d   |   [clic] sél./déplacement/tir  [clic-droit] pivoter  [molette] zoom  [Espace] fin de tour" % [("joueur" if turn == "player" else "ennemi"), live_e]
	if sel >= 0:
		var u = units[sel]
		var atk := ""
		# aperçu de touche sur l'ennemi le plus proche à portée
		for j in units.size():
			if units[j].team == "enemy" and units[j].hp > 0 and _can_attack(u, units[j]):
				atk = "   tir possible : %d%%" % Combat.chance(mesh, units, u, units[j], u.wtype); break
		s = "%s — PV %d/%d  PA %d/%d  (%s)%s\n%s" % [CL[u.cls].name, u.hp, u.max, u.ap, AP_MAX, ("tir " + str(u.w.ranged.range) if u.wtype == "ranged" else "mêlée"), atk, s]
	hud.text = s

func _update_markers() -> void:
	for m in _markers: m.queue_free()
	_markers.clear()
	for cell in reachable.keys():
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.45; cm.bottom_radius = 0.45; cm.height = 0.08; disc.mesh = cm
		var mt := StandardMaterial3D.new(); mt.albedo_color = Color(0.6, 0.85, 1.0, 0.5); mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc.material_override = mt; disc.position = world(cell) + Vector3(0, 0.06, 0)
		add_child(disc); _markers.append(disc)
	if sel >= 0 and units[sel].hp > 0:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 0.7; tm.outer_radius = 0.95; ring.mesh = tm
		var rm := StandardMaterial3D.new(); rm.albedo_color = Color(1, 1, 1); rm.emission_enabled = true; rm.emission = Color(1, 1, 1)
		ring.material_override = rm; ring.position = world(units[sel].cell) + Vector3(0, 0.12, 0)
		add_child(ring); _markers.append(ring)
