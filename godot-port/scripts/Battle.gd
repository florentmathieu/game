extends Node3D
# Tranche combat 3D (vue XCOM, élévation visible). Règles = rules/ (port fidèle).
# Maillage Voronoï extrudé, sphères par équipe (orientées = bec), murets, sélection/déplacement/tir.

const VMesh := preload("res://rules/Mesh.gd")
const Data := preload("res://rules/Data.gd")
const Combat := preload("res://rules/Combat.gd")
const Hazard := preload("res://rules/Hazard.gd")

signal mission_ended(win)

const S := 0.06          # px -> unités monde
const STEP := 2.2        # hauteur monde par niveau d'élévation
const AP_MAX := 2
const MOB := 3           # mobilité de base (plate) par PA — cf. MOB global d'index.html

var CL := {}
var mesh: VMesh
var units: Array = []
var sel := -1
var reachable := {}
var hover_cell := -1
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
var _wall_nodes: Array = []
var armed := ""
# --- HUD reproduit du HTML : roster (haut g.), actions (bas g.), journal repliable (bas dr.), message ---
var roster_box: VBoxContainer
var acts_box: VBoxContainer
var msg_label: Label
var log_box: VBoxContainer
var journal: VBoxContainer
var journal_collapsed := false
var _log_lines: Array = []
var _msg := ""
var objective := "eliminate"
var survive_turns := 6
var extract_count := 1
var protect_n := 0
var exit_set := {}
var turn_num := 1
var over := false
var fast := false           # mode simulation : saute les temporisations d'animation
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
	Hazard.seed_with(seed_value ^ 0x1a2b3c4d)   # hasard de combat reproductible par mission
	_setup_world()
	var authored: bool = mis.has("map")
	if authored:
		_gen_authored(mis.map)        # carte dessinée dans l'éditeur HTML
	else:
		_gen_battle(seed_value)
		mesh.distort(_corrupt_level())   # distorsion progressive : le terrain se tord à mesure qu'on avance
	_terrain_root = Node3D.new(); add_child(_terrain_root)
	_build_tiles()
	_build_walls()
	if authored: _spawn_authored(mis.map)
	else: _spawn_units()
	setup_objective()
	_setup_camera()
	compute_vis(); detect_enemies()
	for i in units.size():
		if units[i].team == "player": sel = i; break
	_compute_reach()
	_jlog("▶ " + _obj_label())
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
	if mis.has("map"):                       # carte authored : objectif + paramètres du JSON, neutres déjà placés
		var mp: Dictionary = mis.map
		objective = String(mp.get("objective", "eliminate"))
		survive_turns = int(mp.get("surviveTurns", 6))
		extract_count = int(mp.get("extractCount", 1))
		protect_n = int(mp.get("protect", 0)) if mp.get("protect") != null else 0
		exit_set = {}
		for c in mp.get("exitZone", []): exit_set[int(c)] = true
		return
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
	_build_hud()

# ---------- HUD (reproduction fidèle du HTML) ----------
const COL_PANEL := Color(0.047, 0.035, 0.024, 0.86)
const COL_BORDER := Color(0.353, 0.27, 0.188)
const COL_NAME := Color(0.749, 0.902, 1.0)
const COL_SUB := Color(0.604, 0.541, 0.455)
const COL_ST := Color(0.624, 0.827, 0.925)
const COL_GOLD := Color(0.792, 0.635, 0.29)
const COL_SELBG := Color(0.18, 0.141, 0.063, 0.92)

func _stylebox(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new(); sb.bg_color = bg
	sb.border_color = border; sb.set_border_width_all(1); sb.set_corner_radius_all(radius)
	sb.content_margin_left = 9; sb.content_margin_right = 9; sb.content_margin_top = 5; sb.content_margin_bottom = 5
	return sb

# police avec repli emoji (Noto Color Emoji) pour que les icônes d'action/statut s'affichent
func _emoji_theme() -> Theme:
	var th := Theme.new()
	var emoji = load("res://assets/NotoColorEmoji.ttf")
	if emoji != null:
		var fv := FontVariation.new(); fv.base_font = ThemeDB.fallback_font
		fv.fallbacks = [emoji]; th.default_font = fv
	return th

func _build_hud() -> void:
	if fast: return
	var ci := CanvasLayer.new(); add_child(ci)
	var th := _emoji_theme()
	# objectif / tour : petite ligne discrète en haut au centre
	hud = Label.new(); hud.add_theme_color_override("font_color", COL_GOLD)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.anchor_left = 0.0; hud.anchor_right = 1.0; hud.offset_top = 8; hud.offset_bottom = 30
	hud.theme = th; ci.add_child(hud)
	# roster : cartes des persos, haut-gauche
	roster_box = VBoxContainer.new(); roster_box.add_theme_constant_override("separation", 5)
	roster_box.theme = th; roster_box.position = Vector2(12, 40); ci.add_child(roster_box)
	# bas-gauche : message au-dessus des boutons d'action (comme #hud-bl)
	var bl := VBoxContainer.new(); bl.add_theme_constant_override("separation", 6); bl.theme = th
	bl.anchor_top = 1.0; bl.anchor_bottom = 1.0; bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bl.offset_left = 12; bl.offset_bottom = -12; ci.add_child(bl)
	msg_label = Label.new(); msg_label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.74))
	var msb := _stylebox(COL_PANEL, COL_BORDER, 8); msg_label.add_theme_stylebox_override("normal", msb)
	bl.add_child(msg_label)
	acts_box = VBoxContainer.new(); acts_box.add_theme_constant_override("separation", 6); bl.add_child(acts_box)
	# journal repliable, bas-droite (#journal)
	var jp := PanelContainer.new()
	jp.add_theme_stylebox_override("panel", _stylebox(Color(0.047, 0.035, 0.024, 0.9), COL_BORDER, 8))
	jp.anchor_left = 1.0; jp.anchor_right = 1.0; jp.anchor_top = 1.0; jp.anchor_bottom = 1.0
	jp.grow_horizontal = Control.GROW_DIRECTION_BEGIN; jp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	jp.offset_right = -12; jp.offset_bottom = -12; jp.custom_minimum_size = Vector2(300, 0)
	jp.theme = th; ci.add_child(jp)
	journal = VBoxContainer.new(); jp.add_child(journal)
	var jhd := Button.new(); jhd.text = "📜 Journal  ▾"; jhd.flat = true
	jhd.add_theme_color_override("font_color", COL_GOLD); jhd.alignment = HORIZONTAL_ALIGNMENT_LEFT
	jhd.pressed.connect(_toggle_journal); journal.add_child(jhd)
	log_box = VBoxContainer.new(); log_box.add_theme_constant_override("separation", 1); journal.add_child(log_box)
	journal.set_meta("hd", jhd)

func _toggle_journal() -> void:
	journal_collapsed = not journal_collapsed
	log_box.visible = not journal_collapsed
	var hd = journal.get_meta("hd")
	if hd: hd.text = "📜 Journal  " + ("▸" if journal_collapsed else "▾")

func _set_msg(t: String) -> void:
	_msg = t
	if msg_label: msg_label.text = t; msg_label.visible = t != ""

func _jlog(t: String) -> void:
	_log_lines.append(t)
	if _log_lines.size() > 40: _log_lines.pop_front()
	if log_box == null: return
	for c in log_box.get_children(): c.queue_free()
	var start: int = max(0, _log_lines.size() - 12)
	for i in range(start, _log_lines.size()):
		var l := Label.new(); l.text = _log_lines[i]
		l.add_theme_font_size_override("font_size", 12); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(284, 0); l.add_theme_color_override("font_color", Color(0.82, 0.76, 0.66))
		log_box.add_child(l)

# ---------- génération ----------
func _gen_battle(seed_value: int) -> void:
	mesh = VMesh.new()
	mesh.generate(seed_value, 720.0, 560.0, 50.0, 28.0)
	mesh.decorate(seed_value ^ 0x9e37, 0.30)

# carte AUTHORED (dessinée dans l'éditeur HTML) : maillage + murets reconstruits depuis le JSON
func _gen_authored(mp: Dictionary) -> void:
	mesh = VMesh.new()
	mesh.load_from_data(mp.get("cells", []), mp.get("walls", []))

# unités d'une carte authored : ennemis/neutres depuis le JSON, joueurs = escouade déployée
func _spawn_authored(mp: Dictionary) -> void:
	var player_cells := []
	for ud in mp.get("units", []):
		var team := String(ud.get("team", "enemy"))
		if team == "player": player_cells.append(int(ud.get("cell", 0))); continue
		_make_unit(team, String(ud.get("cls", "soldat")), int(ud.get("cell", 0)))
		var u = units[-1]
		if bool(ud.get("asleep", false)): u.asleep = true
		if bool(ud.get("hvt", false)): u["hvt"] = true
		if bool(ud.get("hostage", false)): u["hostage"] = true
		if bool(ud.get("guard", false)): u.civ = false
		if ud.has("pod"): u.pod = int(ud.pod)
		if ud.has("facing"): u.facing = float(ud.facing)
		if u.get("node") != null: u.node.rotation.y = -float(u.facing)
	var pass_cells := []
	for c in mesh.cells:
		if mesh.passable(c.id): pass_cells.append(c.id)
	var pi := 0
	for spec in _deploy_squad():
		var cell := -1
		if pi < player_cells.size(): cell = int(player_cells[pi])
		else:
			for id in pass_cells:
				if _unit_at(id) < 0: cell = id; break
		if cell < 0: continue
		_make_unit("player", spec.cls, cell, spec.get("mem", {})); pi += 1

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
	if fast: return
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
	if fast: return
	_wall_nodes.clear()
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
		var mt := StandardMaterial3D.new(); mt.albedo_color = Color(0.55, 0.55, 0.6); mt.roughness = 0.9   # pierre grise (≠ contour jaune)
		bar.material_override = mt
		bar.position = Vector3(midp.x, top, midp.y)
		bar.rotation.y = -atan2(p1.y - p0.y, p1.x - p0.x)
		_terrain_root.add_child(bar)
		_wall_nodes.append({"node": bar, "a": x, "b": y})   # pour le brouillard : muret masqué si ses 2 cases sont hors vue

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
		"spellsCast":0, "dmgTaken":0, "kills":0, "crackers":int(d.get("crackers", 0)), "scatterBonus":0, "mobBonus":0}
	if wtype == "ranged" and w.ranged.has("clip"): u.clip = int(w.ranged.clip); u.ammo = int(w.ranged.clip)
	if team == "player":
		var ids: Array = mem.get("perks", []) if not mem.is_empty() else []
		if ids.is_empty() and mem.is_empty():   # combat autonome : arbre A complet (démo)
			for g in Data.perks().get(cls, []): ids.append(g.A.id)
		apply_perk_mods(u, ids)
		if not mem.is_empty():
			u.max = int(mem.get("maxHp", u.max)); u.hp = int(mem.get("deployHp", u.max))
	if fast:                       # simulation : pas de noeuds 3D
		u.node = null; u.mat = null; units.append(u); return
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
	units.append(u); u.node.position = world(u.cell) + Vector3(0, 0.85, 0); u.node.rotation.y = -float(u.facing)

# placement : glisse vers la case (animation de déplacement) sauf en simulation
func _place(u) -> void:
	if u.get("node") == null: return
	u.node.rotation.y = -float(u.facing)
	var tgt := world(u.cell) + Vector3(0, 0.85, 0)
	if fast:
		u.node.position = tgt; return
	var tw := create_tween()
	tw.tween_property(u.node, "position", tgt, 0.22).set_trans(Tween.TRANS_SINE)

# FX d'attaque : traceur lumineux (tir) ou brève fente (mêlée)
func _attack_fx(att, tgt, ranged: bool) -> void:
	if fast or att.get("node") == null or tgt.get("node") == null: return
	var a := world(att.cell) + Vector3(0, 0.9, 0)
	var b := world(tgt.cell) + Vector3(0, 0.9, 0)
	if ranged:
		var p := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.13; sm.height = 0.26; p.mesh = sm
		var m := StandardMaterial3D.new(); m.albedo_color = Color(1, 0.9, 0.5)
		m.emission_enabled = true; m.emission = Color(1, 0.8, 0.35); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.material_override = m; p.position = a; add_child(p)
		var tw := create_tween()
		tw.tween_property(p, "position", b, 0.16)
		tw.tween_callback(p.queue_free)
	else:
		var orig: Vector3 = att.node.position
		var tw := create_tween()
		tw.tween_property(att.node, "position", orig.lerp(b, 0.45), 0.09)
		tw.tween_property(att.node, "position", orig, 0.13)

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
	return [{"cls":"soldat"}, {"cls":"assassin"}, {"cls":"sapeur"}, {"cls":"mage"}]

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
	_spawn_enemy_pods(pass_cells, used)

# Répartition ennemie en PODS (port de genMission) : ancres par échantillonnage « point le plus
# éloigné » + biais d'intérieur (les pods s'étalent au lieu de se masser au bord opposé), puis
# le nombre d'ennemis est réparti en groupes autour de chaque ancre (rayon 2).
func _spawn_enemy_pods(pass_cells: Array, used: Dictionary) -> void:
	var anchor_cell: int = units[0].cell if not units.is_empty() else pass_cells[0]
	var intf := func(id: int) -> int:
		var c := 0
		for n in mesh.cells[id].nb: if mesh.passable(n): c += 1
		return c
	# profondeur (hops depuis le déploiement) des cases libres
	var depth := {}
	for id in pass_cells:
		if not used.has(id): depth[id] = mesh.hops(anchor_cell, id)
	var maxd := 0
	for id in depth: maxd = max(maxd, int(depth[id]))
	var pod_min: int = max(3, int(maxd * 0.45))
	# candidats d'ancre : profonds ET hors vue directe du déploiement (sinon repli progressif)
	var cand := []
	for id in depth:
		if int(depth[id]) >= pod_min and not mesh.los(anchor_cell, id): cand.append(id)
	if cand.size() < 1:
		for id in depth: if int(depth[id]) >= min(pod_min, 3): cand.append(id)
	if cand.is_empty():
		for id in depth: if id != anchor_cell: cand.append(id)
	if cand.is_empty(): return
	var pod_count: int = clampi(int(round(n_enemies / 2.0)), 1, 4)
	# 1re ancre : profonde mais pas collée au bord ; suivantes : loin des précédentes + intérieur
	var anchors := []
	var first: int = cand[0]; var fbs := -1.0e9
	for id in cand:
		var sc: float = float(depth[id]) * 0.4 + float(intf.call(id)) * 1.6
		if sc > fbs: fbs = sc; first = id
	anchors.append(first)
	while anchors.size() < pod_count and anchors.size() < cand.size():
		var best := -1; var bs := -1.0e9
		for id in cand:
			if anchors.has(id): continue
			var spread: int = 1 << 30
			for a in anchors: spread = min(spread, mesh.hops(a, id))
			var sc: float = float(spread) * 3.0 + float(intf.call(id)) * 1.2 + float(depth[id]) * 0.15
			if sc > bs: bs = sc; best = id
		if best < 0: break
		var sp: int = 1 << 30
		for a in anchors: sp = min(sp, mesh.hops(a, best))
		if sp < 2: break               # évite l'agglutinement des pods
		anchors.append(best)
	# répartition déterministe du nombre d'ennemis sur les pods
	var pn: int = max(1, anchors.size())
	var sizes := []
	for i in pn: sizes.append(int(n_enemies / pn) + (1 if i < n_enemies % pn else 0))
	var epool := ["shieldbearer", "archer", "shieldbearer", "emage", "brute", "archer", "shieldbearer", "brute"]
	var ei := 0
	for pi in anchors.size():
		var anc: int = anchors[pi]
		var ball := {}; var q := [anc]; ball[anc] = 0    # pool autour de l'ancre (rayon 2)
		while q.size():
			var id: int = q.pop_front()
			if int(ball[id]) >= 2: continue
			for n in mesh.cells[id].nb:
				if mesh.passable(n) and not ball.has(n): ball[n] = int(ball[id]) + 1; q.append(n)
		var spots := []
		for id in ball: if not used.has(id): spots.append(id)
		spots.sort_custom(func(a, b): return int(ball[a]) < int(ball[b]))
		for s in int(sizes[pi]):
			if spots.is_empty(): break
			var cell: int = spots.pop_front()
			if used.has(cell): continue
			_make_unit("enemy", epool[ei % epool.size()], cell); used[cell] = true
			units[-1].asleep = true; units[-1].pod = pi; units[-1].home = cell; ei += 1
	# garde-fou : si les pods n'ont pas placé tout l'effectif (carte ouverte, peu d'ancres),
	# complète au pod le plus loin du déploiement parmi les cases libres profondes.
	if ei < n_enemies:
		var anchor0: int = units[0].cell if not units.is_empty() else pass_cells[0]
		var rest := []
		for c in mesh.cells:
			if mesh.passable(c.id) and not used.has(c.id): rest.append(c.id)
		rest.sort_custom(func(a, b): return mesh.hops(anchor0, a) > mesh.hops(anchor0, b))
		for cell in rest:
			if ei >= n_enemies: break
			_make_unit("enemy", epool[ei % epool.size()], cell); used[cell] = true
			units[-1].asleep = true; units[-1].pod = (ei % max(1, anchors.size())); units[-1].home = cell; ei += 1

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
			var dmg := Data.BLAST_MIN + Hazard.rint(Data.BLAST_MAX - Data.BLAST_MIN + 1)
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
	var stun := Hazard.chance(50.0)
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
	if fast: return
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
		if m.has("mob"): u.mobBonus += m.mob
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
	var imp: int = cand[Hazard.rint(cand.size())] if not cand.is_empty() else target
	for o in units:
		if o.hp <= 0: continue
		if mesh.hops(imp, o.cell) <= int(cr.radius):
			var dmg := int(cr.dmg_min) + Hazard.rint(int(cr.dmg_max) - int(cr.dmg_min) + 1)
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
		if n != u.cell and mesh.hops(u.cell, n) > _mob_of(u): continue
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
	# garde le même but tant qu'il est valide (dans la laisse ET la zone du pod) — sinon en (re)choisit un
	var goal: int = int(e.get("patrolGoal", -1))
	var valid: bool = goal >= 0 and goal != e.cell and ball.has(goal) and pod_owns(e, goal) and not occ.has(goal)
	if not valid:
		var zone := []
		for id in ball:
			if pod_owns(e, id) and (id == e.cell or not occ.has(id)): zone.append(id)
		goal = zone[Hazard.rint(zone.size())] if not zone.is_empty() else e.cell
		e["patrolGoal"] = goal
	if goal == e.cell: return
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
	pivot = Node3D.new(); pivot.position = Vector3(mesh.W * S * 0.5, 0, mesh.H * S * 0.5); add_child(pivot)   # centre = vraie taille de carte (procédurale OU dessinée)
	cam = Camera3D.new(); cam.fov = 46; pivot.add_child(cam); _update_cam()

func _update_cam() -> void:
	if not cam: return
	var pitch := deg_to_rad(52.0)
	cam.position = Vector3(sin(_yaw) * cos(pitch) * _dist, sin(pitch) * _dist, cos(_yaw) * cos(pitch) * _dist)
	cam.look_at(pivot.global_position, Vector3.UP)

# secousse de caméra sur impact (grenade, brèche, gros coup)
func _shake(power: float) -> void:
	if fast: return
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
# mobilité de DÉPLACEMENT = base plate (3) + perks (cf. mobOf d'index.html) ; le mob de classe ne sert pas au mouvement
func _mob_of(u) -> int: return MOB + int(u.get("mobBonus", 0))
func budget(u) -> int: return (_free_mp(u) if u.get("freeAvail", true) else 0) + u.ap * _mob_of(u)
func ap_for_move(u, cost: int) -> int:
	var free: int = _free_mp(u) if u.get("freeAvail", true) else 0
	return max(0, int(ceil(float(cost - free) / _mob_of(u))))

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
	_attack_fx(att, hit_tgt, att.wtype == "ranged")   # traceur (tir) / fente (mêlée)
	if hit_tgt.team == "enemy" and hit_tgt.hp > 0: wake_enemy(hit_tgt)   # le bruit réveille le pod visé
	if res.dmg > 0: _flash(hit_tgt, str(res.dmg), Color(1, 0.5, 0.4)); _hit_react(hit_tgt)
	else: _flash(hit_tgt, res.txt, Color(0.85, 0.85, 0.9))
	var who: String = str(att.get("name", CL[att.cls].name)); var vic: String = str(hit_tgt.get("name", CL[hit_tgt.cls].name))
	if res.dmg > 0: _jlog("⚔ %s touche %s (−%d)" % [who, vic, res.dmg])
	else: _jlog("✦ %s — %s sur %s" % [who, str(res.txt), vic])
	if res.killed: _shake(4); _jlog("✝ %s tombe." % vic)
	for u in units:
		if u.hp <= 0 and is_instance_valid(u.node): u.node.visible = false
	if att.get("node") != null: att.node.rotation.y = -float(att.facing)   # l'attaquant ne change que d'orientation (la fente gère la position)
	_compute_reach(); _refresh(); _check_end()

# réaction visuelle au coup : flash blanc bref de la sphère
func _hit_react(u) -> void:
	if not u.has("mat") or u.mat == null: return
	u.mat.emission = Color(1, 1, 1)
	var tw := create_tween(); tw.tween_property(u.mat, "emission", _team_color(u.team) * 0.32, 0.28)

func _flash(u, txt: String, col: Color) -> void:
	if fast: return
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

# rotation clavier fluide : pivote tant que Q/E (ou ←/→) est tenue
func _process(delta: float) -> void:
	if cam == null: return
	var d := 0.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT): d -= 1.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_RIGHT): d += 1.0
	if d != 0.0: _yaw += d * 1.8 * delta; _update_cam()
	# survol : suit la case sous le curseur pour l'aperçu de chemin + paliers progressifs
	if not fast and sel >= 0 and turn == "player" and not over:
		var hc := _pick_cell(get_viewport().get_mouse_position())
		if hc != hover_cell:
			hover_cell = hc; _update_markers()

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
	turn = "enemy"; sel = -1; reachable = {}; hover_cell = -1; _set_msg(""); _jlog("— Tour ennemi —"); _refresh()
	_begin_turn("enemy")
	await _enemy_turn()
	_begin_turn("player")
	turn = "player"; _jlog("— Tour joueur %d —" % turn_num); _check_end(); _refresh()

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
			patrol_step(e); detect_enemies(); _refresh()
			if not fast: await get_tree().create_timer(0.04).timeout
			continue
		# cibles vues par cet ennemi
		var tgts := []
		for j in units.size():
			if units[j].team == "player" and units[j].hp > 0 and Combat.enemy_sees_p(mesh, e, units[j]): tgts.append(j)
		if not tgts.is_empty():
			var used := enemy_use_abil(e)
			if not used: used = enemy_shield_act(e, tgts)
			if used:
				detect_enemies(); _refresh()
				if not fast: await get_tree().create_timer(0.3).timeout
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
			if not fast: await get_tree().create_timer(0.12).timeout
			continue
		var guard := 0
		while e.ap > 0 and guard < 4:
			guard += 1
			var bt := _best_target(e)
			if bt >= 0:
				_do_attack(i, bt)
				if not fast: await get_tree().create_timer(0.25).timeout
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
			e.cell = best; _place(e); react_to(e); detect_enemies()
			if not fast: await get_tree().create_timer(0.18).timeout

func _end(msg: String, win: bool) -> void:
	over = true; armed = ""; reachable = {}
	if hud != null: hud.text = "■ " + msg + "\n— retour au territoire dans un instant —"
	_jlog("■ " + msg)
	var t := get_tree().create_timer(2.4)
	t.timeout.connect(_emit_end.bind(win))

func _emit_end(win: bool) -> void:
	mission_ended.emit(win)

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
	for w in _wall_nodes:   # muret visible si l'une de ses deux cases est dans le champ de vision
		if is_instance_valid(w.node): w.node.visible = seen_cells.has(w.a) or seen_cells.has(w.b)
	_build_fog()

# brouillard de guerre : voile sombre sur les cases hors champ de vision des joueurs (LdV + portée 7)
var _fog_nodes: Array = []
var _fog_sig := ""
func _build_fog() -> void:
	if fast: return
	var keys := seen_cells.keys(); keys.sort()
	var sig := str(keys)
	if sig == _fog_sig and not _fog_nodes.is_empty(): return   # rien n'a changé
	_fog_sig = sig
	for n in _fog_nodes: n.queue_free()
	_fog_nodes.clear()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := Color(0.02, 0.02, 0.035, 0.66)
	var any := false
	for c in mesh.cells:
		if seen_cells.has(c.id): continue
		any = true
		var top: float = c.elev * STEP + 0.04
		var ctr := Vector3(c.cx * S, top, c.cy * S); var p: Array = c.poly
		for k in p.size():
			var a: Vector2 = p[k]; var b: Vector2 = p[(k + 1) % p.size()]
			st.set_color(col); st.add_vertex(ctr)
			st.set_color(col); st.add_vertex(Vector3(b.x * S, top, b.y * S))
			st.set_color(col); st.add_vertex(Vector3(a.x * S, top, a.y * S))
	if not any: return
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat
	add_child(mi); _fog_nodes.append(mi)

# ----- roster (cartes des persos, haut-gauche) — reproduit renderRoster() -----
func _render_roster() -> void:
	if roster_box == null: return
	for c in roster_box.get_children(): c.queue_free()
	for i in units.size():
		var u = units[i]
		if u.team != "player": continue
		var card := PanelContainer.new(); card.custom_minimum_size = Vector2(168, 0)
		var seld: bool = (i == sel); var dead: bool = u.hp <= 0; var spent: bool = (u.ap <= 0 and turn == "player")
		var bg := COL_SELBG if seld else COL_PANEL
		var bd := COL_GOLD if seld else COL_BORDER
		card.add_theme_stylebox_override("panel", _stylebox(bg, bd, 8))
		if dead: card.modulate = Color(1, 1, 1, 0.45)
		elif spent: card.modulate = Color(1, 1, 1, 0.7)
		card.gui_input.connect(_card_input.bind(i))
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(v)
		var nm := RichTextLabel.new(); nm.bbcode_enabled = true; nm.fit_content = true
		nm.scroll_active = false; nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stars := ""
		if int(u.get("grade", 0)) > 0: stars = " [color=#e0b341]%s[/color]" % "★".repeat(int(u.grade))
		nm.text = "[color=#bfe6ff][b]%s[/b][/color] [color=#9a8a74]%s%s[/color]" % [u.name, CL[u.cls].name, stars]
		v.add_child(nm)
		var bar := ColorRect.new(); bar.color = Color(0.227, 0.192, 0.157); bar.custom_minimum_size = Vector2(150, 5)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new(); fill.color = Color(0.435, 0.816, 0.435)
		fill.anchor_bottom = 1.0; fill.offset_right = 150.0 * clampf(float(max(0, u.hp)) / float(u.max), 0, 1)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; bar.add_child(fill); v.add_child(bar)
		var st := Label.new(); st.add_theme_font_size_override("font_size", 12); st.add_theme_color_override("font_color", COL_ST)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icons := ""
		if u.get("overwatch", false): icons += (" · 👁🏹" if u.get("owMode", "") == "ranged" else " · 👁")
		if u.get("bracing", false): icons += " · 🛡"
		if u.get("stunned", false): icons += " · ✦"
		if u.get("slowed", false): icons += " · ❄"
		if int(u.get("crackers", 0)) > 0: icons += " · 💣%d" % int(u.crackers)
		st.text = "PV %d/%d · PA %s%s" % [max(0, u.hp), u.max, (str(u.ap) + "/" + str(AP_MAX) if u.hp > 0 else "–"), icons]
		v.add_child(st)
		roster_box.add_child(card)

func _card_input(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_select_unit(i)

func _select_unit(i: int) -> void:
	if i < 0 or i >= units.size(): return
	if units[i].hp > 0 and turn == "player" and not over:
		sel = i; armed = ""; hover_cell = -1; _compute_reach(); _refresh()

# ----- barre d'action (bas-gauche) — reproduit renderActs() -----
var _act_n := 0
func _act_btn(icon: String, on: bool, cb: Callable) -> void:
	_act_n += 1
	var b := Button.new(); b.custom_minimum_size = Vector2(64, 64); b.text = icon
	b.add_theme_font_size_override("font_size", 26)
	var bg := Color(0.18, 0.29, 0.125) if on else Color(0.047, 0.035, 0.024, 0.9)
	var bd := COL_GOLD if on else COL_BORDER
	b.add_theme_stylebox_override("normal", _stylebox(bg, bd, 9))
	b.add_theme_stylebox_override("hover", _stylebox(bg.lightened(0.05), bd, 9))
	b.add_theme_stylebox_override("pressed", _stylebox(bg, COL_GOLD, 9))
	var num := Label.new(); num.text = str(_act_n); num.add_theme_font_size_override("font_size", 11)
	num.position = Vector2(6, 3); num.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(num)
	b.pressed.connect(cb); acts_box.add_child(b)

func _act_btn_cd(icon: String, cd: int) -> void:
	var b := Button.new(); b.custom_minimum_size = Vector2(64, 64); b.text = icon; b.disabled = true
	b.add_theme_font_size_override("font_size", 26); b.modulate = Color(1, 1, 1, 0.6)
	b.add_theme_stylebox_override("disabled", _stylebox(Color(0.047, 0.035, 0.024, 0.9), Color(0.227, 0.173, 0.11), 9))
	var n := Label.new(); n.text = str(cd); n.add_theme_font_size_override("font_size", 15)
	n.position = Vector2(44, 3); n.add_theme_color_override("font_color", Color(0.498, 0.69, 0.847))
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(n)
	acts_box.add_child(b)

func _render_acts() -> void:
	if acts_box == null: return
	for c in acts_box.get_children(): c.queue_free()
	if sel < 0 or turn != "player" or over: return
	var u = units[sel]; _act_n = 0
	var can_shoot: bool = u.w.has("ranged") and (not u.has("clip") or u.ammo > 0)
	if can_shoot: _act_btn("🏹", u.wtype == "ranged" and u.w.has("melee"), _act_aim.bind("ranged"))
	if u.w.has("melee"): _act_btn(("🗡" if u.get("flank") else "⚔️"), u.wtype == "melee" and can_shoot, _act_aim.bind("melee"))
	if u.ap > 0 and can_shoot: _act_btn("👁🏹", u.get("overwatch", false) and u.get("owMode", "") == "ranged", _act_overwatch.bind("ranged"))
	if u.ap > 0 and u.w.has("melee"): _act_btn("👁", u.get("overwatch", false) and u.get("owMode", "") == "melee", _act_overwatch.bind("melee"))
	if u.w.has("cracker") and int(u.get("crackers", 0)) > 0 and u.ap > 0: _act_btn("💣", armed == "cracker", _use_ability.bind("cracker"))
	if potions > 0 and u.ap > 0: _act_btn("🧪", armed == "potion", _use_ability.bind("potion"))
	if u.has("clip") and u.ammo < u.clip and u.ap > 0: _act_btn("🔄", false, _act_reload)
	if int(u.get("shieldBlock", 0)) > 0 and u.ap > 0 and not u.get("bracing", false): _act_btn("🛡", false, _act_brace)
	for aid in u.abil:
		if not ABIL.has(aid): continue
		if aid == "vanish" and u.get("vanishUsed", false): continue
		var cd: int = (u.cd[aid] if u.cd.has(aid) else 0)
		if cd > 0: _act_btn_cd(ABIL[aid].icon, cd)
		elif u.ap > 0: _act_btn(ABIL[aid].icon, armed == aid, _use_ability.bind(aid))
	_act_btn("🙅", false, _end_turn)

func _act_aim(mode: String) -> void:
	if sel < 0: return
	units[sel].wtype = mode; armed = ""
	_set_msg("Clique une cible ennemie à portée." if mode == "ranged" else "Clique un ennemi adjacent.")
	_refresh()

func _act_overwatch(mode: String) -> void:
	if sel < 0: return
	var u = units[sel]; if u.ap <= 0: return
	u.overwatch = true; u.owMode = mode; u.reacted = false; u.ap = 0
	_set_msg("Vigilance — tir de réaction si un ennemi bouge à portée."); armed = ""
	_compute_reach(); _refresh()

func _act_reload() -> void:
	if sel < 0: return
	var u = units[sel]; if u.ap <= 0 or not u.has("clip"): return
	u.ap -= 1; u.ammo = u.clip; _set_msg("Rechargé."); _refresh()

func _act_brace() -> void:
	if sel < 0: return
	var u = units[sel]; if u.ap <= 0: return
	u.ap -= 1; u.bracing = true; u.freeAvail = false; _set_msg("En garde — défense renforcée ce tour."); _refresh()

func _refresh() -> void:
	if fast: return
	_update_fog()
	_update_markers()
	_render_roster()
	_render_acts()
	var live_e := 0
	for u in units: if u.team == "enemy" and u.hp > 0: live_e += 1
	if over: return   # message de fin déjà posé
	if hud != null:
		hud.text = "%s   ·   tour : %s   ·   ennemis : %d" % [_obj_label(), ("joueur" if turn == "player" else "ennemi"), live_e]

# paliers de déplacement : bleu (gratuit) / jaune (1 PA) / rouge (2 PA)
func _tier_col(t: int) -> Color:
	return [Color(0.30, 0.60, 1.0), Color(1.0, 0.85, 0.2), Color(0.95, 0.28, 0.24)][min(t, 2)]

# palier d'une case : 0 = gratuit (0 PA), 2 = consomme tout le PA restant, 1 = entre
func _tier_of(u, cell: int) -> int:
	var a := ap_for_move(u, reachable[cell])
	return 0 if a <= 0 else (2 if a >= u.ap else 1)

# une case appartient au palier t si atteignable<=t, OU occupée/infranchissable mais entourée (évite les trous)
func _in_reg(cid: int, t: int, tier: Dictionary, occ: Dictionary) -> bool:
	if tier.has(cid) and tier[cid] <= t: return true
	if occ.has(cid) or not mesh.passable(cid):
		for m in mesh.cells[cid].nb:
			if tier.has(m) and tier[m] <= t: return true
	return false

# ruban plat le long d'un segment (XZ), couleur unie — pour contours, chemin et liserés
func _ribbon(line: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var dir := (b - a); dir = dir.normalized() if dir.length() > 0.001 else Vector3(1, 0, 0)
	var perp := Vector3(-dir.z, 0, dir.x) * w
	for v in [a - perp, b + perp, b - perp, a - perp, a + perp, b + perp]:
		line.set_color(col); line.add_vertex(v)

# CONTOURS de déplacement (paliers imbriqués révélés jusqu'à la case survolée) + aperçu de chemin mauve
func _draw_move_overlay(u) -> void:
	var line := SurfaceTool.new(); line.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tier := {}
	for cell in reachable: tier[cell] = _tier_of(u, cell)
	var occ := _occupied()
	var hoverT := 2
	if hover_cell >= 0 and reachable.has(hover_cell): hoverT = tier[hover_cell]   # ne révèle que jusqu'au survol
	for t in range(0, hoverT + 1):
		var lc := _tier_col(t); lc.a = 1.0
		for c in mesh.cells:
			if not _in_reg(c.id, t, tier, occ): continue
			var top: float = _cell_top(c.id) + 0.06
			for nb in c.nb:
				if _in_reg(nb, t, tier, occ): continue   # arête intérieure → pas de tracé
				var seg = mesh.wall_seg.get(mesh.wkey(c.id, nb))
				if seg == null: continue
				_ribbon(line, Vector3(seg[0].x * S, top, seg[0].y * S), Vector3(seg[1].x * S, top, seg[1].y * S), 0.10, lc)
	# aperçu du chemin (mauve) vers la case survolée + liseré mauve de la case
	if hover_cell >= 0 and reachable.has(hover_cell) and hover_cell != u.cell:
		var mauve := Color(0.78, 0.49, 1.0)
		var path: Array = mesh.path_to(u.cell, hover_cell, occ)
		for i in range(1, path.size()):
			var ca = mesh.cells[path[i - 1]]; var cb = mesh.cells[path[i]]
			var pa := Vector3(ca.cx * S, _cell_top(path[i - 1]) + 0.10, ca.cy * S)
			var pb := Vector3(cb.cx * S, _cell_top(path[i]) + 0.10, cb.cy * S)
			_ribbon(line, pa, pb, 0.13, mauve)
		var hc = mesh.cells[hover_cell]; var htop: float = _cell_top(hover_cell) + 0.09
		for nb in hc.nb:
			var seg = mesh.wall_seg.get(mesh.wkey(hover_cell, nb))
			if seg == null: continue
			_ribbon(line, Vector3(seg[0].x * S, htop, seg[0].y * S), Vector3(seg[1].x * S, htop, seg[1].y * S), 0.11, mauve)
	var lm := StandardMaterial3D.new(); lm.vertex_color_use_as_albedo = true; lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lm.emission_enabled = true; lm.emission = Color(1, 1, 1); lm.emission_energy_multiplier = 0.5
	var lmi := MeshInstance3D.new(); lmi.mesh = line.commit(); lmi.material_override = lm; add_child(lmi); _markers.append(lmi)

func _update_markers() -> void:
	if fast: return
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
