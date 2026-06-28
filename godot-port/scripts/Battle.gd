extends Node3D
# Tranche verticale 3D : maillage extrudé par l'élévation (vue XCOM), unités = sphères,
# sélection / déplacement / tir, tour ennemi simple. Règles = rules/ (port validé).

const VMesh := preload("res://rules/Mesh.gd")
const Classes := preload("res://rules/Classes.gd")
const Combat := preload("res://rules/Combat.gd")

const S := 0.06          # px -> unités monde
const STEP := 2.2        # hauteur monde par niveau d'élévation
const AP_MAX := 2

var mesh: VMesh
var units: Array = []     # {team,cls,cell,hp,max,ap,aim,range,dmg_min,dmg_max,mob,node,team_color}
var sel := -1             # index unité sélectionnée
var reachable := {}       # cell -> coût (pour l'unité sélectionnée)
var turn := "player"
var pivot: Node3D
var cam: Camera3D
var hud: Label
var tiles_mi: MeshInstance3D
var _yaw := 0.6
var _dist := 52.0
var _dragging := false

func _ready() -> void:
	randomize()
	_setup_world()
	_gen_battle(int(Time.get_unix_time_from_system()) & 0x7fffffff)
	_build_tiles()
	_spawn_units()
	_setup_camera()
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

func _cell_top(id: int) -> float:
	return mesh.cells[id].elev * STEP

func world(id: int) -> Vector3:
	var c = mesh.cells[id]
	return Vector3(c.cx * S, _cell_top(id), c.cy * S)

func _tile_color(c) -> Color:
	if c.terr == "wall": return Color(0.46, 0.46, 0.50)
	if c.terr == "rough": return Color(0.46, 0.39, 0.26)
	var e: int = c.elev
	return [Color(0.34,0.30,0.24), Color(0.46,0.39,0.28), Color(0.58,0.48,0.33), Color(0.72,0.58,0.38)][min(e,3)]

# ---------- maillage 3D (faces du dessus + parois) ----------
func _build_tiles() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in mesh.cells:
		var col := _tile_color(c)
		var top: float = c.elev * STEP
		var ctr := Vector3(c.cx * S, top, c.cy * S)
		var p: Array = c.poly
		var c2 := Vector2(c.cx, c.cy)
		# face du dessus (éventail depuis le centroïde), normale = +Y (éclairage correct)
		for k in p.size():
			var a: Vector2 = p[k]; var b: Vector2 = p[(k + 1) % p.size()]
			var va := Vector3(a.x * S, top, a.y * S)
			var vb := Vector3(b.x * S, top, b.y * S)
			st.set_normal(Vector3.UP); st.set_color(col); st.add_vertex(ctr)
			st.set_normal(Vector3.UP); st.set_color(col); st.add_vertex(vb)
			st.set_normal(Vector3.UP); st.set_color(col); st.add_vertex(va)
		# parois (de l'arête jusqu'à la base y=0) — rend l'élévation visible
		var side := col.darkened(0.45)
		for k in p.size():
			var a: Vector2 = p[k]; var b: Vector2 = p[(k + 1) % p.size()]
			var midp := (a + b) * 0.5
			var nd := (midp - c2); nd = nd.normalized() if nd.length() > 0.001 else Vector2(1, 0)
			var nrm := Vector3(nd.x, 0, nd.y)
			var ta := Vector3(a.x * S, top, a.y * S)
			var tb := Vector3(b.x * S, top, b.y * S)
			var ba := Vector3(a.x * S, 0.0, a.y * S)
			var bb := Vector3(b.x * S, 0.0, b.y * S)
			st.set_normal(nrm); st.set_color(side); st.add_vertex(ta)
			st.set_normal(nrm); st.set_color(side); st.add_vertex(bb)
			st.set_normal(nrm); st.set_color(side); st.add_vertex(tb)
			st.set_normal(nrm); st.set_color(side); st.add_vertex(ta)
			st.set_normal(nrm); st.set_color(side); st.add_vertex(ba)
			st.set_normal(nrm); st.set_color(side); st.add_vertex(bb)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # double-face : pas de tuile masquée par le winding
	st.set_material(mat)
	tiles_mi = MeshInstance3D.new()
	tiles_mi.mesh = st.commit()
	add_child(tiles_mi)

# ---------- unités ----------
func _make_unit(team: String, cls: String, cell: int) -> void:
	var d = Classes.DATA[cls]
	var u := {"team":team, "cls":cls, "cell":cell, "hp":d.hp, "max":d.hp, "ap":AP_MAX,
		"aim":d.aim, "range":d.range, "dmg_min":d.dmg_min, "dmg_max":d.dmg_max, "mob":d.mob}
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.62; sm.height = 1.24
	ball.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = d.color
	mat.emission_enabled = true; mat.emission = d.color * 0.35
	ball.material_override = mat
	add_child(ball)
	u.node = ball
	units.append(u)
	_place(u)

func _place(u) -> void:
	u.node.position = world(u.cell) + Vector3(0, 0.85, 0)

func _occupied(except_idx := -1) -> Dictionary:
	var o := {}
	for i in units.size():
		if i == except_idx: continue
		if units[i].hp > 0: o[units[i].cell] = true
	return o

func _free_near(target: int, used: Dictionary):
	# cellule passable la plus proche de `target`, non occupée
	var best := -1; var bd := 1 << 30
	for c in mesh.cells:
		if not mesh.passable(c.id) or used.has(c.id): continue
		var h: int = mesh.hops(target, c.id)
		if h < bd: bd = h; best = c.id
	return best

func _spawn_units() -> void:
	# joueurs dans un coin (cellule passable de plus petit cx+cy), ennemis dispersés au loin
	var pass_cells := []
	for c in mesh.cells:
		if mesh.passable(c.id): pass_cells.append(c.id)
	pass_cells.sort_custom(func(a, b): return (mesh.cells[a].cx + mesh.cells[a].cy) < (mesh.cells[b].cx + mesh.cells[b].cy))
	var used := {}
	var pteam := ["soldat", "archer", "garde", "brute"]
	var pi := 0
	for id in pass_cells:
		if pi >= 4: break
		var ok := true
		for k in used: if mesh.hops(k, id) < 2: ok = false; break
		if ok: _make_unit("player", pteam[pi], id); used[id] = true; pi += 1
	# ennemis : loin du coin de déploiement
	var far := pass_cells.duplicate()
	far.reverse()
	var eteam := ["garde_e", "archer_e", "garde_e", "brute"]
	var ei := 0
	for id in far:
		if ei >= 4: break
		if used.has(id): continue
		var ok := true
		for k in used: if mesh.hops(k, id) < 4: ok = false; break
		if ok: _make_unit("enemy", eteam[ei % eteam.size()], id); used[id] = true; ei += 1

# ---------- caméra XCOM ----------
func _setup_camera() -> void:
	pivot = Node3D.new()
	pivot.position = Vector3(720 * S * 0.5, 0, 560 * S * 0.5)
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 46
	pivot.add_child(cam)
	_update_cam()

func _update_cam() -> void:
	if not cam: return
	var pitch := deg_to_rad(52.0)
	var h := sin(pitch) * _dist
	var horiz := cos(pitch) * _dist
	cam.position = Vector3(sin(_yaw) * horiz, h, cos(_yaw) * horiz)
	cam.look_at(pivot.global_position, Vector3.UP)

# ---------- sélection / portée ----------
func _unit_at(cell: int) -> int:
	for i in units.size():
		if units[i].hp > 0 and units[i].cell == cell: return i
	return -1

func _compute_reach() -> void:
	reachable = {}
	if sel < 0: return
	var u = units[sel]
	if u.ap <= 0: return
	reachable = mesh.reach(u.cell, u.mob, _occupied(sel))

func _can_attack(att, tgt) -> bool:
	if att.range > 0:
		return mesh.hops(att.cell, tgt.cell) <= att.range and mesh.los(att.cell, tgt.cell)
	return mesh.hops(att.cell, tgt.cell) <= 1

func _do_attack(ai: int, ti: int) -> void:
	var att = units[ai]; var tgt = units[ti]
	if att.ap <= 0 or not _can_attack(att, tgt): return
	att.ap -= 1
	var ch := Combat.hit_chance(mesh, att, tgt)
	var hit := randi() % 100 < ch
	if hit:
		var dmg: int = att.dmg_min + randi() % (att.dmg_max - att.dmg_min + 1)
		tgt.hp -= dmg
		_flash(tgt, str(dmg), Color(1, 0.5, 0.4))
		if tgt.hp <= 0:
			tgt.node.visible = false
	else:
		_flash(tgt, "raté", Color(0.8, 0.8, 0.85))
	_refresh()
	_check_end()

func _flash(u, txt: String, col: Color) -> void:
	var l := Label3D.new(); l.text = txt; l.modulate = col; l.font_size = 64
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
	l.position = world(u.cell) + Vector3(0, 2.2, 0)
	add_child(l)
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
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var plane := Plane(Vector3.UP, 0)
	var hit = plane.intersects_ray(from, dir)
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
			u.ap -= 1; u.cell = cell; _place(u); _compute_reach(); _refresh()

# ---------- tours ----------
func _end_turn() -> void:
	if turn != "player": return
	turn = "enemy"; sel = -1; reachable = {}; _refresh()
	await _enemy_turn()
	for u in units: if u.hp > 0: u.ap = AP_MAX
	turn = "player"; _refresh()

func _enemy_turn() -> void:
	for i in units.size():
		var e = units[i]
		if e.team != "enemy" or e.hp <= 0: continue
		# cible joueur la plus proche
		var tgt := -1; var td := 1 << 30
		for j in units.size():
			if units[j].team == "player" and units[j].hp > 0:
				var h: int = mesh.hops(e.cell, units[j].cell)
				if h < td: td = h; tgt = j
		if tgt < 0: break
		while e.ap > 0:
			if _can_attack(e, units[tgt]):
				_do_attack(i, tgt); await get_tree().create_timer(0.25).timeout
			else:
				var d := mesh.reach(e.cell, e.mob, _occupied(i))
				var best: int = e.cell; var bd: int = mesh.hops(e.cell, units[tgt].cell)
				for c in d:
					var h: int = mesh.hops(c, units[tgt].cell)
					if h < bd: bd = h; best = c
				if best == e.cell: break
				e.ap -= 1; e.cell = best; _place(e)
				await get_tree().create_timer(0.2).timeout

func _check_end() -> void:
	var pa := units.any(func(u): return u.team == "player" and u.hp > 0)
	var ea := units.any(func(u): return u.team == "enemy" and u.hp > 0)
	if not ea: hud.text = "VICTOIRE"
	elif not pa: hud.text = "DÉFAITE"

# ---------- HUD / surbrillance ----------
func _refresh() -> void:
	_update_selection_rings()
	var live_e := 0
	for u in units: if u.team == "enemy" and u.hp > 0: live_e += 1
	var s := "Tour : %s   |   ennemis : %d   |   [clic] sélection/déplacement/tir  [clic-droit] pivoter  [molette] zoom  [Espace] fin de tour" % [("joueur" if turn == "player" else "ennemi"), live_e]
	if sel >= 0:
		var u = units[sel]
		s = "%s — PV %d/%d  PA %d/%d   (portée %s)\n%s" % [Classes.DATA[u.cls].name, u.hp, u.max, u.ap, AP_MAX, ("tir " + str(u.range) if u.range > 0 else "mêlée"), s]
	hud.text = s

var _markers: Array = []
func _update_selection_rings() -> void:
	for m in _markers: m.queue_free()
	_markers.clear()
	# cases atteignables : petits disques clairs
	for cell in reachable.keys():
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.5; cm.bottom_radius = 0.5; cm.height = 0.08
		disc.mesh = cm
		var mt := StandardMaterial3D.new(); mt.albedo_color = Color(0.6, 0.85, 1.0, 0.5); mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc.material_override = mt
		disc.position = world(cell) + Vector3(0, 0.06, 0)
		add_child(disc); _markers.append(disc)
	# anneau sous l'unité sélectionnée
	if sel >= 0 and units[sel].hp > 0:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 0.7; tm.outer_radius = 0.95
		ring.mesh = tm
		var rm := StandardMaterial3D.new(); rm.albedo_color = Color(1, 1, 1); rm.emission_enabled = true; rm.emission = Color(1, 1, 1)
		ring.material_override = rm
		ring.position = world(units[sel].cell) + Vector3(0, 0.12, 0)
		add_child(ring); _markers.append(ring)
