extends Node3D
# Tranche combat 3D (vue XCOM, élévation visible). Règles = rules/ (port fidèle).
# Maillage Voronoï extrudé, sphères par équipe (orientées = bec), murets, sélection/déplacement/tir.

const VMesh := preload("res://rules/Mesh.gd")
const Data := preload("res://rules/Data.gd")
const Combat := preload("res://rules/Combat.gd")

signal mission_ended(win)

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
var armed := ""
var abil_bar: HBoxContainer
var objective := "eliminate"
var survive_turns := 6
var extract_count := 1
var protect_n := 0
var exit_set := {}
var turn_num := 1
var over := false
var mis := {}                # Run.mission (vide = combat autonome aléatoire)
var n_enemies := 5
var potions := 2             # stock partagé de soins (lu/écrit sur Run en campagne)
var _terrain_root: Node3D    # tuiles + murets (reconstruits après une brèche)

func _run_mission() -> Dictionary:
	var r = get_node_or_null("/root/Run")
	if r != null and not r.mission.is_empty(): return r.mission
	return {}

# corruptLevel() : la distorsion croît avec le nombre de missions (cumulatif, plafonné à 1)
func _corrupt_level() -> float:
	var r = get_node_or_null("/root/Run")
	if r == null or r.camp.is_empty(): return 0.0
	return min(1.0, int(r.camp.get("missionN", 0)) * 0.06)

func _ready() -> void:
	randomize()
	CL = Data.classes()
	mis = _run_mission()
	var seed_value: int = (int(mis.seed) if mis.has("seed") else int(Time.get_unix_time_from_system())) & 0x7fffffff
	if mis.has("enemies"): n_enemies = int(mis.enemies)
	var _r = get_node_or_null("/root/Run")
	if _r != null and not _r.camp.is_empty(): potions = int(_r.camp.get("potions", 2))
	_setup_world()
	_gen_battle(seed_value)
	mesh.distort(_corrupt_level())   # distorsion progressive : le terrain se tord à mesure qu'on avance
	_terrain_root = Node3D.new(); add_child(_terrain_root)
	_build_tiles()
	_build_walls()
	_spawn_units()
	setup_objective()
	_setup_camera()
	compute_vis(); detect_enemies()
	for i in units.size():
		if units[i].team == "player": sel = i; break
	_compute_reach()
	_refresh()

# ---------- objectifs / archétypes ----------
func _deepest_from_players() -> int:
	var pcells := []
	for u in units: if u.team == "player": pcells.append(u.cell)
	var best := -1; var bd := -1
	for c in mesh.cells:
		if not mesh.passable(c.id): continue
		var dmin := 1 << 30
		for pc in pcells: dmin = min(dmin, mesh.hops(pc, c.id))
		if dmin > bd and dmin < (1 << 30): bd = dmin; best = c.id
	return best

func _make_neutral(cls: String, cell: int, hostage: bool) -> void:
	_make_unit("neutral", cls, cell)
	var u = units[-1]
	if hostage: u["hostage"] = true
	else: u.civ = false   # VIP à défendre (compté)

func setup_objective() -> void:
	if mis.has("objective"):
		objective = mis.objective
	else:
		var kinds := ["eliminate", "assassinate", "rescue", "defend", "survive", "extract"]
		objective = kinds[randi() % kinds.size()]
	match objective:
		"assassinate":
			var deep := -1; var bd := -1
			for u in units:
				if u.team == "enemy":
					var h: int = mesh.hops(units[0].cell, u.cell)
					if h > bd: bd = h; deep = units.find(u)
			if deep >= 0: units[deep]["hvt"] = true
		"rescue":
			var spot := _deepest_from_players()
			if spot >= 0 and _unit_at(spot) < 0: _make_neutral("homme", spot, true)
		"defend":
			survive_turns = 6
			var near := -1
			for c in mesh.cells:
				if mesh.passable(c.id) and _unit_at(c.id) < 0 and mesh.hops(units[0].cell, c.id) <= 2: near = c.id; break
			if near >= 0: _make_neutral("femme", near, false)
		"survive": survive_turns = 6
		"extract":
			var deep := _deepest_from_players()
			exit_set = {}
			if deep >= 0:
				exit_set[deep] = true
				for n in mesh.cells[deep].nb: if mesh.passable(n): exit_set[n] = true
			var np := 0
			for u in units: if u.team == "player": np += 1
			extract_count = max(1, np - 1)

func _obj_label() -> String:
	match objective:
		"assassinate": return "Objectif : éliminer la cible (✦)"
		"rescue": return "Objectif : libérer l'otage (neutraliser les geôliers)"
		"defend": return "Objectif : protéger le VIP %d tours" % survive_turns
		"survive": return "Objectif : tenir %d tours" % survive_turns
		"extract": return "Objectif : %d unités sur la zone d'extraction" % extract_count
		_: return "Objectif : éliminer tous les ennemis"

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
	var ci := CanvasLayer.new(); ci.add_child(hud)
	abil_bar = HBoxContainer.new()
	abil_bar.anchor_left = 0.5; abil_bar.anchor_right = 0.5; abil_bar.anchor_top = 1.0; abil_bar.anchor_bottom = 1.0
	abil_bar.offset_left = -300; abil_bar.offset_right = 300; abil_bar.offset_top = -56; abil_bar.offset_bottom = -10
	abil_bar.alignment = BoxContainer.ALIGNMENT_CENTER; abil_bar.add_theme_constant_override("separation", 8)
	ci.add_child(abil_bar)
	add_child(ci)

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
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); _terrain_root.add_child(mi)

func _rebuild_terrain() -> void:   # après une brèche (terrain modifié)
	for c in _terrain_root.get_children(): c.queue_free()
	_build_tiles(); _build_walls()

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
		_terrain_root.add_child(bar)

# ---------- unités ----------
func _team_color(team: String) -> Color:
	return Data.PLAYER_COL if team == "player" else (Data.ENEMY_COL if team == "enemy" else Data.NEUTRAL_COL)

func _make_unit(team: String, cls: String, cell: int, mem := {}) -> void:
	var d = CL[cls]; var w = d.w
	var wtype := "ranged" if w.has("ranged") else "melee"
	var nm: String = mem.get("name", CL[cls].name) if not mem.is_empty() else CL[cls].name
	var u := {"team":team, "cls":cls, "cell":cell, "name":nm, "hp":int(d.hp), "max":int(d.hp), "ap":AP_MAX,
		"mob":int(d.mob), "facing":(PI if team == "enemy" else 0.0), "w":w, "wtype":wtype,
		"shieldBlock":int(d.get("shieldBlock", 0)), "parry":int(d.get("parry", 0)), "stealth":d.get("stealth", false),
		"civ":d.get("civ", false), "aimBonus":0, "dmgBonus":0, "rangeBonus":0, "reacted":false, "bracing":false, "wallStance":false,
		"asleep":false, "pod":-1, "home":cell, "freeAvail":true, "freeMpBonus":0,
		"abil":(d.get("abil", []) as Array).duplicate(), "cd":{}, "slowed":false, "stunned":false,
		"spellsCast":0, "dmgTaken":0, "kills":0, "crackers":int(d.get("crackers", 0)), "scatterBonus":0}
	if wtype == "ranged" and w.ranged.has("clip"): u.clip = int(w.ranged.clip); u.ammo = int(w.ranged.clip)
	if team == "player":
		var ids: Array = mem.get("perks", []) if not mem.is_empty() else []
		if ids.is_empty() and mem.is_empty():   # combat autonome : arbre A complet (démo)
			for g in Data.perks().get(cls, []): ids.append(g.A.id)
		apply_perk_mods(u, ids)
		if not mem.is_empty():
			u.max = int(mem.get("maxHp", u.max)); u.hp = int(mem.get("deployHp", u.max))
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
	u.node = node; u.mat = mat
	units.append(u); _place(u)

func _place(u) -> void:
	u.node.position = world(u.cell) + Vector3(0, 0.85, 0)
	u.node.rotation.y = -float(u.facing)

func _occupied(except_idx := -1) -> Dictionary:
	var o := {}
	for i in units.size():
		if i != except_idx and units[i].hp > 0: o[units[i].cell] = true
	return o

# escouade à déployer : roster sélectionné (campagne) sinon 4 classes par défaut (autonome)
func _deploy_squad() -> Array:
	var r = get_node_or_null("/root/Run")
	if r != null and not r.camp.is_empty() and (r.camp.get("roster", []) as Array).size() > 0:
		var sel: Array = r.camp.get("deploySel", [])
		if sel.is_empty(): sel = r.ready_members()
		var out: Array = []
		for nm in sel:
			var m: Dictionary = r.member(nm)
			if m.is_empty() or bool(m.get("dead", false)): continue
			var dh: Dictionary = r.mem_deploy_hp(m, bool(mis.get("bonus", false)))
			out.append({"cls":m.cls, "mem":{"name":m.name, "perks":r.member_perks(m), "maxHp":int(dh.max), "deployHp":int(dh.hp)}})
		if not out.is_empty(): return out
	return [{"cls":"soldat"}, {"cls":"assassin"}, {"cls":"garde"}, {"cls":"mage"}]

# rapport de fin (par nom) : PV, usure, kills, sorts, K.O. — consommé par Run.resolve_mission
func build_report() -> Dictionary:
	var rep := {}
	for u in units:
		if u.team == "player":
			rep[u.name] = {"hp":int(u.hp), "max":int(u.max), "dmgTaken":int(u.get("dmgTaken", 0)),
				"kills":int(u.get("kills", 0)), "spellsCast":int(u.get("spellsCast", 0)), "ko":u.hp <= 0}
	return rep

func _spawn_units() -> void:
	var pass_cells := []
	for c in mesh.cells:
		if mesh.passable(c.id): pass_cells.append(c.id)
	pass_cells.sort_custom(func(a, b): return (mesh.cells[a].cx + mesh.cells[a].cy) < (mesh.cells[b].cx + mesh.cells[b].cy))
	var used := {}
	# déploiement de l'escouade : roster sélectionné (campagne) ou 4 classes par défaut (autonome)
	var squad: Array = _deploy_squad()
	var r = get_node_or_null("/root/Run")
	var fb: Dictionary = {}
	if r != null and r.camp.has("forgeBonus"): fb = r.camp.forgeBonus
	for spec in squad:
		for id in pass_cells:
			if used.has(id): continue
			var ok := true
			for k in used: if mesh.hops(k, id) < 2: ok = false; break
			if ok:
				_make_unit("player", spec.cls, id, spec.get("mem", {})); used[id] = true
				if not fb.is_empty(): units[-1].dmgBonus += int(fb.get("dmg", 0))   # dégâts de forge (PV déjà dans maxHp)
				break
	# escouade ennemie : nombre selon difficulté, répartie en pods, la plus loin = boss
	var pool := ["garde", "archer", "emage", "shieldbearer", "brute", "archer", "garde", "brute"]
	var far := pass_cells.duplicate(); far.reverse()
	var pod := 0; var placed := 0
	for k in min(n_enemies, pool.size()):
		var cls: String = pool[k]
		for id in far:
			if used.has(id): continue
			var ok := true
			for u in used: if mesh.hops(u, id) < 4: ok = false; break
			if ok:
				_make_unit("enemy", cls, id); used[id] = true
				units[-1].asleep = true; units[-1].pod = pod; pod += 1; placed += 1
				break

# ---------- cooldowns / statuts ----------
func on_cd(u, id: String) -> bool: return u.cd.has(id) and u.cd[id] > 0
func set_cd(u, id: String) -> void:
	if Data.COOLDOWN.has(id): u.cd[id] = Data.COOLDOWN[id]
func tick_cd(team: String) -> void:
	for u in units:
		if u.team == team:
			for k in u.cd: if u.cd[k] > 0: u.cd[k] -= 1

# ---------- capacités (port de exec* d'index.html) ----------
func _hostiles_of(u) -> Array:
	var r := []
	for o in units:
		if o.hp > 0 and o.team != u.team and not (u.team == "neutral" or o.team == "neutral"): r.append(o)
	return r

func exec_blast(u, center: int) -> bool:
	if on_cd(u, "blast") or mesh.hops(u.cell, center) > Data.BLAST_RANGE or not mesh.los(u.cell, center): return false
	for e in _hostiles_of(u):
		if mesh.hops(center, e.cell) <= Data.BLAST_RADIUS:
			var dmg := Data.BLAST_MIN + randi() % (Data.BLAST_MAX - Data.BLAST_MIN + 1)
			e.hp = max(0, e.hp - dmg); _flash(e, str(dmg), Color(1, 0.6, 0.2)); _hit_react(e)
			if e.team == "player": e.dmgTaken = int(e.get("dmgTaken", 0)) + dmg
			if e.hp <= 0 and u.team == "player": u.kills = int(u.get("kills", 0)) + 1
			if e.hp > 0 and e.team == "enemy": wake_enemy(e)
	_fx_burst(center, Color(1, 0.55, 0.15), 1.6)
	u.spellsCast += 1; set_cd(u, "blast"); u.ap = 0
	return true

func exec_frost(u, tgt) -> bool:
	if on_cd(u, "frost") or mesh.hops(u.cell, tgt.cell) > Data.FROST_RANGE or not mesh.los(u.cell, tgt.cell): return false
	tgt.slowed = true; tgt.ap = max(0, tgt.ap - 1); _fx_burst(tgt.cell, Color(0.5, 0.8, 1.0), 1.0)
	_flash(tgt, "givré", Color(0.6, 0.85, 1.0)); u.spellsCast += 1; set_cd(u, "frost"); u.ap -= 1
	return true

func exec_heal(u, a) -> bool:
	if on_cd(u, "heal") or a.hp >= a.max or mesh.hops(u.cell, a.cell) > Data.HEAL_RANGE or not mesh.los(u.cell, a.cell): return false
	var before: int = a.hp; a.hp = min(a.max, a.hp + Data.HEAL_AMT)
	_flash(a, "+%d" % (a.hp - before), Color(0.5, 1.0, 0.6)); u.spellsCast += 1; set_cd(u, "heal"); u.ap -= 1
	return true

func _shove_dest(u, tgt) -> int:
	var a0 := atan2(mesh.cells[tgt.cell].cy - mesh.cells[u.cell].cy, mesh.cells[tgt.cell].cx - mesh.cells[u.cell].cx)
	var best := -1; var bd := 1.0
	for n in mesh.cells[tgt.cell].nb:
		if not mesh.passable(n) or _unit_at(n) >= 0: continue
		var an := atan2(mesh.cells[n].cy - mesh.cells[tgt.cell].cy, mesh.cells[n].cx - mesh.cells[tgt.cell].cx)
		var diff := abs(Combat._norm(an - a0))
		if diff < bd: bd = diff; best = n
	return best

func exec_shove(u, tgt) -> bool:
	if on_cd(u, "shove") or not Combat.adjacent(mesh, u.cell, tgt.cell): return false
	set_cd(u, "shove")
	var dest := _shove_dest(u, tgt)
	if dest >= 0: tgt.cell = dest; _place(tgt)
	var stun := randf() * 100.0 < 50.0
	if stun: tgt.stunned = true
	_flash(tgt, "repoussé" + (" ✦" if stun else ""), Color(1, 0.8, 0.4)); u.ap = 0
	return true

func exec_charge(u, tgt) -> bool:
	if on_cd(u, "charge"): return false
	var best := -1; var bl := 1 << 30
	for n in mesh.cells[tgt.cell].nb:
		if n != u.cell and (_unit_at(n) >= 0 or not mesh.passable(n)): continue
		var len: int = (0 if n == u.cell else mesh.hops(u.cell, n))
		if len <= 0 or len > Data.CHARGE_RANGE: continue
		if len < bl: bl = len; best = n
	if best < 0 or bl < 2: return false
	set_cd(u, "charge"); u.cell = best; _place(u)
	var bonus: int = min(6, 1 + bl); u.dmgBonus += bonus
	var res := Combat.do_attack(mesh, units, u, tgt, "melee")
	u.dmgBonus -= bonus; u.ap = 0
	if res.dmg > 0: _flash(res.target, str(res.dmg), Color(1, 0.5, 0.4))
	for o in units: if o.hp <= 0 and is_instance_valid(o.node): o.node.visible = false
	return true

func enemy_use_abil(e) -> bool:
	if e.abil.is_empty() or e.ap <= 0: return false
	if e.abil.has("blast") and not on_cd(e, "blast"):
		var best := -1; var bc := 0
		for p in units:
			if p.team == e.team or p.hp <= 0: continue
			if mesh.hops(e.cell, p.cell) > Data.BLAST_RANGE or not mesh.los(e.cell, p.cell): continue
			var cnt := 0
			for q in units: if q.team != e.team and q.hp > 0 and mesh.hops(p.cell, q.cell) <= Data.BLAST_RADIUS: cnt += 1
			if cnt > bc: bc = cnt; best = p.cell
		if best >= 0 and bc >= 2 and exec_blast(e, best): return true
	if e.abil.has("frost") and not on_cd(e, "frost"):
		var t := _best_target(e)
		if t >= 0 and not units[t].slowed and exec_frost(e, units[t]): return true
	return false

func enemy_shield_act(e, tgts: Array) -> bool:
	if e.ap <= 0: return false
	if e.abil.has("charge") and not on_cd(e, "charge"):
		var pick := -1; var pd := 1 << 30
		for j in tgts:
			var h: int = mesh.hops(e.cell, units[j].cell)
			if h >= 2 and h <= Data.CHARGE_RANGE and mesh.los(e.cell, units[j].cell) and h < pd: pd = h; pick = j
		if pick >= 0 and exec_charge(e, units[pick]): return true
	if e.abil.has("shove") and not on_cd(e, "shove"):
		for j in tgts:
			if Combat.adjacent(mesh, e.cell, units[j].cell) and exec_shove(e, units[j]): return true
	return false

func _fx_burst(cell: int, col: Color, scale: float) -> void:
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 1.0; s.mesh = sm
	var mt := StandardMaterial3D.new(); mt.albedo_color = col; mt.emission_enabled = true; mt.emission = col
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mt.albedo_color.a = 0.7
	s.material_override = mt; s.position = world(cell) + Vector3(0, 0.9, 0); add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * (2.0 + scale), 0.45)
	tw.parallel().tween_property(mt, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(s.queue_free)

# ---------- perks ----------
func apply_perk_mods(u, ids: Array) -> void:
	for id in ids:
		var p = Data.perk_by_id(u.cls, id)
		if p == null: continue
		if p.has("abil"):
			if not u.abil.has(p.abil): u.abil.append(p.abil)
			if p.abil == "protect": u["protect"] = true
			continue
		var m: Dictionary = p.get("mod", {})
		if m.has("hp"): u.max += m.hp; u.hp += m.hp
		if m.has("shieldBlock"): u.shieldBlock += m.shieldBlock
		if m.has("parry"): u.parry += m.parry
		if m.has("mob"): u.mob += m.mob
		if m.has("aim"): u.aimBonus += m.aim
		if m.has("dmg"): u.dmgBonus += m.dmg
		if m.has("range"): u.rangeBonus += m.range
		if m.has("freeMp"): u.freeMpBonus += m.freeMp
		if m.has("scatter"): u.scatterBonus += m.scatter
		if m.has("crackers"): u.crackers += m.crackers

# ---------- capacités : registre (pour la barre) + execs restants ----------
const ABIL := {
	"smoke":{"icon":"🌫","target":"cell"}, "breach":{"icon":"💥","target":"cell"},
	"shadowstrike":{"icon":"🌑","target":"enemy"}, "rally":{"icon":"📣","target":"ally"},
	"vanish":{"icon":"💨","target":"self"}, "taunt":{"icon":"💢","target":"self"},
	"holdline":{"icon":"🛡","target":"self"}, "wall":{"icon":"🧱","target":"self"},
	"blast":{"icon":"🔥","target":"cell"}, "heal":{"icon":"✨","target":"ally"},
	"frost":{"icon":"❄","target":"enemy"}, "shove":{"icon":"🛡➡","target":"enemy"}, "charge":{"icon":"🛡⚡","target":"enemy"},
	"cracker":{"icon":"💣","target":"cell"}, "potion":{"icon":"➕","target":"ally"}}
const POTION_AMT := 6

func exec_potion(u, a) -> bool:
	if potions <= 0 or a.team != "player" or a.hp <= 0 or a.hp >= a.max: return false
	if a != u and not Combat.adjacent(mesh, u.cell, a.cell): return false
	var before: int = a.hp; a.hp = min(a.max, a.hp + POTION_AMT)
	potions -= 1; u.ap -= 1
	_flash(a, "+%d" % (a.hp - before), Color(0.5, 1.0, 0.6))
	return true

const SMOKE_TURNS := 2
const SMOKE_RANGE := 6
const SMOKE_RADIUS := 1
const BREACH_RANGE := 6

# ---------- sapeur : grenade (cracker, aire + dispersion) + brèche (ouvre un passage) ----------
func exec_cracker(u, target: int) -> bool:
	var cr = u.w.get("cracker")
	if cr == null or int(u.get("crackers", 0)) <= 0: return false
	if mesh.hops(u.cell, target) > int(cr.range) or not mesh.los(u.cell, target): return false
	u.crackers = int(u.crackers) - 1; u.ap = 0; u.freeAvail = false
	var scat: int = max(0, int(cr.scatter) - int(u.get("scatterBonus", 0)))
	var cand: Array = []
	for c in mesh.cells:
		if mesh.passable(c.id) and mesh.hops(target, c.id) <= scat: cand.append(c.id)
	var imp: int = cand[randi() % cand.size()] if not cand.is_empty() else target
	for o in units:
		if o.hp <= 0: continue
		if mesh.hops(imp, o.cell) <= int(cr.radius):
			var dmg := int(cr.dmg_min) + randi() % (int(cr.dmg_max) - int(cr.dmg_min) + 1)
			o.hp = max(0, o.hp - dmg)
			if o.team == "player": o.dmgTaken = int(o.get("dmgTaken", 0)) + dmg
			if o.hp <= 0 and u.team == "player" and o.team == "enemy": u.kills = int(u.get("kills", 0)) + 1
			_flash(o, str(dmg), Color(1, 0.55, 0.2)); _hit_react(o)
			if o.hp > 0 and o.team == "enemy": wake_enemy(o)
	_fx_burst(imp, Color(1, 0.5, 0.15), 2.2); _shake(7)
	for o in units:
		if o.hp <= 0 and is_instance_valid(o.node): o.node.visible = false
	return true

func exec_breach(u, id: int) -> bool:
	if on_cd(u, "breach") or not mesh.los(u.cell, id): return false
	var d: int = mesh.hops(u.cell, id)   # une case-rocher n'est pas « atteignable » : on mesure via un voisin praticable
	if not mesh.passable(id):
		d = 1 << 30
		for n in mesh.cells[id].nb:
			if mesh.passable(n): d = min(d, mesh.hops(u.cell, n) + 1)
	if d > BREACH_RANGE: return false
	var done := false
	if mesh.cells[id].terr == "wall": mesh.cells[id].terr = "plain"; done = true
	for n in mesh.cells[id].nb:
		var k := mesh.wkey(id, n)
		if mesh.walls.has(k): mesh.walls.erase(k); done = true
	if not done: return false
	u.ap = 0; u.freeAvail = false; set_cd(u, "breach")
	_fx_burst(id, Color(0.9, 0.7, 0.3), 1.6); _shake(5)
	for e in units:
		if e.team == "enemy" and e.hp > 0 and mesh.hops(id, e.cell) <= 3: wake_enemy(e)
	_rebuild_terrain()
	return true

func exec_smoke(u, cell: int) -> bool:
	if on_cd(u, "smoke") or mesh.hops(u.cell, cell) > SMOKE_RANGE or not mesh.los(u.cell, cell): return false
	for c in mesh.cells:
		if mesh.hops(cell, c.id) <= SMOKE_RADIUS: mesh.smoke[c.id] = SMOKE_TURNS
	_fx_burst(cell, Color(0.8, 0.82, 0.85), 1.4); set_cd(u, "smoke"); u.ap -= 1
	return true

func exec_rally(u, a) -> bool:
	if on_cd(u, "rally") or a == u or a.team != u.team or a.hp <= 0 or not Combat.adjacent(mesh, u.cell, a.cell): return false
	a.ap = min(AP_MAX, a.ap + 1); _flash(a, "+1 PA", Color(0.9, 0.9, 0.5)); set_cd(u, "rally"); u.ap -= 1
	return true

func exec_vanish(u) -> bool:
	if u.get("vanishUsed", false): return false
	u["hidden"] = true; u["vanishUsed"] = true; _flash(u, "estompe", Color(0.7, 0.8, 0.9)); u.ap -= 1
	return true

func exec_taunt(u) -> bool:
	if on_cd(u, "taunt"): return false
	u["taunt"] = true; _flash(u, "provoque", Color(1, 0.7, 0.5)); set_cd(u, "taunt"); u.ap -= 1
	return true

func exec_wall(u) -> bool:
	if on_cd(u, "wall"): return false
	u.wallStance = true; _flash(u, "mur mobile", Color(0.8, 0.7, 0.5)); set_cd(u, "wall"); u.ap -= 1
	return true

func exec_holdline(u) -> bool:
	if on_cd(u, "holdline"): return false
	var n := 0
	for a in units:
		if a.team == u.team and a != u and a.hp > 0 and Combat.adjacent(mesh, u.cell, a.cell) and a.ap > 0:
			a["overwatch"] = true; a["owMode"] = a.wtype; a.reacted = false; n += 1
	_flash(u, "tenez la ligne", Color(0.7, 0.85, 1.0)); set_cd(u, "holdline"); u.ap -= 1
	return true

func exec_shadowstrike(u, tgt) -> bool:
	if on_cd(u, "shadowstrike") or mesh.hops(u.cell, tgt.cell) > 4: return false
	var best := -1; var bs := -1
	for n in mesh.cells[tgt.cell].nb:
		if n != u.cell and (_unit_at(n) >= 0 or not mesh.passable(n)): continue
		if n != u.cell and mesh.hops(u.cell, n) > u.mob: continue
		var f := Combat.flank_of(mesh, {"cell":n}, tgt)
		var s: int = {"back":3, "side":2, "front":1}[f]
		if s > bs: bs = s; best = n
	if best < 0: return false
	set_cd(u, "shadowstrike"); if best != u.cell: u.cell = best; _place(u)
	u.dmgBonus += 2
	var res := Combat.do_attack(mesh, units, u, tgt, "melee")
	u.dmgBonus -= 2; u.ap = 0
	if res.dmg > 0: _flash(res.target, str(res.dmg), Color(1, 0.5, 0.4))
	for o in units: if o.hp <= 0 and is_instance_valid(o.node): o.node.visible = false
	return true

# overwatch : un guetteur hostile tire sur l'unité qui bouge (1 fois)
func react_to(mover) -> void:
	for o in units:
		if o.hp > 0 and o.team != mover.team and o.get("overwatch", false) and not o.get("reacted", false):
			var mode: String = o.get("owMode", o.wtype)
			if Combat.in_range(mesh, o, mover, mode):
				o.reacted = true
				var res := Combat.do_attack(mesh, units, o, mover, mode, true)
				if res.dmg > 0: _flash(res.target, str(res.dmg), Color(1, 0.7, 0.3))
				if mover.hp <= 0: return

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

# secousse de caméra sur impact (grenade, brèche, gros coup)
func _shake(power: float) -> void:
	if cam == null: return
	var tw := create_tween()
	for i in 4:
		tw.tween_property(cam, "h_offset", (randf() * 2.0 - 1.0) * power * 0.02, 0.04)
		tw.parallel().tween_property(cam, "v_offset", (randf() * 2.0 - 1.0) * power * 0.02, 0.04)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.05)

# ---------- sélection / combat ----------
func _unit_at(cell: int) -> int:
	for i in units.size():
		if units[i].hp > 0 and units[i].cell == cell: return i
	return -1

# mouvement : déplacement gratuit (freeAvail) + PA × mobilité (modèle d'index.html)
func _free_mp(u) -> int: return Data.FREE_MP + int(u.get("freeMpBonus", 0))
func budget(u) -> int: return (_free_mp(u) if u.get("freeAvail", true) else 0) + u.ap * u.mob
func ap_for_move(u, cost: int) -> int:
	var free: int = _free_mp(u) if u.get("freeAvail", true) else 0
	return max(0, int(ceil(float(cost - free) / u.mob)))

func _compute_reach() -> void:
	reachable = {}
	if sel >= 0 and units[sel].ap > 0:
		var r := mesh.reach(units[sel].cell, budget(units[sel]), _occupied(sel))
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
	if res.dmg > 0: _flash(hit_tgt, str(res.dmg), Color(1, 0.5, 0.4)); _hit_react(hit_tgt)
	else: _flash(hit_tgt, res.txt, Color(0.85, 0.85, 0.9))
	if res.killed: _shake(4)
	for u in units:
		if u.hp <= 0 and is_instance_valid(u.node): u.node.visible = false
	_place(att)
	_compute_reach(); _refresh(); _check_end()

# réaction visuelle au coup : flash blanc bref de la sphère
func _hit_react(u) -> void:
	if not u.has("mat") or u.mat == null: return
	u.mat.emission = Color(1, 1, 1)
	var tw := create_tween(); tw.tween_property(u.mat, "emission", _team_color(u.team) * 0.32, 0.28)

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

# ---------- capacités joueur : barre + ciblage ----------
func _use_ability(id: String) -> void:
	if sel < 0 or turn != "player": return
	var u = units[sel]
	if u.ap <= 0 or on_cd(u, id): return
	var t: String = ABIL[id].target
	if t == "self":
		var ok := false
		match id:
			"vanish": ok = exec_vanish(u)
			"taunt": ok = exec_taunt(u)
			"wall": ok = exec_wall(u)
			"holdline": ok = exec_holdline(u)
		armed = ""; _compute_reach(); _refresh()
	else:
		armed = id; _refresh()

func _resolve_armed(cell: int) -> void:
	var u = units[sel]; var id := armed; armed = ""
	var t: String = ABIL[id].target
	var ui := _unit_at(cell)
	var ok := false
	if t == "cell":
		match id:
			"smoke": ok = exec_smoke(u, cell)
			"blast": ok = exec_blast(u, cell)
			"breach": ok = exec_breach(u, cell)
			"cracker": ok = exec_cracker(u, cell)
	elif t == "enemy" and ui >= 0 and units[ui].team == "enemy":
		match id:
			"frost": ok = exec_frost(u, units[ui])
			"shove": ok = exec_shove(u, units[ui])
			"charge": ok = exec_charge(u, units[ui])
			"shadowstrike": ok = exec_shadowstrike(u, units[ui])
	elif t == "ally" and ui >= 0 and units[ui].team == "player":
		match id:
			"heal": ok = exec_heal(u, units[ui])
			"potion": ok = exec_potion(u, units[ui])
			"rally": ok = exec_rally(u, units[ui])
	for o in units: if o.hp <= 0 and is_instance_valid(o.node): o.node.visible = false
	_compute_reach(); _refresh(); _check_end()

func _click(screen: Vector2) -> void:
	if turn != "player" or over: return
	var cell := _pick_cell(screen)
	if cell < 0: return
	if armed != "":
		_resolve_armed(cell); return
	var ui := _unit_at(cell)
	if ui >= 0 and units[ui].team == "player":
		sel = ui; _compute_reach(); _refresh(); return
	if sel >= 0:
		var u = units[sel]
		if ui >= 0 and units[ui].team == "enemy":
			if _can_attack(u, units[ui]): _do_attack(sel, ui)
			return
		if reachable.has(cell) and u.ap > 0:
			u.ap -= ap_for_move(u, reachable[cell]); u.freeAvail = false
			u.facing = atan2(mesh.cells[cell].cy - mesh.cells[u.cell].cy, mesh.cells[cell].cx - mesh.cells[u.cell].cx)
			u.cell = cell; _place(u); react_to(u); detect_enemies(); _compute_reach(); _refresh()

# ---------- tours ----------
func _begin_turn(team: String) -> void:
	for u in units:
		if u.team != team or u.hp <= 0: continue
		u.ap = AP_MAX - (1 if u.slowed else 0); u.slowed = false
		if u.stunned: u.ap = 0; u.stunned = false
		u.reacted = false; u.bracing = false; u["overwatch"] = false; u.freeAvail = true
		if team == "player": u["hidden"] = false; u["taunt"] = false; u.wallStance = false
	tick_cd(team)
	if team == "player":   # nouveau round joueur : compteur de tours + dissipation de la fumée
		turn_num += 1
		for k in mesh.smoke.keys():
			mesh.smoke[k] -= 1
			if mesh.smoke[k] <= 0: mesh.smoke.erase(k)

func _end_turn() -> void:
	if turn != "player" or over: return
	turn = "enemy"; sel = -1; reachable = {}; _refresh()
	_begin_turn("enemy")
	await _enemy_turn()
	_begin_turn("player")
	turn = "player"; _check_end(); _refresh()

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
			var k: float = Combat.shot_from(mesh, units, e, e.cell, p, e.wtype) * 1000.0 - p.hp + (100000.0 if p.get("taunt", false) else 0.0)
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
		if not tgts.is_empty():
			var used := enemy_use_abil(e)
			if not used: used = enemy_shield_act(e, tgts)
			if used:
				detect_enemies(); _refresh(); await get_tree().create_timer(0.3).timeout
				if e.ap <= 0: continue
		if tgts.is_empty():
			var foe := _nearest_player(e)
			if foe >= 0:
				var d := mesh.reach(e.cell, budget(e), _occupied(i))
				var best: int = e.cell; var bd: int = mesh.hops(e.cell, units[foe].cell)
				for c in d:
					var h: int = mesh.hops(c, units[foe].cell)
					if h < bd: bd = h; best = c
				if best != e.cell:
					e.facing = atan2(mesh.cells[best].cy - mesh.cells[e.cell].cy, mesh.cells[best].cx - mesh.cells[e.cell].cx)
					e.ap -= ap_for_move(e, d[best]); e.freeAvail = false
					e.cell = best; _place(e); react_to(e); detect_enemies()
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
			var d := mesh.reach(e.cell, budget(e), _occupied(i))
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
			e.ap -= ap_for_move(e, d[best]); e.freeAvail = false
			e.facing = atan2(mesh.cells[best].cy - mesh.cells[e.cell].cy, mesh.cells[best].cx - mesh.cells[e.cell].cx)
			e.cell = best; _place(e); react_to(e); detect_enemies(); await get_tree().create_timer(0.18).timeout

func _end(msg: String, win: bool) -> void:
	over = true; armed = ""; reachable = {}; hud.text = "■ " + msg
	hud.text += "\n— retour au territoire dans un instant —"
	var t := get_tree().create_timer(2.4)
	t.timeout.connect(func(): mission_ended.emit(win))

func _check_end() -> void:
	if over: return
	# défaites communes
	for u in units:
		if u.team == "neutral" and u.get("hostage", false) and u.hp <= 0: return _end("Défaite — l'otage est tombé.", false)
	var guard := []
	for u in units: if u.team == "neutral" and not u.get("hostage", false) and not u.civ: guard.append(u)
	if guard.size() > 0:
		var aliveg := 0
		for u in guard: if u.hp > 0: aliveg += 1
		var need: int = protect_n if protect_n > 0 else guard.size()
		if aliveg < need: return _end("Défaite — le VIP est tombé.", false)
	if not units.any(func(u): return u.team == "player" and u.hp > 0): return _end("Défaite.", false)
	var no_enemies := not units.any(func(u): return u.team == "enemy" and u.hp > 0)
	match objective:
		"assassinate":
			if not units.any(func(u): return u.team == "enemy" and u.get("hvt", false) and u.hp > 0): _end("Victoire — cible éliminée !", true)
		"survive", "defend":
			if turn_num > survive_turns: _end("Victoire — position tenue !", true)
			elif no_enemies: _end("Victoire !", true)
		"extract":
			var on_exit := 0
			for u in units: if u.team == "player" and u.hp > 0 and exit_set.has(u.cell): on_exit += 1
			if on_exit >= extract_count: _end("Victoire — extraction réussie !", true)
		"rescue":
			if no_enemies: _end("Victoire — otage libéré !", true)
		_:
			if no_enemies: _end("Victoire !", true)

# ---------- HUD / surbrillance ----------
func _update_fog() -> void:
	compute_vis()
	for u in units:
		if not is_instance_valid(u.node): continue
		if u.hp <= 0: u.node.visible = false; continue
		# brouillard : un ennemi n'est visible que si une de ses cases est vue
		u.node.visible = (u.team != "enemy") or seen_cells.has(u.cell)

func _rebuild_abil_bar() -> void:
	if abil_bar == null: return
	for c in abil_bar.get_children(): c.queue_free()
	if sel < 0 or turn != "player": return
	var u = units[sel]
	var lbl := {"smoke":"Fumée","breach":"Brèche","shadowstrike":"Ombre","rally":"Rallie","vanish":"Estompe","taunt":"Provoc","holdline":"Ligne","wall":"Mur","blast":"Déflag","heal":"Soin","frost":"Givre","shove":"Repouss","charge":"Charge","cracker":"Grenade","potion":"Potion"}
	var ids: Array = (u.abil as Array).duplicate()
	if int(u.get("crackers", 0)) > 0: ids.append("cracker")   # grenade : arme, pas un perk
	if potions > 0: ids.append("potion")                       # soin : stock partagé
	for id in ids:
		if not ABIL.has(id): continue   # protect = passif
		var b := Button.new()
		var cd: int = (u.cd[id] if u.cd.has(id) else 0)
		var extra := ""
		if id == "cracker": extra = " x%d" % int(u.crackers)
		elif id == "potion": extra = " x%d" % potions
		elif cd > 0: extra = " (%d)" % cd
		b.text = str(lbl.get(id, id)) + extra
		b.disabled = cd > 0 or u.ap <= 0
		if armed == id: b.modulate = Color(1, 0.9, 0.4)
		b.pressed.connect(_use_ability.bind(id))
		abil_bar.add_child(b)

func _refresh() -> void:
	_update_fog()
	_update_markers()
	_rebuild_abil_bar()
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
	if over: hud.text = hud.text; return   # message de fin déjà posé
	hud.text = _obj_label() + "\n" + s

# paliers de déplacement : bleu (gratuit) / jaune (1 PA) / rouge (2 PA)
func _tier_col(t: int) -> Color:
	return [Color(0.30, 0.60, 1.0), Color(1.0, 0.85, 0.2), Color(0.95, 0.28, 0.24)][min(t, 2)]

# CONTOURS uniquement (bord externe + frontières de paliers) — pas de teinte des tuiles
func _draw_move_overlay(u) -> void:
	var line := SurfaceTool.new(); line.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tier := {}
	for cell in reachable: tier[cell] = ap_for_move(u, reachable[cell])
	for cell in reachable:
		var t: int = tier[cell]
		var top: float = _cell_top(cell) + 0.06
		var c = mesh.cells[cell]
		# une arête est tracée si elle borde une case hors-portée OU un palier supérieur (couleur du palier le plus coûteux)
		for nb in c.nb:
			var draw := false; var lc := _tier_col(t)
			if not reachable.has(nb): draw = true
			elif tier[nb] > t: draw = true; lc = _tier_col(tier[nb])
			if not draw: continue
			var seg = mesh.wall_seg.get(mesh.wkey(cell, nb))
			if seg == null: continue
			var p0 := Vector3(seg[0].x * S, top, seg[0].y * S)
			var p1 := Vector3(seg[1].x * S, top, seg[1].y * S)
			var dir := (p1 - p0); dir = dir.normalized() if dir.length() > 0.001 else Vector3(1, 0, 0)
			var perp := Vector3(-dir.z, 0, dir.x) * 0.10
			lc.a = 1.0
			for v in [p0 - perp, p1 + perp, p1 - perp, p0 - perp, p0 + perp, p1 + perp]:
				line.set_color(lc); line.add_vertex(v)
	var lm := StandardMaterial3D.new(); lm.vertex_color_use_as_albedo = true; lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lm.emission_enabled = true; lm.emission = Color(1, 1, 1); lm.emission_energy_multiplier = 0.5
	var lmi := MeshInstance3D.new(); lmi.mesh = line.commit(); lmi.material_override = lm; add_child(lmi); _markers.append(lmi)

func _update_markers() -> void:
	for m in _markers: m.queue_free()
	_markers.clear()
	for cell in exit_set.keys():   # zone d'extraction
		var ex := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.55; cm.bottom_radius = 0.55; cm.height = 0.06; ex.mesh = cm
		var mt := StandardMaterial3D.new(); mt.albedo_color = Color(0.4, 1.0, 0.5, 0.45); mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.emission_enabled = true; mt.emission = Color(0.3, 1.0, 0.4)
		ex.material_override = mt; ex.position = world(cell) + Vector3(0, 0.05, 0)
		add_child(ex); _markers.append(ex)
	if sel >= 0 and not reachable.is_empty(): _draw_move_overlay(units[sel])
	if sel >= 0 and units[sel].hp > 0:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 0.7; tm.outer_radius = 0.95; ring.mesh = tm
		var rm := StandardMaterial3D.new(); rm.albedo_color = Color(1, 1, 1); rm.emission_enabled = true; rm.emission = Color(1, 1, 1)
		ring.material_override = rm; ring.position = world(units[sel].cell) + Vector3(0, 0.12, 0)
		add_child(ring); _markers.append(ring)
